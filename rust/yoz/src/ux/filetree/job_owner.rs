use super::io::Signature;
use super::jobs::TaskContext;
use super::{Entry, Filetree, Resource, resource};
use crate::ux::treeview::*;
use std::sync::{Arc, Mutex};

pub(super) struct Claim {
    pub task: TaskContext,
    pub job: u64,
    pub source: Arc<Source>,
    pub nodes: Arc<[NodeId]>,
}
impl NativeAction for Claim {
    fn bytes(&self) -> usize {
        128 + self.nodes.len() * 8
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut candidate = engine.clone();
        let task = candidate
            .states
            .get_mut(&self.task.state.id())
            .and_then(|entry| entry.task.as_mut())
            .ok_or_else(|| Error::stale("task lock expired"))?;
        task.check(self.task.lock, Some(self.task.cleanup))?;
        if task.native_job.is_some() {
            return Err(Error::new(
                ErrorCode::Busy,
                "task already has a file operation",
            ));
        }
        let prepared = &task
            .prepared
            .as_ref()
            .ok_or_else(|| Error::stale("task has no prepared sources"))?
            .1;
        let _roots = crate::ux::treeview::memory::Charge::new(task.roots.len() * 32);
        engine.memory.check()?;
        let roots: std::collections::HashSet<_> = task.roots.iter().copied().collect();
        if !Arc::ptr_eq(prepared, &self.source)
            || self.nodes.iter().any(|node| !roots.contains(node))
        {
            return Err(Error::stale(
                "operation sources are not prepared subtree roots",
            ));
        }
        if task
            .deadline
            .is_some_and(|deadline| deadline <= std::time::Instant::now())
        {
            return Err(Error::stale("source preparation deadline expired"));
        }
        task.native_job = Some(self.job);
        for work in candidate.reads.values().filter(|work| {
            !work.cancelled
                && candidate
                    .source
                    .node(work.token.node)
                    .is_some_and(|node| node.request_epoch == work.token.epoch)
        }) {
            task.bind_read(&candidate.source, work.token, work.admit_new)?;
        }
        /* Once IO owns the task, only its completion/cancellation may release this lock. */
        task.deadline = None;
        candidate.memory.check()?;
        *engine = candidate;
        Ok(Reply::NoChange)
    }
}

pub(super) struct ReleaseTask {
    pub task: TaskContext,
    pub job: Option<u64>,
}
impl NativeAction for ReleaseTask {
    fn bytes(&self) -> usize {
        128
    }
    fn control(&self) -> bool {
        true
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let task = engine
            .states
            .get(&self.task.state.id())
            .and_then(|entry| entry.task.as_ref())
            .ok_or_else(|| Error::stale("task lock expired"))?;
        /* Rejection before or during Claim can release only the exact unclaimed task.
         * Check on the owner so a competing Job cannot claim between check and release. */
        if task.lock != self.task.lock
            || task.cleanup != Some(self.task.cleanup)
            || (task.native_job.is_some() && task.native_job != self.job)
        {
            return Err(Error::stale("file operation no longer owns task"));
        }
        engine.unlock_selection(self.task.state.id(), self.task.lock)
    }
}

pub(super) fn current(source: &Source, resource: &Resource, parent: bool) -> Result<()> {
    resource.check_current(source, parent)
}

pub(super) struct Replacement {
    pub name: std::ffi::OsString,
    pub signature: Signature,
    pub node: Option<NodeId>,
}

pub(super) struct CaptureReplacement {
    pub tree: Filetree,
    pub parent: Resource,
    pub name: std::ffi::OsString,
    pub signature: Signature,
    pub result: Arc<Mutex<Option<Replacement>>>,
}
impl NativeAction for CaptureReplacement {
    fn bytes(&self) -> usize {
        256 + self.name.len()
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        current(engine.source(), &self.parent, true)?;
        let index = self
            .tree
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let node = index
            .child(Some(self.parent.node), &self.name)
            .filter(|id| {
                resource::entry(engine.source(), *id)
                    .is_ok_and(|entry| Signature::entry(&entry, false) == self.signature)
            });
        *self
            .result
            .lock()
            .unwrap_or_else(|error| error.into_inner()) = Some(Replacement {
            name: self.name,
            signature: self.signature,
            node,
        });
        Ok(Reply::NoChange)
    }
}

