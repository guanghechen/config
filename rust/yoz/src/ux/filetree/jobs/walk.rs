use super::*;
use std::collections::VecDeque;
use std::fs::{self, ReadDir};
use std::ops::Deref;

const LOOKAHEAD: usize = 4;

fn directory_error(operation: &str, error: std::io::Error) -> Error {
    match error.kind() {
        std::io::ErrorKind::AlreadyExists
        | std::io::ErrorKind::NotFound
        | std::io::ErrorKind::NotADirectory => Error::stale(format!(
            "{operation}: directory identity changed or disappeared"
        )),
        _ => resource::io_error(operation, error),
    }
}

/** Ordinary cleanup identities use three words rather than retaining a full Entry or Source. */
pub(super) enum CapturedSignature {
    Plain { identity: [u64; 3], kind: Kind },
    Link(Box<Signature>),
}

impl CapturedSignature {
    pub fn new(entry: &Entry) -> Self {
        if entry.kind == Kind::Link {
            Self::Link(Box::new(Signature::entry(entry, false)))
        } else {
            Self::Plain {
                identity: [
                    entry.identity.volume,
                    entry.identity.file as u64,
                    (entry.identity.file >> 64) as u64,
                ],
                kind: entry.kind,
            }
        }
    }
    pub fn matches(&self, entry: &Entry) -> bool {
        match self {
            Self::Plain { identity, kind } => {
                *kind == entry.kind
                    && identity[0] == entry.identity.volume
                    && identity[1] == entry.identity.file as u64
                    && identity[2] == (entry.identity.file >> 64) as u64
            }
            Self::Link(signature) => signature.as_ref() == &Signature::entry(entry, false),
        }
    }
    pub fn extra_bytes(&self) -> usize {
        match self {
            Self::Plain { .. } => 0,
            Self::Link(signature) => std::mem::size_of::<Signature>() + 32 + signature.link_bytes(),
        }
    }
}

pub(super) struct Witness {
    pub parent: Arc<Origin>,
    pub signature: Option<CapturedSignature>,
}

/** A captured directory chain contains no browse Source and can outlive the Job in results. */
pub(super) struct Origin {
    pub id: ItemId,
    pub root: NodeId,
    pub node: Option<NodeId>,
    pub parent: Option<Arc<Origin>>,
    pub path: PathBuf,
    pub signature: Signature,
    pub discover: bool,
    ancestors: Arc<[super::super::FileIdentity]>,
    _memory: Reservation,
}

impl Origin {
    pub(super) fn cycle(&self, entry: &Entry) -> bool {
        entry.target_identity().is_some_and(|identity| {
            self.ancestors.contains(&identity)
                || std::iter::successors(Some(self), |origin| origin.parent.as_deref())
                    .any(|origin| origin.signature.identity == identity)
        })
    }
}

pub(super) struct Captured {
    pub id: ItemId,
    pub root: NodeId,
    pub parent: Option<Arc<Origin>>,
    pub path: PathBuf,
    pub entry: Entry,
    _memory: Reservation,
}

#[derive(Clone)]
pub(super) struct Item {
    captured: Arc<Captured>,
    pub resource: Option<Resource>,
}

impl Deref for Item {
    type Target = Captured;
    fn deref(&self) -> &Captured {
        &self.captured
    }
}

impl Item {
    pub fn new(
        id: ItemId,
        root: NodeId,
        parent: Option<Arc<Origin>>,
        path: PathBuf,
        entry: Entry,
        resource: Option<Resource>,
        memory: &Arc<Memory>,
    ) -> Result<Self> {
        let reservation =
            memory.reserve(1024 + path.as_os_str().len() * 2 + entry.encoded_len() * 2)?;
        Ok(Self {
            captured: Arc::new(Captured {
                id,
                root,
                parent,
                path,
                entry,
                _memory: reservation,
            }),
            resource,
        })
    }
    pub fn node(&self) -> Option<NodeId> {
        self.resource.as_ref().map(|resource| resource.node)
    }
    pub fn bound(&self) -> Result<&Resource> {
        self.resource
            .as_ref()
            .ok_or_else(|| Error::invalid("operation needs an admitted occurrence"))
    }
    pub fn path(&self) -> Result<PathBuf> {
        Ok(self.path.clone())
    }
    pub fn entry(&self) -> Result<Entry> {
        Ok(self.entry.clone())
    }

