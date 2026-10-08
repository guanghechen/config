//! File explorer interaction policy; Treeview remains the only topology and selection owner.

pub(crate) mod lua;

use super::filetree::{
    CreatePlan, Entry, Filetree, Job, OperationPlan, Request, Resource, WeakJob,
};
use super::treeview::*;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

#[derive(Clone)]
pub struct Explorer {
    pub tree: Filetree,
    pub state: StateHandle,
    pub workspace: Option<NodeId>,
    workspace_path: Arc<PathBuf>,
    previous: Arc<Mutex<Option<NodeId>>>,
    /* The worker and callers own Jobs; this guard only prevents concurrent starts. */
    job: Arc<Mutex<WeakJob>>,
}

#[derive(Clone, Copy)]
pub enum Mark {
    Toggle,
    Select,
    Copy,
    Cut,
}

#[derive(Clone, Copy)]
pub enum Fold {
    Toggle,
    Recursive,
    Collapse,
}

pub enum Workspace {
    Resource(Resource),
    Path(PathBuf),
}

impl Explorer {
    pub fn new(tree: Filetree, state: StateHandle, workspace: Workspace) -> Result<Self> {
        if tree.source().identity() != state.data().source().identity() {
            return Err(Error::invalid("Explorer state belongs to another Filetree"));
        }
        let Root::ChildrenOf(root) = *state.snapshot()?.root() else {
            return Err(Error::invalid("Explorer requires a directory display root"));
        };
        let source = tree.source();
        let (workspace, workspace_path) = match workspace {
            Workspace::Resource(resource) => {
                if resource.source.identity() != source.identity() {
                    return Err(Error::invalid("workspace belongs to another Filetree"));
                }
                if !resource.entry()?.directory() {
                    return Err(Error::invalid("workspace is not a browsable directory"));
                }
                (Some(resource.node), resource.path()?)
            }
            Workspace::Path(workspace_path) => {
                let workspace_path = std::path::absolute(workspace_path)
                    .map_err(|error| Error::invalid(format!("invalid workspace path: {error}")))?;
                let mut workspace = None;
                /* Bind a known ancestor without making a valid opening wait for workspace IO. */
                for start in [root, tree.root()] {
                    if !source.contains(start) {
                        continue;
                    }
                    let mut path = Resource {
                        source: source.clone(),
                        node: start,
                    }
                    .path()?;
                    let mut current = Some(start);
                    while let Some(node) = current {
                        if path == workspace_path {
                            workspace = Some(node);
                            break;
                        }
                        current = source.node(node).and_then(|entry| entry.parent);
                        path.pop();
                    }
                    if workspace.is_some() {
                        break;
                    }
                }
                (workspace, workspace_path)
            }
        };
        Ok(Self {
            tree,
            state,
            workspace,
            workspace_path: Arc::new(workspace_path),
            previous: Arc::new(Mutex::new(None)),
            job: Arc::new(Mutex::new(WeakJob::default())),
        })
    }

    pub fn previous(&self) -> Option<NodeId> {
        *self
            .previous
            .lock()
            .unwrap_or_else(|error| error.into_inner())
    }

    pub fn workspace_path(&self) -> Result<PathBuf> {
        let source = self.tree.source();
        if let Some(workspace) = self.workspace.filter(|node| source.contains(*node)) {
            Resource {
                source,
                node: workspace,
            }
            .path()
        } else {
            Ok((*self.workspace_path).clone())
        }
    }

    pub fn mark(
        &self,
        frame: Arc<Snapshot>,
        start: usize,
        end: usize,
        mark: Mark,
        visual: bool,
    ) -> Ticket {
        self.state.submit(Action::Native(Box::new(Marking {
            state: self.state.id(),
            frame,
            start,
            end,
            mark,
            visual,
        })))
    }

    pub fn fold(&self, frame: Arc<Snapshot>, node: NodeId, kind: Fold) -> Ticket {
        self.state.submit(Action::Native(Box::new(Folding {
            state: self.state.id(),
            frame,
            node,
            kind,
        })))
    }

