//! File explorer interaction policy; Treeview remains the only topology and selection owner.

pub(crate) mod lua;

use super::filetree::{CreatePlan, Entry, Filetree, Job, OperationPlan, Request, Resource};
use super::treeview::*;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

#[derive(Clone)]
pub struct Explorer {
    pub tree: Filetree,
    pub state: StateHandle,
    pub workspace: NodeId,
    workspace_path: Arc<PathBuf>,
    previous: Arc<Mutex<Option<NodeId>>>,
    job: Arc<Mutex<Option<Job>>>,
}

#[derive(Clone, Copy)]
pub enum Mark {
    Toggle,
    Select,
    Copy,
    Cut,
}

impl Explorer {
    pub fn new(tree: Filetree, state: StateHandle) -> Result<Self> {
        if tree.source().identity() != state.data().source().identity() {
            return Err(Error::invalid("Explorer state belongs to another Filetree"));
        }
        let Root::ChildrenOf(workspace) = *state.snapshot()?.root() else {
            return Err(Error::invalid("Explorer requires a directory display root"));
        };
        let workspace_path = Arc::new(
            Resource {
                source: tree.source(),
                node: workspace,
            }
            .path()?,
        );
        Ok(Self {
            tree,
            state,
            workspace,
            workspace_path,
            previous: Arc::new(Mutex::new(None)),
            job: Arc::new(Mutex::new(None)),
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
        if source.contains(self.workspace) {
            Resource {
                source,
                node: self.workspace,
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

    pub fn inspect_range(&self, frame: Arc<Snapshot>, start: usize, end: usize) -> Ticket {
        self.state.submit(Action::Native(Box::new(InspectRange {
            state: self.state.id(),
            frame,
            start,
            end,
        })))
    }

    pub fn navigate(&self, node: NodeId, reveal: bool) -> Ticket {
        self.state.submit(Action::Native(Box::new(Navigation {
            explorer: self.clone(),
            node,
            reveal,
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

    pub fn job(&self) -> Option<Job> {
        self.job
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .clone()
    }

    pub fn start_operation(&self, plan: OperationPlan) -> Result<Job> {
        let mut current = self.job.lock().unwrap_or_else(|error| error.into_inner());
        if current.as_ref().is_some_and(|job| !job.status().terminal) {
            return Err(Error::new(
                ErrorCode::Busy,
                "Explorer already has an active job",
            ));
        }
        let job = self.tree.start_operation(plan)?;
        *current = Some(job.clone());
        Ok(job)
    }

    pub fn start_create(&self, plan: CreatePlan) -> Result<Job> {
        let mut current = self.job.lock().unwrap_or_else(|error| error.into_inner());
        if current.as_ref().is_some_and(|job| !job.status().terminal) {
            return Err(Error::new(
                ErrorCode::Busy,
                "Explorer already has an active job",
            ));
        }
        let job = self.tree.start_create(plan)?;
        *current = Some(job.clone());
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
                frame: self.frame,
                start: self.start,
                end: self.end,
            },
            None,
            Scope::Subtree,
            &Context::default(),
        )?;
        Ok(Reply::Inspected {
            revisions: engine.revisions(Some(self.state)),
            sources: SelectionSources {
                data_revision: engine.source.revision(),
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

struct Marking {
    state: u64,
    frame: Arc<Snapshot>,
    start: usize,
    end: usize,
    mark: Mark,
    visual: bool,
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
        let summary = entry.state.summary(&candidate.source)?;
        let purpose = entry.state.selection_purpose.clone();
        let current_mode = purpose
            .as_deref()
            .or_else(|| (!summary.is_empty()).then_some("select"));
        if !self.visual && current_mode != mode(&self.frame) {
            return Err(Error::stale("Explorer selection mode changed"));
        }
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
            (!self.visual || matches!(self.mark, Mark::Toggle)).then_some(SelectAction::Toggle),
            Scope::Subtree,
            &context,
        )?;
        if nodes.is_empty() {
            return Ok(Reply::NoChange);
        }
        if !self.visual && nodes.len() != 1 {
            return Err(Error::invalid("Normal Explorer marking requires one item"));
        }
        let requested = match self.mark {
            Mark::Toggle => purpose.clone(),
            Mark::Select => None,
            Mark::Copy => Some(Arc::from("copy")),
            Mark::Cut => Some(Arc::from("cut")),
        };
        let marked = !self.visual
            && self
                .frame
                .state
                .selection
                .value(self.frame.source(), nodes[0])?;
        let action = match self.mark {
            Mark::Toggle => Some(SelectAction::Toggle),
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

struct Navigation {
    explorer: Explorer,
    node: NodeId,
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
        let resource = Resource {
            source: source.clone(),
            node: self.node,
        };
        let mut target = self.node;
        let entry = candidate
            .states
            .get_mut(&id)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "Explorer state released"))?;
        let Root::ChildrenOf(previous) = entry.state.root else {
            return Err(Error::invalid("Explorer requires a directory display root"));
        };
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
                    .node(self.node)
                    .and_then(|node| node.parent)
                    .unwrap_or(self.node)
            };
            entry
                .state
                .set_expanded(&source, &ancestors, true, Scope::SelfOnly)?;
            entry.state.cursor = Some(self.node);
            entry.state.display.selected_only = false;
            if ancestors
                .iter()
                .chain(std::iter::once(&self.node))
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