    pub fn parent_signature(&self, roots: &Source) -> Result<Option<Signature>> {
        if let Some(parent) = &self.parent {
            return Ok(Some(parent.signature.clone()));
        }
        roots
            .node(self.root)
            .and_then(|node| node.parent)
            .map(|node| resource::entry(roots, node).map(|entry| Signature::entry(&entry, true)))
            .transpose()
    }

    pub fn current(&self, current: &Source, roots: &Arc<Source>) -> Result<()> {
        let root = Resource {
            node: self.root,
            source: roots.clone(),
        };
        job_owner::current(current, &root, false)?;
        if let Some(resource) = &self.resource {
            job_owner::current(current, resource, false)?;
        }
        Ok(())
    }

    fn validate_scope(&self, source: &Source, scope: &NativeTaskStatus) -> Result<()> {
        if self.resource.is_some() || !scope.has_closed_slots() {
            return Ok(());
        }
        let mut chain: Vec<_> =
            std::iter::successors(self.parent.as_deref(), |origin| origin.parent.as_deref())
                .collect();
        let root = chain
            .pop()
            .ok_or_else(|| Error::stale("private item has no prepared root"))?;
        let root_node = root
            .node
            .ok_or_else(|| Error::stale("private origin has no prepared occurrence"))?;
        if resource::path(source, root_node)? != root.path
            || Signature::entry(&resource::entry(source, root_node)?, true) != root.signature
        {
            return Err(Error::stale("private traversal root changed"));
        }
        let mut parent = root_node;
        let mut captured_parent = root;
        for origin in chain.into_iter().rev() {
            let name = origin.path.file_name().expect("private directory basename");
            let node = match origin.node {
                Some(node) => {
                    if source
                        .node(node)
                        .is_none_or(|node| node.parent != Some(parent))
                    {
                        return Err(Error::stale("captured traversal occurrence disappeared"));
                    }
                    Some(node)
                }
                None => resource::child(source, parent, name)?,
            };
            let Some(node) = node else {
                if scope.closed(parent)
                    || !captured_parent.discover
                    || source.node(parent).unwrap().completeness == Completeness::Complete
                {
                    return Err(Error::stale(
                        "private directory is outside the discovery scope",
                    ));
                }
                /* No deeper browse occurrence can exist below an unmaterialized parent. */
                return Ok(());
            };
            let entry = resource::entry(source, node)?;
            if entry.name != name || Signature::entry(&entry, true) != origin.signature {
                return Err(Error::stale("private traversal ancestor changed"));
            }
            parent = node;
            captured_parent = origin;
        }
        if let Some(node) = resource::child(source, parent, &self.entry.name)? {
            if Signature::entry(&resource::entry(source, node)?, false)
                != Signature::entry(&self.entry, false)
            {
                return Err(Error::stale("private traversal item changed"));
            }
        } else if scope.closed(parent)
            || !captured_parent.discover
            || source.node(parent).unwrap().completeness == Completeness::Complete
        {
            return Err(Error::stale("private item is outside the discovery scope"));
        }
        Ok(())
    }
}

struct Observed {
    path: PathBuf,
    entry: Entry,
    resource: Option<Resource>,
    position: Option<usize>,
}

/** Bounded filesystem enumeration; a small bitset verifies the originally loaded members. */
pub(super) struct Cursor {
    pub origin: Arc<Origin>,
    source: Option<Resource>,
    iterator: ReadDir,
    #[cfg(any(target_os = "macos", target_os = "linux"))]
    hidden: io::staging::Filter,
    items: VecDeque<Item>,
    carry: Option<Observed>,
    seen: Vec<u64>,
    remaining: usize,
    exhausted: bool,
    _memory: Reservation,
}