    /// Cancel copy/cut while retaining selection; otherwise clear the selection.
    pub fn cancel_transfer_or_clear_selection(&self) -> Ticket {
        self.state.submit(Action::Native(Box::new(ResetSelection {
            state: self.state.id(),
        })))
    }

    pub fn inspect_range(&self, frame: Arc<Snapshot>, start: usize, end: usize) -> Ticket {
        self.state.submit(Action::Native(Box::new(InspectRange {
            state: self.state.id(),
            frame,
            start,
            end,
        })))
    }

    pub fn prepare_cursor(&self, frame: Arc<Snapshot>, node: NodeId) -> Ticket {
        self.state.submit(Action::Native(Box::new(PrepareCursor {
            state: self.state.id(),
            frame,
            node,
        })))
    }

    pub fn prepare_selection(&self) -> Ticket {
        self.state.submit(Action::Native(Box::new(PrepareSelection {
            state: self.state.id(),
        })))
    }

    pub fn navigate(&self, node: NodeId, reveal: bool) -> Ticket {
        self.state.submit(Action::Native(Box::new(Navigation {
            explorer: self.clone(),
            target: NavigationTarget::Node(node),
            reveal,
        })))
    }

    pub fn navigate_parent(&self) -> Ticket {
        self.state.submit(Action::Native(Box::new(Navigation {
            explorer: self.clone(),
            target: NavigationTarget::Parent,
            reveal: false,
        })))
    }

    pub fn reveal_path(&self, path: PathBuf) -> Request<PathBuf> {
        let frame = match self.state.snapshot() {
            Ok(frame) => frame,
            Err(error) => return Request::ready(Err(error)),
        };
        Request::run(move || {
            let failure = |error: std::io::Error| {
                Error::new(
                    ErrorCode::ProviderError,
                    format!("resolve Explorer reveal: {error}"),
                )
            };
            let Root::ChildrenOf(root) = *frame.root() else {
                return Err(Error::invalid("Explorer requires a directory display root"));
            };
            let root = Resource {
                source: frame.source.clone(),
                node: root,
            };
            let logical = match root.path() {
                Ok(logical) => logical,
                Err(error) if error.code == ErrorCode::MissingNode => return Ok(path),
                Err(error) => return Err(error),
            };
            if path.starts_with(&logical) {
                return Ok(path);
            }
            let physical = std::fs::canonicalize(&path).map_err(failure)?;
            let expected = root.entry()?;
            let observed = match Entry::read(&logical) {
                Ok(observed) => observed,
                Err(error)
                    if matches!(
                        error.kind(),
                        std::io::ErrorKind::NotFound | std::io::ErrorKind::NotADirectory
                    ) =>
                {
                    return Ok(path);
                }
                Err(error) => return Err(failure(error)),
            };
            if observed.identity != expected.identity
                || observed.target != expected.target
                || observed.kind != expected.kind
            {
                /* A stale display root cannot supply aliases for an explicit target. */
                return Ok(path);
            }
            let mut best: Option<(usize, PathBuf)> = None;
            let mut consider = |alias: PathBuf| {
                if let Ok(target) = std::fs::canonicalize(&alias)
                    && let Ok(relative) = physical.strip_prefix(&target)
                {
                    let depth = target.components().count();
                    let candidate = alias.join(relative);
                    if best.as_ref().is_none_or(|(old_depth, old)| {
                        depth > *old_depth || depth == *old_depth && candidate < *old
                    }) {
                        best = Some((depth, candidate));
                    }
                }
            };
            consider(logical.clone());
            for entry in std::fs::read_dir(&logical).map_err(failure)? {
                let entry = entry.map_err(failure)?;
                if entry.file_type().map_err(failure)?.is_symlink() {
                    consider(entry.path());
                }
            }
            Ok(best.map_or(path, |(_, path)| path))
        })
    }

    pub fn start_operation(&self, plan: OperationPlan) -> Result<Job> {
        let mut current = self.job.lock().unwrap_or_else(|error| error.into_inner());
        if current.upgrade().is_some_and(|job| !job.status().terminal) {
            return Err(Error::new(
                ErrorCode::Busy,
                "Explorer already has an active job",
            ));
        }
        let job = self.tree.start_operation(plan)?;
        *current = job.downgrade();
        Ok(job)
    }

