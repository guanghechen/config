//! Support shared by Filetree tests.

use super::jobs::EXECUTOR;
use super::*;
use crate::test_support::eventually;
use crate::ux::treeview::test_support::{Listening, listen};
use crate::ux::treeview::*;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

/// The value of a request that must succeed.
pub(crate) fn request<T: Clone>(request: Request<T>) -> T {
    eventually(|| request.poll()).unwrap_or_else(|error| panic!("{error:?}"))
}

/// The outcome of a ticket that must not be rejected.
pub(super) fn ticket(ticket: Ticket) -> Outcome {
    let outcome = eventually(|| ticket.poll());
    if let Outcome::Reply(Reply::Rejected { error }) = &outcome {
        panic!("{error:?}");
    }
    outcome
}

/// The reply of a ticket that must be accepted.
pub(super) fn reply(ticket: Ticket) -> Reply {
    match self::ticket(ticket) {
        Outcome::Reply(reply) => reply,
        _ => panic!("expected reply"),
    }
}

/// A state over the tree's root, shown in `mode`.
pub(super) fn state(tree: &Filetree, mode: Mode) -> StateHandle {
    let Outcome::State(state) = ticket(tree.create_state(
        None,
        DisplayOptions {
            mode,
            ..DisplayOptions::default()
        },
    )) else {
        panic!("expected state")
    };
    state
}

/// Waits until `node` has loaded all its children; a load error fails the test.
pub(super) fn loaded(tree: &Filetree, node: NodeId) {
    eventually(|| {
        let source = tree.source();
        let node = source.node(node).unwrap();
        assert!(node.error.is_none(), "{:?}", node.error);
        node.completeness == Completeness::Complete && node.load_state == LoadState::Idle
    });
}

/// Waits until `node` is watched, loaded and the tree is idle, and stays so for the watch's event
/// merge window.
pub(super) fn watching(tree: &Filetree, node: NodeId) {
    let mut stable = None;
    eventually(|| {
        let status = tree.watch_status();
        assert!(status.error.is_none(), "{:?}", status.error);
        let source = tree.source();
        let ready = status.covered.contains(&node)
            && source.node(node).is_some_and(|node| {
                node.load_state == LoadState::Idle && node.completeness == Completeness::Complete
            })
            && !tree.data().has_work()
            && tree.data().queue_depth() == 0;
        if ready {
            stable.get_or_insert(Instant::now());
        } else {
            stable = None;
        }
        stable.is_some_and(|time| time.elapsed() >= Duration::from_millis(35))
    });
}

/// The child of `parent` named `name`.
pub(super) fn child(tree: &Filetree, parent: NodeId, name: &str) -> NodeId {
    let source = tree.source();
    source
        .node(parent)
        .unwrap()
        .children()
        .find(|id| resource::entry(&source, *id).unwrap().name == name)
        .unwrap()
}

/// Takes every permission from a directory until dropped.
#[cfg(unix)]
pub(super) struct DeniedDirectory(std::path::PathBuf, std::fs::Permissions);

#[cfg(unix)]
impl DeniedDirectory {
    pub(super) fn new(path: std::path::PathBuf) -> Self {
        use std::os::unix::fs::PermissionsExt;
        let permissions = std::fs::metadata(&path).unwrap().permissions();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o000)).unwrap();
        Self(path, permissions)
    }
}

#[cfg(unix)]
impl Drop for DeniedDirectory {
    fn drop(&mut self) {
        std::fs::set_permissions(&self.0, self.1.clone()).unwrap();
    }
}

/// An operation on `source`, into `target` when given; both are paths relative to the tree's root.
pub(super) fn plan(
    tree: &Filetree,
    source: &str,
    target: Option<&str>,
    kind: OperationKind,
) -> OperationPlan {
    let base = tree
        .inspect(tree.source(), tree.root())
        .unwrap()
        .path()
        .unwrap();
    let source = request(tree.resolve(base.join(source)));
    let target = target.map(|target| request(tree.resolve(base.join(target))));
    OperationPlan {
        source: source.source,
        nodes: vec![source.node].into(),
        target,
        kind,
        name: None,
        task: None,
        prepare_move: false,
    }
}

/// Selects the plan's nodes in a new state, locks it and binds the plan to the prepared sources.
pub(super) fn selection(tree: &Filetree, plan: &mut OperationPlan) -> StateHandle {
    selection_with_deadline(tree, plan, None)
}

/// [`selection`] with a lock that expires at `deadline`.
pub(super) fn selection_with_deadline(
    tree: &Filetree,
    plan: &mut OperationPlan,
    deadline: Option<Instant>,
) -> StateHandle {
    let Outcome::State(state) = ticket(tree.create_state(None, DisplayOptions::default())) else {
        panic!("state");
    };
    reply(state.dispatch(
        Command::Select {
            targets: Targets::Nodes(plan.nodes.clone()),
            action: SelectAction::Select,
            scope: Scope::Subtree,
        },
        Context::default(),
    ));
    let Reply::Locked { token, .. } = reply(state.submit(Action::Lock(
        state.id(),
        state.status().unwrap().revisions.selection.unwrap(),
        deadline,
    ))) else {
        panic!("lock");
    };
    let Reply::Ready {
        source, cleanup, ..
    } = reply(state.dispatch(
        Command::PrepareSources {
            lock: token,
            retry: false,
        },
        Context::default(),
    ))
    else {
        panic!("ready");
    };
    plan.source = source;
    plan.task = Some(TaskContext {
        state: state.clone(),
        lock: token,
        cleanup,
    });
    state
}

/// The status of a job once it has finished.
pub(crate) fn finished(job: &Job) -> JobStatus {
    eventually(|| {
        let status = job.status();
        status.terminal.then_some(status)
    })
}

/// The results of a job that must finish without a job error or cleanup error.
pub(super) fn done(job: &Job) -> Vec<Arc<ItemResult>> {
    let status = finished(job);
    assert!(status.error.is_none(), "{:?}", status.error);
    assert!(
        status
            .cleanup
            .as_ref()
            .is_none_or(|cleanup| cleanup.is_ok()),
        "{:?}",
        status.cleanup
    );
    job.results(0, status.results).unwrap()
}

/// Starts `operation` and runs `action` once, on the first wake whose job status satisfies `when`.
/// The job's IO waits until the listener is registered, so no status passes unobserved. Keep the
/// returned listener alive while the action may still run.
pub(super) fn start_observed(
    tree: &Filetree,
    operation: OperationPlan,
    when: impl Fn(&JobStatus) -> bool + Send + Sync + 'static,
    action: impl FnOnce(&Job) + Send + 'static,
) -> (Job, Listening) {
    let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
    let job = tree.start_operation(operation).unwrap();
    let observed = job.clone();
    let action = Mutex::new(Some(action));
    let listening = listen(tree.data(), move || {
        if !when(&observed.status()) {
            return;
        }
        let action = action.lock().unwrap().take();
        if let Some(action) = action {
            action(&observed);
        }
    });
    drop(execution);
    (job, listening)
}