impl Cursor {
    pub fn new(item: &Item, roots: &Arc<Source>, memory: &Arc<Memory>) -> Result<Self> {
        if item.entry.kind != Kind::Directory || item.entry.cycle {
            return Err(Error::invalid(
                "recursive source is not a regular acyclic directory",
            ));
        }
        io::browse_directory(&item.entry)
            .map_err(|error| resource::io_error("open operation directory", error))?;
        let signature = Signature::entry(&item.entry, true);
        signature
            .verify(&item.path, true)
            .map_err(|error| directory_error("verify traversed directory", error))?;
        let known = item.resource.as_ref().map_or(0, |resource| {
            resource.source.node(resource.node).unwrap().child_count()
        });
        let reservation =
            memory.reserve(65536 + known.div_ceil(64) * 8 + item.path.as_os_str().len() * 2)?;
        let iterator = fs::read_dir(&item.path)
            .map_err(|error| directory_error("read operation directory", error))?;
        let ancestors = match &item.parent {
            Some(parent) => parent.ancestors.clone(),
            None => resource::ancestors(roots, item.root)?.into(),
        };
        let origin = Arc::new(Origin {
            id: item.id,
            root: item.root,
            node: item.node(),
            parent: item.parent.clone(),
            path: item.path.clone(),
            signature,
            discover: item.resource.as_ref().is_none_or(|resource| {
                resource.source.node(resource.node).unwrap().completeness != Completeness::Complete
            }),
            _memory: memory
                .reserve(1024 + item.path.as_os_str().len() * 2 + ancestors.len() * 32)?,
            ancestors,
        });
        Ok(Self {
            #[cfg(any(target_os = "macos", target_os = "linux"))]
            hidden: io::staging::Filter::new(item.entry.identity),
            origin,
            source: item.resource.clone(),
            iterator,
            items: VecDeque::with_capacity(LOOKAHEAD),
            carry: None,
            seen: vec![0; known.div_ceil(64)],
            remaining: known,
            exhausted: false,
            _memory: reservation,
        })
    }

    fn observe(&mut self) -> Result<Option<Observed>> {
        loop {
            let Some(entry) = self.iterator.next() else {
                self.origin
                    .signature
                    .verify(&self.origin.path, true)
                    .map_err(|error| directory_error("finish operation directory", error))?;
                if self.remaining != 0 {
                    return Err(Error::stale("loaded operation members disappeared"));
                }
                self.exhausted = true;
                return Ok(None);
            };
            let path = entry
                .map_err(|error| directory_error("enumerate operation directory", error))?
                .path();
            let resource = if let Some(parent) = &self.source {
                resource::child(
                    &parent.source,
                    parent.node,
                    path.file_name().expect("directory entry"),
                )?
                .map(|node| Resource {
                    node,
                    source: parent.source.clone(),
                })
            } else {
                None
            };
            #[cfg(any(target_os = "macos", target_os = "linux"))]
            let entry = self.hidden.read(&path);
            #[cfg(not(any(target_os = "macos", target_os = "linux")))]
            let entry = Entry::read(&path).map(Some);
            let Some(mut entry) = entry.map_err(|error| {
                if error.kind() == std::io::ErrorKind::NotADirectory
                    || resource.is_some() && error.kind() == std::io::ErrorKind::NotFound
                {
                    return Error::stale("captured operation member disappeared");
                }
                if error.kind() == std::io::ErrorKind::NotFound
                    && let Err(parent) = self.origin.signature.verify(&self.origin.path, true)
                {
                    return directory_error("verify operation parent", parent);
                }
                resource::io_error("read operation entry", error)
            })?
            else {
                continue;
            };
            entry.cycle = self.origin.cycle(&entry);
            let position = if let Some(resource) = &resource {
                let before = resource.entry()?;
                if before.name != entry.name
                    || Signature::entry(&before, false) != Signature::entry(&entry, false)
                {
                    return Err(Error::stale("loaded operation occurrence changed"));
                }
                let parent = self.source.as_ref().expect("known parent");
                let position = parent
                    .source
                    .node(parent.node)
                    .unwrap()
                    .child_position(resource.node)
                    .unwrap();
                if self.seen[position / 64] & (1 << (position % 64)) != 0 {
                    return Err(Error::stale(
                        "operation enumeration repeated a loaded occurrence",
                    ));
                }
                Some(position)
            } else {
                if !self.origin.discover {
                    return Err(Error::stale("complete operation directory gained a member"));
                }
                None
            };
            return Ok(Some(Observed {
                path,
                entry,
                resource,
                position,
            }));
        }
    }

