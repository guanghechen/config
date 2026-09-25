use super::index::Index;
use super::work::{Demand, Dirty, Request, wait};
use super::{Entry, Resource, reader, resource};
use crate::ux::treeview::storage::Map;
use crate::ux::treeview::*;
use std::path::{Component, Path, PathBuf};
use std::sync::{Arc, Mutex};

#[derive(Clone)]
pub struct Filetree {
    interest: Arc<Mutex<super::watch::Interest>>,
    data: DataHandle,
    root: NodeId,
    pub(super) index: Arc<Mutex<Index>>,
    dirty: Dirty,
    pub(super) annotations: Arc<Mutex<super::annotations::Annotations>>,
}

fn observe(path: &Path) -> Result<Vec<Entry>> {
    let mut path = std::path::absolute(path)
        .map_err(|error| resource::io_error("resolve absolute path", error))?;
    if path.components().any(|part| part == Component::ParentDir) {
        let mut resolved = PathBuf::new();
        for component in path.components() {
            resolved.push(component);
            if component == Component::ParentDir {
                resolved = std::fs::canonicalize(&resolved)
                    .map_err(|error| resource::io_error("resolve parent components", error))?;
            }
        }
        path = resolved;
    }
    let mut prefix = PathBuf::new();
    let mut entries = Vec::new();
    let mut ancestors = Vec::new();
    for component in path.components() {
        prefix.push(component);
        #[cfg(windows)]
        if matches!(component, Component::Prefix(_)) {
            continue;
        }
        let mut entry = Entry::read(&prefix)
            .map_err(|error| resource::io_error("resolve path component", error))?;
        #[cfg(any(target_os = "macos", windows))]
        {
            entry.name = resource::observed_name(&prefix)?;
        }
        if entries.is_empty() {
            entry.anchor = Some(prefix.clone());
        }
        entry.cycle = entry
            .target_identity()
            .is_some_and(|identity| ancestors.contains(&identity));
        if let Some(identity) = entry.target_identity() {
            ancestors.push(identity);
        }
        entries.push(entry);
    }
    if entries.is_empty() {
        return Err(Error::invalid("path has no filesystem root"));
    }
    Ok(entries)
}

impl Filetree {
    pub fn open(path: PathBuf) -> Request<Self> {
        Request::run(move || {
            let entries = observe(&path)?;
            if !entries.last().is_some_and(Entry::directory) {
                return Err(Error::invalid("Filetree root is not a browsable directory"));
            }
            let index = Arc::new(Mutex::new(Index::default()));
            let dirty = Arc::new(Mutex::new(Map::default()));
            let interest = Arc::new(Mutex::new(super::watch::Interest::default()));
            let reader = reader::Reader::new(index.clone(), dirty.clone(), interest.clone());
            let data = DataHandle::with_reader(
                Limits {
                    concurrent_reads: 4,
                    queued_reads: 256,
                    ..Limits::default()
                },
                Some(Box::new(reader)),
            )?;
            let (source, before) = {
                let index = index.lock().unwrap_or_else(|error| error.into_inner());
                (data.source(), index.clone())
            };
            let resolved = Arc::new(Mutex::new(None));
            wait(data.submit(Action::Native(Box::new(Install {
                source,
                before,
                entries,
                index: index.clone(),
                resolved: resolved.clone(),
            }))))?;
            let root = resolved
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .as_ref()
                .map(|resource| resource.node)
                .ok_or_else(|| Error::invalid("missing resolved resource"))?;
            Ok(Self {
                interest,
                data,
                root,
                index,
                dirty,
                annotations: Arc::new(Mutex::new(super::annotations::Annotations::default())),
            })
        })
    }
    pub fn watch_status(&self) -> super::WatchStatus {
        self.interest
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .status
            .clone()
    }
    pub(crate) fn set_viewports(&self, viewports: Vec<super::watch::Viewport>) -> Result<()> {
        if viewports.len() > self.data.limits().views {
            return Err(Error::invalid("invalid Filetree viewport hints"));
        }
        let mut interest = self
            .interest
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        interest.version = interest
            .version
            .checked_add(1)
            .ok_or_else(|| Error::limit("watch interest revision exhausted"))?;
        interest.viewports = viewports;
        Ok(())
    }
    pub fn data(&self) -> &DataHandle {
        &self.data
    }
    pub fn root(&self) -> NodeId {
        self.root
    }
    pub fn source(&self) -> Arc<Source> {
        self.data.source()
    }
    pub fn inspect(&self, source: Arc<Source>, node: NodeId) -> Result<Resource> {
        if source.identity() != self.source().identity() {
            return Err(Error::invalid(
                "resource source belongs to another Filetree",
            ));
        }
        resource::entry(&source, node)?;
        Ok(Resource { source, node })
    }
    pub fn create_state(&self, root: Option<Root>, display: DisplayOptions) -> Ticket {
        self.data.submit(Action::CreateState(
            root.unwrap_or(Root::ChildrenOf(self.root)),
            DisplayOptions {
                list_text: ListText::Ancestry,
                sort: Sort::Source,
                branches_first: false,
                ..display
            },
        ))
    }
    pub fn resolve(&self, path: PathBuf) -> Request<Resource> {
        let this = self.clone();
        Request::run(move || {
            let (source, before) = {
                let index = this.index.lock().unwrap_or_else(|error| error.into_inner());
                (this.source(), index.clone())
            };
            let entries = observe(&path)?;
            let resolved = Arc::new(Mutex::new(None));
            wait(this.data.submit(Action::Native(Box::new(Install {
                source,
                before,
                entries,
                index: this.index.clone(),
                resolved: resolved.clone(),
            }))))?;
            resolved
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .clone()
                .ok_or_else(|| Error::invalid("missing resolved resource"))
        })
    }
    pub fn refresh(&self, state: &StateHandle) -> Result<Ticket> {
        if state.data().source().identity() != self.source().identity() {
            return Err(Error::invalid("state belongs to another Filetree"));
        }
        {
            let mut interest = self
                .interest
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            interest.version = interest
                .version
                .checked_add(1)
                .ok_or_else(|| Error::limit("watch interest revision exhausted"))?;
        }
        Ok(state.submit(Action::Native(Box::new(Refresh {
            state: state.id(),
            dirty: self.dirty.clone(),
        }))))
    }
}

