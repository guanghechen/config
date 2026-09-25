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
        let requested: HashSet<_> = self
            .manual_reads
            .iter()
            .chain(self.observed_reads.iter())
            .chain(self.leased_reads.values())
            .chain(ids.iter())
            .copied()
            .collect();
        if requested.len() > self.limits.queued_reads {
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
                let epoch = node.request_epoch;
                node.request_epoch = node
                    .request_epoch
                    .checked_add(1)
                    .ok_or_else(|| Error::limit("request epoch exhausted"))?;
                let next = node
                    .request_epoch
                    .checked_add(1)
                    .ok_or_else(|| Error::limit("request epoch exhausted"))?;
                for entry in candidate.states.values_mut() {
                    if let Some(task) = &mut entry.task {
                        task.restart_read(id, epoch, next);
                    }
                }
                node.load_state = LoadState::Idle;
                node.error = None;
                source.nodes.insert(id, node);
                candidate.source = Arc::new(source);
            }
            candidate.observed_reads.remove(&id);
            candidate.manual_reads.insert(id);
        }
        let effects = candidate.schedule_reads()?;
        *self = candidate;
        Ok(self.applied(None, effects))
    }

    pub(crate) fn lease_children(&mut self, node: NodeId) -> Result<(u64, Reply)> {
        if self.leased_reads.len() >= 16 {
            return Err(Error::limit("native read lease capacity exceeded"));
        }
        let mut candidate = self.clone();
        let manual = candidate.manual_reads.contains(&node);
        let observed = candidate.observed_reads.contains(&node);
        let retry = candidate
            .source
            .node(node)
            .ok_or_else(|| Error::missing(node))?
            .load_state
            != LoadState::Loading;
        let lease = identity()?;
        let reply = candidate.request_children(&[node], retry)?;
        candidate.leased_reads.insert(lease, node);
        if !manual {
            candidate.manual_reads.remove(&node);
        }
        if observed {
            candidate.observed_reads.insert(node);
        }
        *self = candidate;
        Ok((lease, reply))
    }

    pub(crate) fn release_read_lease(&mut self, lease: u64) {
        self.leased_reads.remove(&lease);
    }

    /** Native task discovery joins the ordinary epoch and page protocol. */
    pub(crate) fn prepare_task_read(
        &mut self,
        state: u64,
        lock: super::tasks::LockToken,
        cleanup: super::tasks::CleanupToken,
        parent: NodeId,
    ) -> Result<Reply> {
        let _memory = self.memory.enter();
        let mut candidate = self.clone();
        let node = candidate
            .source
            .node(parent)
            .ok_or_else(|| Error::missing(parent))?;
        let admit_new = node.completeness != Completeness::Complete;
        let retry = node.load_state != LoadState::Loading;
        let task = candidate
            .states
            .get_mut(&state)
            .and_then(|entry| entry.task.as_mut())
            .ok_or_else(|| Error::stale("task lock expired"))?;
        task.check(lock, Some(cleanup))?;
        if task.source_root(parent).is_none() {
            return Err(Error::stale("directory is outside prepared task roots"));
        }
        if !task.needed.contains(&parent) {
            let mut needed = task.needed.to_vec();
            needed.push(parent);
            task.needed = needed.into();
        }
        let reply = candidate.request_observed_children(&[parent], retry)?;
        let node = candidate
            .source
            .node(parent)
            .expect("requested task directory");
        let epoch = if node.load_state == LoadState::Loading {
            node.request_epoch
        } else {
            node.request_epoch
                .checked_add(1)
                .ok_or_else(|| Error::limit("children epoch exhausted"))?
        };
        candidate
            .states
            .get_mut(&state)
            .and_then(|entry| entry.task.as_mut())
            .expect("task")
            .grant_read(&candidate.source, parent, epoch, admit_new)?;
        candidate.memory.check()?;
        *self = candidate;
        Ok(reply)
    }

    /** Observer refreshes remain subscribed only while a view or preparing task needs them. */
    pub(crate) fn request_observed_children(
        &mut self,
        nodes: &[NodeId],
        retry: bool,
    ) -> Result<Reply> {
        let nodes: Vec<_> = nodes
            .iter()
            .copied()
            .filter(|id| self.observed_interest(*id))
            .collect();
        let manual = self.manual_reads.clone();
        let reply = self.request_children(&nodes, retry)?;
        for id in nodes {
            if !manual.contains(&id) {
                self.manual_reads.remove(&id);
                self.observed_reads.insert(id);
            }
        }
        Ok(reply)
    }

    pub(crate) fn observed_interest(&self, node: NodeId) -> bool {
        self.states.values().any(|entry| {
            (entry.views != 0 && entry.state.observes_children(&self.source, node))
                || entry
                    .task
                    .as_ref()
                    .is_some_and(|task| task.valid && task.needed.contains(&node))
        })
    }

    pub(crate) fn needed(&self, node: NodeId) -> bool {
        self.manual_reads.contains(&node)
            || self.leased_reads.values().any(|id| *id == node)
            || (self.observed_reads.contains(&node) && self.observed_interest(node))
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
                    current_read.then_some(id),
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
        let expired: Vec<_> = self
            .observed_reads
            .iter()
            .copied()
            .filter(|id| {
                !self.observed_interest(*id)
                    || self
                        .source
                        .node(*id)
                        .is_none_or(|node| !node.data.can_expand)
            })
            .collect();
        for id in expired {
            self.observed_reads.remove(&id);
        }
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
            let manual = self.manual_reads.contains(&id)
                || self.observed_reads.contains(&id)
                || self.leased_reads.values().any(|node| *node == id);
            if self.source.node(id).is_some_and(|node| {
                node.data.can_expand
                    && node.load_state != LoadState::Error
                    && (manual || node.completeness != Completeness::Complete)
            }) {
                queued.insert(id);
                self.read_queue.push_back(id);
            }
        };
        for id in self
            .manual_reads
            .iter()
            .chain(self.observed_reads.iter())
            .chain(self.leased_reads.values())
            .copied()
        {
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
                || (node.completeness == Completeness::Complete
                    && !self.manual_reads.contains(&id)
                    && !self.observed_reads.contains(&id)
                    && !self.leased_reads.values().any(|node| *node == id))
            {
                continue;
            }
            /* Reconcile requested ancestors before descendants reserve read slots. */
            if (!self.manual_reads.is_empty() || !self.observed_reads.is_empty())
                && std::iter::successors(node.parent, |parent| {
                    self.source.node(*parent).and_then(|node| node.parent)
                })
                .any(|parent| {
                    self.manual_reads.contains(&parent) || self.observed_reads.contains(&parent)
                })
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
        let members = records
            .iter()
            .map(|record| self.source.id(&record.key).expect("accepted record"))
            .collect();
        effects.extend(self.finish_children_page(token, sequence, members, done, false)?);
        Ok(effects)
    }

    /** Native providers have already aligned direct children and their sibling order. */
    pub(crate) fn children_delta(
        &mut self,
        token: ReadToken,
        sequence: u64,
        operations: Vec<super::data::Operation>,
        members: Vec<Arc<str>>,
        done: bool,
    ) -> Result<Reply> {
        if let Err(error) = self.check_read(token, sequence) {
            self.retire_stale_read(token);
            return Err(error);
        }
        let mut candidate = self.clone();
        let result: Result<Vec<Effect>> = (|| {
            let _memory = candidate.memory.enter();
            let mut effects = candidate
                .apply_operations(
                    Batch {
                        base_revision: candidate.source.revision(),
                        operations,
                    },
                    Some(token.node),
                    None,
                )?
                .into_effects();
            let members = members
                .iter()
                .map(|key| {
                    let id = candidate
                        .source
                        .id(key)
                        .ok_or_else(|| Error::invalid("missing native page member"))?;
                    if candidate
                        .source
                        .node(id)
                        .is_none_or(|node| node.parent != Some(token.node))
                    {
                        return Err(Error::invalid("native page member outside slot"));
                    }
                    Ok(id)
                })
                .collect::<Result<Vec<_>>>()?;
            effects.extend(candidate.finish_children_page(token, sequence, members, done, true)?);
            candidate.memory.check()?;
            Ok(effects)
        })();
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

    fn finish_children_page(
        &mut self,
        token: ReadToken,
        sequence: u64,
        members: Vec<NodeId>,
        done: bool,
        preserve_order: bool,
    ) -> Result<Vec<Effect>> {
        let _memory = self.memory.enter();
        let mut effects = Vec::new();
        let work = self.reads.get_mut(&token.work).expect("validated read");
        let mut additions = Vec::new();
        for id in members {
            if work.received.position(&id).is_none() {
                additions.push(id);
            }
        }
        work.received
            .splice(work.received.len(), work.received.len(), additions)?;
        if done {
            let operations = if preserve_order {
                self.source
                    .node(token.node)
                    .expect("validated slot")
                    .children()
                    .filter(|id| work.received.position(id).is_none())
                    .map(|id| super::data::Operation::Remove { node: id.into() })
                    .collect()
            } else {
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
                let scope = DataScope::Children(token.node);
                let protected: Vec<_> = self
                    .providers
                    .values()
                    .map(|provider| provider.scope)
                    .filter(|protected| !scope.overlaps(*protected, &self.source))
                    .collect();
                plan_import(
                    &self.source,
                    scope,
                    &records,
                    true,
                    false,
                    &self.limits,
                    &protected,
                )?
            };
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
            for entry in self.states.values_mut() {
                if let Some(task) = &mut entry.task {
                    task.finish_read(token);
                }
            }
            self.reads.remove(&token.work);
            self.manual_reads.remove(&token.node);
            self.observed_reads.remove(&token.node);
            self.leased_reads.retain(|_, node| *node != token.node);
            self.memory.check()?;
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
            self.observed_reads.remove(&token.node);
        }
        self.memory.check()?;
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
            if self
                .source
                .node(token.node)
                .is_none_or(|node| !node.data.can_expand)
            {
                self.manual_reads.remove(&token.node);
                self.observed_reads.remove(&token.node);
                self.leased_reads.retain(|_, node| *node != token.node);
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
        candidate.observed_reads.remove(&token.node);
        candidate.leased_reads.retain(|_, node| *node != token.node);
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
        if current
            || self
                .source
                .node(token.node)
                .is_none_or(|node| !node.data.can_expand)
        {
            self.manual_reads.remove(&token.node);
            self.observed_reads.remove(&token.node);
            self.leased_reads.retain(|_, node| *node != token.node);
        }
        Ok(self.applied(None, vec![]))
    }
}