    pub fn fill(
        &mut self,
        memory: &Arc<Memory>,
        next: &mut u64,
        cancel: &AtomicBool,
    ) -> Result<()> {
        #[cfg(test)]
        let _span = super::super::profile::span(super::super::profile::Stage::SourceRead);
        while !self.exhausted && self.items.len() < LOOKAHEAD {
            if cancel.load(Ordering::Acquire) {
                return Err(Error::new(
                    ErrorCode::ProviderError,
                    "file operation cancelled",
                ));
            }
            if self.carry.is_none() {
                self.carry = self.observe()?;
            }
            let Some(observed) = self.carry.take() else {
                break;
            };
            let id = next
                .checked_add(1)
                .ok_or_else(|| Error::limit("job item identity exhausted"))?;
            let item = Item::new(
                ItemId(id),
                self.origin.root,
                Some(self.origin.clone()),
                observed.path.clone(),
                observed.entry.clone(),
                observed.resource.clone(),
                memory,
            );
            let item = match item {
                Ok(item) => item,
                Err(error) => {
                    self.carry = Some(observed);
                    return Err(error);
                }
            };
            *next = id;
            if let Some(position) = observed.position {
                self.seen[position / 64] |= 1 << (position % 64);
                self.remaining -= 1;
            }
            self.items.push_back(item);
        }
        Ok(())
    }
    pub fn pop(&mut self) -> Option<Item> {
        self.items.pop_front()
    }
    pub fn items(&self) -> impl Iterator<Item = &Item> {
        self.items.iter()
    }
}

struct Invalidate {
    task: TaskContext,
    job: u64,
}

impl NativeAction for Invalidate {
    fn bytes(&self) -> usize {
        64
    }
    fn control(&self) -> bool {
        true
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let task = engine
            .states
            .get_mut(&self.task.state.id())
            .and_then(|state| state.task.as_mut())
            .ok_or_else(|| Error::stale("operation task expired"))?;
        if task.lock != self.task.lock
            || task.cleanup != Some(self.task.cleanup)
            || task.native_job != Some(self.job)
        {
            return Err(Error::stale("operation no longer owns task"));
        }
        task.valid = false;
        Ok(Reply::NoChange)
    }
}