    pub fn start_create(&self, plan: CreatePlan) -> Result<Job> {
        let mut current = self.job.lock().unwrap_or_else(|error| error.into_inner());
        if current.upgrade().is_some_and(|job| !job.status().terminal) {
            return Err(Error::new(
                ErrorCode::Busy,
                "Explorer already has an active job",
            ));
        }
        let job = self.tree.start_create(plan)?;
        *current = job.downgrade();
        Ok(job)
    }
}

pub fn mode(frame: &Snapshot) -> Option<&str> {
    frame
        .state
        .selection_purpose
        .as_deref()
        .or_else(|| (!frame.summary.is_empty()).then_some("select"))
}

struct ResetSelection {
    state: u64,
}

impl NativeAction for ResetSelection {
    fn bytes(&self) -> usize {
        64
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let state = &engine
            .states
            .get(&self.state)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?
            .state;
        if !matches!(state.selection_purpose.as_deref(), Some("copy" | "cut")) {
            return engine.dispatch(self.state, Command::ClearSelection, Context::default());
        }
        state.check_unlocked()?;
        let mut candidate = engine.clone();
        let entry = candidate
            .states
            .get_mut(&self.state)
            .expect("Explorer state");
        entry.state.selection_purpose = None;
        entry.state.revision = entry.state.revision.next()?;
        entry.dirty.pending = true;
        candidate.commit = candidate.commit.next()?;
        candidate.memory.check()?;
        let reply = candidate.applied(
            Some(self.state),
            vec![Effect::ViewChanged { state: self.state }],
        );
        *engine = candidate;
        Ok(reply)
    }
}

struct InspectRange {
    state: u64,
    frame: Arc<Snapshot>,
    start: usize,
    end: usize,
}

impl NativeAction for InspectRange {
    fn bytes(&self) -> usize {
        256
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let state = &engine
            .states
            .get(&self.state)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?
            .state;
        let nodes = engine.targets(
            state,
            &Targets::Range {
                frame: self.frame.clone(),
                start: self.start,
                end: self.end,
            },
            None,
            Scope::Subtree,
            &Context::default(),
        )?;
        Ok(Reply::Inspected {
            revisions: engine.revisions(Some(self.state)),
            source: self.frame.source.clone(),
            sources: SelectionSources {
                /* Owner revisions describe validation; range resources retain the input snapshot. */
                data_revision: self.frame.source.revision(),
                selection_revision: state.selection_revision,
                summary: Summary {
                    known_roots: nodes.len(),
                    ..Summary::default()
                },
                subtree_roots: nodes.into(),
                self_only_nodes: Arc::from([]),
                needed_children: Arc::from([]),
            },
        })
    }
}

struct PrepareCursor {
    state: u64,
    frame: Arc<Snapshot>,
    node: NodeId,
}

impl NativeAction for PrepareCursor {
    fn bytes(&self) -> usize {
        256
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut state = engine
            .states
            .get(&self.state)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?
            .state
            .clone();
        if self.frame.state_id() != self.state
            || self.frame.source.identity() != engine.source.identity()
        {
            return Err(Error::stale("input frame belongs to another state"));
        }
        state.check_unlocked()?;
        if mode(&self.frame).is_some()
            || state.selection.generation != self.frame.state.selection.generation
            || !state.summary(&engine.source)?.is_empty()
            || state.selection_purpose.is_some()
        {
            return Err(Error::stale("Explorer selection intent changed"));
        }
        if self.frame.position(self.node).is_none() {
            return Err(Error::invalid("cursor is outside the captured frame"));
        }
        Resource {
            source: self.frame.source.clone(),
            node: self.node,
        }
        .check_current(&engine.source, false)?;
        engine.lock_selection(self.state, state.selection_revision, None)
    }
}

struct PrepareSelection {
    state: u64,
}