pub(super) struct MovedNode {
    pub node: NodeId,
    pub entry: Entry,
    pub _memory: crate::ux::treeview::memory::Charge,
}

pub(super) struct BeginMove {
    pub tree: Filetree,
    pub source: Resource,
    pub token: Option<TaskUpdateToken>,
}
impl NativeAction for BeginMove {
    fn bytes(&self) -> usize {
        128
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        current(engine.source(), &self.source, false)?;
        if let Some(token) = self.token {
            let task = engine
                .states
                .values()
                .find_map(|entry| {
                    entry.task.as_ref().filter(|task| {
                        task.expected
                            .as_ref()
                            .is_some_and(|expected| expected.token == token)
                    })
                })
                .ok_or_else(|| Error::stale("move authorization expired"))?;
            task.check(task.lock, task.cleanup)?;
        }
        let mut index = self
            .tree
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if index.moving.is_some() {
            return Err(Error::new(ErrorCode::Busy, "move already in progress"));
        }
        let mut next = index.clone();
        next.moving = Some(self.source.node);
        let reads: Vec<_> = engine
            .reads
            .values()
            .filter(|read| !read.cancelled && next.move_blocks(engine.source(), read.token.node))
            .map(|read| read.token)
            .collect();
        let mut candidate = engine.clone();
        let mut notifications = Vec::new();
        for token in reads {
            effects(
                super::reader::restart(&mut candidate, token)?,
                &mut notifications,
            );
        }
        engine.memory.check()?;
        *index = next;
        *engine = candidate;
        Ok(engine.applied(None, notifications))
    }
}

pub(super) struct EndMove {
    pub tree: Filetree,
    pub node: NodeId,
}
impl NativeAction for EndMove {
    fn bytes(&self) -> usize {
        64
    }
    fn control(&self) -> bool {
        true
    }
    fn apply(self: Box<Self>, _: &mut Engine) -> Result<Reply> {
        let mut index = self
            .tree
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if index.moving == Some(self.node) {
            index.moving = None;
        }
        Ok(Reply::NoChange)
    }
}

pub(super) struct MovedDescendants {
    pub source: Arc<Source>,
    pub entries: Vec<MovedNode>,
}

pub(super) struct Publish {
    pub tree: Filetree,
    pub source: Option<Resource>,
    pub anchor: Resource,
    pub target: Option<Resource>,
    pub entry: Option<Entry>,
    pub moved: bool,
    pub replaced: Option<Replacement>,
    pub token: Option<TaskUpdateToken>,
    pub descendants: Option<MovedDescendants>,
    pub result: Arc<Mutex<Option<Resource>>>,
}

#[derive(Clone)]
pub(super) struct CopyPublication {
    pub source: Option<Resource>,
    pub anchor: Resource,
    pub target: Resource,
    pub entry: Entry,
}

pub(super) struct PublishCopies {
    pub tree: Filetree,
    pub items: Vec<CopyPublication>,
    pub results: Arc<Mutex<Vec<Option<Error>>>>,
}

impl NativeAction for PublishCopies {
    fn bytes(&self) -> usize {
        256 + self
            .items
            .iter()
            .map(|item| 256 + item.entry.encoded_len())
            .sum::<usize>()
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut notifications = Vec::new();
        let mut results = self
            .results
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        for (item, result) in self.items.into_iter().zip(results.iter_mut()) {
            /* Each item keeps Publish's atomic validation. A stale occurrence must
             * not discard other completed IO or retain intermediate source snapshots. */
            let reply = Box::new(Publish {
                tree: self.tree.clone(),
                source: item.source,
                anchor: item.anchor,
                target: Some(item.target),
                entry: Some(item.entry),
                moved: false,
                replaced: None,
                token: None,
                descendants: None,
                result: Arc::new(Mutex::new(None)),
            })
            .apply(engine);
            match reply {
                Ok(reply) => effects(reply, &mut notifications),
                Err(error) => *result = Some(error),
            }
        }
        Ok(engine.applied(None, notifications))
    }
}

