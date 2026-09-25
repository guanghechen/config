mod backend;

use super::work::{Demand, Dirty};
use super::{FileIdentity, Kind, resource};
use crate::ux::treeview::memory::Charge;
use crate::ux::treeview::storage::Map;
use crate::ux::treeview::*;
use std::collections::{BTreeSet, HashMap, HashSet};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

const LIMIT: usize = 50;
const MERGE: Duration = Duration::from_millis(150);

#[derive(Clone)]
struct Target {
    identity: FileIdentity,
    path: Arc<PathBuf>,
    nodes: Arc<Vec<NodeId>>,
    _memory: Arc<Charge>,
}
impl PartialEq for Target {
    fn eq(&self, other: &Self) -> bool {
        self.identity == other.identity && self.path == other.path && self.nodes == other.nodes
    }
}

#[derive(Clone, Default)]
pub struct Status {
    pub revision: u64,
    pub directories: usize,
    pub covered: Arc<[NodeId]>,
    pub limited: bool,
    pub error: Option<Error>,
    _memory: Option<Arc<Charge>>,
}

pub(crate) struct Viewport {
    pub state: u64,
    pub root: Root,
    pub nodes: Arc<[NodeId]>,
    pub _memory: Charge,
}
#[derive(Default)]
pub(crate) struct Interest {
    pub version: u64,
    pub viewports: Vec<Viewport>,
    pub status: Status,
}

struct Shared {
    desired: Mutex<Option<Desired>>,
    wake: Condvar,
    stopped: AtomicBool,
    interest: Arc<Mutex<Interest>>,
    _memory: Charge,
}

#[derive(Clone)]
struct Recovery {
    path: Arc<PathBuf>,
    nodes: Arc<Vec<NodeId>>,
    priority: usize,
    _memory: Arc<Charge>,
}
impl PartialEq for Recovery {
    fn eq(&self, other: &Self) -> bool {
        self.path == other.path && self.nodes == other.nodes && self.priority == other.priority
    }
}
struct Desired {
    targets: Vec<Target>,
    recoveries: Vec<Recovery>,
    root_targets: usize,
    limited: bool,
}

struct Controller {
    shared: Arc<Shared>,
}
impl Drop for Controller {
    fn drop(&mut self) {
        self.shared.stopped.store(true, Ordering::Release);
        self.shared.wake.notify_one();
    }
}

struct Dirtied {
    nodes: Arc<[NodeId]>,
    dirty: Dirty,
}
impl NativeAction for Dirtied {
    fn bytes(&self) -> usize {
        self.nodes.len() * 8 + 64
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let _memory = engine.memory.enter();
        let mut dirty = self.dirty.lock().unwrap_or_else(|error| error.into_inner());
        let mut next = dirty.clone();
        let generation = resource::sequence()?;
        for id in self.nodes.iter() {
            if engine.source().contains(*id) {
                let observed = next.get(id).is_none_or(|demand| demand.observed);
                next.insert(
                    *id,
                    Demand {
                        generation,
                        observed,
                    },
                );
            }
        }
        engine.memory.check()?;
        *dirty = next;
        Ok(Reply::NoChange)
    }
}

fn status(
    shared: &Shared,
    active: &HashMap<FileIdentity, (u64, Target)>,
    limited: bool,
    error: Option<Error>,
) -> Result<()> {
    let _guard = shared._memory.budget.as_ref().map(|budget| budget.enter());
    let mut covered: Vec<_> = active
        .values()
        .flat_map(|(_, target)| target.nodes.iter().copied())
        .collect();
    covered.sort_unstable();
    covered.dedup();
    let mut interest = shared
        .interest
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    if interest.status.directories != active.len()
        || interest.status.covered.as_ref() != covered
        || interest.status.error != error
        || interest.status.limited != limited
    {
        let memory = Arc::new(Charge::new(
            covered.capacity() * 8 + 128 + error.as_ref().map_or(0, |error| error.message.len()),
        ));
        crate::ux::treeview::memory::check()?;
        interest.status = Status {
            revision: interest.status.revision.saturating_add(1),
            directories: active.len(),
            covered: covered.into(),
            limited,
            error,
            _memory: Some(memory),
        };
    }
    Ok(())
}

