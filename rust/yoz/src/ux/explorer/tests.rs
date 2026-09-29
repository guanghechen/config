use super::*;
use crate::ux::filetree::{ItemStatus, JobStatus, OperationKind, Request};
use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant};

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!("yoz-explorer-{}", uuid::Uuid::new_v4()));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
fn request<T: Clone>(value: Request<T>) -> T {
    let start = Instant::now();
    loop {
        if let Some(value) = value.poll() {
            return value.unwrap();
        }
        assert!(start.elapsed() < Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(1));
    }
}
fn reply(explorer: &Explorer, ticket: Ticket) -> Reply {
    let Outcome::Reply(reply) = ticket.wait() else {
        panic!("expected reply")
    };
    assert!(!matches!(reply, Reply::Rejected { .. }), "{reply:?}");
    if let Reply::Applied { revisions, .. } | Reply::Locked { revisions, .. } = &reply {
        let started = Instant::now();
        while Some(explorer.state.snapshot().unwrap().state_revision()) < revisions.state {
            assert!(started.elapsed() < Duration::from_secs(10));
            std::thread::sleep(Duration::from_millis(1));
        }
    }
    reply
}
fn explorer(path: &std::path::Path) -> Explorer {
    let tree = request(Filetree::open(path.to_path_buf()));
    for name in ["a", "b"] {
        request(tree.resolve(path.join(name)));
    }
    let Outcome::State(state) = tree.create_state(None, DisplayOptions::default()).wait() else {
        panic!("expected state")
    };
    Explorer::new(tree, state).unwrap()
}

fn wait_job(job: &Job) -> JobStatus {
    let started = Instant::now();
    loop {
        let status = job.status();
        if status.terminal {
            return status;
        }
        assert!(started.elapsed() < Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(1));
    }
}

#[test]
fn t_completed_jobs_release_with_the_last_external_handle() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    fs::create_dir(directory.0.join("target")).unwrap();
    let explorer = explorer(&directory.0);
    let source = request(explorer.tree.resolve(directory.0.join("a")));
    let target = request(explorer.tree.resolve(directory.0.join("target")));
    for create in [false, true] {
        let job = if create {
            explorer.start_create(CreatePlan {
                target: target.clone(),
                path: "created".into(),
                directory: false,
            })
        } else {
            explorer.start_operation(OperationPlan {
                kind: OperationKind::Copy,
                source: source.source.clone(),
                nodes: Arc::from([source.node]),
                target: Some(target.clone()),
                name: None,
                task: None,
                prepare_move: false,
            })
        }
        .unwrap();
        let retained = job.downgrade();
        let status = wait_job(&job);
        assert!(status.error.is_none());
        assert_eq!(status.results, 1);
        assert_eq!(job.results(0, 1).unwrap()[0].status, ItemStatus::Success);
        drop(job);
        let started = Instant::now();
        while retained.upgrade().is_some() {
            assert!(
                started.elapsed() < Duration::from_secs(1),
                "Explorer must not retain a completed Job after its callers release it"
            );
            std::thread::sleep(Duration::from_millis(1));
        }
    }
    assert_eq!(fs::read(directory.0.join("target/a")).unwrap(), b"content");
    assert!(directory.0.join("target/created").is_file());
}

#[test]
fn t_running_job_blocks_both_start_paths_even_after_its_caller_drops_the_handle() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    fs::create_dir(directory.0.join("target")).unwrap();
    fs::write(directory.0.join("target/a"), "conflict").unwrap();
    let explorer = explorer(&directory.0);
    let source = request(explorer.tree.resolve(directory.0.join("a")));
    let target = request(explorer.tree.resolve(directory.0.join("target")));
    let operation = || OperationPlan {
        kind: OperationKind::Copy,
        source: source.source.clone(),
        nodes: Arc::from([source.node]),
        target: Some(target.clone()),
        name: None,
        task: None,
        prepare_move: false,
    };
    let job = explorer.start_operation(operation()).unwrap();
    let retained = job.downgrade();
    let started = Instant::now();
    let confirmation = loop {
        if let Some(confirmation) = job.status().confirmation {
            break confirmation;
        }
        assert!(started.elapsed() < Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(1));
    };
    drop(job);
    let other = explorer.clone();
    assert!(
        matches!(other.start_operation(operation()), Err(error) if error.code == ErrorCode::Busy)
    );
    assert!(matches!(
        other.start_create(CreatePlan {
            target,
            path: "unexpected".into(),
            directory: false,
        }),
        Err(error) if error.code == ErrorCode::Busy
    ));
    let job = retained.upgrade().expect("the worker owns its running Job");
    job.confirm(confirmation.token, true).unwrap();
    assert!(wait_job(&job).error.is_none());
    assert_eq!(job.results(0, 1).unwrap()[0].status, ItemStatus::Success);
    assert_eq!(fs::read(directory.0.join("target/a")).unwrap(), b"content");
    assert!(!directory.0.join("target/unexpected").exists());
}