impl NativeAction for PrepareSelection {
    fn bytes(&self) -> usize {
        64
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let inspected =
            engine.dispatch(self.state, Command::InspectSelection, Context::default())?;
        if let Reply::Inspected { sources, .. } = &inspected
            && sources.summary.pending
        {
            return engine.lock_selection(self.state, sources.selection_revision, None);
        }
        Ok(inspected)
    }
}

struct Marking {
    state: u64,
    frame: Arc<Snapshot>,
    start: usize,
    end: usize,
    mark: Mark,
    visual: bool,
}

/// Normal input keeps its key-time occurrence while resolving relative state on the owner.
fn validate_input(engine: &Engine, state_id: u64, frame: &Snapshot, node: NodeId) -> Result<()> {
    let state = &engine.states[&state_id].state;
    if frame.state_id() != state.id || frame.source().identity() != engine.source.identity() {
        return Err(Error::stale("input frame belongs to another state"));
    }
    if frame.root() != &state.root || frame.state.display != state.display {
        return Err(Error::stale("Explorer input view changed"));
    }
    if frame.position(node).is_none() {
        return Err(Error::invalid("input target is outside the captured frame"));
    }
    Resource {
        source: frame.source.clone(),
        node,
    }
    .check_current(&engine.source, true)
}

struct Folding {
    state: u64,
    frame: Arc<Snapshot>,
    node: NodeId,
    kind: Fold,
}

impl NativeAction for Folding {
    fn bytes(&self) -> usize {
        256
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let state = &engine
            .states
            .get(&self.state)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?
            .state;
        validate_input(engine, self.state, &self.frame, self.node)?;
        if state.display.mode != Mode::Tree {
            return Ok(Reply::NoChange);
        }
        let Root::ChildrenOf(root) = state.root else {
            return Err(Error::invalid("Explorer requires a directory display root"));
        };
        let mut node = self.node;
        let (value, scope) = match self.kind {
            Fold::Collapse => {
                // A preceding collapse can hide the captured row before its frame is published.
                let mut parent = engine.source.node(node).and_then(|node| node.parent);
                while let Some(id) = parent.filter(|id| *id != root) {
                    if !state.expanded(&engine.source, id)? {
                        node = id;
                    }
                    parent = engine.source.node(id).and_then(|node| node.parent);
                }
                if !state.expanded(&engine.source, node)? {
                    let Some(parent) = engine.source.node(node).and_then(|node| node.parent) else {
                        return Ok(Reply::NoChange);
                    };
                    node = parent;
                }
                if node == root {
                    return Ok(Reply::NoChange);
                }
                (false, Scope::SelfOnly)
            }
            Fold::Toggle => (!state.expanded(&engine.source, node)?, Scope::SelfOnly),
            Fold::Recursive => (!state.expanded(&engine.source, node)?, Scope::Subtree),
        };
        engine.dispatch(
            self.state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![node].into()),
                value,
                scope,
            },
            Context::default(),
        )
    }
}