fn effects(reply: Reply, output: &mut Vec<Effect>) {
    if let Reply::Applied { effects, .. } = reply {
        output.extend(effects.iter().cloned());
    }
}
impl NativeAction for Publish {
    fn bytes(&self) -> usize {
        256 + self.entry.as_ref().map_or(0, Entry::encoded_len)
            + self.descendants.as_ref().map_or(0, |value| {
                value
                    .entries
                    .iter()
                    .map(|value| value.entry.encoded_len() + 256)
                    .sum::<usize>()
            })
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        current(engine.source(), &self.anchor, false)?;
        if let Some(source) = &self.source {
            current(engine.source(), source, false)?;
        }
        let source_node = self.source.as_ref().map(|source| source.node);
        if source_node.is_none()
            && (self.moved || self.entry.is_none() || self.descendants.is_some())
        {
            return Err(Error::invalid(
                "destructive publication needs an admitted source",
            ));
        }
        if let Some(target) = &self.target {
            current(engine.source(), target, true)?;
        }
        if !self.moved
            && source_node != Some(self.anchor.node)
            && let (Some(target), Some(entry)) = (&self.target, &self.entry)
            && entry.kind != super::Kind::Directory
            && engine
                .source()
                .node(target.node)
                .is_some_and(|node| node.completeness == Completeness::Unknown)
        {
            let unseen = {
                let index = self
                    .tree
                    .index
                    .lock()
                    .unwrap_or_else(|error| error.into_inner());
                index.child(Some(target.node), &entry.name).is_none()
                    && self
                        .replaced
                        .as_ref()
                        .is_none_or(|old| index.child(Some(target.node), &old.name).is_none())
            };
            if unseen {
                let mut candidate = engine.clone();
                candidate.unloaded_children_changed(target.node);
                let reply = candidate.request_observed_children(&[target.node], true)?;
                candidate.memory.check()?;
                *engine = candidate;
                return Ok(reply);
            }
        }
        if let Some(descendants) = &self.descendants {
            let root = source_node.expect("moved root");
            if engine
                .source()
                .node(root)
                .expect("moving root")
                .subtree_revision
                != descendants
                    .source
                    .node(root)
                    .expect("observed root")
                    .subtree_revision
                || descendants.entries.iter().any(|entry| {
                    engine.source().node(entry.node).is_none_or(|node| {
                        let before = &descendants
                            .source
                            .node(entry.node)
                            .expect("observed descendant")
                            .data
                            .payload;
                        node.data
                            .payload
                            .as_ref()
                            .zip(before.as_ref())
                            .is_none_or(|(current, before)| !Arc::ptr_eq(current, before))
                    })
                })
            {
                return Err(Error::stale(
                    "moved subtree changed during metadata observation",
                ));
            }
        }
        let task = if self.descendants.is_some() {
            self.token
                .map(|token| {
                    engine
                        .states
                        .iter()
                        .find_map(|(&id, entry)| {
                            entry
                                .task
                                .as_ref()
                                .filter(|task| {
                                    task.expected
                                        .as_ref()
                                        .is_some_and(|expected| expected.token == token)
                                })
                                .map(|task| (id, task.lock, task.cleanup.expect("prepared task")))
                        })
                        .ok_or_else(|| Error::stale("move authorization expired"))
                })
                .transpose()?
        } else {
            None
        };
        let mut candidate = engine.clone();
        let mut notifications = Vec::new();
        let mut index = self
            .tree
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let mut next = index.clone();
        let mut operations = Vec::new();
        let mut own = Vec::new();
        let key = if let Some(entry) = &self.entry {
            let parent = self.target.as_ref().expect("published destination").node;
            if let Some(replaced) = &self.replaced
                && let Some(node) = replaced.node.and_then(|id| candidate.source().node(id))
                && (node.parent != Some(parent)
                    || resource::entry(candidate.source(), node.id)?.name != replaced.name)
            {
                return Err(Error::stale(
                    "confirmed destination occurrence moved before publication",
                ));
            }
            let mut old: Vec<_> = [
                index.child(Some(parent), &entry.name),
                self.replaced
                    .as_ref()
                    .and_then(|old| index.child(Some(parent), &old.name)),
            ]
            .into_iter()
            .flatten()
            .filter(|id| Some(*id) != source_node)
            .collect();
            old.sort_unstable();
            old.dedup();
            let mut already_observed = None;
            for &id in &old {
                let observed = Signature::entry(&resource::entry(candidate.source(), id)?, false);
                if observed == Signature::entry(entry, false) {
                    if !self.moved {
                        already_observed = Some(id);
                    }
                } else if !self.replaced.as_ref().is_some_and(|replaced| {
                    replaced.signature == observed && replaced.node.is_none_or(|node| node == id)
                }) {
                    return Err(Error::stale(
                        "destination occurrence changed before result publication",
                    ));
                }
            }
            for id in old.into_iter().filter(|id| Some(*id) != already_observed) {
                let remove = Operation::Remove { node: id.into() };
                effects(
                    candidate.apply_batch(Batch {
                        base_revision: candidate.source().revision(),
                        operations: vec![remove.clone()],
                    })?,
                    &mut notifications,
                );
                operations.push(remove);
            }
            let position =
                resource::position(candidate.source(), Some(parent), entry, source_node)?;
            if self.moved {
                let data = entry.node_data();
                own.push(Operation::Reparent {
                    node: source_node.expect("admitted source").into(),
                    parent: Some(parent.into()),
                    position,
                });
                own.push(Operation::Update {
                    node: source_node.expect("admitted source").into(),
                    patch: NodePatch {
                        label: Some(data.label),
                        payload: Some(data.payload),
                        hidden: Some(data.hidden),
                        can_expand: Some(data.can_expand),
                        foldable: Some(data.foldable),
                        ..NodePatch::default()
                    },
                });
                Some(
                    engine
                        .source()
                        .node(source_node.expect("admitted source"))
                        .expect("source")
                        .key
                        .clone(),
                )
            } else if let Some(id) = already_observed {
                Some(
                    candidate
                        .source()
                        .node(id)
                        .expect("observed output")
                        .key
                        .clone(),
                )
            } else {
                let key = resource::key()?;
                let insert = Operation::Insert {
                    key: key.clone(),
                    parent: Some(parent.into()),
                    position,
                    data: entry.node_data(),
                    completeness: if entry.directory() || entry.target_unknown {
                        Completeness::Unknown
                    } else {
                        Completeness::Complete
                    },
                };
                effects(
                    candidate.apply_batch(Batch {
                        base_revision: candidate.source().revision(),
                        operations: vec![insert.clone()],
                    })?,
                    &mut notifications,
                );
                operations.push(insert);
                Some(key)
            }
        } else {
            own.push(Operation::Remove {
                node: source_node.expect("admitted source").into(),
            });
            None
        };
        if !own.is_empty() {
            let own = resource::retarget_children(candidate.source(), own)?;
            let batch = Batch {
                base_revision: candidate.source().revision(),
                operations: own.clone(),
            };
            if let Some(token) = self.token {
                effects(
                    candidate.apply_task_batch(batch, token)?,
                    &mut notifications,
                );
            } else {
                effects(candidate.apply_batch(batch)?, &mut notifications);
            }
            operations.extend(own);
        }
        if let Some(descendants) = self.descendants {
            for value in descendants.entries {
                let old = resource::entry(candidate.source(), value.node)?;
                if old == value.entry {
                    continue;
                }
                let node = candidate
                    .source()
                    .node(value.node)
                    .expect("relocated descendant");
                let parent = node.parent;
                let data = value.entry.node_data();
                let mut updates = resource::retarget_children(
                    candidate.source(),
                    vec![Operation::Update {
                        node: value.node.into(),
                        patch: NodePatch {
                            payload: Some(data.payload),
                            can_expand: Some(data.can_expand),
                            ..NodePatch::default()
                        },
                    }],
                )?;
                if old.sort_key() != value.entry.sort_key() {
                    updates.push(Operation::Reparent {
                        node: value.node.into(),
                        parent: parent.map(Into::into),
                        position: resource::position(
                            candidate.source(),
                            parent,
                            &value.entry,
                            Some(value.node),
                        )?,
                    });
                }
                let mut expected = Vec::new();
                for update in &updates {
                    match update {
                        Operation::Remove { node } => expected.push(ExpectedChange::Remove {
                            node: candidate.source().resolve(node)?,
                        }),
                        Operation::Update { patch, .. } => {
                            let completeness = patch.completeness.unwrap_or(node.completeness);
                            if data.can_expand != node.data.can_expand
                                || completeness != node.completeness
                            {
                                expected.push(ExpectedChange::Slot {
                                    node: value.node,
                                    can_expand: data.can_expand,
                                    completeness,
                                });
                            }
                        }
                        Operation::Reparent { .. } => expected.push(ExpectedChange::Reparent {
                            node: value.node,
                            parent,
                        }),
                        _ => unreachable!("relocated metadata update"),
                    }
                }
                let token = if !expected.is_empty() {
                    task.map(|(state, lock, cleanup)| {
                        candidate.authorize_task_update(state, lock, cleanup, expected.into())
                    })
                    .transpose()?
                } else {
                    None
                };
                let batch = Batch {
                    base_revision: candidate.source().revision(),
                    operations: updates.clone(),
                };
                let reply = if let Some(token) = token {
                    candidate.apply_task_batch(batch, token)?
                } else {
                    candidate.apply_batch(batch)?
                };
                effects(reply, &mut notifications);
                operations.extend(updates);
            }
        }
        next.update(engine.source(), candidate.source(), &operations)?;
        engine.memory.check()?;
        let result = key
            .and_then(|key| candidate.source().id(&key))
            .map(|node| Resource {
                node,
                source: candidate.source().clone(),
            });
        *self
            .result
            .lock()
            .unwrap_or_else(|error| error.into_inner()) = result;
        *index = next;
        *engine = candidate;
        Ok(engine.applied(None, notifications))
    }
}