#[test]
fn t_marking_switches_purpose_atomically_without_restamping_selected_nodes() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    let original = explorer.state.snapshot().unwrap();
    reply(
        &explorer,
        explorer.mark(original.clone(), 0, 1, Mark::Copy, false),
    );
    let copied = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&copied), Some("copy"));
    assert_eq!(copied.summary.known_roots, 1);
    let selection_revision = copied.selection_revision();
    reply(
        &explorer,
        explorer.mark(copied.clone(), 0, 1, Mark::Cut, false),
    );
    let cut = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&cut), Some("cut"));
    assert_eq!(cut.selection_revision(), selection_revision);
    assert_eq!(mode(&copied), Some("copy"));
    assert_eq!(mode(&original), None);
    reply(&explorer, explorer.mark(cut, 1, 2, Mark::Toggle, false));
    let both = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&both), Some("cut"));
    assert_eq!(both.summary.known_roots, 2);
    reply(&explorer, explorer.mark(both, 0, 2, Mark::Toggle, true));
    let empty = explorer.state.snapshot().unwrap();
    assert!(empty.summary.is_empty());
    assert_eq!(mode(&empty), None);
}

#[test]
fn t_select_mark_exits_transfer_without_unselecting_then_toggles() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    reply(
        &explorer,
        explorer.mark(explorer.state.snapshot().unwrap(), 0, 1, Mark::Copy, false),
    );
    let copied = explorer.state.snapshot().unwrap();
    let revision = copied.selection_revision();
    reply(&explorer, explorer.mark(copied, 0, 1, Mark::Select, false));
    let selected = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&selected), Some("select"));
    assert_eq!(selected.summary.known_roots, 1);
    assert_eq!(selected.selection_revision(), revision);
    reply(
        &explorer,
        explorer.mark(selected, 0, 1, Mark::Select, false),
    );
    let empty = explorer.state.snapshot().unwrap();
    assert!(empty.summary.is_empty());
    assert_eq!(mode(&empty), None);
    reply(&explorer, explorer.mark(empty, 1, 2, Mark::Cut, false));
    reply(
        &explorer,
        explorer.mark(
            explorer.state.snapshot().unwrap(),
            0,
            1,
            Mark::Select,
            false,
        ),
    );
    let both = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&both), Some("select"));
    assert_eq!(both.summary.known_roots, 2);
}

#[test]
fn t_cancel_transfer_preserves_selection_then_clears_without_a_cursor_target() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    for mark in [Mark::Copy, Mark::Cut] {
        reply(
            &explorer,
            explorer.mark(explorer.state.snapshot().unwrap(), 0, 1, mark, false),
        );
        let before = explorer.state.snapshot().unwrap();
        let revision = before.selection_revision();
        reply(&explorer, explorer.cancel_transfer_or_clear_selection());
        let selected = explorer.state.snapshot().unwrap();
        assert_eq!(mode(&selected), Some("select"));
        assert_eq!(selected.summary.known_roots, 1);
        assert_eq!(selected.selection_revision(), revision);
        assert!(matches!(mode(&before), Some("copy" | "cut")));
        reply(&explorer, explorer.cancel_transfer_or_clear_selection());
        let cleared = explorer.state.snapshot().unwrap();
        assert!(cleared.summary.is_empty());
        assert_eq!(mode(&cleared), None);
    }
}

#[test]
fn t_cancel_transfer_uses_the_queued_purpose_before_a_frame_is_observed() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    let original = explorer.state.snapshot().unwrap();
    let marked = explorer.mark(original, 0, 1, Mark::Copy, false);
    let cancelled = explorer.cancel_transfer_or_clear_selection();
    reply(&explorer, marked);
    reply(&explorer, cancelled);
    let selected = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&selected), Some("select"));
    assert_eq!(selected.summary.known_roots, 1);
}

