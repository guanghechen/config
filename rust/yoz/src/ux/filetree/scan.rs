use super::resource;
use super::{Entry, FileIdentity};
use crate::ux::treeview::memory::Budget;
use crate::ux::treeview::{
    Completeness, Error, NodePatch, NodeRef, Operation, Position, Result, Source,
};
use std::collections::{BTreeMap, HashSet, VecDeque};
use std::ffi::OsString;
use std::fs::{self, ReadDir};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

mod known;
use known::Known;

#[cfg(test)]
mod tests;

pub(crate) const PAGE_ITEMS: usize = 512;
pub(crate) const PAGE_BYTES: usize = 1024 * 1024;
const FOLLOWUP_ITEMS: usize = 4 * PAGE_ITEMS;
const FOLLOWUP_BYTES: usize = 4 * PAGE_BYTES;
const STAGING_BYTES: usize = 32 * PAGE_BYTES;
type SortKey = (bool, Vec<u8>, Vec<u8>);

/** Scan indices and pending observations are bounded separately and by the owner's total. */
pub(crate) struct Reservation {
    budget: Arc<Budget>,
    staging: Arc<AtomicUsize>,
    bytes: usize,
}

impl Reservation {
    pub fn new(budget: Arc<Budget>, staging: Arc<AtomicUsize>) -> Self {
        Self {
            budget,
            staging,
            bytes: 0,
        }
    }
    pub fn add(&mut self, bytes: usize) -> Result<()> {
        self.staging
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |used| {
                used.checked_add(bytes)
                    .filter(|used| *used <= STAGING_BYTES)
            })
            .map_err(|_| Error::limit("Filetree scan staging capacity exceeded"))?;
        self.bytes += bytes;
        self.budget.add(bytes);
        self.budget.check()
    }

    fn absorb(&mut self, mut other: Self) {
        debug_assert!(Arc::ptr_eq(&self.budget, &other.budget));
        debug_assert!(Arc::ptr_eq(&self.staging, &other.staging));
        self.bytes += other.bytes;
        other.bytes = 0;
    }
}
impl Drop for Reservation {
    fn drop(&mut self) {
        self.staging.fetch_sub(self.bytes, Ordering::Relaxed);
        self.budget.remove(self.bytes);
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

struct Observation {
    entry: Entry,
    named: Option<usize>,
    renamed: bool,
    reservation: Reservation,
}

pub(crate) struct Scan {
    /* Every page uses the same alignment baseline, including deferred observations. */
    known: Known,
    path: PathBuf,
    directory: Entry,
    #[cfg(any(target_os = "macos", target_os = "linux"))]
    hidden: super::io::staging::Filter,
    ancestors: Vec<FileIdentity>,
    iterator: ReadDir,
    names: HashSet<OsString>,
    order: BTreeMap<SortKey, Arc<str>>,
    deferred: VecDeque<Observation>,
    carry: Option<Observation>,
    exhausted: bool,
    first_page: bool,
    reservation: Reservation,
}

impl Scan {
    pub fn new(
        source: &Arc<Source>,
        node: crate::ux::treeview::NodeId,
        mut reservation: Reservation,
        cancelled: &AtomicBool,
    ) -> Result<Self> {
        if cancelled.load(Ordering::Acquire) {
            return Err(Error::stale("directory scan cancelled"));
        }
        let path = resource::path(source, node)?;
        let directory = resource::entry(source, node)?;
        let current = super::io::browse_entry(&path)
            .map_err(|error| resource::io_error("open directory", error))?;
        super::io::browse_directory(&current)
            .map_err(|error| resource::io_error("open directory", error))?;
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
        #[cfg(any(target_os = "macos", target_os = "linux"))]
        let hidden =
            super::io::staging::Filter::new(current.target_identity().expect("directory identity"));
        let iterator =
            fs::read_dir(&path).map_err(|error| resource::io_error("read directory", error))?;
        let ancestors = resource::ancestors(source, node)?;
        reservation.add(
            path.as_os_str().len()
                + directory.encoded_len()
                + ancestors.capacity() * std::mem::size_of::<FileIdentity>()
                + std::mem::size_of::<Self>()
                + 256,
        )?;
        let known = Known::new(source.clone(), node, &mut reservation, cancelled)?;
        Ok(Self {
            known,
            path,
            directory,
            #[cfg(any(target_os = "macos", target_os = "linux"))]
            hidden,
            ancestors,
            iterator,
            names: HashSet::new(),
            order: BTreeMap::new(),
            deferred: VecDeque::new(),
            carry: None,
            exhausted: false,
            first_page: true,
            reservation,
        })
    }

    pub fn context(&self) -> (PathBuf, FileIdentity) {
        (self.path.clone(), self.directory.identity)
    }

    fn verify_directory(&self) -> Result<Entry> {
        let current = super::io::browse_entry(&self.path)
            .map_err(|error| resource::io_error("verify directory", error))?;
        if current.identity != self.directory.identity
            || current.target_identity() != self.directory.target_identity()
        {
            return Err(Error::stale("directory replaced during enumeration"));
        }
        Ok(current)
    }

    pub fn page(
        &mut self,
        node: crate::ux::treeview::NodeId,
        mut reservation: Reservation,
        cancelled: &AtomicBool,
    ) -> Result<Page> {
        let current = self.verify_directory()?;
        reservation.add(self.path.as_os_str().len() + std::mem::size_of::<Page>())?;
        let mut page = Page {
            source: self.known.source.clone(),
            operations: Vec::new(),
            members: Vec::new(),
            done: false,
            path: self.path.clone(),
            identity: current.identity,
            target: current.target_identity(),
            bytes: 0,
            _reservation: reservation,
        };
        let mut count = 0;
        let mut vanished = false;
        let mut observations = Vec::new();
        /* Keep the first screen prompt, then amortize scattered insertion/index work.
         * All pages still share the same bounded scan staging ledger. */
        let headroom = STAGING_BYTES
            .saturating_sub(self.reservation.staging.load(Ordering::Relaxed))
            .min(self.reservation.budget.remaining());
        let (items, bytes) = if !self.first_page && headroom >= 2 * FOLLOWUP_BYTES {
            (FOLLOWUP_ITEMS, FOLLOWUP_BYTES)
        } else {
            (PAGE_ITEMS, PAGE_BYTES)
        };
        self.first_page = false;
        while count < items {
            if cancelled.load(Ordering::Acquire) {
                return Err(Error::stale("directory scan cancelled"));
            }
            let observation = if let Some(observation) = self.carry.take() {
                observation
            } else if self.exhausted {
                let Some(observation) = self.deferred.pop_front() else {
                    break;
                };
                observation
            } else {
                match self.iterator.next() {
                    Some(item) => {
                        let item =
                            item.map_err(|error| resource::io_error("enumerate directory", error))?;
                        #[cfg(any(target_os = "macos", target_os = "linux"))]
                        let observed = self.hidden.read(&item.path());
                        #[cfg(not(any(target_os = "macos", target_os = "linux")))]
                        let observed = Entry::read(&item.path()).map(Some);
                        let mut entry = match observed {
                            Ok(Some(entry)) => entry,
                            Ok(None) => {
                                count += 1;
                                continue;
                            }
                            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                                /* A directory iterator can retain names removed by a concurrent
                                 * rename. The final membership pass retires their old occurrences. */
                                count += 1;
                                vanished = true;
                                continue;
                            }
                            Err(error) => {
                                return Err(resource::io_error("read entry metadata", error));
                            }
                        };
                        let named = self.known.named(&entry)?;
                        if entry.target_unknown
                            && let Some(ordinal) = named
                        {
                            entry.retain_unknown_target(&self.known.entry(ordinal)?);
                        }
                        entry.cycle = entry
                            .target_identity()
                            .is_some_and(|id| self.ancestors.contains(&id));
                        let size = entry.encoded_len() * 2 + entry.name.len() * 8 + 1024;
                        if size > PAGE_BYTES {
                            return Err(Error::limit(
                                "filesystem entry exceeds page byte capacity",
                            ));
                        }
                        let mut held = Reservation::new(
                            self.reservation.budget.clone(),
                            self.reservation.staging.clone(),
                        );
                        held.add(entry.encoded_len() + 64)?;
                        let fresh = if let Some(ordinal) = named {
                            self.known.observe_name(ordinal)
                        } else {
                            self.reservation.add(entry.name.len() + 64)?;
                            self.names.insert(entry.name.clone())
                        };
                        if !fresh {
                            return Err(Error::stale(
                                "directory changed during enumeration: duplicate name",
                            ));
                        }
                        let old_identity = self.known.observe_identity(entry.identity);
                        let defer = if let Some(ordinal) = named {
                            self.known.entry(ordinal)?.identity != entry.identity
                        } else {
                            old_identity
                        };
                        let observation = Observation {
                            entry,
                            named,
                            renamed: false,
                            reservation: held,
                        };
                        if defer {
                            self.defer(observation)?;
                            count += 1;
                            continue;
                        }
                        observation
                    }
                    None => {
                        self.exhausted = true;
                        for observation in &mut self.deferred {
                            if cancelled.load(Ordering::Acquire) {
                                return Err(Error::stale("directory scan cancelled"));
                            }
                            observation.renamed = self.known.renamed(&observation.entry)?;
                        }
                        self.deferred
                            .make_contiguous()
                            .sort_unstable_by_key(|observation| !observation.renamed);
                        continue;
                    }
                }
            };
            let mut observation = observation;
            let size =
                (observation.entry.encoded_len() * 2 + observation.entry.name.len() * 8 + 1024)
                    .max(observation.reservation.bytes);
            if page.bytes + size > bytes {
                self.carry = Some(observation);
                break;
            }
            /* Deferred/carry entries own only their observation; page output is admitted when consumed. */
            observation
                .reservation
                .add(size - observation.reservation.bytes)?;
            page.bytes += size;
            count += 1;
            observations.push((observation.entry.sort_key(), observation));
        }
        if vanished {
            /* Missing children must not turn a removed/replaced directory into empty success. */
            self.verify_directory()?;
        }
        observations
            .sort_unstable_by(|a, b| b.1.renamed.cmp(&a.1.renamed).then_with(|| a.0.cmp(&b.0)));
        for (sort, observation) in observations {
            let Observation {
                entry,
                named,
                reservation,
                ..
            } = observation;
            let mut old = if self.exhausted {
                self.known
                    .unique(entry.identity)
                    .and_then(|ordinal| self.known.take(ordinal))
            } else {
                None
            };
            if old.is_none() {
                old = named.and_then(|ordinal| self.known.take(ordinal));
            }
            let (key, reordered) = if let Some(ordinal) = old {
                let old_entry = self.known.entry(ordinal)?;
                let id = self.known.node(ordinal);
                let key = self
                    .known
                    .source
                    .node(id)
                    .expect("captured child")
                    .key
                    .clone();
                if old_entry.identity == entry.identity && old_entry.kind == entry.kind {
                    if old_entry != entry {
                        let data = entry.node_data();
                        page.operations.push(Operation::Update {
                            node: NodeRef::Key(key.clone()),
                            patch: NodePatch {
                                label: Some(data.label),
                                payload: Some(data.payload),
                                can_expand: Some(data.can_expand),
                                foldable: Some(data.foldable),
                                hidden: Some(data.hidden),
                                completeness: entry.target_unknown.then_some(Completeness::Partial),
                                ..NodePatch::default()
                            },
                        });
                    }
                    let reordered = old_entry.sort_cmp(&entry).is_ne();
                    if reordered {
                        self.known.retire(ordinal);
                        self.reserve_order(&entry, &key)?;
                        page.operations.push(Operation::Reparent {
                            node: NodeRef::Key(key.clone()),
                            parent: Some(node.into()),
                            position: self.position(&entry, &sort)?,
                        });
                    }
                    (key, reordered)
                } else {
                    self.known.retire(ordinal);
                    page.operations.push(Operation::Remove {
                        node: NodeRef::Key(key),
                    });
                    (
                        self.insert(node, &entry, &sort, &mut page.operations)?,
                        true,
                    )
                }
            } else {
                (
                    self.insert(node, &entry, &sort, &mut page.operations)?,
                    true,
                )
            };
            if reordered {
                self.order.insert(sort, key.clone());
            }
            page.members.push(key);
            page._reservation.absorb(reservation);
        }
        page.done = self.exhausted && self.deferred.is_empty() && self.carry.is_none();
        Ok(page)
    }

    fn defer(&mut self, observation: Observation) -> Result<()> {
        if self.deferred.len() == self.deferred.capacity() {
            let capacity = self.deferred.capacity();
            let growth = capacity.max(4);
            let item_bytes = std::mem::size_of::<Observation>();
            /* The deque retains popped slots until Scan drops; only payload charges follow pages. */
            self.reservation.add(growth * item_bytes)?;
            self.deferred
                .try_reserve_exact(growth)
                .map_err(|_| Error::limit("Filetree deferred scan allocation failed"))?;
            let extra = self.deferred.capacity() - capacity - growth;
            if extra != 0 {
                self.reservation.add(extra * item_bytes)?;
            }
        }
        self.deferred.push_back(observation);
        Ok(())
    }

    fn position(&self, entry: &Entry, sort: &SortKey) -> Result<Position> {
        let ordinal = self.known.lower_bound(entry.directory(), &entry.name)?;
        let old = self.known.next(ordinal);
        let changed = self
            .order
            .range((std::ops::Bound::Included(sort), std::ops::Bound::Unbounded))
            .next();
        let key = match (old, changed) {
            (Some(ordinal), Some((changed_sort, key)))
                if self.known.entry(ordinal)?.sort_key() >= *changed_sort =>
            {
                Some(NodeRef::Key(key.clone()))
            }
            (Some(ordinal), _) => Some(self.known.node(ordinal).into()),
            (None, Some((_, key))) => Some(NodeRef::Key(key.clone())),
            (None, None) => None,
        };
        Ok(key.map_or(Position::Last, Position::Before))
    }

    fn reserve_order(&mut self, entry: &Entry, key: &str) -> Result<()> {
        self.reservation.add(entry.name.len() * 2 + key.len() + 192)
    }

    fn insert(
        &mut self,
        parent: crate::ux::treeview::NodeId,
        entry: &Entry,
        sort: &SortKey,
        operations: &mut Vec<Operation>,
    ) -> Result<Arc<str>> {
        let key = resource::key()?;
        self.reserve_order(entry, &key)?;
        operations.push(Operation::Insert {
            key: key.clone(),
            parent: Some(parent.into()),
            position: self.position(entry, sort)?,
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