impl Controller {
    fn new(interest: Arc<Mutex<Interest>>, dirty: Dirty, data: WeakDataHandle) -> Result<Self> {
        let shared = Arc::new(Shared {
            desired: Mutex::new(None),
            wake: Condvar::new(),
            stopped: AtomicBool::new(false),
            interest,
            _memory: Charge::new(512 * 1024),
        });
        crate::ux::treeview::memory::check()?;
        let worker = shared.clone();
        std::thread::Builder::new()
            .name("yoz-filetree-watch".into())
            .spawn(move || {
                let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    run(&worker, dirty, data)
                }))
                .unwrap_or_else(|_| Err(Error::invalid("directory watcher panicked")));
                if let Err(error) = result {
                    worker.stopped.store(true, Ordering::Release);
                    let mut interest = worker
                        .interest
                        .lock()
                        .unwrap_or_else(|error| error.into_inner());
                    interest.status = Status {
                        revision: interest.status.revision.saturating_add(1),
                        error: Some(error),
                        ..Status::default()
                    };
                }
            })
            .map_err(|error| resource::io_error("start directory watcher", error))?;
        Ok(Self { shared })
    }
    fn update(&self, desired: Desired) {
        *self
            .shared
            .desired
            .lock()
            .unwrap_or_else(|error| error.into_inner()) = Some(desired);
        self.shared.wake.notify_one();
    }
}

/** Resolve link-text parents on the watch thread, retaining root priority and the shared cap. */
fn recovery_targets(desired: Desired) -> Result<(Vec<Target>, bool, Option<Error>)> {
    if desired.recoveries.is_empty() {
        return Ok((desired.targets, desired.limited, None));
    }
    /* Resolved targets own their mutable buffers; the owner's demand cache stays immutable. */
    let mut pending = desired
        .targets
        .iter()
        .map(|target| Target {
            identity: target.identity,
            path: Arc::new((*target.path).clone()),
            nodes: Arc::new((*target.nodes).clone()),
            _memory: Arc::new(Charge::new(0)),
        })
        .enumerate()
        .peekable();
    let mut targets: Vec<Target> = Vec::new();
    let mut limited = desired.limited;
    let mut report = None;
    let mut admit = |target: Target| {
        if let Some(existing) = targets
            .iter_mut()
            .find(|existing| existing.identity == target.identity)
        {
            Arc::make_mut(&mut existing.nodes).extend(target.nodes.iter().copied());
        } else if targets.len() < LIMIT {
            targets.push(target);
        } else {
            limited = true;
        }
    };
    for recovery in desired.recoveries {
        /* Merge in demand order so recovery does not evict a more visible directory. */
        let priority = recovery.priority.max(desired.root_targets);
        while pending.peek().is_some_and(|(at, _)| *at < priority) {
            admit(pending.next().expect("pending target").1);
        }
        let resolved = (|| -> std::io::Result<_> {
            let path = std::fs::canonicalize(&*recovery.path)?;
            let metadata = std::fs::metadata(&path)?;
            if !metadata.is_dir() {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::NotADirectory,
                    "link target parent is not a directory",
                ));
            }
            let identity = FileIdentity::at(&path, &metadata, true)?;
            Ok((identity, path))
        })();
        let (identity, path) = match resolved {
            Ok(value) => value,
            Err(error) => {
                report = Some(resource::io_error("watch link target parent", error));
                continue;
            }
        };
        admit(Target {
            identity,
            path: Arc::new(path),
            nodes: Arc::new((*recovery.nodes).clone()),
            _memory: Arc::new(Charge::new(0)),
        });
    }
    for (_, target) in pending {
        admit(target);
    }
    for target in &mut targets {
        let nodes = Arc::make_mut(&mut target.nodes);
        nodes.sort_unstable();
        nodes.dedup();
        target._memory = Arc::new(Charge::new(
            nodes.capacity() * 8 + target.path.capacity() + std::mem::size_of::<Target>() + 64,
        ));
    }
    crate::ux::treeview::memory::check()?;
    Ok((targets, limited, report))
}

