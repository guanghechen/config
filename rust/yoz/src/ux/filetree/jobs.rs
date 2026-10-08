use super::io::{self, Destination, Signature};
use super::{Entry, Filetree, Kind, Request, Resource, job_owner, resource, work};
use crate::ux::treeview::memory::{Budget, Charge};
use crate::ux::treeview::*;
use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::{Component, Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex, Weak};
use std::time::{Duration, Instant};

mod admission;
mod create;
#[cfg(test)]
mod profile_tests;
#[cfg(test)]
mod progress_tests;
mod results;
use super::memory::{Memory, Reservation};
#[cfg(any(target_os = "macos", target_os = "linux"))]
mod staged;
mod trash;
mod walk;
pub use create::CreatePlan;
use walk::{Cursor, Item};

const RESULT_LIMIT: usize = super::memory::LIMIT;
const PROGRESS_INTERVAL: Duration = Duration::from_millis(40);
const COPY_PUBLICATION_ITEMS: usize = 16;
const COPY_PUBLICATION_BYTES: usize = 64 * 1024;
const SMALL_COPY_BYTES: u64 = 64 * 1024;
static ACTIVE: AtomicUsize = AtomicUsize::new(0);
static EXECUTOR: Mutex<()> = Mutex::new(());

fn physical_path(path: &Path) -> std::io::Result<PathBuf> {
    let parent = std::fs::canonicalize(path.parent().expect("operation parent"))?;
    Ok(parent.join(path.file_name().expect("operation name")))
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum OperationKind {
    Copy,
    Move,
    Delete,
    Trash,
}
#[derive(Clone)]
pub struct TaskContext {
    pub state: StateHandle,
    pub lock: LockToken,
    pub cleanup: CleanupToken,
}
pub struct OperationPlan {
    pub kind: OperationKind,
    pub source: Arc<Source>,
    pub nodes: Arc<[NodeId]>,
    pub target: Option<Resource>,
    pub name: Option<OsString>,
    pub task: Option<TaskContext>,
    pub prepare_move: bool,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ItemStatus {
    Success,
    Failed,
    Skipped,
}
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct ItemId(pub(crate) u64);

pub struct ItemResult {
    pub item: ItemId,
    pub node: Option<NodeId>,
    pub status: ItemStatus,
    contents: results::Contents,
    _memory: Reservation,
}
#[derive(Clone)]
pub struct Confirmation {
    pub token: u64,
    pub item: ItemId,
    pub node: Option<NodeId>,
    pub source: PathBuf,
    pub target: PathBuf,
    pub prepare_move: bool,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum JobPhase {
    Preparing,
    Reading,
    Working,
    Publishing,
    Cleanup,
    Complete,
}
#[derive(Clone)]
pub struct JobStatus {
    pub revision: u64,
    pub terminal: bool,
    pub cancelling: bool,
    pub cancelled: bool,
    pub confirmation: Option<Confirmation>,
    pub results: usize,
    pub processed: usize,
    pub bytes: u64,
    pub phase: JobPhase,
    pub error: Option<Error>,
    pub cleanup: Option<Result<()>>,
}
struct Status {
    phase: JobPhase,
    terminal: bool,
    cancelled: bool,
    confirmation: Option<Confirmation>,
    answer: Option<bool>,
    results: Vec<Arc<ItemResult>>,
    published: usize,
    error: Option<Error>,
    cleanup: Option<Result<()>>,
}
struct Shared {
    _source: Arc<Source>,
    _state: Option<StateHandle>,
    data: WeakDataHandle,
    id: u64,
    cancel: AtomicBool,
    bytes: AtomicU64,
    processed: AtomicUsize,
    revision: AtomicU64,
    progress: Mutex<Option<Instant>>,
    state: Mutex<Status>,
    changed: Condvar,
    task_memory: Arc<Memory>,
    _memory: Charge,
}
#[derive(Clone)]
pub struct Job(Arc<Shared>);

struct PhaseGuard {
    job: Job,
    previous: JobPhase,
}

impl Drop for PhaseGuard {
    fn drop(&mut self) {
        self.job.set_phase(self.previous);
    }
}

#[derive(Clone, Default)]
pub(crate) struct WeakJob(Weak<Shared>);

impl WeakJob {
    pub(crate) fn upgrade(&self) -> Option<Job> {
        self.0.upgrade().map(Job)
    }
}

impl Job {
    pub(crate) fn downgrade(&self) -> WeakJob {
        WeakJob(Arc::downgrade(&self.0))
    }

    fn notify(&self) {
        self.0.revision.fetch_add(1, Ordering::Release);
        if let Some(data) = self.0.data.upgrade() {
            data.notify();
        }
    }

    fn notify_progress(&self, first: bool) {
        let mut last = self
            .0
            .progress
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let now = Instant::now();
        if !first && last.is_some_and(|last| now.duration_since(last) < PROGRESS_INTERVAL) {
            return;
        }
        *last = Some(now);
        drop(last);
        self.notify();
    }

    fn copied(&self, bytes: u64) {
        let previous = self.0.bytes.fetch_add(bytes, Ordering::Relaxed);
        self.notify_progress(previous == 0 && bytes > 0);
    }

    fn processed(&self) {
        let previous = self.0.processed.fetch_add(1, Ordering::Relaxed);
        self.notify_progress(previous == 0);
    }

    fn set_phase(&self, phase: JobPhase) -> JobPhase {
        let mut state = self
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let previous = state.phase;
        state.phase = phase;
        drop(state);
        if phase != previous {
            self.notify();
        }
        previous
    }

    fn phase(&self, phase: JobPhase) -> PhaseGuard {
        PhaseGuard {
            previous: self.set_phase(phase),
            job: self.clone(),
        }
    }

    pub fn status(&self) -> JobStatus {
        self.status_since(None).expect("unconditional job status")
    }

    pub(crate) fn status_since(&self, previous: Option<u64>) -> Option<JobStatus> {
        /* Capture before reading: a racing publication may cause another read, never hide unseen state. */
        let revision = self.0.revision.load(Ordering::Acquire);
        if previous == Some(revision) {
            return None;
        }
        let state = self
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        Some(JobStatus {
            revision,
            terminal: state.terminal,
            cancelling: !state.terminal && self.0.cancel.load(Ordering::Acquire),
            cancelled: state.cancelled,
            confirmation: state.confirmation.clone(),
            results: state.published,
            processed: self.0.processed.load(Ordering::Relaxed),
            bytes: self.0.bytes.load(Ordering::Relaxed),
            phase: state.phase,
            error: state.error.clone(),
            cleanup: state.cleanup.clone(),
        })
    }
    pub fn results(&self, first: usize, last: usize) -> Result<Vec<Arc<ItemResult>>> {
        let state = self
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if first > last || last > state.published || last - first > 512 {
            return Err(Error::invalid("invalid job result range"));
        }
        Ok(state.results[first..last].to_vec())
    }
    pub fn confirm(&self, token: u64, overwrite: bool) -> Result<()> {
        let mut state = self
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if state.terminal
            || self.0.cancel.load(Ordering::Acquire)
            || state.answer.is_some()
            || state
                .confirmation
                .as_ref()
                .is_none_or(|pending| pending.token != token)
        {
            return Err(Error::stale("confirmation is no longer pending"));
        }
        state.answer = Some(overwrite);
        self.0.changed.notify_all();
        drop(state);
        self.notify();
        Ok(())
    }
    pub fn cancel(&self) {
        let state = self
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if !state.terminal {
            self.0.cancel.store(true, Ordering::Release);
            self.0.changed.notify_all();
            drop(state);
            self.notify();
        }
    }
}
struct Active;
impl Drop for Active {
    fn drop(&mut self) {
        ACTIVE.fetch_sub(1, Ordering::AcqRel);
    }
}

struct Moving {
    tree: Filetree,
    node: NodeId,
}
impl Moving {
    fn begin(tree: &Filetree, source: &Resource, token: Option<TaskUpdateToken>) -> Result<Self> {
        work::wait(
            tree.data()
                .submit(Action::Native(Box::new(job_owner::BeginMove {
                    tree: tree.clone(),
                    source: source.clone(),
                    token,
                }))),
        )?;
        Ok(Self {
            tree: tree.clone(),
            node: source.node,
        })
    }
}
impl Drop for Moving {
    fn drop(&mut self) {
        let _ = work::wait(
            self.tree
                .data()
                .submit(Action::Native(Box::new(job_owner::EndMove {
                    tree: self.tree.clone(),
                    node: self.node,
                }))),
        );
    }
}

impl Filetree {
    pub fn check_transfer_target(&self, source: Resource, target: Resource) -> Request<Resource> {
        let tree = self.clone();
        Request::run(move || {
            let memory = tree.data().memory();
            let _memory = memory.enter();
            let current = tree.source();
            if source.source.identity() != current.identity()
                || target.source.identity() != current.identity()
            {
                return Err(Error::invalid(
                    "transfer target belongs to another Filetree",
                ));
            }
            super::job_owner::current(&current, &source, false)?;
            super::job_owner::current(&current, &target, true)?;
            let path = source.path()?;
            let directory = target.path()?;
            let _paths =
                Charge::new((path.as_os_str().len() + directory.as_os_str().len()) * 4 + 1024);
            memory.check()?;
            let entry = source.entry()?;
            let parent = target.entry()?;
            if !parent.directory() {
                return Err(Error::invalid("transfer target is not a directory"));
            }
            super::io::Signature::entry(&entry, false)
                .verify(&path, false)
                .map_err(|error| resource::io_error("verify transfer source", error))?;
            super::io::Signature::entry(&parent, true)
                .verify(&directory, true)
                .map_err(|error| resource::io_error("verify transfer target", error))?;
            if entry.kind == Kind::Directory {
                let source = std::fs::canonicalize(path)
                    .map_err(|error| resource::io_error("resolve transfer source", error))?;
                let target = std::fs::canonicalize(directory)
                    .map_err(|error| resource::io_error("resolve transfer target", error))?;
                if target.starts_with(source) {
                    return Err(Error::invalid("directory destination is inside its source"));
                }
            }
            Ok(target)
        })
    }

    pub fn start_operation(&self, plan: OperationPlan) -> Result<Job> {
        let tree = self.clone();
        let task = plan
            .task
            .as_ref()
            .filter(|task| task.state.data().source().identity() == tree.source().identity())
            .cloned();
        let result = launch(tree, plan);
        if result.is_err()
            && let Some(task) = task
        {
            /* No Runner owns synchronous failures, including a failed thread spawn. */
            let _ = work::wait(task.state.submit(Action::Native(Box::new(
                job_owner::ReleaseTask {
                    task: task.clone(),
                    job: None,
                },
            ))));
        }
        result
    }
}

fn launch(tree: Filetree, plan: OperationPlan) -> Result<Job> {
    if plan.source.identity() != tree.source().identity() || plan.nodes.is_empty() {
        return Err(Error::invalid("invalid Filetree operation sources"));
    }
    if plan.prepare_move && plan.kind != OperationKind::Move {
        return Err(Error::invalid("move preparation requires a move operation"));
    }
    if plan.nodes.len() > tree.data().limits().nodes {
        return Err(Error::limit("too many operation sources"));
    }
    if let Some(target) = &plan.target {
        if target.source.identity() != plan.source.identity() || !target.entry()?.directory() {
            return Err(Error::invalid("invalid target directory"));
        }
    }
    if matches!(plan.kind, OperationKind::Delete | OperationKind::Trash) != plan.target.is_none() {
        return Err(Error::invalid("operation target does not match kind"));
    }
    if let Some(name) = &plan.name {
        let mut components = Path::new(name).components();
        if matches!(plan.kind, OperationKind::Delete | OperationKind::Trash)
            || plan.nodes.len() != 1
            || !matches!(components.next(), Some(Component::Normal(component)) if component == name.as_os_str())
            || components.next().is_some()
        {
            return Err(Error::invalid(
                "name must be one basename for a single source",
            ));
        }
    }
    if let Some(task) = &plan.task {
        if task.state.data().source().identity() != plan.source.identity() {
            return Err(Error::invalid("task belongs to another Filetree"));
        }
    }
    ACTIVE
        .try_update(Ordering::AcqRel, Ordering::Acquire, |count| {
            (count < 16).then_some(count + 1)
        })
        .map_err(|_| Error::new(ErrorCode::Busy, "file operation capacity exceeded"))?;
    let active = Active;
    let memory = tree.data().memory();
    let _guard = memory.enter();
    let job = Job(Arc::new(Shared {
        _source: plan.source.clone(),
        _state: plan.task.as_ref().map(|task| task.state.clone()),
        data: tree.data().downgrade(),
        id: resource::sequence()?,
        cancel: AtomicBool::new(false),
        bytes: AtomicU64::new(0),
        processed: AtomicUsize::new(0),
        revision: AtomicU64::new(1),
        progress: Mutex::new(None),
        state: Mutex::new(Status {
            phase: JobPhase::Preparing,
            terminal: false,
            cancelled: false,
            confirmation: None,
            answer: None,
            results: Vec::new(),
            published: 0,
            error: None,
            cleanup: None,
        }),
        changed: Condvar::new(),
        task_memory: Memory::new(memory.clone()),
        _memory: Charge::new(1024 + plan.nodes.len() * 8),
    }));
    memory.check()?;
    let runner = Runner {
        tree,
        plan,
        job: job.clone(),
        memory,
        result_parents: Weak::new(),
        successful: Vec::new(),
        next_item: 0,
        bindings: HashMap::new(),
        bindings_memory: job.0.task_memory.reserve(0)?,
        physical: HashMap::new(),
        copier: io::Copier::default(),
        pending_copies: Vec::new(),
        pending_copy_bytes: 0,
    };
    #[cfg(test)]
    let profile = super::profile::current();
    std::thread::Builder::new()
        .name(format!("yoz-filetree-job-{}", job.0.id))
        .spawn(move || {
            let _active = active;
            #[cfg(test)]
            let _profile = super::profile::enter(profile);
            #[cfg(test)]
            let _span = super::profile::span(super::profile::Stage::Job);
            let mut runner = runner;
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| runner.run()))
                .unwrap_or_else(|_| Err(Error::invalid("file operation worker panicked")));
            runner.finish(result);
        })
        .map_err(|error| resource::io_error("start file operation", error))?;
    Ok(job)
}

struct Runner {
    tree: Filetree,
    plan: OperationPlan,
    job: Job,
    memory: Arc<Budget>,
    result_parents: Weak<results::Parents>,
    successful: Vec<Arc<ItemResult>>,
    next_item: u64,
    bindings: HashMap<ItemId, NodeId>,
    bindings_memory: Reservation,
    physical: HashMap<ItemId, (Option<PathBuf>, Option<PathBuf>, Reservation, usize)>,
    copier: io::Copier,
    pending_copies: Vec<PendingCopy>,
    pending_copy_bytes: usize,
}
struct PendingCopy {
    source: Item,
    publication: job_owner::CopyPublication,
    path: PathBuf,
    target_path: PathBuf,
    charge: Reservation,
}
struct Directory {
    created: bool,
    source: Item,
    path: PathBuf,
    target: Option<Resource>,
    target_path: Option<PathBuf>,
    children: Cursor,
    success: bool,
    result_start: usize,
    successful_start: usize,
    charge: Reservation,
}
enum Step {
    Done(bool),
    Directory(Directory),
}
impl Runner {
    fn check(&self) -> Result<()> {
        if self.job.0.cancel.load(Ordering::Acquire) {
            return Err(Error::new(
                ErrorCode::ProviderError,
                "file operation cancelled",
            ));
        }
        self.check_context()
    }
    fn check_context(&self) -> Result<()> {
        self.task_snapshot().map(|_| ())
    }
    fn task_snapshot(&self) -> Result<Option<(Arc<Source>, NativeTaskStatus)>> {
        if let Some(task) = &self.plan.task {
            let (source, status) = task.state.native_task()?;
            if status.lock != task.lock
                || status.cleanup != task.cleanup
                || status.job != self.job.0.id
                || !status.valid
            {
                return Err(Error::stale("file operation task context changed"));
            }
            return Ok(Some((source, status)));
        }
        Ok(None)
    }
    fn reserve(&self, bytes: usize) -> Result<Reservation> {
        self.job.0.task_memory.reserve(bytes)
    }
    fn validate_sources(&self) -> Result<()> {
        let _guard = self.memory.enter();
        let root_bytes = self.plan.nodes.len() * 32;
        if root_bytes > RESULT_LIMIT {
            return Err(Error::limit("operation planning capacity exceeded"));
        }
        let _roots = Charge::new(root_bytes);
        self.memory.check()?;
        let mut seen = HashSet::with_capacity(self.plan.nodes.len());
        for node in self.plan.nodes.iter().copied() {
            resource::entry(&self.plan.source, node)?;
            if !seen.insert(node) {
                return Err(Error::invalid("duplicate operation source"));
            }
        }
        let mut visited = HashSet::new();
        let mut ancestor_space = Charge::new(0);
        for node in self.plan.nodes.iter() {
            let mut parent = self
                .plan
                .source
                .node(*node)
                .expect("validated source")
                .parent;
            while let Some(id) = parent {
                if seen.contains(&id) {
                    return Err(Error::invalid("operation sources overlap"));
                }
                if visited.len() == visited.capacity() {
                    let capacity = visited.capacity().max(16) * 2;
                    let bytes = capacity * 32;
                    if root_bytes + bytes > RESULT_LIMIT {
                        return Err(Error::limit("operation ancestry capacity exceeded"));
                    }
                    let charge = Charge::new(bytes);
                    self.memory.check()?;
                    visited.reserve(capacity - visited.len());
                    ancestor_space = charge;
                }
                if !visited.insert(id) {
                    break;
                }
                parent = self.plan.source.node(id).and_then(|node| node.parent);
            }
        }
        drop(ancestor_space);
        Ok(())
    }
    fn run(&mut self) -> Result<()> {
        self.validate_sources()?;
        if let Some(task) = &self.plan.task {
            work::wait(
                self.tree
                    .data()
                    .submit(Action::Native(Box::new(job_owner::Claim {
                        task: task.clone(),
                        job: self.job.0.id,
                        source: self.plan.source.clone(),
                        nodes: self.plan.nodes.clone(),
                    }))),
            )?;
        }
        let roots = self.plan.nodes.clone();
        self.job.set_phase(JobPhase::Working);
        for node in roots.iter().copied() {
            self.check()?;
            let resource = Resource {
                node,
                source: self.plan.source.clone(),
            };
            self.next_item = self
                .next_item
                .checked_add(1)
                .ok_or_else(|| Error::limit("job item identity exhausted"))?;
            let source = Item::new(
                ItemId(self.next_item),
                node,
                None,
                resource.path()?,
                resource.entry()?,
                Some(resource),
                &self.job.0.task_memory,
            )?;
            let mut pending = Some((source, self.plan.target.clone(), self.plan.name.clone()));
            let mut stack: Vec<Directory> = Vec::new();
            loop {
                if let Some((source, target, name)) = pending.take() {
                    match self.begin(source, target, name, stack.is_empty())? {
                        Step::Done(success) => {
                            if let Some(parent) = stack.last_mut() {
                                parent.success &= success;
                            }
                        }
                        Step::Directory(directory) => stack.push(directory),
                    }
                }
                let Some(directory) = stack.last_mut() else {
                    break;
                };
                self.check()?;
                self.fill_cursor(&mut directory.children)?;
                if let Some(source) = directory.children.pop() {
                    pending = Some((source, directory.target.clone(), None));
                    continue;
                }
                let directory = stack.pop().expect("directory");
                let success = self.end(directory)?;
                if let Some(parent) = stack.last_mut() {
                    parent.success &= success;
                }
            }
            self.flush_copies();
            let mut state = self
                .job
                .0
                .state
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            state.published = state.results.len();
            drop(state);
            self.job.notify();
        }
        Ok(())
    }
    fn authorize(
        &self,
        node: NodeId,
        target: Option<NodeId>,
        relocated: Option<&Entry>,
    ) -> Result<Option<TaskUpdateToken>> {
        self.check()?;
        let Some(task) = &self.plan.task else {
            return Ok(None);
        };
        let change = if let Some(parent) = target {
            ExpectedChange::Reparent {
                node,
                parent: Some(parent),
            }
        } else {
            ExpectedChange::Remove { node }
        };
        let mut changes = vec![change];
        if let Some(relocated) = relocated {
            let source = self.tree.source();
            let old = resource::entry(&source, node)?;
            let current = source.node(node).expect("moving link");
            let expandable = relocated.directory() || relocated.target_unknown;
            let retarget = resource::ends_children(&old, relocated);
            if retarget {
                changes.extend(
                    current
                        .children()
                        .map(|node| ExpectedChange::Remove { node }),
                );
                let completeness = if expandable {
                    Completeness::Unknown
                } else {
                    Completeness::Complete
                };
                if current.data.can_expand != expandable || current.completeness != completeness {
                    changes.push(ExpectedChange::Slot {
                        node,
                        can_expand: expandable,
                        completeness,
                    });
                }
            }
        }
        match task
            .state
            .submit(Action::Authorize(
                task.state.id(),
                task.lock,
                task.cleanup,
                changes.into(),
            ))
            .wait()
        {
            Outcome::TaskUpdate(token) => Ok(Some(token)),
            Outcome::Reply(Reply::Rejected { error }) => Err(error),
            _ => Err(Error::invalid("missing file operation authorization")),
        }
    }
    fn capture_replacement(
        &self,
        target: &Resource,
        destination: &Destination,
    ) -> Result<Option<job_owner::Replacement>> {
        let Some(signature) = &destination.expected else {
            return Ok(None);
        };
        #[cfg(any(target_os = "macos", windows))]
        let name = resource::observed_name(&destination.path)?;
        #[cfg(not(any(target_os = "macos", windows)))]
        let name = destination
            .path
            .file_name()
            .expect("destination name")
            .to_owned();
        let captured = Arc::new(Mutex::new(None));
        work::wait(self.tree.data().submit(Action::Native(Box::new(
            job_owner::CaptureReplacement {
                tree: self.tree.clone(),
                parent: target.clone(),
                name,
                signature: signature.clone(),
                result: captured.clone(),
            },
        ))))?;
        Ok(captured
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .take())
    }
    fn moved_descendants(
        &self,
        root: &Resource,
        target: &Resource,
        path: &Path,
        observed: &Entry,
    ) -> Result<job_owner::MovedDescendants> {
        let source = self.tree.source();
        job_owner::current(&source, root, false)?;
        if observed.identity != root.entry()?.identity || observed.kind != Kind::Directory {
            return Err(Error::stale(
                "moved directory replaced before metadata observation",
            ));
        }
        let mut ancestors: HashSet<_> = resource::ancestors(&source, target.node)?
            .into_iter()
            .collect();
        ancestors.insert(observed.identity);
        let limit = RESULT_LIMIT.saturating_sub(self.job.0.task_memory.used());
        let mut bytes = path.as_os_str().len() * 4 + ancestors.len() * 64 + 256;
        if bytes > limit {
            return Err(Error::limit(
                "relocated metadata exceeds task staging capacity",
            ));
        }
        let mut path = path.to_path_buf();
        let mut stack = vec![(
            source.node(root.node).expect("moving directory").children(),
            None,
            bytes,
            Charge::new(bytes),
        )];
        self.memory.check()?;
        let mut entries = Vec::new();
        while let Some((children, _, _, _)) = stack.last_mut() {
            let Some(node) = children.next() else {
                let (_, identity, size, _) = stack.pop().expect("ancestor frame");
                bytes -= size;
                if let Some(identity) = identity {
                    ancestors.remove(&identity);
                }
                if !stack.is_empty() {
                    path.pop();
                }
                continue;
            };
            let old = resource::entry(&source, node)?;
            if !matches!(old.kind, Kind::Directory | Kind::Link) {
                continue;
            }
            path.push(&old.name);
            let mut entry = if old.kind == Kind::Link {
                let entry = Entry::read(&path)
                    .map_err(|error| resource::io_error("read relocated link", error))?;
                if entry.identity != old.identity || entry.kind != old.kind {
                    return Err(Error::stale("relocated link occurrence changed"));
                }
                entry
            } else {
                old.clone()
            };
            entry.cycle = entry
                .target_identity()
                .is_some_and(|identity| ancestors.contains(&identity));
            let descend = !resource::ends_children(&old, &entry)
                && source.node(node).expect("loaded descendant").child_count() != 0;
            let identity = entry.target_identity();
            let frame_bytes = 256 + entry.name.len() * 4;
            if entry.kind == Kind::Link || entry.cycle != old.cycle {
                let size = entry.encoded_len() * 2 + 512;
                if size > limit.saturating_sub(bytes) {
                    return Err(Error::limit(
                        "relocated metadata exceeds task staging capacity",
                    ));
                }
                bytes += size;
                entries.push(job_owner::MovedNode {
                    node,
                    entry,
                    _memory: Charge::new(size),
                });
            }
            if descend {
                if frame_bytes > limit.saturating_sub(bytes) {
                    return Err(Error::limit(
                        "relocated metadata exceeds task staging capacity",
                    ));
                }
                bytes += frame_bytes;
                if let Some(identity) = identity {
                    ancestors.insert(identity);
                }
                stack.push((
                    source.node(node).expect("loaded descendant").children(),
                    identity,
                    frame_bytes,
                    Charge::new(frame_bytes),
                ));
            } else {
                path.pop();
            }
            self.memory.check()?;
        }
        drop(stack);
        Ok(job_owner::MovedDescendants { source, entries })
    }

    fn flush_copies(&mut self) {
        if self.pending_copies.is_empty() {
            return;
        }
        let copies = std::mem::take(&mut self.pending_copies);
        self.pending_copy_bytes = 0;
        let results = Arc::new(Mutex::new(vec![None; copies.len()]));
        let failure = work::wait(self.tree.data().submit(Action::Native(Box::new(
            job_owner::PublishCopies {
                tree: self.tree.clone(),
                items: copies.iter().map(|copy| copy.publication.clone()).collect(),
                results: results.clone(),
            },
        ))))
        .err();
        let mut results = results.lock().unwrap_or_else(|error| error.into_inner());
        for (copy, result) in copies.into_iter().zip(results.iter_mut()) {
            /* Disk IO has succeeded, even if publication or the whole submission failed. */
            self.record_result(
                &copy.source,
                copy.path,
                Some(copy.target_path),
                ItemStatus::Success,
                None,
                failure.clone().or_else(|| result.take()),
                copy.charge,
            );
        }
    }

    fn publish(
        &mut self,
        source: &Item,
        target: Option<Resource>,
        entry: Option<Entry>,
        moved: bool,
        token: Option<TaskUpdateToken>,
        replaced: Option<job_owner::Replacement>,
        descendants: Option<job_owner::MovedDescendants>,
    ) -> Result<Option<Resource>> {
        #[cfg(test)]
        let _span = super::profile::span(super::profile::Stage::PublishModel);
        self.flush_copies();
        let result = Arc::new(Mutex::new(None));
        work::wait(
            self.tree
                .data()
                .submit(Action::Native(Box::new(job_owner::Publish {
                    tree: self.tree.clone(),
                    source: source.resource.clone(),
                    anchor: Resource {
                        node: source.root,
                        source: self.plan.source.clone(),
                    },
                    target,
                    entry,
                    moved,
                    token,
                    replaced,
                    descendants,
                    result: result.clone(),
                }))),
        )?;
        let value = result
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .clone();
        Ok(value)
    }
    fn ask(
        &mut self,
        source: &Item,
        path: &Path,
        target: &Path,
        prepare_move: bool,
    ) -> Result<bool> {
        self.flush_copies();
        self.check()?;
        let mut state = self
            .job
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        state.confirmation = Some(Confirmation {
            token: resource::sequence()?,
            item: source.id,
            node: source.node(),
            source: path.to_owned(),
            target: target.to_owned(),
            prepare_move,
        });
        state.answer = None;
        drop(state);
        self.job.notify();
        let mut state = self
            .job
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        loop {
            if let Err(error) = self.check() {
                state.confirmation = None;
                drop(state);
                self.job.notify();
                return Err(error);
            }
            if let Some(answer) = state.answer.take() {
                state.confirmation = None;
                drop(state);
                self.job.notify();
                return Ok(answer);
            }
            state = self
                .job
                .0
                .changed
                .wait_timeout(state, Duration::from_millis(50))
                .unwrap_or_else(|error| error.into_inner())
                .0;
        }
    }
    fn record(
        &mut self,
        source: &Item,
        path: PathBuf,
        target: Option<PathBuf>,
        status: ItemStatus,
        error: Option<std::io::Error>,
        sync_error: Option<Error>,
        charge: Reservation,
    ) {
        self.flush_copies();
        self.record_result(source, path, target, status, error, sync_error, charge);
    }

    fn record_result(
        &mut self,
        source: &Item,
        path: PathBuf,
        target: Option<PathBuf>,
        status: ItemStatus,
        error: Option<std::io::Error>,
        sync_error: Option<Error>,
        charge: Reservation,
    ) {
        let result = self.result(source, path, target, status, error, sync_error, charge);
        self.deliver(result);
    }

    fn result(
        &mut self,
        source: &Item,
        path: PathBuf,
        target: Option<PathBuf>,
        status: ItemStatus,
        error: Option<std::io::Error>,
        sync_error: Option<Error>,
        charge: Reservation,
    ) -> Arc<ItemResult> {
        #[cfg(test)]
        let _span = super::profile::span(super::profile::Stage::Results);
        let (source_physical, target_physical, path_memory) = self
            .physical
            .remove(&source.id)
            .map_or((None, None, None), |(source, target, charge, _)| {
                (source, target, Some(charge))
            });
        let result = ItemResult::new(
            source.id,
            source.node(),
            status,
            results::Details {
                source: path,
                target,
                source_physical,
                target_physical,
                error_kind: error.as_ref().map(|error| format!("{:?}", error.kind())),
                os_code: error.as_ref().and_then(io::os_code),
                error: error.map(|error| {
                    resource::io_error(
                        match self.plan.kind {
                            OperationKind::Copy => "copy",
                            OperationKind::Move => "move",
                            OperationKind::Delete => "delete",
                            OperationKind::Trash => "trash",
                        },
                        error,
                    )
                }),
                sync_error,
                _path_memory: path_memory,
            },
            charge,
            &mut self.result_parents,
            (status == ItemStatus::Success && self.plan.task.is_some())
                .then(|| {
                    source.parent.as_ref().map(|parent| walk::Witness {
                        parent: parent.clone(),
                        signature: source
                            .node()
                            .is_none()
                            .then(|| walk::CapturedSignature::new(&source.entry)),
                    })
                })
                .flatten(),
        );
        self.job.processed();
        result
    }

    fn deliver(&mut self, result: Arc<ItemResult>) {
        if result.status == ItemStatus::Success {
            self.successful.push(result.clone());
        }
        self.job
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .results
            .push(result);
    }
    fn begin(
        &mut self,
        mut source: Item,
        target: Option<Resource>,
        name: Option<OsString>,
        root: bool,
    ) -> Result<Step> {
        self.check()?;
        self.check_item(&source)?;
        if self.plan.kind != OperationKind::Copy {
            self.bind_item(&mut source)?;
        }
        let path = source.path()?;
        let entry = source.entry()?;
        let target_path = target
            .as_ref()
            .map(|target| {
                target
                    .path()
                    .map(|path| path.join(name.as_ref().unwrap_or(&entry.name)))
            })
            .transpose()?;
        let reserved = 4096
            + entry.encoded_len() * 2
            + path.as_os_str().len() * 2
            + target_path
                .as_ref()
                .map_or(0, |path| path.as_os_str().len() * 2);
        let small_copy = self.plan.kind == OperationKind::Copy
            && entry.kind == Kind::File
            && entry.size <= SMALL_COPY_BYTES;
        let pending_bytes = reserved + entry.encoded_len() + std::mem::size_of::<PendingCopy>();
        if !small_copy
            || self.pending_copies.len() == COPY_PUBLICATION_ITEMS
            || self.pending_copy_bytes + pending_bytes > COPY_PUBLICATION_BYTES
            || self.pending_copies.last().is_some_and(|copy| {
                Some(copy.publication.target.node) != target.as_ref().map(|target| target.node)
            })
        {
            self.flush_copies();
        }
        let charge = match self.reserve(reserved) {
            Err(_) if !self.pending_copies.is_empty() => {
                self.flush_copies();
                self.reserve(reserved)?
            }
            result => result?,
        };
        let expected = Signature::entry(&entry, false);
        let parent_signature = source.parent_signature(&self.plan.source)?;
        let preparation = (|| -> std::io::Result<Option<Destination>> {
            if entry.kind == Kind::Directory {
                self.verify_directory(&expected, &path)
                    .map_err(std::io::Error::other)?;
            } else {
                expected.verify(&path, false)?;
            }
            if let Some(parent) = &parent_signature {
                self.verify_directory(parent, path.parent().expect("source parent"))
                    .map_err(std::io::Error::other)?;
            }
            if entry.anchor.is_some() {
                return Err(std::io::Error::other(
                    "filesystem anchors cannot be operated on",
                ));
            }
            let Some(target) = &target else {
                return Ok(None);
            };
            let parent = Signature::entry(&target.entry().map_err(std::io::Error::other)?, true);
            parent.verify(&target.path().map_err(std::io::Error::other)?, true)?;
            let target_path = target_path.as_ref().expect("target path");
            if entry.kind == Kind::Directory {
                let physical_source = std::fs::canonicalize(&path)?;
                let physical_target =
                    std::fs::canonicalize(target_path.parent().expect("target parent"))?;
                if physical_target.starts_with(&physical_source) {
                    return Err(std::io::Error::other(
                        "directory destination is inside its source",
                    ));
                }
            }
            let existing = io::existing(target_path)?;
            if let Some(existing) = &existing {
                if (entry.kind == Kind::Directory) != (existing.kind == Kind::Directory) {
                    return Err(std::io::Error::other("file and directory types conflict"));
                }
                if self.plan.kind == OperationKind::Move
                    && existing.kind == Kind::Directory
                    && existing.identity != expected.identity
                    && std::fs::read_dir(target_path)?
                        .next()
                        .transpose()?
                        .is_some()
                {
                    return Err(std::io::Error::new(
                        std::io::ErrorKind::DirectoryNotEmpty,
                        "move destination directory is not empty",
                    ));
                }
            }
            Ok(Some(Destination {
                path: target_path.clone(),
                parent,
                expected: existing,
            }))
        })();
        let destination = match preparation {
            Ok(value) => value,
            Err(error) => {
                self.record(
                    &source,
                    path,
                    target_path,
                    ItemStatus::Failed,
                    Some(error),
                    None,
                    charge,
                );
                return Ok(Step::Done(false));
            }
        };
        if destination
            .as_ref()
            .is_some_and(|value| value.expected.is_some())
        {
            self.flush_copies();
        }
        let replacement = match destination.as_ref().map_or(Ok(None), |destination| {
            self.capture_replacement(target.as_ref().expect("destination parent"), destination)
        }) {
            Ok(replacement) => replacement,
            Err(error) => {
                self.record(
                    &source,
                    path,
                    target_path,
                    ItemStatus::Failed,
                    None,
                    Some(error),
                    charge,
                );
                return Ok(Step::Done(false));
            }
        };
        if destination
            .as_ref()
            .and_then(|destination| destination.expected.as_ref())
            .is_some_and(|value| value.identity == expected.identity)
        {
            #[cfg(not(any(target_os = "macos", windows)))]
            let case_rename = false;
            #[cfg(any(target_os = "macos", windows))]
            let case_rename = if self.plan.kind == OperationKind::Move
                && source
                    .bound()?
                    .source
                    .node(source.bound()?.node)
                    .and_then(|node| node.parent)
                    == target.as_ref().map(|target| target.node)
                && path.file_name() != target_path.as_ref().expect("target").file_name()
            {
                let destination = target_path.as_ref().expect("target");
                std::fs::canonicalize(path.parent().expect("source parent")).ok()
                    == std::fs::canonicalize(destination.parent().expect("target parent")).ok()
                    && resource::observed_name(&path)? == resource::observed_name(destination)?
            } else {
                false
            };
            if !case_rename {
                self.record(
                    &source,
                    path,
                    target_path,
                    ItemStatus::Skipped,
                    None,
                    None,
                    charge,
                );
                return Ok(Step::Done(false));
            }
        } else if destination
            .as_ref()
            .is_some_and(|destination| destination.expected.is_some())
            && !(self.plan.kind == OperationKind::Copy && entry.kind == Kind::Directory)
            && !self.ask(&source, &path, target_path.as_ref().expect("target"), false)?
        {
            self.record(
                &source,
                path,
                target_path,
                ItemStatus::Skipped,
                None,
                None,
                charge,
            );
            return Ok(Step::Done(false));
        }
        self.check()?;
        if root && self.plan.prepare_move {
            let valid = (|| -> std::io::Result<()> {
                let current = self.tree.source();
                source
                    .current(&current, &self.plan.source)
                    .map_err(std::io::Error::other)?;
                if let Some(target) = &target {
                    job_owner::current(&current, target, true).map_err(std::io::Error::other)?;
                }
                expected.verify(&path, false)?;
                if let Some(parent) = &parent_signature {
                    parent.verify(path.parent().expect("source parent"), true)?;
                }
                if let Some(destination) = &destination {
                    destination.verify()?;
                }
                Ok(())
            })();
            if let Err(error) = valid {
                self.record(
                    &source,
                    path,
                    target_path,
                    ItemStatus::Failed,
                    Some(error),
                    None,
                    charge,
                );
                return Ok(Step::Done(false));
            }
        }
        let mut prepared_paths = if root && self.plan.prepare_move {
            let from = physical_path(&path)
                .map_err(|error| resource::io_error("prepare move source", error))?;
            let to = physical_path(target_path.as_ref().expect("move target"))
                .map_err(|error| resource::io_error("prepare move target", error))?;
            let bytes = (from.as_os_str().len() + to.as_os_str().len()) * 2 + 128;
            if self.job.0.task_memory.used().saturating_add(bytes) > RESULT_LIMIT {
                return Err(Error::limit("move preparation capacity exceeded"));
            }
            let preparation_charge = {
                let _memory = self.memory.enter();
                let charge = Charge::new(bytes);
                self.memory.check()?;
                charge
            };
            if !self.ask(&source, &from, &to, true)? {
                self.record(
                    &source,
                    path,
                    target_path,
                    ItemStatus::Skipped,
                    None,
                    None,
                    charge,
                );
                return Ok(Step::Done(false));
            }
            Some((from, to, preparation_charge))
        } else {
            None
        };
        let current = self.tree.source();
        let valid = source.current(&current, &self.plan.source).and_then(|_| {
            target
                .as_ref()
                .map_or(Ok(()), |target| job_owner::current(&current, target, true))
        });
        if let Err(error) = valid {
            self.record(
                &source,
                path,
                target_path,
                ItemStatus::Failed,
                None,
                Some(error),
                charge,
            );
            return Ok(Step::Done(false));
        }
        #[cfg(any(target_os = "macos", target_os = "linux"))]
        if self.plan.kind == OperationKind::Copy
            && entry.kind == Kind::Directory
            && destination
                .as_ref()
                .is_some_and(|destination| destination.expected.is_none())
        {
            return self
                .copy_directory(
                    source,
                    target.expect("copy target parent"),
                    path,
                    destination.expect("copy destination"),
                    charge,
                )
                .map(Step::Done);
        }
        let recursive = entry.kind == Kind::Directory
            && matches!(self.plan.kind, OperationKind::Copy | OperationKind::Delete);
        let relocated = if self.plan.kind == OperationKind::Move && entry.kind == Kind::Link {
            let mut predicted = entry.clone();
            predicted.target_unknown = false;
            let lookup = target_path
                .as_ref()
                .expect("link destination")
                .parent()
                .expect("destination parent")
                .join(entry.link.as_ref().expect("link text"));
            predicted.target = match std::fs::metadata(&lookup) {
                Ok(metadata) => Some((
                    Kind::metadata(&metadata),
                    super::FileIdentity::at(&lookup, &metadata, true)
                        .map_err(|error| resource::io_error("resolve relocated link", error))?,
                )),
                Err(error) => {
                    predicted.target_unknown = !matches!(
                        error.kind(),
                        std::io::ErrorKind::NotFound | std::io::ErrorKind::NotADirectory
                    );
                    None
                }
            };
            predicted.cycle = predicted.target_identity().is_some_and(|identity| {
                resource::ancestors(
                    &target.as_ref().expect("target").source,
                    target.as_ref().expect("target").node,
                )
                .is_ok_and(|ancestors| ancestors.contains(&identity))
            });
            Some(predicted)
        } else {
            None
        };
        let token = if !recursive && self.plan.kind != OperationKind::Copy {
            self.authorize(
                source.bound()?.node,
                target.as_ref().map(|target| target.node),
                relocated.as_ref(),
            )?
        } else {
            None
        };
        let mut execution = Some(EXECUTOR.lock().unwrap_or_else(|error| error.into_inner()));
        self.check()?;
        self.check_item(&source)?;
        let mut moving = if matches!(self.plan.kind, OperationKind::Move | OperationKind::Trash) {
            Some(Moving::begin(&self.tree, source.bound()?, token)?)
        } else {
            None
        };
        self.check()?;
        let _memory = self.memory.enter();
        self.memory.check()?;
        let mut copied_file = None;
        let result = (|| -> std::io::Result<bool> {
            if entry.kind == Kind::Directory {
                self.verify_directory(&expected, &path)
                    .map_err(std::io::Error::other)?;
            } else {
                expected.verify(&path, false)?;
            }
            if let Some(parent) = &parent_signature {
                self.verify_directory(parent, path.parent().expect("source parent"))
                    .map_err(std::io::Error::other)?;
            }
            if let Some(destination) = &destination {
                destination.verify()?;
            }
            if self.plan.kind == OperationKind::Move {
                /* Neovim canonicalizes parent aliases. Never follow a final symlink:
                 * moving that link must not rename a buffer for its referent. */
                let from = physical_path(&path)?;
                let target = target_path.as_ref().expect("move target");
                let to = physical_path(target)?;
                if prepared_paths
                    .as_ref()
                    .is_some_and(|(old_from, old_to, _)| *old_from != from || *old_to != to)
                {
                    return Err(std::io::Error::new(
                        std::io::ErrorKind::AlreadyExists,
                        "move paths changed during preparation",
                    ));
                }
                drop(prepared_paths.take());
                let from = (from != path).then_some(from);
                let to = (to != *target).then_some(to);
                if from.is_some() || to.is_some() {
                    let bytes = 128
                        + from.as_ref().map_or(0, |path| path.as_os_str().len() * 2)
                        + to.as_ref().map_or(0, |path| path.as_os_str().len() * 2);
                    let charge = self.reserve(bytes).map_err(std::io::Error::other)?;
                    self.physical.insert(source.id, (from, to, charge, bytes));
                }
            }
            if recursive {
                if let Some(destination) = &destination {
                    if destination.expected.is_none() {
                        io::create_directory(destination)?;
                    }
                }
                return Ok(true);
            }
            match self.plan.kind {
                OperationKind::Copy => {
                    copied_file = self.copier.copy(
                        &path,
                        &expected,
                        destination.as_ref().expect("copy target"),
                        &self.job.0.cancel,
                        |bytes| self.job.copied(bytes),
                    )?;
                }
                OperationKind::Delete => io::remove(&path, &expected, &self.job.0.cancel)?,
                OperationKind::Trash => trash::recycle(&path, &expected, &self.job.0.cancel)?,
                OperationKind::Move => {
                    let destination = destination.as_ref().expect("move target");
                    match io::rename(&path, &destination.path, destination.expected.is_some()) {
                        Ok(()) => {}
                        Err(error) if error.kind() == std::io::ErrorKind::CrossesDevices => {
                            if entry.kind == Kind::Directory {
                                io::create_directory(destination)?;
                                return Ok(true);
                            }
                            copied_file = self.copier.copy(
                                &path,
                                &expected,
                                destination,
                                &self.job.0.cancel,
                                |bytes| self.job.copied(bytes),
                            )?;
                            io::remove(&path, &expected, &self.job.0.cancel)?;
                        }
                        Err(error) => return Err(error),
                    }
                }
            }
            Ok(false)
        })();
        let observed = if result.is_ok() {
            target_path
                .as_ref()
                .map(|path| io::observed_output(path, copied_file.as_ref()))
                .transpose()
        } else {
            Ok(None)
        };
        drop(copied_file);
        let whole_directory_move = matches!(result, Ok(false))
            && self.plan.kind == OperationKind::Move
            && entry.kind == Kind::Directory;
        let descendants = if whole_directory_move {
            observed
                .as_ref()
                .ok()
                .and_then(Option::as_ref)
                .map(|observed| {
                    self.moved_descendants(
                        source.bound()?,
                        target.as_ref().expect("move target"),
                        target_path.as_ref().expect("move path"),
                        observed,
                    )
                })
                .transpose()
        } else {
            Ok(None)
        };
        if moving.is_none() || result.is_err() {
            drop(moving.take());
            drop(execution.take());
        }
        let directory = match result {
            Ok(value) => value,
            Err(error) => {
                if let Some(capacity) = error
                    .get_ref()
                    .and_then(|error| error.downcast_ref::<Error>())
                    && capacity.code == ErrorCode::ResourceLimit
                {
                    return Err(capacity.clone());
                }
                self.record(
                    &source,
                    path,
                    target_path,
                    ItemStatus::Failed,
                    Some(error),
                    None,
                    charge,
                );
                return Ok(Step::Done(false));
            }
        };
        let mut observed = match observed {
            Ok(value) => value,
            Err(error) => {
                let error = resource::io_error("read completed destination", error);
                self.record(
                    &source,
                    path,
                    target_path,
                    if directory {
                        ItemStatus::Failed
                    } else {
                        ItemStatus::Success
                    },
                    None,
                    Some(error),
                    charge,
                );
                return Ok(Step::Done(!directory));
            }
        };
        if let (Some(observed), Some(target)) = (&mut observed, &target) {
            observed.cycle = observed.target_identity().is_some_and(|identity| {
                resource::ancestors(&target.source, target.node)
                    .is_ok_and(|ancestors| ancestors.contains(&identity))
            });
        }
        if directory {
            let created = self.plan.kind == OperationKind::Move
                || destination
                    .as_ref()
                    .is_some_and(|target| target.expected.is_none());
            let destination = if let (Some(target), Some(entry)) = (&target, observed) {
                let existing = self
                    .tree
                    .index
                    .lock()
                    .unwrap_or_else(|error| error.into_inner())
                    .child(Some(target.node), &entry.name);
                let current = self.tree.source();
                if let Some(node) = existing.filter(|id| {
                    resource::entry(&current, *id).is_ok_and(|old| {
                        Signature::entry(&old, true) == Signature::entry(&entry, true)
                    })
                }) {
                    Some(Resource {
                        source: current,
                        node,
                    })
                } else {
                    match self.publish(
                        &source,
                        Some(target.clone()),
                        Some(entry),
                        false,
                        None,
                        replacement,
                        None,
                    ) {
                        Ok(value) => value,
                        Err(error) => {
                            self.record(
                                &source,
                                path,
                                target_path,
                                ItemStatus::Failed,
                                None,
                                Some(error),
                                charge,
                            );
                            return Ok(Step::Done(false));
                        }
                    }
                }
            } else {
                None
            };
            /* Cross-filesystem traversal needs its reads; each later mutation owns a fresh guard. */
            drop(moving.take());
            drop(execution.take());
            let children = match self.cursor(&source) {
                Ok(children) => children,
                Err(error) => {
                    self.record(
                        &source,
                        path,
                        target_path,
                        ItemStatus::Failed,
                        None,
                        Some(error),
                        charge,
                    );
                    return Ok(Step::Done(false));
                }
            };
            let result_start = self
                .job
                .0
                .state
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .results
                .len();
            return Ok(Step::Directory(Directory {
                created,
                source,
                path,
                target: destination,
                target_path,
                children,
                success: true,
                result_start,
                successful_start: self.successful.len(),
                charge,
            }));
        }
        if small_copy
            && replacement.is_none()
            && destination
                .as_ref()
                .is_some_and(|value| value.expected.is_none())
            && observed
                .as_ref()
                .is_some_and(|entry| entry.kind == Kind::File && entry.size <= SMALL_COPY_BYTES)
        {
            let entry = observed.expect("copied file");
            let bytes = reserved + entry.encoded_len() + std::mem::size_of::<PendingCopy>();
            if bytes <= COPY_PUBLICATION_BYTES {
                if self.pending_copy_bytes + bytes > COPY_PUBLICATION_BYTES {
                    self.flush_copies();
                }
                self.pending_copy_bytes += bytes;
                self.pending_copies.push(PendingCopy {
                    source: source.clone(),
                    publication: job_owner::CopyPublication {
                        source: source.resource.clone(),
                        anchor: Resource {
                            node: source.root,
                            source: self.plan.source.clone(),
                        },
                        target: target.expect("copy target"),
                        entry,
                    },
                    path,
                    target_path: target_path.expect("copy target path"),
                    charge,
                });
                return Ok(Step::Done(true));
            }
            observed = Some(entry);
        }
        let sync = descendants.and_then(|descendants| {
            self.publish(
                &source,
                target,
                observed,
                self.plan.kind == OperationKind::Move,
                token,
                replacement,
                descendants,
            )
        });
        self.record(
            &source,
            path,
            target_path,
            ItemStatus::Success,
            None,
            sync.err(),
            charge,
        );
        Ok(Step::Done(true))
    }
    fn end(&mut self, directory: Directory) -> Result<bool> {
        self.flush_copies();
        self.check()?;
        let mut success = directory.success;
        let mut failure = None;
        let mut sync_error = None;
        if directory.created {
            let target = directory.target.as_ref().expect("created directory");
            let target = Resource {
                node: target.node,
                source: self.tree.source(),
            };
            let target_entry = target.entry();
            if let Ok(target_entry) = target_entry {
                let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
                self.verify_directory(
                    &Signature::entry(&directory.source.entry, true),
                    &directory.path,
                )?;
                let result = io::directory_permissions(
                    &directory.path,
                    &Signature::entry(&directory.source.entry()?, false),
                    directory.target_path.as_ref().expect("destination path"),
                    &Signature::entry(&target_entry, false),
                );
                drop(execution);
                match result {
                    Ok(entry) => {
                        sync_error = work::wait(self.tree.data().submit(Action::Native(Box::new(
                            job_owner::Metadata { target, entry },
                        ))))
                        .err();
                    }
                    Err(error) => {
                        success = false;
                        failure = Some(error);
                    }
                }
            } else {
                success = false;
                sync_error = target_entry.err();
            }
        }
        if success && self.plan.kind != OperationKind::Copy {
            let target_parent = directory
                .target
                .as_ref()
                .and_then(|target| target.source.node(target.node).and_then(|node| node.parent));
            let children: Vec<_> = directory.target.as_ref().map_or_else(Vec::new, |target| {
                self.tree
                    .source()
                    .node(target.node)
                    .map_or_else(Vec::new, |node| node.children().collect())
            });
            let token = if self.plan.kind == OperationKind::Delete {
                self.authorize(directory.source.bound()?.node, None, None)?
            } else if let Some(task) = &self.plan.task {
                let mut changes = vec![ExpectedChange::Reparent {
                    node: directory.source.bound()?.node,
                    parent: target_parent,
                }];
                let source_node = directory.source.bound()?.node;
                changes.extend(children.iter().map(|node| ExpectedChange::Reparent {
                    node: *node,
                    parent: Some(source_node),
                }));
                match task
                    .state
                    .submit(Action::Authorize(
                        task.state.id(),
                        task.lock,
                        task.cleanup,
                        changes.into(),
                    ))
                    .wait()
                {
                    Outcome::TaskUpdate(token) => Some(token),
                    Outcome::Reply(Reply::Rejected { error }) => return Err(error),
                    _ => return Err(Error::invalid("missing directory move authorization")),
                }
            } else {
                None
            };
            let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
            self.check()?;
            let moving = if self.plan.kind == OperationKind::Move {
                Some(Moving::begin(&self.tree, directory.source.bound()?, token)?)
            } else {
                None
            };
            self.check()?;
            let result = (|| -> std::io::Result<()> {
                self.verify_directory(
                    &Signature::entry(&directory.source.entry, true),
                    &directory.path,
                )
                .map_err(std::io::Error::other)?;
                if let Some(target) = &directory.target {
                    Signature::entry(&target.entry().map_err(std::io::Error::other)?, true)
                        .verify(&target.path().map_err(std::io::Error::other)?, true)?;
                }
                if let Some(parent) = directory
                    .source
                    .parent_signature(&self.plan.source)
                    .map_err(std::io::Error::other)?
                {
                    self.verify_directory(&parent, directory.path.parent().expect("source parent"))
                        .map_err(std::io::Error::other)?;
                }
                io::remove(
                    &directory.path,
                    &Signature::entry(
                        &directory.source.entry().map_err(std::io::Error::other)?,
                        false,
                    ),
                    &self.job.0.cancel,
                )
            })();
            let observed = if self.plan.kind == OperationKind::Move && result.is_ok() {
                directory
                    .target_path
                    .as_ref()
                    .map(|path| Entry::read(path))
                    .transpose()
            } else {
                Ok(None)
            };
            if moving.is_none() {
                drop(execution);
            }
            match result {
                Err(error) => {
                    success = false;
                    failure = Some(error);
                }
                Ok(()) if self.plan.kind == OperationKind::Delete => {
                    sync_error = self
                        .publish(&directory.source, None, None, false, token, None, None)
                        .err();
                }
                Ok(()) => {
                    sync_error = match observed {
                        Err(error) => Some(resource::io_error("read moved directory", error)),
                        Ok(Some(entry)) => work::wait(self.tree.data().submit(Action::Native(
                            Box::new(job_owner::FinishMove {
                                tree: self.tree.clone(),
                                source: directory.source.bound()?.clone(),
                                target: directory.target.clone().expect("moved directory"),
                                parent: target_parent.expect("destination parent"),
                                entry,
                                token,
                                children,
                            }),
                        )))
                        .err(),
                        Ok(None) => Some(Error::invalid("missing moved directory")),
                    };
                }
            }
        }
        if success {
            /* Once a complete subtree succeeds, its root carries both the result and cleanup identity. */
            let mut state = self
                .job
                .0
                .state
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            if state.results[directory.result_start..]
                .iter()
                .all(|result| result.sync_error().is_none())
                && sync_error.is_none()
            {
                state.results.truncate(directory.result_start);
                if state.results.capacity() > state.results.len() * 2 {
                    state.results.shrink_to_fit();
                }
                self.successful.truncate(directory.successful_start);
                if self.successful.capacity() > self.successful.len() * 2 {
                    self.successful.shrink_to_fit();
                }
            }
        }
        self.record(
            &directory.source,
            directory.path,
            directory.target_path,
            if success {
                ItemStatus::Success
            } else {
                ItemStatus::Failed
            },
            failure,
            sync_error,
            directory.charge,
        );
        Ok(success)
    }
    fn finish(&mut self, result: Result<()>) {
        #[cfg(test)]
        let _span = super::profile::span(super::profile::Stage::Cleanup);
        self.flush_copies();
        self.job.set_phase(JobPhase::Cleanup);
        let cleanup = self.plan.task.clone().map(|task| {
            /* A rejected claim must never clean or unlock the job that already owns this task. */
            let claimed = task
                .state
                .status()
                .ok()
                .and_then(|status| status.native_task)
                .is_some_and(|status| status.job == self.job.0.id);
            let cleaned = if claimed {
                self.cleanup_nodes().and_then(|(successful, _memory)| {
                    work::wait(task.state.dispatch(
                        Command::Unselect {
                            lock: task.lock,
                            cleanup: task.cleanup,
                            successful,
                        },
                        Context::default(),
                    ))
                    .map(|_| ())
                })
            } else {
                Err(Error::stale("file operation did not claim task"))
            };
            let unlocked = work::wait(task.state.submit(Action::Native(Box::new(
                job_owner::ReleaseTask {
                    task: task.clone(),
                    job: Some(self.job.0.id),
                },
            ))))
            .map(|_| ());
            cleaned.and(unlocked)
        });
        let mut state = self
            .job
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        state.cancelled = self.job.0.cancel.load(Ordering::Acquire);
        state.error = result.err();
        state.cleanup = cleanup;
        state.confirmation = None;
        state.answer = None;
        state.published = state.results.len();
        state.terminal = true;
        state.phase = JobPhase::Complete;
        self.job.0.changed.notify_all();
        drop(state);
        self.job.notify();
    }
}

#[cfg(test)]
mod notification_tests {
    use super::*;
    use crate::ux::treeview::Listener;

    struct Observer {
        job: Job,
        statuses: Mutex<Vec<JobStatus>>,
    }

    impl Listener for Observer {
        fn wake(&self) {
            /* Reading here also verifies that notification does not hold the Job status lock. */
            let status = self.job.status();
            self.statuses.lock().unwrap().push(status);
        }

        fn close(&self) {}

        fn is_closed(&self) -> bool {
            false
        }
    }

    #[test]
    fn t_job_notifications_coalesce_bytes_and_publish_confirmation_and_cancellation() {
        let data = DataHandle::new(Limits::default()).unwrap();
        let job = Job(Arc::new(Shared {
            _source: data.source(),
            _state: None,
            data: data.downgrade(),
            id: 1,
            cancel: AtomicBool::new(false),
            bytes: AtomicU64::new(0),
            processed: AtomicUsize::new(0),
            revision: AtomicU64::new(1),
            progress: Mutex::new(None),
            state: Mutex::new(Status {
                phase: JobPhase::Preparing,
                terminal: false,
                cancelled: false,
                confirmation: None,
                answer: None,
                results: Vec::new(),
                published: 0,
                error: None,
                cleanup: None,
            }),
            changed: Condvar::new(),
            task_memory: Memory::new(data.memory()),
            _memory: Charge::new(1024),
        }));
        let observer = Arc::new(Observer {
            job: job.clone(),
            statuses: Mutex::new(Vec::new()),
        });
        let listener: Arc<dyn Listener> = observer.clone();
        data.listen(&listener).unwrap();
        job.set_phase(JobPhase::Reading);
        assert_eq!(
            observer.statuses.lock().unwrap().last().unwrap().phase,
            JobPhase::Reading
        );
        job.set_phase(JobPhase::Working);
        job.copied(100);
        assert_eq!(observer.statuses.lock().unwrap().last().unwrap().bytes, 100);
        let count = observer.statuses.lock().unwrap().len();
        let revision = job.status().revision;
        /* Keep scheduler pauses from advancing the progress window in this test. */
        *job.0.progress.lock().unwrap() = Some(Instant::now() + Duration::from_secs(60));
        job.copied(200);
        assert_eq!(observer.statuses.lock().unwrap().len(), count);
        assert_eq!(job.status().bytes, 300);
        assert!(job.status_since(Some(revision)).is_none());
        job.processed();
        assert_eq!(observer.statuses.lock().unwrap().len(), count + 1);
        assert_eq!(
            observer.statuses.lock().unwrap().last().unwrap().processed,
            1
        );
        *job.0.progress.lock().unwrap() = Some(Instant::now() + Duration::from_secs(60));
        job.processed();
        assert_eq!(observer.statuses.lock().unwrap().len(), count + 1);
        assert_eq!(job.status().processed, 2);
        let count = observer.statuses.lock().unwrap().len();
        job.0.state.lock().unwrap().confirmation = Some(Confirmation {
            token: 1,
            item: ItemId(1),
            node: Some(NodeId(1)),
            source: PathBuf::from("source"),
            target: PathBuf::from("target"),
            prepare_move: false,
        });
        job.confirm(1, false).unwrap();
        assert_eq!(observer.statuses.lock().unwrap().len(), count + 1);
        assert_eq!(job.status_since(Some(revision)).unwrap().bytes, 300);
        job.cancel();
        assert!(observer.statuses.lock().unwrap().last().unwrap().cancelling);
        assert_eq!(observer.statuses.lock().unwrap().len(), count + 2);
        let weak = data.downgrade();
        drop(data);
        assert!(
            weak.upgrade().is_none(),
            "a Job notification must not retain its data owner"
        );
        job.notify();
    }

    #[test]
    fn t_copy_keeps_completed_io_when_batch_submission_exceeds_the_budget() {
        use super::super::tests::{Directory, request};
        use std::fs;

        struct Pressure {
            job: Job,
            memory: Arc<Budget>,
            charge: Mutex<Option<Charge>>,
        }
        impl Listener for Pressure {
            fn wake(&self) {
                if self.job.status().bytes == 0 {
                    return;
                }
                let mut charge = self.charge.lock().unwrap();
                if charge.is_none() {
                    let _guard = self.memory.enter();
                    *charge = Some(Charge::new(Limits::default().memory_bytes));
                }
            }
            fn close(&self) {}
            fn is_closed(&self) -> bool {
                false
            }
        }

        let directory = Directory::new();
        fs::create_dir(directory.0.join("dst")).unwrap();
        fs::write(directory.0.join("source"), b"contents").unwrap();
        let tree = request(Filetree::open(directory.0.clone()));
        let source = request(tree.resolve(directory.0.join("source")));
        let target = request(tree.resolve(directory.0.join("dst")));
        /* Hold IO until the listener is registered. The first copied bytes trigger
         * deterministic budget pressure after admission and before publication. */
        let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
        let job = tree
            .start_operation(OperationPlan {
                kind: OperationKind::Copy,
                source: source.source.clone(),
                nodes: vec![source.node].into(),
                target: Some(target.clone()),
                name: None,
                task: None,
                prepare_move: false,
            })
            .unwrap();
        let pressure = Arc::new(Pressure {
            job: job.clone(),
            memory: tree.data().memory(),
            charge: Mutex::new(None),
        });
        let listener: Arc<dyn Listener> = pressure.clone();
        tree.data().listen(&listener).unwrap();
        drop(execution);
        let start = Instant::now();
        while !job.status().terminal {
            assert!(start.elapsed() < Duration::from_secs(10));
            std::thread::sleep(Duration::from_millis(1));
        }
        assert!(pressure.charge.lock().unwrap().is_some());
        let status = job.status();
        assert!(status.error.is_none(), "{:?}", status.error);
        assert!(!status.cancelled);
        assert_eq!(status.results, 1);
        let results = job.results(0, status.results).unwrap();
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(results[0].error().is_none());
        assert_eq!(
            results[0].sync_error().unwrap().code,
            ErrorCode::ResourceLimit
        );
        assert_eq!(fs::read(directory.0.join("source")).unwrap(), b"contents");
        assert_eq!(
            fs::read(directory.0.join("dst/source")).unwrap(),
            b"contents"
        );
        assert_eq!(fs::read_dir(directory.0.join("dst")).unwrap().count(), 1);
        assert!(
            tree.index
                .lock()
                .unwrap()
                .child(Some(target.node), std::ffi::OsStr::new("source"))
                .is_none()
        );
        drop(listener);
        drop(pressure);
    }
}
