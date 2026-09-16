use super::command::{Effect, Reply};
use super::data::{Batch, Change, ChangeKind};
use super::engine::Engine;
use super::model::*;
use super::provider::{DataScope, Record, plan_import};
use super::storage::IndexedSequence;
use std::collections::HashSet;
use std::sync::Arc;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ReadToken {
    pub(crate) data: u64,
    pub(crate) work: u64,
    pub node: NodeId,
    pub epoch: u64,
}

#[derive(Clone)]
pub(crate) struct ReadWork {
    pub token: ReadToken,
    pub received: IndexedSequence<NodeId>,
    pub cancelled: bool,
}

impl Engine {
    pub fn request_children(&mut self, nodes: &[NodeId], retry: bool) -> Result<Reply> {
        let ids: HashSet<_> = nodes.iter().copied().collect();
        if ids.is_empty() {
            return Ok(Reply::NoChange);
        }
        if self.manual_reads.len() + ids.len() > self.limits.queued_reads {
            return Err(Error::limit("explicit children request capacity exceeded"));
        }
        for id in &ids {
            if self.query_for_slot(*id).is_some() {
                return Err(Error::invalid(
                    "query-owned slots are refreshed through their query session",
                ));
            }
            let node = self.source.node(*id).ok_or_else(|| Error::missing(*id))?;
            if !node.data.can_expand {
                return Err(Error::invalid("leaf has no children slot"));
            }
            if !retry && let Some(error) = &node.error {
                return Err(error.clone());
            }
        }
        let mut candidate = self.clone();
        for id in ids {
            if retry {
                candidate.set_slot(id, None, LoadState::Idle, None, None)?;
                let mut source = (*candidate.source).clone();
                let mut node = source.node(id).expect("validated request").clone();
                node.request_epoch = node
                    .request_epoch
                    .checked_add(1)
                    .ok_or_else(|| Error::limit("request epoch exhausted"))?;
                node.load_state = LoadState::Idle;
                node.error = None;
                source.nodes.insert(id, node);
                candidate.source = Arc::new(source);
            }
            candidate.manual_reads.insert(id);
        }
        let effects = candidate.schedule_reads()?;
        *self = candidate;
        Ok(self.applied(None, effects))
    }

    pub(crate) fn needed(&self, node: NodeId) -> bool {
        self.manual_reads.contains(&node)
            || self.states.values().any(|entry| {
                (entry.views != 0
                    && entry.frame.needed_children.contains(&node)
                    && (!entry.dirty.layout || entry.state.demands_children(&self.source, node)))
                    || entry
                        .task
                        .as_ref()
                        .is_some_and(|task| task.valid && task.needed.contains(&node))
            })
    }

    pub(crate) fn set_slot(
        &mut self,
        id: NodeId,
        completeness: Option<Completeness>,
        loading: LoadState,
        error: Option<Error>,
        sequence: Option<u64>,
    ) -> Result<()> {
        let _memory = self.memory.enter();
        let revision = self.source.revision().next()?;
        let commit = self.commit.next()?;
        let mut source = (*self.source).clone();
        let mut node = source.node(id).ok_or_else(|| Error::missing(id))?.clone();
        let structural = completeness.is_some_and(|value| node.completeness != value);
        if let Some(completeness) = completeness {
            node.completeness = completeness;
        }
        node.load_state = loading;
        node.error = error;
        if let Some(sequence) = sequence {
            node.next_sequence = sequence;
        }
        node.modified = revision;
        let parent = node.parent;
        source.nodes.insert(id, node);
        source.revision = revision;
        if structural {
            source.touch_ancestors(Some(id), revision)?;
        }
        let change = Change {
            kind: if structural {
                ChangeKind::Completeness
            } else {
                ChangeKind::Loading
            },
            node: Some(id),
            old_parent: parent,
            new_parent: parent,
            removed: Arc::new([]),
        };
        let mut states = self.states.clone();
        let current_read = self.reads.values().any(|work| {
            !work.cancelled
                && work.token.node == id
                && source
                    .node(id)
                    .is_some_and(|node| node.request_epoch == work.token.epoch)
        });
        for entry in states.values_mut() {
            entry.state.changed_source(&source, &change)?;
            entry.state.finish_source_batch(&source, structural)?;
            if let Some(task) = &mut entry.task {
                task.changed(
                    &self.source,
                    &source,
                    &change,
                    false,
                    current_read && task.needed.contains(&id),
                );
            }
            entry.dirty.pending = true;
            entry.dirty.layout |= structural;
            entry.dirty.changes.push(change.clone());
        }
        self.source = Arc::new(source);
        self.states = states;
        self.commit = commit;
        Ok(())
    }