fn run(shared: &Shared, dirty: Dirty, data: WeakDataHandle) -> Result<()> {
    let mut backend = backend::Backend::new()?;
    let mut active = HashMap::<FileIdentity, (u64, Target)>::new();
    let mut changed = BTreeSet::new();
    let mut due = None;
    let mut pending: Option<(Ticket, Arc<[NodeId]>)> = None;
    let mut delivery_error = None;
    let mut limited = false;
    let mut report = None;
    while !shared.stopped.load(Ordering::Acquire) {
        let desired = shared
            .desired
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .take();
        if let Some(desired) = desired {
            let _memory = shared._memory.budget.as_ref().map(|budget| budget.enter());
            let (targets, limit, mut last_error) = recovery_targets(desired)?;
            limited = limit;
            let wanted: HashSet<_> = targets.iter().map(|target| target.identity).collect();
            active.retain(|identity, (id, _)| {
                if wanted.contains(identity) {
                    true
                } else {
                    backend.remove(*id);
                    false
                }
            });
            for target in targets {
                if let Some((id, current)) = active.get_mut(&target.identity) {
                    if current.path != target.path {
                        if let Err(error) = backend.add(*id, &target) {
                            last_error = Some(error);
                            changed.extend(target.nodes.iter().copied());
                            /* A failed path switch has no coverage and must retry registration. */
                            backend.remove(*id);
                            active.remove(&target.identity);
                            continue;
                        }
                    }
                    for node in target
                        .nodes
                        .iter()
                        .filter(|id| current.nodes.binary_search(id).is_err())
                    {
                        changed.insert(*node);
                    }
                    *current = target;
                } else {
                    let id = resource::sequence()?;
                    match backend.add(id, &target) {
                        Ok(()) => {
                            changed.extend(target.nodes.iter().copied());
                            active.insert(target.identity, (id, target));
                        }
                        Err(error) => {
                            changed.extend(target.nodes.iter().copied());
                            last_error = Some(error);
                        }
                    }
                }
            }
            /* Re-read after registration to close the read-before-watch gap. */
            if !changed.is_empty() {
                due.get_or_insert(Instant::now());
            }
            report = Some(last_error);
        }
        let events = backend.poll()?;
        if !events.is_empty() {
            for (id, target) in active.values() {
                if events.contains(id) {
                    changed.extend(target.nodes.iter().copied());
                }
            }
            due.get_or_insert_with(|| Instant::now() + MERGE);
        }
        if let Some((ticket, nodes)) = &pending {
            if let Some(outcome) = ticket.poll() {
                if let Outcome::Reply(Reply::Rejected { error }) = outcome {
                    if matches!(error.code, ErrorCode::ResourceLimit | ErrorCode::Busy) {
                        changed.extend(nodes.iter().copied());
                        due = Some(Instant::now() + Duration::from_millis(10));
                        delivery_error = Some(error.clone());
                    }
                    report = Some(Some(error));
                } else if let Some(error) = delivery_error.take() {
                    let mut interest = shared
                        .interest
                        .lock()
                        .unwrap_or_else(|error| error.into_inner());
                    /* Recovery owns only its delivery error, not a later registration or IO failure. */
                    if report.is_none() && interest.status.error.as_ref() == Some(&error) {
                        interest.status.error = None;
                        interest.status.revision = interest.status.revision.saturating_add(1);
                    }
                }
                pending = None;
            }
        }
        if backend.ready() && pending.is_none() && due.is_some_and(|due| due <= Instant::now()) {
            let Some(data) = data.upgrade() else { break };
            let nodes: Arc<[_]> = (0..512).filter_map(|_| changed.pop_first()).collect();
            if !nodes.is_empty() {
                pending = Some((
                    data.submit(Action::Native(Box::new(Dirtied {
                        nodes: nodes.clone(),
                        dirty: dirty.clone(),
                    }))),
                    nodes,
                ));
            }
            due = (!changed.is_empty()).then(Instant::now);
        }
        if backend.ready()
            && let Some(error) = report.take()
        {
            status(shared, &active, limited, error)?;
        }
        let desired = shared
            .desired
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if desired.is_none() && !shared.stopped.load(Ordering::Acquire) {
            drop(
                shared
                    .wake
                    .wait_timeout(desired, Duration::from_millis(10))
                    .unwrap_or_else(|error| error.into_inner()),
            );
        }
    }
    Ok(())
}