impl Runner {
    pub(super) fn check_item(&self, item: &Item) -> Result<()> {
        let result = self.task_snapshot().and_then(|snapshot| {
            snapshot.map_or(Ok(()), |(source, scope)| {
                item.validate_scope(&source, &scope)
            })
        });
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::Stale)
        {
            self.invalidate_context();
        }
        result
    }

    pub(super) fn verify_directory(&self, signature: &Signature, path: &Path) -> Result<()> {
        let result = signature
            .verify(path, true)
            .map_err(|error| directory_error("verify operation directory", error));
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::Stale)
        {
            self.invalidate_context();
        }
        result
    }

    fn invalidate_context(&self) {
        if let Some(task) = &self.plan.task {
            let _ = work::wait(self.tree.data().submit(Action::Native(Box::new(Invalidate {
                task: task.clone(),
                job: self.job.0.id,
            }))));
        }
    }

    pub(super) fn cursor(&mut self, source: &Item) -> Result<Cursor> {
        self.check()?;
        self.check_item(source)?;
        source.current(&self.tree.source(), &self.plan.source)?;
        let _phase = self.job.phase(JobPhase::Reading);
        let result = Cursor::new(source, &self.plan.source, &self.job.0.task_memory);
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::Stale)
        {
            self.invalidate_context();
        }
        result
    }

    pub(super) fn fill_cursor(&mut self, cursor: &mut Cursor) -> Result<()> {
        self.check()?;
        job_owner::current(
            &self.tree.source(),
            &Resource {
                node: cursor.origin.root,
                source: self.plan.source.clone(),
            },
            false,
        )?;
        let result = cursor.fill(
            &self.job.0.task_memory,
            &mut self.next_item,
            &self.job.0.cancel,
        );
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::Stale)
        {
            self.invalidate_context();
        }
        result?;
        if let Some((source, scope)) = self.task_snapshot()? {
            for item in cursor.items() {
                if let Err(error) = item.validate_scope(&source, &scope) {
                    self.invalidate_context();
                    return Err(error);
                }
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::super::{EXECUTOR, ItemStatus, OperationKind, OperationPlan};
    use crate::ux::filetree::Entry;
    use crate::ux::filetree::jobs_tests::selection;
    use crate::ux::filetree::runtime::tests::{begin_job_read, deliver_job_page, paged_job_tree};
    use crate::ux::filetree::tests::Directory;
    use crate::ux::treeview::{Completeness, Record};
    use std::fs;
    use std::time::{Duration, Instant};

    fn delete_after_browse_materialization(complete: bool) {
        let directory = Directory::new();
        fs::create_dir_all(directory.0.join("src/branch")).unwrap();
        fs::create_dir(directory.0.join("dst")).unwrap();
        fs::write(directory.0.join("src/branch/file"), b"data").unwrap();
        let tree = paged_job_tree(&directory.0, None);
        let source = tree.source();
        let src = source.id("src").unwrap();
        assert_eq!(source.node(src).unwrap().child_count(), 0);
        let mut operation = OperationPlan {
            kind: OperationKind::Delete,
            source,
            nodes: vec![src].into(),
            target: None,
            name: None,
            task: None,
            prepare_move: false,
        };
        let state = selection(&tree, &mut operation);
        let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
        let job = tree.start_operation(operation).unwrap();
        let deadline = Instant::now() + Duration::from_secs(10);
        while state.native_task().is_err() {
            assert!(!job.status().terminal);
            assert!(Instant::now() < deadline);
            std::thread::sleep(Duration::from_millis(1));
        }
        let read = begin_job_read(&tree, src);
        deliver_job_page(
            &tree,
            read,
            1,
            vec![Record::new(
                "branch",
                Entry::read(&directory.0.join("src/branch"))
                    .unwrap()
                    .node_data(),
            )],
            true,
        );
        let branch = tree.source().id("branch").unwrap();
        let read = begin_job_read(&tree, branch);
        deliver_job_page(
            &tree,
            read,
            1,
            vec![Record::new(
                "file",
                Entry::read(&directory.0.join("src/branch/file"))
                    .unwrap()
                    .node_data(),
            )],
            complete,
        );
        assert_eq!(
            tree.source().node(branch).unwrap().completeness,
            if complete {
                Completeness::Complete
            } else {
                Completeness::Partial
            }
        );
        assert!(state.native_task().unwrap().1.valid);
        assert_eq!(
            fs::read(directory.0.join("src/branch/file")).unwrap(),
            b"data"
        );
        drop(execution);
        while !job.status().terminal {
            assert!(Instant::now() < deadline);
            std::thread::sleep(Duration::from_millis(1));
        }
        let status = job.status();
        let results = job.results(0, status.results).unwrap();
        let errors: Vec<_> = results.iter().map(|result| result.error()).collect();
        assert!(status.error.is_none(), "{:?}; {errors:?}", status.error);
        assert!(!results.is_empty());
        assert!(
            results
                .iter()
                .all(|result| result.status == ItemStatus::Success),
            "{errors:?}"
        );
        assert!(
            matches!(status.cleanup, Some(Ok(()))),
            "{:?}",
            status.cleanup
        );
        assert!(!status.cancelled);
        assert!(!state.status().unwrap().locked);
        assert!(state.snapshot().unwrap().summary.is_empty());
        assert!(!directory.0.join("src").exists());
        assert!(directory.0.join("dst").is_dir());
        assert!(tree.source().node(src).is_none());
    }

    #[test]
    fn t_delete_tracks_browse_completed_after_launch() {
        delete_after_browse_materialization(true);
    }

    #[test]
    fn t_delete_tracks_browse_partial_after_launch() {
        delete_after_browse_materialization(false);
    }
}
