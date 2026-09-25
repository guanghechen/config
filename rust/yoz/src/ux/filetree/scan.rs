use super::resource;
use super::{Entry, FileIdentity};
use crate::ux::treeview::memory::{Budget, Charge};
use crate::ux::treeview::{
    Completeness, Error, NodePatch, NodeRef, Operation, Position, Result, Source,
};
use std::collections::{BTreeMap, HashMap, HashSet, VecDeque};
use std::ffi::OsString;
use std::fs::{self, ReadDir};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

pub(crate) const PAGE_ITEMS: usize = 512;
pub(crate) const PAGE_BYTES: usize = 1024 * 1024;
const STAGING_BYTES: usize = 32 * PAGE_BYTES;
type SortKey = (bool, Vec<u8>, Vec<u8>);

/** Scan indices and pending observations are bounded separately and by the owner's total. */
pub(crate) struct Reservation {
    budget: Arc<Budget>,
    staging: Arc<AtomicUsize>,
    bytes: usize,
    charges: Vec<Charge>,
}

impl Reservation {
    pub fn new(budget: Arc<Budget>, staging: Arc<AtomicUsize>) -> Self {
        Self {
            budget,
            staging,
            bytes: 0,
            charges: Vec::new(),
        }
    }
    pub fn add(&mut self, bytes: usize) -> Result<()> {
        self.staging
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |used| {
                used.checked_add(bytes)
                    .filter(|used| *used <= STAGING_BYTES)
            })
            .map_err(|_| Error::limit("Filetree scan staging capacity exceeded"))?;
        self.bytes += bytes;
        let _guard = self.budget.enter();
        self.charges.push(Charge::new(bytes));
        self.budget.check()
    }
}
impl Drop for Reservation {
    fn drop(&mut self) {
        self.staging.fetch_sub(self.bytes, Ordering::Relaxed);
    }
}

pub(crate) struct Page {
    pub source: Arc<Source>,
    pub operations: Vec<Operation>,
    pub members: Vec<Arc<str>>,
    pub done: bool,
    pub path: PathBuf,
    pub identity: FileIdentity,
    pub target: Option<FileIdentity>,
    pub bytes: usize,
    pub _reservation: Reservation,
}

struct Known {
    key: Arc<str>,
    identity: FileIdentity,
    data: Arc<crate::ux::treeview::NodeData>,
}

pub(crate) struct Scan {
    /* Every page uses the same alignment baseline, including deferred observations. */
    source: Arc<Source>,
    path: PathBuf,
    directory: Entry,
    ancestors: Vec<FileIdentity>,
    iterator: ReadDir,
    old: HashMap<OsString, Known>,
    old_identity: HashMap<FileIdentity, Vec<OsString>>,
    observed: HashMap<FileIdentity, usize>,
    names: HashSet<OsString>,
    order: BTreeMap<SortKey, Arc<str>>,
    deferred: VecDeque<Entry>,
    carry: Option<Entry>,
    exhausted: bool,
    reservation: Reservation,
}