struct Install {
    source: Arc<Source>,
    before: Index,
    entries: Vec<Entry>,
    index: Arc<Mutex<Index>>,
    resolved: Arc<Mutex<Option<Resource>>>,
}
impl NativeAction for Install {
    fn bytes(&self) -> usize {
        self.entries
            .iter()
            .map(|entry| entry.encode().len() + 256)
            .sum()
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let _memory = engine.memory.enter();
        let mut index = self.index.lock().unwrap_or_else(|error| error.into_inner());
        let mut next = index.clone();
        let mut candidate = engine.clone();
        let mut parent_id = None;
        let mut before_parent = None;
        let mut parent = None;
        let mut operations = Vec::new();
        let mut last = None;
        let count = self.entries.len();
        let same_route = |before: &Entry, current: &Entry| {
            before.identity == current.identity
                && before.kind == current.kind
                && before.name == current.name
                && before.anchor == current.anchor
                && before.target_unknown == current.target_unknown
                && !resource::ends_children(before, current)
        };
        for (offset, mut entry) in self.entries.into_iter().enumerate() {
            let old = if parent.is_none() || parent_id.is_some() {
                index.child(parent_id, &entry.name)
            } else {
                None
            };
            let expected = if parent.is_none() || before_parent.is_some() {
                self.before.child(before_parent, &entry.name)
            } else {
                None
            };
            let previous = expected
                .filter(|id| self.source.contains(*id))
                .map(|id| resource::entry(&self.source, id))
                .transpose()?;
            let current = old
                .map(|id| resource::entry(engine.source(), id))
                .transpose()?;
            let same_parent = expected
                .and_then(|id| self.source.node(id))
                .zip(old.and_then(|id| engine.source().node(id)))
                .is_some_and(|(before, current)| before.parent == current.parent);
            if let Some(current) = &current {
                if current.identity == entry.identity && current.kind == entry.kind {
                    entry.retain_unknown_target(current);
                }
            }
            let unchanged = match (expected, old) {
                (Some(before), Some(now)) => {
                    before == now
                        && resource::unchanged(
                            &self.source,
                            engine.source(),
                            now,
                            current.as_ref().is_some_and(|current| {
                                current.identity != entry.identity
                                    || current.kind != entry.kind
                                    || resource::ends_children(current, &entry)
                            }),
                        )
                }
                (None, None) => match (before_parent, parent_id) {
                    (Some(before), Some(current)) if before == current => self
                        .source
                        .node(before)
                        .zip(engine.source().node(current))
                        .is_some_and(|(before, current)| {
                            before.subtree_revision == current.subtree_revision
                        }),
                    (None, None) if parent.is_some() => true,
                    (None, None) => {
                        self.source.ancestry_revision == engine.source().ancestry_revision
                    }
                    _ => false,
                },
                _ => false,
            };
            if !unchanged && current.as_ref() != Some(&entry) {
                /* Unrelated ancestor metadata may advance while this path is observed. */
                if offset + 1 < count
                    && expected == old
                    && same_parent
                    && previous
                        .as_ref()
                        .zip(current.as_ref())
                        .is_some_and(|(before, current)| {
                            same_route(before, current) && same_route(&entry, current)
                        })
                {
                    entry = current.clone().expect("validated ancestor");
                } else {
                    return Err(Error::stale("resource path changed during resolve"));
                }
            }
            let existing = old.filter(|id| {
                resource::entry(engine.source(), *id)
                    .is_ok_and(|old| old.identity == entry.identity && old.kind == entry.kind)
            });
            let mut ends_children = false;
            let key = if let Some(id) = existing {
                let node = engine.source().node(id).expect("indexed resource");
                let old = resource::entry(engine.source(), id)?;
                ends_children = resource::ends_children(&old, &entry);
                if old != entry {
                    let data = entry.node_data();
                    operations.push(Operation::Update {
                        node: id.into(),
                        patch: NodePatch {
                            label: Some(data.label),
                            fields: Some(data.fields),
                            hidden: Some(data.hidden),
                            can_expand: Some(data.can_expand),
                            foldable: Some(data.foldable),
                            completeness: entry.target_unknown.then_some(Completeness::Partial),
                            ..NodePatch::default()
                        },
                    });
                    if old.sort_key() != entry.sort_key() {
                        operations.push(Operation::Reparent {
                            node: id.into(),
                            parent: parent.clone(),
                            position: resource::position(
                                engine.source(),
                                parent_id,
                                &entry,
                                Some(id),
                            )?,
                        });
                    }
                }
                node.key.clone()
            } else {
                if let Some(id) = old {
                    operations.push(Operation::Remove { node: id.into() });
                }
                let key = resource::key()?;
                operations.push(Operation::Insert {
                    key: key.clone(),
                    parent: parent.clone(),
                    position: resource::position(engine.source(), parent_id, &entry, old)?,
                    data: entry.node_data(),
                    completeness: if entry.directory() || entry.target_unknown {
                        Completeness::Unknown
                    } else {
                        Completeness::Complete
                    },
                });
                key
            };
            /* A retarget keeps the link key, but the rest of this path belongs to new children. */
            parent_id = existing.filter(|_| !ends_children);
            before_parent = expected.filter(|_| existing.is_some() && !ends_children);
            parent = Some(NodeRef::Key(key.clone()));
            last = Some(key);
        }
        let operations = resource::retarget_children(engine.source(), operations)?;
        let reply = candidate.apply_batch(Batch {
            base_revision: candidate.source().revision(),
            operations: operations.clone(),
        })?;
        next.update(engine.source(), candidate.source(), &operations)?;
        engine.memory.check()?;
        *self
            .resolved
            .lock()
            .unwrap_or_else(|error| error.into_inner()) = last
            .and_then(|key| candidate.source().id(&key))
            .map(|node| Resource {
                source: candidate.source().clone(),
                node,
            });
        *index = next;
        *engine = candidate;
        Ok(reply)
    }
}

