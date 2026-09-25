use super::io::{self, Destination, Signature};
use super::{Entry, Filetree, Kind, Request, Resource, job_owner, resource, work};
use crate::ux::treeview::memory::{Budget, Charge};
use crate::ux::treeview::*;
use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::{Component, Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

mod create;
mod trash;
pub use create::CreatePlan;

const RESULT_LIMIT: usize = 32 * 1024 * 1024;
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
#[derive(Clone)]
pub struct ItemResult {
    pub node: NodeId,
    pub source: PathBuf,
    pub target: Option<PathBuf>,
    pub source_physical: Option<PathBuf>,
    pub target_physical: Option<PathBuf>,
    pub status: ItemStatus,
    pub error: Option<Error>,
    pub error_kind: Option<String>,
    pub os_code: Option<i32>,
    pub sync_error: Option<Error>,
    _memory: Arc<Charge>,
    _path_memory: Option<Arc<Charge>>,
    bytes: usize,
}
#[derive(Clone)]
pub struct Confirmation {
    pub token: u64,
    pub node: NodeId,
    pub source: PathBuf,
    pub target: PathBuf,
    pub prepare_move: bool,
}
#[derive(Clone)]
pub struct JobStatus {
    pub terminal: bool,
    pub cancelling: bool,
    pub cancelled: bool,
    pub confirmation: Option<Confirmation>,
    pub results: usize,
    pub bytes: u64,
    pub error: Option<Error>,
    pub cleanup: Option<Result<()>>,
}
struct Status {
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
    id: u64,
    cancel: AtomicBool,
    bytes: AtomicU64,
    state: Mutex<Status>,
    changed: Condvar,
    _memory: Charge,
}
#[derive(Clone)]
pub struct Job(Arc<Shared>);
impl Job {
    pub fn status(&self) -> JobStatus {
        let state = self
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        JobStatus {
            terminal: state.terminal,
            cancelling: !state.terminal && self.0.cancel.load(Ordering::Acquire),
            cancelled: state.cancelled,
            confirmation: state.confirmation.clone(),
            results: state.published,
            bytes: self.0.bytes.load(Ordering::Relaxed),
            error: state.error.clone(),
            cleanup: state.cleanup.clone(),
        }
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
        .fetch_update(Ordering::AcqRel, Ordering::Acquire, |count| {
            (count < 16).then_some(count + 1)
        })
        .map_err(|_| Error::new(ErrorCode::Busy, "file operation capacity exceeded"))?;
    let active = Active;
    let memory = tree.data().memory();
    let _guard = memory.enter();
    let job = Job(Arc::new(Shared {
        _source: plan.source.clone(),
        _state: plan.task.as_ref().map(|task| task.state.clone()),
        id: resource::sequence()?,
        cancel: AtomicBool::new(false),
        bytes: AtomicU64::new(0),
        state: Mutex::new(Status {
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
        _memory: Charge::new(1024 + plan.nodes.len() * 8),
    }));
    memory.check()?;
    let runner = Runner {
        tree,
        plan,
        job: job.clone(),
        memory,
        retained: 0,
        successful: Vec::new(),
        physical: HashMap::new(),
    };
    std::thread::Builder::new()
        .name(format!("yoz-filetree-job-{}", job.0.id))
        .spawn(move || {
            let _active = active;
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
    retained: usize,
    successful: Vec<NodeId>,
    physical: HashMap<NodeId, (Option<PathBuf>, Option<PathBuf>, Arc<Charge>, usize)>,
}
struct Directory {
    created: bool,
    source: Resource,
    path: PathBuf,
    target: Option<Resource>,
    target_path: Option<PathBuf>,
    children: Arc<Source>,
    next: usize,
    success: bool,
    result_start: usize,
    successful_start: usize,
    charge: Arc<Charge>,
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
        if let Some(task) = &self.plan.task {
            let status = task.state.status()?;
            if status.native_task != Some((task.lock, task.cleanup, self.job.0.id, true)) {
                return Err(Error::stale("file operation task context changed"));
            }
        }
        Ok(())
    }
    fn reserve(&mut self, bytes: usize) -> Result<Arc<Charge>> {
        if self.retained.saturating_add(bytes) > RESULT_LIMIT {
            return Err(Error::limit("file operation result capacity exceeded"));
        }
        let _guard = self.memory.enter();
        let charge = Arc::new(Charge::new(bytes));
        self.memory.check()?;
        self.retained += bytes;
        Ok(charge)
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
        for node in roots.iter().copied() {
            self.check()?;
            let source = Resource {
                node,
                source: self.plan.source.clone(),
            };
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
                let parent = directory
                    .children
                    .node(directory.source.node)
                    .expect("directory snapshot");
                if let Some(node) = parent.child_at(directory.next) {
                    directory.next += 1;
                    pending = Some((
                        Resource {
                            source: directory.children.clone(),
                            node,
                        },
                        directory.target.clone(),
                        None,
                    ));
                    continue;
                }
                let directory = stack.pop().expect("directory");
                let success = self.end(directory)?;
                if let Some(parent) = stack.last_mut() {
                    parent.success &= success;
                }
            }
            let mut state = self
                .job
                .0
                .state
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            state.published = state.results.len();
        }
        Ok(())
    }
    fn read(&self, source: &Resource) -> Result<Arc<Source>> {
        self.check()?;
        job_owner::current(&self.tree.source(), source, true)?;
        let lease = Arc::new(Mutex::new(None));
        work::wait(
            self.tree
                .data()
                .submit(Action::Native(Box::new(job_owner::Read {
                    node: source.node,
                    task: self.plan.task.clone(),
                    lease: lease.clone(),
                }))),
        )?;
        let result = (|| {
            loop {
                self.check()?;
                let current = self.tree.source();
                let node = current
                    .node(source.node)
                    .ok_or_else(|| Error::missing(source.node))?;
                if let Some(error) = &node.error {
                    return Err(error.clone());
                }
                if node.completeness == Completeness::Complete && node.load_state == LoadState::Idle
                {
                    job_owner::current(&current, source, true)?;
                    return Ok(current);
                }
                std::thread::sleep(Duration::from_millis(2));
            }
        })();
        if let Some(lease) = *lease.lock().unwrap_or_else(|error| error.into_inner()) {
            work::wait(
                self.tree
                    .data()
                    .submit(Action::Native(Box::new(job_owner::Release(lease)))),
            )?;
        }
        result
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
        let limit = RESULT_LIMIT.saturating_sub(self.retained);
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
                let size = entry.encode().len() * 2 + 512;
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

    fn publish(
        &self,
        source: &Resource,
        target: Option<Resource>,
        entry: Option<Entry>,
        moved: bool,
        token: Option<TaskUpdateToken>,
        replaced: Option<job_owner::Replacement>,
        descendants: Option<job_owner::MovedDescendants>,
    ) -> Result<Option<Resource>> {
        let result = Arc::new(Mutex::new(None));
        work::wait(
            self.tree
                .data()
                .submit(Action::Native(Box::new(job_owner::Publish {
                    tree: self.tree.clone(),
                    source: source.clone(),
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
        &self,
        source: &Resource,
        path: &Path,
        target: &Path,
        prepare_move: bool,
    ) -> Result<bool> {
        self.check()?;
        let mut state = self
            .job
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        state.confirmation = Some(Confirmation {
            token: resource::sequence()?,
            node: source.node,
            source: path.to_owned(),
            target: target.to_owned(),
            prepare_move,
        });
        state.answer = None;
        loop {
            if let Err(error) = self.check() {
                state.confirmation = None;
                return Err(error);
            }
            if let Some(answer) = state.answer.take() {
                state.confirmation = None;
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
        source: &Resource,
        path: PathBuf,
        target: Option<PathBuf>,
        status: ItemStatus,
        error: Option<std::io::Error>,
        sync_error: Option<Error>,
        charge: Arc<Charge>,
    ) {
        if status == ItemStatus::Success {
            self.successful.push(source.node);
        }
        let reserved = 4096
            + path.as_os_str().len() * 2
            + target.as_ref().map_or(0, |path| path.as_os_str().len() * 2);
        let (source_physical, target_physical, path_memory, path_bytes) = self
            .physical
            .remove(&source.node)
            .map_or((None, None, None, 0), |(source, target, charge, bytes)| {
                (source, target, Some(charge), bytes)
            });
        let mut value = ItemResult {
            node: source.node,
            source: path,
            target,
            source_physical,
            target_physical,
            status,
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
            _memory: charge,
            _path_memory: path_memory,
            bytes: reserved + path_bytes,
        };
        let bytes = std::mem::size_of::<ItemResult>()
            + 192
            + value.source.as_os_str().len() * 2
            + value
                .target
                .as_ref()
                .map_or(0, |path| path.as_os_str().len() * 2)
            + value.error.as_ref().map_or(0, |error| error.message.len())
            + value
                .sync_error
                .as_ref()
                .map_or(0, |error| error.message.len());
        if bytes < reserved {
            Arc::get_mut(&mut value._memory)
                .expect("unpublished result reservation")
                .shrink(bytes);
            value.bytes = bytes + path_bytes;
            self.retained -= reserved - bytes;
        }
        self.job
            .0
            .state
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .results
            .push(Arc::new(value));
    }
    fn begin(
        &mut self,
        source: Resource,
        target: Option<Resource>,
        name: Option<OsString>,
        root: bool,
    ) -> Result<Step> {
        self.check()?;
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
        let charge = self.reserve(
            4096 + path.as_os_str().len() * 2
                + target_path
                    .as_ref()
                    .map_or(0, |path| path.as_os_str().len() * 2),
        )?;
        let expected = Signature::entry(&entry, false);
        let parent_signature = source
            .source
            .node(source.node)
            .and_then(|node| node.parent)
            .map(|node| {
                resource::entry(&source.source, node).map(|entry| Signature::entry(&entry, true))
            })
            .transpose()?;
        let preparation = (|| -> std::io::Result<Option<Destination>> {
            expected.verify(&path, false)?;
            if let Some(parent) = &parent_signature {
                parent.verify(path.parent().expect("source parent"), true)?;
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
            let mut case_rename = false;
            #[cfg(any(target_os = "macos", windows))]
            if self.plan.kind == OperationKind::Move
                && source.source.node(source.node).and_then(|node| node.parent)
                    == target.as_ref().map(|target| target.node)
                && path.file_name() != target_path.as_ref().expect("target").file_name()
            {
                let destination = target_path.as_ref().expect("target");
                case_rename = std::fs::canonicalize(path.parent().expect("source parent")).ok()
                    == std::fs::canonicalize(destination.parent().expect("target parent")).ok()
                    && resource::observed_name(&path)? == resource::observed_name(destination)?;
            }
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
                job_owner::current(&current, &source, false).map_err(std::io::Error::other)?;
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
            if self.retained.saturating_add(bytes) > RESULT_LIMIT {
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
        let valid = job_owner::current(&current, &source, false).and_then(|_| {
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
                source.node,
                target.as_ref().map(|target| target.node),
                relocated.as_ref(),
            )?
        } else {
            None
        };
        let mut execution = Some(EXECUTOR.lock().unwrap_or_else(|error| error.into_inner()));
        self.check()?;
        let mut moving = if matches!(self.plan.kind, OperationKind::Move | OperationKind::Trash) {
            Some(Moving::begin(&self.tree, &source, token)?)
        } else {
            None
        };
        self.check()?;
        let _memory = self.memory.enter();
        let buffer = Charge::new(io::COPY_BUFFER);
        self.memory.check()?;
        let result = (|| -> std::io::Result<bool> {
            expected.verify(&path, false)?;
            if let Some(parent) = &parent_signature {
                parent.verify(path.parent().expect("source parent"), true)?;
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
                    self.physical.insert(source.node, (from, to, charge, bytes));
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
                OperationKind::Copy => io::copy(
                    &path,
                    &expected,
                    destination.as_ref().expect("copy target"),
                    &self.job.0.cancel,
                    &self.job.0.bytes,
                )?,
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
                            io::copy(
                                &path,
                                &expected,
                                destination,
                                &self.job.0.cancel,
                                &self.job.0.bytes,
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
                .map(|path| {
                    let mut entry = Entry::read(path)?;
                    #[cfg(any(target_os = "macos", windows))]
                    {
                        entry.name =
                            resource::observed_name(path).map_err(std::io::Error::other)?;
                    }
                    Ok::<_, std::io::Error>(entry)
                })
                .transpose()
        } else {
            Ok(None)
        };
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
                        &source,
                        target.as_ref().expect("move target"),
                        target_path.as_ref().expect("move path"),
                        observed,
                    )
                })
                .transpose()
        } else {
            Ok(None)
        };
        drop(buffer);
        if moving.is_none() || result.is_err() {
            drop(moving.take());
            drop(execution.take());
        }
        let directory = match result {
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
            let children = match self.read(&source) {
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
                next: 0,
                success: true,
                result_start,
                successful_start: self.successful.len(),
                charge,
            }));
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
                self.authorize(directory.source.node, None, None)?
            } else if let Some(task) = &self.plan.task {
                let mut changes = vec![ExpectedChange::Reparent {
                    node: directory.source.node,
                    parent: target_parent,
                }];
                changes.extend(children.iter().map(|node| ExpectedChange::Reparent {
                    node: *node,
                    parent: Some(directory.source.node),
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
                Some(Moving::begin(&self.tree, &directory.source, token)?)
            } else {
                None
            };
            self.check()?;
            let result = (|| -> std::io::Result<()> {
                if let Some(target) = &directory.target {
                    Signature::entry(&target.entry().map_err(std::io::Error::other)?, true)
                        .verify(&target.path().map_err(std::io::Error::other)?, true)?;
                }
                if let Some(parent) = directory
                    .source
                    .source
                    .node(directory.source.node)
                    .and_then(|node| node.parent)
                {
                    Signature::entry(
                        &resource::entry(&directory.source.source, parent)
                            .map_err(std::io::Error::other)?,
                        true,
                    )
                    .verify(directory.path.parent().expect("source parent"), true)?;
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
                                source: directory.source.clone(),
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
                .all(|result| result.sync_error.is_none())
                && sync_error.is_none()
            {
                let released: usize = state.results[directory.result_start..]
                    .iter()
                    .map(|result| result.bytes)
                    .sum();
                self.retained -= released;
                state.results.truncate(directory.result_start);
                self.successful.truncate(directory.successful_start);
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
        let cleanup = self.plan.task.as_ref().map(|task| {
            /* A rejected claim must never clean or unlock the job that already owns this task. */
            let claimed = task
                .state
                .status()
                .ok()
                .and_then(|status| status.native_task)
                .is_some_and(|(_, _, id, _)| id == self.job.0.id);
            let cleaned = if claimed {
                work::wait(task.state.dispatch(
                    Command::Unselect {
                        lock: task.lock,
                        cleanup: task.cleanup,
                        successful: self.successful.clone().into(),
                    },
                    Context::default(),
                ))
                .map(|_| ())
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
        self.job.0.changed.notify_all();
    }
}