#[test]
fn t_visual_union_restamps_and_task_lock_rejects_mode_changes() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    reply(
        &explorer,
        explorer.mark(explorer.state.snapshot().unwrap(), 0, 1, Mark::Copy, false),
    );
    let before = explorer.state.snapshot().unwrap();
    reply(
        &explorer,
        explorer.mark(before.clone(), 0, 2, Mark::Copy, true),
    );
    let after = explorer.state.snapshot().unwrap();
    assert!(after.selection_revision() > before.selection_revision());
    assert_eq!(after.summary.known_roots, 2);
    let locked = reply(
        &explorer,
        explorer.state.submit(Action::Lock(
            explorer.state.id(),
            after.selection_revision(),
            None,
        )),
    );
    let Reply::Locked { token, .. } = locked else {
        panic!("lock")
    };
    for mark in [Mark::Cut, Mark::Select] {
        let result = explorer
            .mark(explorer.state.snapshot().unwrap(), 0, 1, mark, false)
            .wait();
        assert!(
            matches!(result, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Busy)
        );
        assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("copy"));
    }
    let cancelled = explorer.cancel_transfer_or_clear_selection().wait();
    assert!(
        matches!(cancelled, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Busy)
    );
    assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("copy"));
    reply(
        &explorer,
        explorer
            .state
            .submit(Action::Unlock(explorer.state.id(), token)),
    );
}

#[test]
fn t_range_inspection_deduplicates_subtrees_without_changing_locked_selection() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    fs::create_dir(directory.0.join("nested")).unwrap();
    fs::write(directory.0.join("nested/file"), "content").unwrap();
    let explorer = explorer(&directory.0);
    let a = request(explorer.tree.resolve(directory.0.join("a")));
    let nested = request(explorer.tree.resolve(directory.0.join("nested")));
    let file = request(explorer.tree.resolve(directory.0.join("nested/file")));
    reply(&explorer, explorer.navigate(file.node, true));
    let frame = explorer.state.snapshot().unwrap();
    let at = frame.position(a.node).unwrap();
    reply(
        &explorer,
        explorer.mark(frame, at, at + 1, Mark::Cut, false),
    );
    let frame = explorer.state.snapshot().unwrap();
    let Reply::Locked { token, .. } = reply(
        &explorer,
        explorer.state.submit(Action::Lock(
            explorer.state.id(),
            frame.selection_revision(),
            None,
        )),
    ) else {
        panic!("lock");
    };
    let before = explorer.state.status().unwrap().revisions;
    let Reply::Inspected { sources, .. } = reply(
        &explorer,
        explorer.inspect_range(
            frame.clone(),
            frame.position(nested.node).unwrap(),
            frame.position(file.node).unwrap() + 1,
        ),
    ) else {
        panic!("range inspection");
    };
    assert_eq!(&*sources.subtree_roots, &[nested.node]);
    assert!(sources.self_only_nodes.is_empty());
    assert!(sources.needed_children.is_empty());
    assert_eq!(explorer.state.status().unwrap().revisions, before);
    let Reply::Inspected { sources, .. } = reply(
        &explorer,
        explorer
            .state
            .dispatch(Command::InspectSelection, Context::default()),
    ) else {
        panic!("selection inspection");
    };
    assert_eq!(&*sources.subtree_roots, &[a.node]);
    assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("cut"));
    reply(
        &explorer,
        explorer
            .state
            .submit(Action::Unlock(explorer.state.id(), token)),
    );
}

#[test]
fn t_range_inspection_rejects_foreign_frames_invalid_bounds_and_removed_roots() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    let a = request(explorer.tree.resolve(directory.0.join("a")));
    let frame = explorer.state.snapshot().unwrap();
    let Outcome::State(other) = explorer
        .tree
        .create_state(None, DisplayOptions::default())
        .wait()
    else {
        panic!("state");
    };
    let foreign = explorer
        .inspect_range(other.snapshot().unwrap(), 0, 1)
        .wait();
    assert!(
        matches!(foreign, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Stale)
    );
    let invalid = explorer
        .inspect_range(frame.clone(), 0, frame.len() + 1)
        .wait();
    assert!(
        matches!(invalid, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::InvalidUpdate)
    );
    fs::remove_file(directory.0.join("a")).unwrap();
    explorer.tree.refresh(&explorer.state).unwrap().wait();
    let started = Instant::now();
    while explorer.tree.source().contains(a.node) {
        assert!(started.elapsed() < Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(1));
    }
    let at = frame.position(a.node).unwrap();
    let removed = explorer.inspect_range(frame, at, at + 1).wait();
    assert!(
        matches!(removed, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::MissingNode)
    );
}