struct Refresh {
    state: u64,
    dirty: Dirty,
}
impl NativeAction for Refresh {
    fn bytes(&self) -> usize {
        64
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let _memory = engine.memory.enter();
        let state = &engine
            .states
            .get(&self.state)
            .ok_or_else(|| Error::invalid("state released"))?
            .state;
        let mut pending = match &state.root {
            Root::ChildrenOf(root) => vec![*root],
            _ => state.display_roots(engine.source()),
        };
        let mut dirty = self.dirty.lock().unwrap_or_else(|error| error.into_inner());
        let mut next = dirty.clone();
        let generation = resource::sequence()?;
        while let Some(id) = pending.pop() {
            if !state.demands_children(engine.source(), id) {
                if state.root == Root::ChildrenOf(id)
                    && resource::entry(engine.source(), id)
                        .is_ok_and(|entry| entry.kind == super::Kind::Link)
                {
                    next.insert(
                        id,
                        Demand {
                            generation,
                            observed: false,
                        },
                    );
                }
                continue;
            }
            next.insert(
                id,
                Demand {
                    generation,
                    observed: false,
                },
            );
            pending.extend(engine.source().node(id).expect("refresh node").children());
        }
        engine.memory.check()?;
        *dirty = next;
        Ok(Reply::NoChange)
    }
}

#[cfg(test)]
mod tests;