    pub(crate) fn work_count(&self) -> usize {
        self.reads.len() + self.query_work.len()
    }

    pub(crate) fn schedule_reads(&mut self) -> Result<Vec<Effect>> {
        let mut effects = Vec::new();
        for work in self.reads.values_mut() {
            if !work.cancelled
                && !self
                    .source
                    .node(work.token.node)
                    .is_some_and(|node| node.request_epoch == work.token.epoch)
            {
                work.cancelled = true;
                effects.push(Effect::CancelChildren { token: work.token });
            }
        }
        let mut queued: HashSet<_> = self.read_queue.iter().copied().collect();
        let active: HashSet<_> = self
            .reads
            .values()
            .filter(|work| !work.cancelled)
            .map(|work| work.token.node)
            .collect();
        let query_scopes: Vec<_> = self
            .queries
            .values()
            .filter_map(|query| {
                self.providers
                    .get(&query.info.provider.0)
                    .map(|provider| provider.scope)
            })
            .collect();
        let mut consider = |id: NodeId| {
            if query_scopes.iter().any(|scope| match scope {
                DataScope::Forest => true,
                DataScope::Children(root) => *root == id,
                DataScope::Descendants(root) => self.source.within(*root, id),
            }) {
                return;
            }
            if queued.len() >= self.limits.queued_reads
                || queued.contains(&id)
                || active.contains(&id)
            {
                return;
            }
            let manual = self.manual_reads.contains(&id);
            if self.source.node(id).is_some_and(|node| {
                node.data.can_expand
                    && node.load_state != LoadState::Error
                    && (manual || node.completeness != Completeness::Complete)
            }) {
                queued.insert(id);
                self.read_queue.push_back(id);
            }
        };
        for id in self.manual_reads.iter().copied() {
            consider(id);
        }
        for entry in self.states.values() {
            if let Some(task) = &entry.task
                && task.valid
            {
                for id in task.needed.iter().copied() {
                    consider(id);
                }
            }
            if entry.views != 0 {
                for id in entry.frame.needed_children.iter().copied() {
                    consider(id);
                }
            }
        }
        while self.work_count() < self.limits.concurrent_reads {
            let Some(id) = self.read_queue.pop_front() else {
                break;
            };
            if !self.needed(id) {
                continue;
            }
            let Some(node) = self.source.node(id) else {
                self.manual_reads.remove(&id);
                continue;
            };
            if node.load_state == LoadState::Error
                || (node.completeness == Completeness::Complete && !self.manual_reads.contains(&id))
            {
                continue;
            }
            let token = ReadToken {
                data: self.source.identity(),
                work: identity()?,
                node: id,
                epoch: node
                    .request_epoch
                    .checked_add(1)
                    .ok_or_else(|| Error::limit("request epoch exhausted"))?,
            };
            let mut source = (*self.source).clone();
            let mut node = node.clone();
            node.request_epoch = token.epoch;
            source.nodes.insert(id, node);
            self.source = Arc::new(source);
            self.set_slot(id, None, LoadState::Loading, None, Some(1))?;
            self.reads.insert(
                token.work,
                ReadWork {
                    token,
                    received: IndexedSequence::default(),
                    cancelled: false,
                },
            );
            effects.push(Effect::NeedChildren { token, sequence: 1 });
        }
        Ok(effects)
    }

    pub(crate) fn check_read(&self, token: ReadToken, sequence: u64) -> Result<()> {
        if token.data != self.source.identity() {
            return Err(Error::stale("children token belongs to another data owner"));
        }
        let work = self
            .reads
            .get(&token.work)
            .filter(|work| work.token == token && !work.cancelled)
            .ok_or_else(|| Error::stale("children request is no longer active"))?;
        let node = self
            .source
            .node(work.token.node)
            .ok_or_else(|| Error::missing(token.node))?;
        if node.request_epoch != token.epoch
            || node.next_sequence != sequence
            || node.load_state != LoadState::Loading
        {
            return Err(Error::stale("children epoch or page sequence changed"));
        }
        Ok(())
    }

    pub fn children_page(
        &mut self,
        token: ReadToken,
        sequence: u64,
        records: Vec<Record>,
        done: bool,
    ) -> Result<Reply> {
        if let Err(error) = self.check_read(token, sequence) {
            self.retire_stale_read(token);
            return Err(error);
        }
        let mut candidate = self.clone();
        let result = candidate.apply_children_page(token, sequence, &records, done);
        match result {
            Ok(effects) => {
                *self = candidate;
                Ok(self.applied(None, effects))
            }
            Err(error) => {
                if let Reply::Applied { effects, .. } =
                    self.children_failed(token, sequence, error.clone())?
                {
                    self.deferred_effects.extend(effects.iter().cloned());
                }
                Err(error)
            }
        }
    }