#[test]
fn t_reveal_invalidation_coalesces_with_loading_and_selection_updates() {
    struct Coalesced {
        explorer: Explorer,
        target: NodeId,
        selected: NodeId,
        loading: bool,
        result: Arc<Mutex<Option<Arc<Snapshot>>>>,
    }
    impl NativeAction for Coalesced {
        fn bytes(&self) -> usize {
            256
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            let mut candidate = engine.clone();
            let state = self.explorer.state.id();
            let mut display = candidate.states[&state].state.display.clone();
            display.compress = true;
            let revision = candidate.states[&state].state.revision;
            candidate.dispatch(
                state,
                Command::SetDisplay(display),
                Context {
                    expected_state: Some(revision),
                    ..Context::default()
                },
            )?;
            for (_, frame) in candidate.project() {
                frame?;
            }
            if self.loading {
                candidate.set_slot(
                    self.explorer.workspace,
                    None,
                    LoadState::Loading,
                    None,
                    None,
                )?;
            } else {
                candidate.dispatch(
                    state,
                    Command::Select {
                        targets: Targets::Nodes(vec![self.selected].into()),
                        action: SelectAction::Select,
                        scope: Scope::SelfOnly,
                    },
                    Context::default(),
                )?;
                if candidate.states[&state].dirty.selected.is_empty() {
                    return Err(Error::invalid(
                        "test selection did not invalidate compression",
                    ));
                }
            }
            Box::new(Navigation {
                explorer: self.explorer,
                node: self.target,
                reveal: true,
            })
            .apply(&mut candidate)?;
            let frame = candidate
                .project()
                .into_iter()
                .find(|(id, _)| *id == state)
                .ok_or_else(|| Error::invalid("navigation did not project"))?
                .1?;
            *self.result.lock().unwrap() = Some(frame);
            Ok(Reply::NoChange)
        }
    }
    for loading in [false, true] {
        let directory = Directory::new();
        for name in ["a", "b"] {
            fs::write(directory.0.join(name), "content").unwrap();
        }
        fs::create_dir(directory.0.join("nested")).unwrap();
        fs::write(directory.0.join("nested/file"), "content").unwrap();
        let explorer = explorer(&directory.0);
        let selected = request(explorer.tree.resolve(directory.0.join("a"))).node;
        let target = request(explorer.tree.resolve(directory.0.join("nested/file"))).node;
        assert!(
            explorer
                .state
                .snapshot()
                .unwrap()
                .position(target)
                .is_none()
        );
        let result = Arc::new(Mutex::new(None));
        reply(
            &explorer,
            explorer.state.submit(Action::Native(Box::new(Coalesced {
                explorer: explorer.clone(),
                target,
                selected,
                loading,
                result: result.clone(),
            }))),
        );
        let frame = result.lock().unwrap().clone().unwrap();
        assert!(frame.position(target).is_some(), "loading={loading}");
        assert_eq!(frame.cursor(), Some(target), "loading={loading}");
        assert_eq!(frame.summary.known_roots, usize::from(!loading));
    }
}

#[test]
fn t_reveal_updates_root_expansion_and_cursor_without_changing_selection() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    fs::create_dir(directory.0.join("nested")).unwrap();
    fs::write(directory.0.join("nested/file"), "content").unwrap();
    let explorer = explorer(&directory.0);
    let a = request(explorer.tree.resolve(directory.0.join("a")));
    let file = request(explorer.tree.resolve(directory.0.join("nested/file")));
    let frame = explorer.state.snapshot().unwrap();
    let at = frame.position(a.node).unwrap();
    reply(
        &explorer,
        explorer.mark(frame, at, at + 1, Mark::Cut, false),
    );
    let selection = explorer.state.snapshot().unwrap().selection_revision();
    reply(&explorer, explorer.navigate(file.node, true));
    let frame = explorer.state.snapshot().unwrap();
    assert_eq!(frame.cursor(), Some(file.node));
    assert!(frame.position(file.node).is_some());
    assert_eq!(*frame.root(), Root::ChildrenOf(explorer.workspace));
    assert_eq!(frame.selection_revision(), selection);
    assert_eq!(mode(&frame), Some("cut"));
    let nested = file.source.node(file.node).unwrap().parent.unwrap();
    reply(&explorer, explorer.navigate(nested, false));
    assert_eq!(explorer.previous(), Some(explorer.workspace));
    assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("cut"));
}

#[test]
fn t_reveal_resolves_an_external_target_after_the_display_root_is_removed() {
    let directory = Directory::new();
    let workspace = directory.0.join("workspace");
    fs::create_dir(&workspace).unwrap();
    for name in ["a", "b"] {
        fs::write(workspace.join(name), "content").unwrap();
    }
    let target = directory.0.join("external");
    fs::write(&target, "content").unwrap();
    let explorer = explorer(&workspace);
    fs::remove_dir_all(&workspace).unwrap();
    assert_eq!(request(explorer.reveal_path(target.clone())), target);
    explorer.tree.refresh(&explorer.state).unwrap().wait();
    assert_eq!(request(explorer.reveal_path(target.clone())), target);
    let resource = request(explorer.tree.resolve(target));
    reply(&explorer, explorer.navigate(resource.node, true));
    let frame = explorer.state.snapshot().unwrap();
    assert_eq!(frame.cursor(), Some(resource.node));
    assert!(frame.position(resource.node).is_some());
}