impl Scan {
    pub fn new(
        source: &Arc<Source>,
        node: crate::ux::treeview::NodeId,
        mut reservation: Reservation,
    ) -> Result<Self> {
        let path = resource::path(source, node)?;
        let directory = resource::entry(source, node)?;
        let current =
            Entry::read(&path).map_err(|error| resource::io_error("open directory", error))?;
        if directory.target_unknown {
            std::fs::metadata(&path)
                .map_err(|error| resource::io_error("read symlink target", error))?;
        }
        if !directory.directory() {
            return Err(Error::new(
                crate::ux::treeview::ErrorCode::ProviderError,
                "symlink target is not a readable directory",
            ));
        }
        if current.identity != directory.identity
            || current.target_identity() != directory.target_identity()
            || current.target_unknown != directory.target_unknown
        {
            return Err(Error::stale(
                "directory identity changed before enumeration",
            ));
        }
        let iterator =
            fs::read_dir(&path).map_err(|error| resource::io_error("read directory", error))?;
        let ancestors = resource::ancestors(source, node)?;
        let mut old = HashMap::new();
        let mut old_identity: HashMap<FileIdentity, Vec<OsString>> = HashMap::new();
        let mut order = BTreeMap::new();
        reservation.add(path.as_os_str().len() + ancestors.len() * 32 + 1024)?;
        for id in source
            .node(node)
            .ok_or_else(|| Error::missing(node))?
            .children()
        {
            let entry = resource::entry(source, id)?;
            let key = source.node(id).expect("source child").key.clone();
            reservation.add(entry.name.len() * 5 + key.len() + 384)?;
            order.insert(entry.sort_key(), key.clone());
            old_identity
                .entry(entry.identity)
                .or_default()
                .push(entry.name.clone());
            old.insert(
                entry.name.clone(),
                Known {
                    key,
                    identity: entry.identity,
                    data: source.node(id).expect("source child").data.clone(),
                },
            );
        }
        Ok(Self {
            source: source.clone(),
            path,
            directory,
            ancestors,
            iterator,
            old,
            old_identity,
            observed: HashMap::new(),
            names: HashSet::new(),
            order,
            deferred: VecDeque::new(),
            carry: None,
            exhausted: false,
            reservation,
        })
    }

    pub fn context(&self) -> (PathBuf, FileIdentity) {
        (self.path.clone(), self.directory.identity)
    }