impl NativeAction for Marking {
    fn bytes(&self) -> usize {
        256
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut candidate = engine.clone();
        let entry = candidate
            .states
            .get_mut(&self.state)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?;
        entry.state.check_unlocked()?;
        entry.state.summary(&candidate.source)?;
        let purpose = entry.state.selection_purpose.clone();
        let targets = Targets::Range {
            frame: self.frame.clone(),
            start: self.start,
            end: self.end,
        };
        let context = Context {
            frame: Some(self.frame.clone()),
            ..Context::default()
        };
        let nodes = candidate.targets(
            &candidate.states[&self.state].state,
            &targets,
            (self.visual && matches!(self.mark, Mark::Toggle)).then_some(SelectAction::Toggle),
            Scope::Subtree,
            &context,
        )?;
        if nodes.is_empty() {
            return Ok(Reply::NoChange);
        }
        if !self.visual && nodes.len() != 1 {
            return Err(Error::invalid("Normal Explorer marking requires one item"));
        }
        if !self.visual {
            validate_input(&candidate, self.state, &self.frame, nodes[0])?;
        }
        let requested = match self.mark {
            Mark::Toggle => purpose.clone(),
            Mark::Select => None,
            Mark::Copy => Some(Arc::from("copy")),
            Mark::Cut => Some(Arc::from("cut")),
        };
        let marked = !self.visual
            && candidate.states[&self.state]
                .state
                .selection
                .value(&candidate.source, nodes[0])?;
        let action = match self.mark {
            Mark::Toggle if self.visual => Some(SelectAction::Toggle),
            _ if self.visual => Some(SelectAction::Select),
            _ if marked && requested != purpose => None,
            _ if marked => Some(SelectAction::Deselect),
            _ => Some(SelectAction::Select),
        };
        if let Some(action) = action {
            candidate.dispatch(
                self.state,
                Command::Select {
                    targets,
                    action,
                    scope: Scope::Subtree,
                },
                context,
            )?;
        }
        let entry = candidate
            .states
            .get_mut(&self.state)
            .expect("Explorer state");
        entry.state.selection_purpose = requested;
        entry.state.summary(&candidate.source)?;
        if action.is_none() {
            entry.state.revision = entry.state.revision.next()?;
            candidate.commit = candidate.commit.next()?;
        }
        entry.dirty.pending = true;
        candidate.memory.check()?;
        let reply = candidate.applied(
            Some(self.state),
            vec![Effect::ViewChanged { state: self.state }],
        );
        *engine = candidate;
        Ok(reply)
    }
}

enum NavigationTarget {
    Node(NodeId),
    Parent,
}

struct Navigation {
    explorer: Explorer,
    target: NavigationTarget,
    reveal: bool,
}

impl NativeAction for Navigation {
    fn bytes(&self) -> usize {
        256
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut candidate = engine.clone();
        let id = self.explorer.state.id();
        let source = candidate.source.clone();
        let entry = candidate
            .states
            .get_mut(&id)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?;
        let Root::ChildrenOf(previous) = entry.state.root else {
            return Err(Error::invalid("Explorer requires a directory display root"));
        };
        let node = match self.target {
            NavigationTarget::Node(node) => node,
            NavigationTarget::Parent => {
                let current = source
                    .node(previous)
                    .ok_or_else(|| Error::missing(previous))?;
                let Some(parent) = current.parent else {
                    return Ok(Reply::NoChange);
                };
                parent
            }
        };
        let resource = Resource {
            source: source.clone(),
            node,
        };
        let mut target = node;
        if self.reveal {
            resource.entry()?;
            let mut ancestors = Vec::new();
            let mut parent = source.node(target).and_then(|node| node.parent);
            while let Some(node) = parent {
                ancestors.push(node);
                parent = source.node(node).and_then(|node| node.parent);
            }
            target = if ancestors.contains(&previous) {
                previous
            } else {
                source
                    .node(node)
                    .and_then(|node| node.parent)
                    .unwrap_or(node)
            };
            entry
                .state
                .set_expanded(&source, &ancestors, true, Scope::SelfOnly)?;
            /* Loading or selection updates may share this projection with the reveal. */
            entry.dirty.expanded.extend(ancestors.iter().copied());
            entry.state.cursor = Some(node);
            entry.state.display.selected_only = false;
            if ancestors
                .iter()
                .chain(std::iter::once(&node))
                .any(|node| source.node(*node).is_some_and(|node| node.data.hidden))
            {
                entry.state.display.show_hidden = true;
            }
        } else if !resource.entry()?.directory() {
            return Err(Error::invalid("Explorer display root must be a directory"));
        }
        entry.state.root = Root::ChildrenOf(target);
        entry.state.revision = entry.state.revision.next()?;
        entry.dirty.layout = true;
        entry.dirty.pending = true;
        candidate.commit = candidate.commit.next()?;
        candidate.memory.check()?;
        let reply = candidate.applied(Some(id), vec![Effect::ViewChanged { state: id }]);
        if previous != target {
            *self
                .explorer
                .previous
                .lock()
                .unwrap_or_else(|error| error.into_inner()) = Some(previous);
        }
        *engine = candidate;
        Ok(reply)
    }
}

#[cfg(test)]
mod tests;

#[cfg(test)]
mod preparation_tests;