pub(crate) struct Watcher {
    interest: Arc<Mutex<Interest>>,
    dirty: Dirty,
    controller: Option<Controller>,
    key: Option<(Vec<(u64, Root, DisplayOptions, u32, usize)>, u64)>,
    index: Option<super::index::Index>,
    recent: Map<NodeId, u64>,
    previous: Map<NodeId, ()>,
    limited: bool,
    targets: Vec<Target>,
    recoveries: Vec<Recovery>,
    root_targets: usize,
}
impl Watcher {
    pub fn new(interest: Arc<Mutex<Interest>>, dirty: Dirty) -> Self {
        Self {
            interest,
            dirty,
            controller: None,
            key: None,
            index: None,
            recent: Map::default(),
            previous: Map::default(),
            limited: false,
            targets: Vec::new(),
            recoveries: Vec::new(),
            root_targets: 0,
        }
    }
    pub fn error(&mut self, error: Error) {
        let mut interest = self
            .interest
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        interest.status.error = Some(error);
        interest.status.revision = interest.status.revision.saturating_add(1);
    }
    pub fn publish(&mut self, engine: &Engine, data: &WeakDataHandle, index: &super::index::Index) {
        let inputs: Vec<_> = engine
            .states
            .iter()
            .map(|(&id, entry)| {
                (
                    id,
                    entry.state.root.clone(),
                    entry.state.display.clone(),
                    entry.state.expansion.generation,
                    entry.views,
                )
            })
            .collect();
        let interest = self
            .interest
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let key = (inputs, interest.version);
        if self.key.as_ref() == Some(&key)
            && self
                .index
                .as_ref()
                .is_some_and(|old| old.same_watch_version(index))
        {
            return;
        }
        let retry = interest.status.error.is_some();
        let source = engine.source();
        let mut wanted = HashSet::new();
        let mut roots = HashSet::new();
        let mut visible = HashSet::new();
        for state in engine.states.values().filter(|entry| entry.views != 0) {
            match state.state.root {
                Root::ChildrenOf(root) => {
                    roots.insert(root);
                }
                _ => roots.extend(state.state.display_roots(source)),
            }
            if state.state.display.mode == Mode::Tree
                && state.state.expansion.is_clear()
                && state.state.expansion.clear & 1 == 0
            {
                continue;
            }
            for (id, _) in index.directories.iter() {
                if state.state.demands_children(source, *id) {
                    wanted.insert(*id);
                }
            }
            for (id, _) in index.links.iter() {
                if state.state.observes_children(source, *id) {
                    wanted.insert(*id);
                }
            }
        }
        wanted.extend(roots.iter().copied());
        let mut visited = HashSet::new();
        for viewport in &interest.viewports {
            let Some(state) = engine
                .states
                .get(&viewport.state)
                .filter(|state| state.views != 0 && state.state.root == viewport.root)
            else {
                continue;
            };
            /* The same leaf can have more visible ancestors under another viewport root. */
            visited.clear();
            for &id in viewport.nodes.iter() {
                let mut current = Some(id);
                while let Some(id) = current {
                    if !visited.insert(id) {
                        break;
                    }
                    visible.insert(id);
                    current = source.node(id).and_then(|node| node.parent);
                    if state.state.root == Root::ChildrenOf(id) {
                        break;
                    }
                }
            }
        }
        drop(interest);
        let removed: Vec<_> = self
            .recent
            .iter()
            .filter_map(|(id, _)| (!source.contains(*id)).then_some(*id))
            .collect();
        for id in removed {
            self.recent.remove(&id);
        }
        let tick = match resource::sequence() {
            Ok(tick) => tick,
            Err(_) => return,
        };
        for &id in &wanted {
            if self.previous.get(&id).is_none() || visible.contains(&id) {
                self.recent.insert(id, tick);
            }
        }
        let mut ordered: Vec<_> = wanted.iter().copied().collect();
        ordered.sort_unstable_by_key(|id| {
            (
                !roots.contains(id),
                !visible.contains(id),
                std::cmp::Reverse(self.recent.get(id).copied().unwrap_or(0)),
                *id,
            )
        });
        let mut targets = Vec::<Target>::new();
        let mut groups = HashMap::new();
        let mut recoveries = Vec::<Recovery>::new();
        let mut recovery_groups = HashMap::<PathBuf, usize>::new();
        let mut root_targets = 0;
        let mut limited = false;
        for id in ordered {
            /* Aliases may share their referent, but retain each entry's parent demands. */
            if !roots.contains(&id)
                && index.links.get(&id).is_none()
                && let Some(identity) = index.directories.get(&id)
            {
                if let Some(&at) = groups.get(identity) {
                    let target: &mut Target = &mut targets[at];
                    Arc::make_mut(&mut target.nodes).push(id);
                    continue;
                }
                if targets.len() == LIMIT && !groups.contains_key(identity) {
                    limited = true;
                    continue;
                }
            }
            let Ok(entry) = resource::entry(source, id) else {
                continue;
            };
            let mut requests = Vec::new();
            let mut recovery_path = None;
            if entry.directory() {
                if let (Some(identity), Ok(path)) =
                    (entry.target_identity(), resource::path(source, id))
                {
                    requests.push((identity, path));
                }
            }
            if entry.kind == Kind::Link {
                if let Some(parent) = source.node(id).and_then(|node| node.parent) {
                    if let (Ok(entry), Ok(path)) = (
                        resource::entry(source, parent),
                        resource::path(source, parent),
                    ) {
                        if let Some(identity) = entry.target_identity() {
                            requests.push((identity, path));
                        }
                    }
                    if let (Some(link), Ok(parent_path)) =
                        (&entry.link, resource::path(source, parent))
                    {
                        if let Some(path) = parent_path.join(link).parent() {
                            recovery_path = Some(path.to_owned());
                        }
                    }
                }
            }
            for (identity, path) in requests {
                if let Some(&at) = groups.get(&identity) {
                    let target: &mut Target = &mut targets[at];
                    Arc::make_mut(&mut target.nodes).push(id);
                } else if targets.len() < LIMIT {
                    groups.insert(identity, targets.len());
                    targets.push(Target {
                        identity,
                        path: Arc::new(path),
                        nodes: Arc::new(vec![id]),
                        _memory: Arc::new(Charge::new(0)),
                    });
                } else {
                    limited = true;
                }
            }
            if let Some(path) = recovery_path {
                if let Some(&at) = recovery_groups.get(&path) {
                    Arc::make_mut(&mut recoveries[at].nodes).push(id);
                } else {
                    recovery_groups.insert(path.clone(), recoveries.len());
                    recoveries.push(Recovery {
                        path: Arc::new(path),
                        nodes: Arc::new(vec![id]),
                        priority: targets.len(),
                        _memory: Arc::new(Charge::new(0)),
                    });
                }
            }
            if roots.contains(&id) {
                root_targets = targets.len();
            }
        }
        for recovery in &mut recoveries {
            recovery._memory = Arc::new(Charge::new(
                recovery.path.capacity()
                    + recovery.nodes.capacity() * 8
                    + std::mem::size_of::<Recovery>()
                    + 64,
            ));
        }
        for target in &mut targets {
            let nodes = Arc::make_mut(&mut target.nodes);
            nodes.sort_unstable();
            nodes.dedup();
            target._memory = Arc::new(Charge::new(
                nodes.capacity() * 8 + target.path.capacity() + std::mem::size_of::<Target>() + 64,
            ));
        }
        if let Err(error) = crate::ux::treeview::memory::check() {
            self.recent = Map::default();
            self.previous = Map::default();
            self.index = None;
            self.targets.clear();
            self.recoveries.clear();
            self.root_targets = 0;
            self.controller = None;
            let mut interest = self
                .interest
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            interest.status = Status {
                revision: interest.status.revision.saturating_add(1),
                error: Some(error),
                ..Status::default()
            };
            return;
        }
        if targets != self.targets
            || recoveries != self.recoveries
            || root_targets != self.root_targets
            || limited != self.limited
            || retry
        {
            if self
                .controller
                .as_ref()
                .is_some_and(|controller| controller.shared.stopped.load(Ordering::Acquire))
            {
                self.controller = None;
            }
            /* The demand cache above bounds retries when controller creation fails. */
            if self.controller.is_none() && !targets.is_empty() {
                match Controller::new(self.interest.clone(), self.dirty.clone(), data.clone()) {
                    Ok(controller) => self.controller = Some(controller),
                    Err(error) => {
                        let mut interest = self
                            .interest
                            .lock()
                            .unwrap_or_else(|error| error.into_inner());
                        interest.status.error = Some(error);
                        interest.status.revision += 1;
                    }
                }
            }
            if let Some(controller) = &self.controller {
                controller.update(Desired {
                    targets: targets.clone(),
                    recoveries: recoveries.clone(),
                    root_targets,
                    limited,
                });
            }
            self.targets = targets;
            self.recoveries = recoveries;
            self.root_targets = root_targets;
        }
        let mut previous: Vec<_> = wanted.into_iter().map(|id| (id, ())).collect();
        previous.sort_unstable_by_key(|(id, _)| *id);
        self.previous = Map::from_sorted(previous);
        self.limited = limited;
        self.index = Some(index.clone());
        self.key = Some(key);
    }
}

#[cfg(all(test, any(target_os = "macos", target_os = "linux", windows)))]
mod tests;