    pub fn page(
        &mut self,
        node: crate::ux::treeview::NodeId,
        mut reservation: Reservation,
        cancelled: &AtomicBool,
    ) -> Result<Page> {
        let current = Entry::read(&self.path)
            .map_err(|error| resource::io_error("verify directory", error))?;
        if current.identity != self.directory.identity
            || current.target_identity() != self.directory.target_identity()
        {
            return Err(Error::stale("directory replaced during enumeration"));
        }
        let mut page = Page {
            source: self.source.clone(),
            operations: Vec::new(),
            members: Vec::new(),
            done: false,
            path: self.path.clone(),
            identity: current.identity,
            target: current.target_identity(),
            bytes: 0,
            _reservation: Reservation::new(reservation.budget.clone(), reservation.staging.clone()),
        };
        let mut count = 0;
        let mut observations = Vec::new();
        while count < PAGE_ITEMS {
            if cancelled.load(Ordering::Acquire) {
                return Err(Error::stale("directory scan cancelled"));
            }
            let entry = if let Some(entry) = self.carry.take() {
                entry
            } else if self.exhausted {
                let Some(entry) = self.deferred.pop_front() else {
                    break;
                };
                entry
            } else {
                match self.iterator.next() {
                    Some(item) => {
                        let item =
                            item.map_err(|error| resource::io_error("enumerate directory", error))?;
                        let mut entry = Entry::read(&item.path())
                            .map_err(|error| resource::io_error("read entry metadata", error))?;
                        if entry.target_unknown {
                            if let Some(old) = self.old.get(&entry.name) {
                                let old =
                                    Entry::from_fields(&old.data.fields).map_err(|error| {
                                        resource::io_error("decode old resource", error)
                                    })?;
                                entry.retain_unknown_target(&old);
                            }
                        }
                        entry.cycle = entry
                            .target_identity()
                            .is_some_and(|id| self.ancestors.contains(&id));
                        self.reservation.add(entry.name.len() + 128)?;
                        if !self.names.insert(entry.name.clone()) {
                            return Err(Error::stale(
                                "directory changed during enumeration: duplicate name",
                            ));
                        }
                        *self.observed.entry(entry.identity).or_default() += 1;
                        if self
                            .old
                            .get(&entry.name)
                            .is_some_and(|old| old.identity != entry.identity)
                            || (!self.old.contains_key(&entry.name)
                                && self.old_identity.contains_key(&entry.identity))
                        {
                            self.reservation.add(entry.encode().len() + 128)?;
                            self.deferred.push_back(entry);
                            count += 1;
                            continue;
                        }
                        entry
                    }
                    None => {
                        self.exhausted = true;
                        let identities = &self.old_identity;
                        let observed = &self.observed;
                        self.deferred.make_contiguous().sort_by_key(|entry| {
                            !identities.get(&entry.identity).is_some_and(|names| {
                                names.len() == 1
                                    && names[0] != entry.name
                                    && observed.get(&entry.identity) == Some(&1)
                            })
                        });
                        continue;
                    }
                }
            };
            let size = entry.encode().len() * 2 + entry.name.len() * 8 + 1024;
            if size > PAGE_BYTES {
                return Err(Error::limit("filesystem entry exceeds page byte capacity"));
            }
            if page.bytes + size > PAGE_BYTES {
                self.carry = Some(entry);
                break;
            }
            reservation.add(size)?;
            page.bytes += size;
            count += 1;
            observations.push((entry.sort_key(), entry));
        }
        let renamed = |entry: &Entry| {
            self.exhausted
                && self.observed.get(&entry.identity) == Some(&1)
                && self
                    .old_identity
                    .get(&entry.identity)
                    .is_some_and(|names| names.len() == 1 && names[0] != entry.name)
        };
        observations.sort_unstable_by(|a, b| {
            renamed(&b.1)
                .cmp(&renamed(&a.1))
                .then_with(|| a.0.cmp(&b.0))
        });
        for (sort, entry) in observations {
            let mut old = if self.exhausted && self.observed.get(&entry.identity) == Some(&1) {
                self.old_identity
                    .get(&entry.identity)
                    .filter(|names| names.len() == 1)
                    .and_then(|names| self.old.remove(&names[0]))
            } else {
                None
            };
            if old.is_none() {
                old = self.old.remove(&entry.name);
            }
            let key = if let Some(old) = old {
                let old_entry = Entry::from_fields(&old.data.fields)
                    .map_err(|error| resource::io_error("decode old resource", error))?;
                let old_sort = old_entry.sort_key();
                if self.order.get(&old_sort) == Some(&old.key) {
                    self.order.remove(&old_sort);
                }
                if old_entry.identity == entry.identity && old_entry.kind == entry.kind {
                    if old_entry != entry {
                        let data = entry.node_data();
                        page.operations.push(Operation::Update {
                            node: NodeRef::Key(old.key.clone()),
                            patch: NodePatch {
                                label: Some(data.label),
                                fields: Some(data.fields),
                                can_expand: Some(data.can_expand),
                                foldable: Some(data.foldable),
                                hidden: Some(data.hidden),
                                completeness: entry.target_unknown.then_some(Completeness::Partial),
                                ..NodePatch::default()
                            },
                        });
                    }
                    if old_sort != sort {
                        page.operations.push(Operation::Reparent {
                            node: NodeRef::Key(old.key.clone()),
                            parent: Some(node.into()),
                            position: self.position(&sort),
                        });
                    }
                    old.key
                } else {
                    page.operations.push(Operation::Remove {
                        node: NodeRef::Key(old.key),
                    });
                    self.insert(node, &entry, &sort, &mut page.operations)?
                }
            } else {
                self.insert(node, &entry, &sort, &mut page.operations)?
            };
            self.order.insert(sort, key.clone());
            page.members.push(key);
        }
        page.done = self.exhausted && self.deferred.is_empty() && self.carry.is_none();
        page._reservation = reservation;
        Ok(page)
    }

    fn position(&self, sort: &SortKey) -> Position {
        self.order
            .range((std::ops::Bound::Included(sort), std::ops::Bound::Unbounded))
            .next()
            .map_or(Position::Last, |(_, key)| {
                Position::Before(NodeRef::Key(key.clone()))
            })
    }

    fn insert(
        &mut self,
        parent: crate::ux::treeview::NodeId,
        entry: &Entry,
        sort: &SortKey,
        operations: &mut Vec<Operation>,
    ) -> Result<Arc<str>> {
        let key = resource::key()?;
        self.reservation
            .add(entry.name.len() * 2 + key.len() + 192)?;
        operations.push(Operation::Insert {
            key: key.clone(),
            parent: Some(parent.into()),
            position: self.position(sort),
            data: entry.node_data(),
            completeness: if entry.directory() || entry.target_unknown {
                Completeness::Unknown
            } else {
                Completeness::Complete
            },
        });
        Ok(key)
    }
}