pub(super) struct FinishMove {
    pub tree: Filetree,
    pub source: Resource,
    pub target: Resource,
    pub parent: NodeId,
    pub entry: Entry,
    pub token: Option<TaskUpdateToken>,
    pub children: Vec<NodeId>,
}
impl NativeAction for FinishMove {
    fn bytes(&self) -> usize {
        256 + self.entry.encoded_len() + self.children.len() * 16
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        current(engine.source(), &self.source, false)?;
        current(engine.source(), &self.target, true)?;
        if !engine
            .source()
            .node(self.target.node)
            .expect("target directory")
            .children()
            .eq(self.children.iter().copied())
        {
            return Err(Error::stale("moved directory membership changed"));
        }
        let mut candidate = engine.clone();
        let mut notifications = Vec::new();
        let mut operations = vec![Operation::Reparent {
            node: self.source.node.into(),
            parent: Some(self.parent.into()),
            position: resource::position(
                candidate.source(),
                Some(self.parent),
                &self.entry,
                Some(self.target.node),
            )?,
        }];
        for node in self.children {
            operations.push(Operation::Reparent {
                node: node.into(),
                parent: Some(self.source.node.into()),
                position: Position::Last,
            });
        }
        let data = self.entry.node_data();
        operations.push(Operation::Update {
            node: self.source.node.into(),
            patch: NodePatch {
                label: Some(data.label),
                payload: Some(data.payload),
                hidden: Some(data.hidden),
                ..NodePatch::default()
            },
        });
        let batch = Batch {
            base_revision: candidate.source().revision(),
            operations: operations.clone(),
        };
        if let Some(token) = self.token {
            effects(
                candidate.apply_task_batch(batch, token)?,
                &mut notifications,
            );
        } else {
            effects(candidate.apply_batch(batch)?, &mut notifications);
        }
        let remove = Operation::Remove {
            node: self.target.node.into(),
        };
        effects(
            candidate.apply_batch(Batch {
                base_revision: candidate.source().revision(),
                operations: vec![remove.clone()],
            })?,
            &mut notifications,
        );
        operations.push(remove);
        let mut index = self
            .tree
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let mut next = index.clone();
        next.update(engine.source(), candidate.source(), &operations)?;
        engine.memory.check()?;
        *index = next;
        *engine = candidate;
        Ok(engine.applied(None, notifications))
    }
}

pub(super) struct Metadata {
    pub target: Resource,
    pub entry: Entry,
}
impl NativeAction for Metadata {
    fn bytes(&self) -> usize {
        128 + self.entry.encoded_len()
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        current(engine.source(), &self.target, true)?;
        let old = resource::entry(engine.source(), self.target.node)?;
        if old == self.entry {
            return Ok(Reply::NoChange);
        }
        if old != self.target.entry()? {
            return Err(Error::stale(
                "destination metadata changed before result publication",
            ));
        }
        engine.apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Update {
                node: self.target.node.into(),
                patch: NodePatch {
                    payload: Some(self.entry.node_data().payload),
                    ..NodePatch::default()
                },
            }],
        })
    }
}