    fn apply_children_page(
        &mut self,
        token: ReadToken,
        sequence: u64,
        records: &[Record],
        done: bool,
    ) -> Result<Vec<Effect>> {
        let scope = DataScope::Children(token.node);
        let protected: Vec<_> = self
            .providers
            .values()
            .map(|provider| provider.scope)
            .filter(|protected| !scope.overlaps(*protected, &self.source))
            .collect();
        let operations = plan_import(
            &self.source,
            scope,
            records,
            false,
            false,
            &self.limits,
            &protected,
        )?;
        let mut effects = self
            .apply_operations(
                Batch {
                    base_revision: self.source.revision(),
                    operations,
                },
                Some(token.node),
                None,
            )?
            .into_effects();
        let work = self.reads.get_mut(&token.work).expect("validated read");
        let mut additions = Vec::new();
        for record in records {
            let id = self.source.id(&record.key).expect("accepted record");
            if work.received.position(&id).is_none() {
                additions.push(id);
            }
        }
        work.received
            .splice(work.received.len(), work.received.len(), additions)?;
        if done {
            let records: Vec<_> = work
                .received
                .iter()
                .map(|id| {
                    let node = self.source.node(*id).expect("current request member");
                    Record {
                        key: node.key.clone(),
                        parent: None,
                        data: (*node.data).clone(),
                        completeness: Some(node.completeness),
                    }
                })
                .collect();
            let operations = plan_import(
                &self.source,
                scope,
                &records,
                true,
                false,
                &self.limits,
                &protected,
            )?;
            effects.extend(
                self.apply_operations(
                    Batch {
                        base_revision: self.source.revision(),
                        operations,
                    },
                    Some(token.node),
                    None,
                )?
                .into_effects(),
            );
            self.set_slot(
                token.node,
                Some(Completeness::Complete),
                LoadState::Idle,
                None,
                None,
            )?;
            self.reads.remove(&token.work);
            self.manual_reads.remove(&token.node);
            return Ok(effects);
        }
        let next = sequence
            .checked_add(1)
            .ok_or_else(|| Error::limit("children page sequence exhausted"))?;
        self.set_slot(
            token.node,
            Some(Completeness::Partial),
            LoadState::Loading,
            None,
            Some(next),
        )?;
        if self.needed(token.node) {
            effects.push(Effect::NeedChildren {
                token,
                sequence: next,
            });
        } else {
            self.set_slot(token.node, None, LoadState::Idle, None, None)?;
            self.reads.remove(&token.work);
        }
        Ok(effects)
    }

    fn retire_stale_read(&mut self, token: ReadToken) {
        let stale = self.reads.get(&token.work).is_some_and(|work| {
            work.token == token
                && (work.cancelled
                    || !self
                        .source
                        .node(token.node)
                        .is_some_and(|node| node.request_epoch == token.epoch))
        });
        if stale {
            self.reads.remove(&token.work);
            if !self.source.contains(token.node) {
                self.manual_reads.remove(&token.node);
            }
        }
    }

    pub fn children_failed(
        &mut self,
        token: ReadToken,
        sequence: u64,
        error: Error,
    ) -> Result<Reply> {
        if let Err(stale) = self.check_read(token, sequence) {
            self.retire_stale_read(token);
            return Err(stale);
        }
        let mut candidate = self.clone();
        candidate.set_slot(
            token.node,
            None,
            LoadState::Error,
            Some(error.clone()),
            None,
        )?;
        candidate.reads.remove(&token.work);
        candidate.manual_reads.remove(&token.node);
        let failed: Vec<_> = candidate
            .states
            .iter()
            .filter_map(|(&id, entry)| {
                entry
                    .task
                    .as_ref()
                    .filter(|task| task.cleanup.is_none() && task.needed.contains(&token.node))
                    .map(|task| (id, task.lock))
            })
            .collect();
        let mut effects = Vec::new();
        for (id, lock) in failed {
            effects.push(candidate.fail_task(id, lock, error.clone())?);
        }
        *self = candidate;
        Ok(self.applied(None, effects))
    }

    pub fn children_cancelled(&mut self, token: ReadToken) -> Result<Reply> {
        if !self
            .reads
            .get(&token.work)
            .is_some_and(|work| work.token == token)
        {
            return Err(Error::stale("children work already ended"));
        }
        let current = self
            .source
            .node(token.node)
            .is_some_and(|node| node.request_epoch == token.epoch);
        if current {
            self.set_slot(token.node, None, LoadState::Idle, None, None)?;
        }
        self.reads.remove(&token.work);
        self.manual_reads.remove(&token.node);
        Ok(self.applied(None, vec![]))
    }
}
