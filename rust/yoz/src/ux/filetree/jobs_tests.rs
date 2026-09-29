use super::tests::Directory;
use super::*;
use crate::ux::treeview::*;
use std::fs;
use std::sync::Arc;
use std::time::{Duration, Instant};

fn until(mut predicate: impl FnMut() -> bool) {
    let start = Instant::now();
    while !predicate() {
        assert!(
            start.elapsed() < Duration::from_secs(15),
            "file job timeout"
        );
        std::thread::sleep(Duration::from_millis(1));
    }
}

#[cfg(unix)]
#[test]
fn t_move_captures_physical_paths_after_confirmation_without_following_final_links() {
    use std::os::unix::fs::symlink;
    let directory = Directory::new();
    fs::create_dir_all(directory.0.join("actual-a/inner")).unwrap();
    fs::create_dir(directory.0.join("source")).unwrap();
    fs::write(directory.0.join("referent"), "keep").unwrap();
    symlink("../referent", directory.0.join("source/file")).unwrap();
    fs::write(directory.0.join("actual-a/inner/file"), "old").unwrap();
    symlink("actual-a", directory.0.join("route")).unwrap();
    let tree = request(Filetree::open(directory.0.clone()));
    let job = tree
        .start_operation(plan(
            &tree,
            "source/file",
            Some("route/inner"),
            OperationKind::Move,
        ))
        .unwrap();
    until(|| job.status().confirmation.is_some());
    fs::rename(directory.0.join("actual-a"), directory.0.join("actual-b")).unwrap();
    fs::remove_file(directory.0.join("route")).unwrap();
    symlink("actual-b", directory.0.join("route")).unwrap();
    job.confirm(job.status().confirmation.unwrap().token, true)
        .unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Success);
    let source = results[0]
        .source_physical
        .as_ref()
        .unwrap_or(&results[0].source);
    assert_eq!(
        *source,
        fs::canonicalize(directory.0.join("source"))
            .unwrap()
            .join("file")
    );
    let target = results[0]
        .target_physical
        .as_ref()
        .or(results[0].target.as_ref())
        .unwrap();
    assert_eq!(
        *target,
        fs::canonicalize(directory.0.join("actual-b/inner"))
            .unwrap()
            .join("file")
    );
    assert!(fs::symlink_metadata(target).unwrap().is_symlink());
    assert_eq!(
        fs::read_to_string(directory.0.join("referent")).unwrap(),
        "keep"
    );
}

#[test]
fn t_move_preparation_follows_overwrite_confirmation_and_rechecks_source_identity() {
    let directory = Directory::new();
    fs::create_dir(directory.0.join("dest")).unwrap();
    fs::write(directory.0.join("a"), "source").unwrap();
    fs::write(directory.0.join("dest/a"), "destination").unwrap();
    let tree = request(Filetree::open(directory.0.clone()));
    let mut operation = plan(&tree, "a", Some("dest"), OperationKind::Move);
    operation.prepare_move = true;
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().confirmation.is_some());
    let overwrite = job.status().confirmation.unwrap();
    assert!(!overwrite.prepare_move);
    job.confirm(overwrite.token, true).unwrap();
    until(|| {
        job.status()
            .confirmation
            .is_some_and(|request| request.prepare_move)
    });
    let preparation = job.status().confirmation.unwrap();
    assert_eq!(
        preparation.source,
        fs::canonicalize(&directory.0).unwrap().join("a")
    );
    assert_eq!(
        fs::read(directory.0.join("dest/a")).unwrap(),
        b"destination"
    );
    fs::rename(directory.0.join("a"), directory.0.join("original")).unwrap();
    fs::write(directory.0.join("a"), "replacement").unwrap();
    job.confirm(preparation.token, true).unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(fs::read(directory.0.join("a")).unwrap(), b"replacement");
    assert_eq!(
        fs::read(directory.0.join("dest/a")).unwrap(),
        b"destination"
    );
}

#[test]
fn t_cancel_during_move_preparation_keeps_files_and_releases_selection() {
    let directory = Directory::new();
    fs::create_dir(directory.0.join("dest")).unwrap();
    fs::write(directory.0.join("a"), "source").unwrap();
    let tree = request(Filetree::open(directory.0.clone()));
    let mut operation = plan(&tree, "a", Some("dest"), OperationKind::Move);
    operation.prepare_move = true;
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    until(|| {
        job.status()
            .confirmation
            .is_some_and(|request| request.prepare_move)
    });
    job.cancel();
    until(|| job.status().terminal);
    assert!(job.status().cancelled);
    assert!(!state.status().unwrap().locked);
    assert!(directory.0.join("a").exists());
    assert!(!directory.0.join("dest/a").exists());
    assert_eq!(state.snapshot().unwrap().summary.known_roots, 1);
}

#[test]
fn t_replaced_source_is_rejected_before_move_preparation_is_requested() {
    let directory = Directory::new();
    fs::create_dir(directory.0.join("dest")).unwrap();
    fs::write(directory.0.join("a"), "source").unwrap();
    fs::write(directory.0.join("dest/a"), "destination").unwrap();
    let tree = request(Filetree::open(directory.0.clone()));
    let mut operation = plan(&tree, "a", Some("dest"), OperationKind::Move);
    operation.prepare_move = true;
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().confirmation.is_some());
    let overwrite = job.status().confirmation.unwrap();
    assert!(!overwrite.prepare_move);
    fs::rename(directory.0.join("a"), directory.0.join("original")).unwrap();
    fs::write(directory.0.join("a"), "replacement").unwrap();
    job.confirm(overwrite.token, true).unwrap();
    until(|| {
        let status = job.status();
        assert!(
            !status
                .confirmation
                .is_some_and(|request| request.prepare_move)
        );
        status.terminal
    });
    assert_eq!(done(&job)[0].status, ItemStatus::Failed);
    assert_eq!(fs::read(directory.0.join("a")).unwrap(), b"replacement");
    assert_eq!(
        fs::read(directory.0.join("dest/a")).unwrap(),
        b"destination"
    );
}
fn request<T: Clone>(request: Request<T>) -> T {
    until(|| request.poll().is_some());
    request
        .poll()
        .unwrap()
        .unwrap_or_else(|error| panic!("{error:?}"))
}
fn reply(ticket: Ticket) -> Reply {
    match ticket.wait() {
        Outcome::Reply(Reply::Rejected { error }) => panic!("{error:?}"),
        Outcome::Reply(reply) => reply,
        _ => panic!("expected reply"),
    }
}
fn done(job: &Job) -> Vec<Arc<ItemResult>> {
    until(|| job.status().terminal);
    let status = job.status();
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
fn plan(tree: &Filetree, source: &str, target: Option<&str>, kind: OperationKind) -> OperationPlan {
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
fn selection(tree: &Filetree, plan: &mut OperationPlan) -> StateHandle {
    prepare_selection(tree, plan, None)
}
fn prepare_selection(
    tree: &Filetree,
    plan: &mut OperationPlan,
    deadline: Option<Instant>,
) -> StateHandle {
    let Outcome::State(state) = tree.create_state(None, DisplayOptions::default()).wait() else {
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

#[test]
fn t_job_copy_merge_skip_continues_and_cleans_discovered_success_only() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src")).unwrap();
    fs::create_dir_all(dir.0.join("dst/src")).unwrap();
    fs::write(dir.0.join("src/a"), "new a").unwrap();
    fs::write(dir.0.join("src/b"), "new b").unwrap();
    fs::write(dir.0.join("dst/src/b"), "old b").unwrap();
    fs::write(dir.0.join("dst/src/keep"), "keep").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut plan = plan(&tree, "src", Some("dst"), OperationKind::Copy);
    let root = plan.nodes[0];
    let state = selection(&tree, &mut plan);
    let job = tree.start_operation(plan).unwrap();
    until(|| job.status().confirmation.is_some() || job.status().terminal);
    let pending = job
        .status()
        .confirmation
        .unwrap_or_else(|| panic!("{:?}", job.status().error));
    assert_eq!(pending.source, dir.0.join("src/b"));
    job.confirm(pending.token, false).unwrap();
    assert!(job.confirm(pending.token, true).is_err());
    let results = done(&job);
    assert!(results.iter().any(|result| result.source.ends_with("src/a")
        && result.status == ItemStatus::Success
        && result.sync_error.is_none()));
    assert!(
        results
            .iter()
            .any(|result| result.source.ends_with("src/b") && result.status == ItemStatus::Skipped)
    );
    assert_eq!(
        fs::read_to_string(dir.0.join("dst/src/a")).unwrap(),
        "new a"
    );
    assert_eq!(
        fs::read_to_string(dir.0.join("dst/src/b")).unwrap(),
        "old b"
    );
    assert!(dir.0.join("dst/src/keep").exists());
    assert!(!state.status().unwrap().locked);
    let Reply::Inspected { sources, .. } =
        reply(state.dispatch(Command::InspectSelection, Context::default()))
    else {
        panic!("selection");
    };
    assert!(sources.self_only_nodes.contains(&root));
    let a = tree
        .index
        .lock()
        .unwrap()
        .child(Some(root), std::ffi::OsStr::new("a"))
        .unwrap();
    let b = tree
        .index
        .lock()
        .unwrap()
        .child(Some(root), std::ffi::OsStr::new("b"))
        .unwrap();
    assert!(!sources.subtree_roots.contains(&a));
    assert!(sources.subtree_roots.contains(&b));
}

#[test]
fn t_job_move_keeps_occurrence_and_delete_discovers_unloaded_children() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src/sub")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("src/sub/a"), "a").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut move_plan = plan(&tree, "src", Some("dst"), OperationKind::Move);
    let root = move_plan.nodes[0];
    let state = selection(&tree, &mut move_plan);
    let result = done(&tree.start_operation(move_plan).unwrap());
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    assert_eq!(
        tree.inspect(tree.source(), root).unwrap().path().unwrap(),
        dir.0.join("dst/src")
    );
    assert!(!state.status().unwrap().locked);
    let mut delete_plan = plan(&tree, "dst/src", None, OperationKind::Delete);
    let state = selection(&tree, &mut delete_plan);
    let result = done(&tree.start_operation(delete_plan).unwrap());
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    assert!(!tree.source().contains(root));
    assert!(!dir.0.join("dst/src").exists());
    assert!(!state.status().unwrap().locked);
}

#[test]
fn t_job_confirmation_does_not_apply_to_replaced_target_and_other_job_progresses() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("a"), "new").unwrap();
    fs::write(dir.0.join("b"), "other").unwrap();
    fs::write(dir.0.join("dst/a"), "old").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let job = tree
        .start_operation(plan(&tree, "a", Some("dst"), OperationKind::Copy))
        .unwrap();
    until(|| job.status().confirmation.is_some());
    let token = job.status().confirmation.unwrap().token;
    assert_eq!(
        done(
            &tree
                .start_operation(plan(&tree, "b", Some("dst"), OperationKind::Copy))
                .unwrap()
        )[0]
        .status,
        ItemStatus::Success
    );
    fs::rename(dir.0.join("dst/a"), dir.0.join("dst/old")).unwrap();
    fs::write(dir.0.join("dst/a"), "replacement").unwrap();
    job.confirm(token, true).unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(
        fs::read_to_string(dir.0.join("dst/a")).unwrap(),
        "replacement"
    );
}

#[cfg(unix)]
#[test]
fn t_job_links_are_copied_and_replaced_without_modifying_referents() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("a"), "new").unwrap();
    fs::write(dir.0.join("referent"), "unchanged").unwrap();
    symlink("../referent", dir.0.join("dst/a")).unwrap();
    symlink("missing-relative", dir.0.join("link")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let job = tree
        .start_operation(plan(&tree, "a", Some("dst"), OperationKind::Copy))
        .unwrap();
    until(|| job.status().confirmation.is_some());
    job.confirm(job.status().confirmation.unwrap().token, true)
        .unwrap();
    assert_eq!(done(&job)[0].status, ItemStatus::Success);
    assert_eq!(
        fs::read_to_string(dir.0.join("referent")).unwrap(),
        "unchanged"
    );
    assert!(
        !fs::symlink_metadata(dir.0.join("dst/a"))
            .unwrap()
            .is_symlink()
    );
    let job = tree
        .start_operation(plan(&tree, "link", Some("dst"), OperationKind::Copy))
        .unwrap();
    assert_eq!(done(&job)[0].status, ItemStatus::Success);
    assert_eq!(
        fs::read_link(dir.0.join("dst/link")).unwrap(),
        std::path::PathBuf::from("missing-relative")
    );
}

#[cfg(unix)]
#[test]
fn t_job_copy_unknown_link_keeps_incomplete_children_after_read_failure() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    std::os::unix::fs::symlink("loop", dir.0.join("loop")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let plan = plan(&tree, "loop", Some("dst"), OperationKind::Copy);
    let target = plan.target.as_ref().unwrap().node;
    assert_eq!(
        tree.source().node(plan.nodes[0]).unwrap().completeness,
        Completeness::Unknown
    );
    let job = tree.start_operation(plan).unwrap();
    let results = done(&job);
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error.is_none(),
        "{:?}",
        results[0].sync_error
    );
    let source = tree.source();
    let copied = source
        .node(target)
        .unwrap()
        .children()
        .find(|id| source.node(*id).unwrap().data.label.as_ref() == "loop")
        .unwrap();
    assert!(
        tree.inspect(source.clone(), copied)
            .unwrap()
            .entry()
            .unwrap()
            .target_unknown
    );
    assert!(source.node(copied).unwrap().data.can_expand);
    assert_eq!(
        source.node(copied).unwrap().completeness,
        Completeness::Unknown
    );

    let Outcome::State(state) = tree
        .create_state(
            Some(Root::ChildrenOf(copied)),
            DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            },
        )
        .wait()
    else {
        panic!("state");
    };
    let _view = state.attach().unwrap();
    until(|| tree.source().node(copied).unwrap().load_state == LoadState::Error);
    let source = tree.source();
    let node = source.node(copied).unwrap();
    assert_eq!(node.completeness, Completeness::Unknown);
    assert_eq!(node.error.as_ref().unwrap().code, ErrorCode::ProviderError);
}

#[cfg(unix)]
#[test]
fn t_job_link_operations_ignore_refreshed_directory_referent() {
    for kind in [
        OperationKind::Copy,
        OperationKind::Move,
        OperationKind::Delete,
    ] {
        for prepared in [false, true] {
            let dir = Directory::new();
            fs::create_dir(dir.0.join("dst")).unwrap();
            fs::create_dir(dir.0.join("referent")).unwrap();
            fs::write(dir.0.join("referent/content"), "old").unwrap();
            std::os::unix::fs::symlink(dir.0.join("referent"), dir.0.join("link")).unwrap();
            let tree = request(Filetree::open(dir.0.clone()));
            let mut operation = plan(
                &tree,
                "link",
                (kind != OperationKind::Delete).then_some("dst"),
                kind,
            );
            let state = prepared.then(|| selection(&tree, &mut operation));
            let node = operation.nodes[0];
            let before = resource::entry(&operation.source, node).unwrap();
            fs::rename(dir.0.join("referent"), dir.0.join("previous")).unwrap();
            fs::create_dir(dir.0.join("referent")).unwrap();
            fs::write(dir.0.join("referent/content"), "new").unwrap();
            let refreshed = request(tree.resolve(dir.0.join("link")));
            let after = refreshed.entry().unwrap();
            assert_eq!(refreshed.node, node);
            assert_eq!(before.identity, after.identity);
            assert_eq!(before.link, after.link);
            assert_ne!(before.target, after.target);

            let results = done(&tree.start_operation(operation).unwrap());
            assert_eq!(results.len(), 1);
            assert_eq!(results[0].status, ItemStatus::Success);
            assert!(
                results[0].sync_error.is_none(),
                "{:?}",
                results[0].sync_error
            );
            assert_eq!(
                fs::read_to_string(dir.0.join("referent/content")).unwrap(),
                "new"
            );
            assert_eq!(
                fs::read_to_string(dir.0.join("previous/content")).unwrap(),
                "old"
            );
            if kind == OperationKind::Delete {
                assert!(!tree.source().contains(node));
            } else {
                assert_eq!(
                    fs::read_link(dir.0.join("dst/link")).unwrap(),
                    dir.0.join("referent")
                );
                if kind == OperationKind::Move {
                    assert_eq!(
                        resource::path(&tree.source(), node).unwrap(),
                        dir.0.join("dst/link")
                    );
                } else {
                    assert_eq!(
                        fs::read_link(dir.0.join("link")).unwrap(),
                        dir.0.join("referent")
                    );
                }
            }
            if kind != OperationKind::Copy {
                assert!(fs::symlink_metadata(dir.0.join("link")).is_err());
            }
            if let Some(state) = state {
                assert!(!state.status().unwrap().locked);
            }
        }
    }
}

#[cfg(unix)]
#[test]
fn t_job_publication_rejects_retargeted_destination_directory() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("real")).unwrap();
    fs::write(dir.0.join("a"), "source").unwrap();
    std::os::unix::fs::symlink("real", dir.0.join("dst")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let source = request(tree.resolve(dir.0.join("a")));
    let target = request(tree.resolve(dir.0.join("dst")));
    fs::copy(dir.0.join("a"), dir.0.join("dst/a")).unwrap();
    let observed = Entry::read(&dir.0.join("dst/a")).unwrap();
    fs::rename(dir.0.join("real"), dir.0.join("previous")).unwrap();
    fs::create_dir(dir.0.join("real")).unwrap();
    let refreshed = request(tree.resolve(dir.0.join("dst")));
    assert_eq!(refreshed.node, target.node);
    assert_ne!(
        refreshed.entry().unwrap().target,
        target.entry().unwrap().target
    );
    let result = tree
        .data()
        .submit(Action::Native(Box::new(super::job_owner::Publish {
            tree: tree.clone(),
            source: source.clone(),
            target: Some(target),
            entry: Some(observed),
            moved: false,
            descendants: None,
            token: None,
            replaced: None,
            result: Arc::new(std::sync::Mutex::new(None)),
        })))
        .wait();
    let Outcome::Reply(Reply::Rejected { error }) = result else {
        panic!("publication into retargeted directory");
    };
    assert_eq!(error.code, ErrorCode::Stale);
    assert!(tree.source().contains(source.node));
    assert!(
        tree.index
            .lock()
            .unwrap()
            .child(Some(refreshed.node), std::ffi::OsStr::new("a"))
            .is_none()
    );
    assert!(!dir.0.join("dst/a").exists());
    assert_eq!(
        fs::read_to_string(dir.0.join("previous/a")).unwrap(),
        "source"
    );
}

#[test]
fn t_job_rejected_plan_releases_prepared_lock_and_keeps_selection() {
    for failure in ["missing target", "invalid name", "memory limit"] {
        let dir = Directory::new();
        fs::create_dir(dir.0.join("dst")).unwrap();
        fs::write(dir.0.join("a"), "content").unwrap();
        let tree = request(Filetree::open(dir.0.clone()));
        let mut operation = plan(&tree, "a", Some("dst"), OperationKind::Copy);
        let node = operation.nodes[0];
        let state = selection(&tree, &mut operation);
        let memory = tree.data().memory();
        let _memory = memory.enter();
        let pressure = (failure == "memory limit")
            .then(|| crate::ux::treeview::memory::Charge::new(tree.data().limits().memory_bytes));
        match failure {
            "invalid name" => operation.name = Some("bad/name".into()),
            "missing target" => operation.target = None,
            _ => {}
        }
        let expected = if pressure.is_some() {
            ErrorCode::ResourceLimit
        } else {
            ErrorCode::InvalidUpdate
        };
        assert!(matches!(tree.start_operation(operation), Err(error) if error.code == expected));
        drop(pressure);
        assert!(!state.status().unwrap().locked);
        let Reply::Inspected { sources, .. } =
            reply(state.dispatch(Command::InspectSelection, Context::default()))
        else {
            panic!("selection");
        };
        assert!(sources.subtree_roots.contains(&node));
        assert_eq!(fs::read_to_string(dir.0.join("a")).unwrap(), "content");
        assert!(!dir.0.join("dst/a").exists());
    }
}

#[test]
fn t_job_failed_claim_releases_only_its_unclaimed_selection_lock() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("a"), "original").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "a", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    fs::rename(dir.0.join("a"), dir.0.join("prior")).unwrap();
    fs::write(dir.0.join("a"), "replacement").unwrap();
    request(tree.resolve(dir.0.join("a")));
    assert!(state.status().unwrap().locked);
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().terminal);
    assert_eq!(job.status().error.unwrap().code, ErrorCode::Stale);
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    assert!(!state.status().unwrap().locked);
    assert_eq!(fs::read_to_string(dir.0.join("a")).unwrap(), "replacement");
    assert_eq!(fs::read_to_string(dir.0.join("prior")).unwrap(), "original");
    assert!(!dir.0.join("dst/a").exists());
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_job_case_only_rename_preserves_occurrence_and_actual_spelling() {
    let dir = Directory::new();
    fs::write(dir.0.join("original"), "content").unwrap();
    if !dir.0.join("ORIGINAL").exists() {
        return;
    }
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "original", Some("."), OperationKind::Move);
    let node = operation.nodes[0];
    operation.name = Some("Original".into());
    selection(&tree, &mut operation);
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert_eq!(
        resource::entry(&tree.source(), node).unwrap().name,
        "Original"
    );
    assert_eq!(
        resource::observed_name(&dir.0.join("original")).unwrap(),
        "Original"
    );
    assert_eq!(request(tree.resolve(dir.0.join("ORIGINAL"))).node, node);
}

#[cfg(unix)]
#[test]
fn t_job_move_to_same_entry_through_alias_preserves_both_occurrences() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("real")).unwrap();
    fs::write(dir.0.join("real/a"), "content").unwrap();
    std::os::unix::fs::symlink("real", dir.0.join("alias")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let alias = request(tree.resolve(dir.0.join("alias/a")));
    let mut operation = plan(&tree, "real/a", Some("alias"), OperationKind::Move);
    let source = operation.nodes[0];
    let before = tree.source();
    let state = selection(&tree, &mut operation);
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].status, ItemStatus::Skipped);
    let after = tree.source();
    for node in [source, alias.node] {
        assert_eq!(
            after.node(node).unwrap().parent,
            before.node(node).unwrap().parent
        );
        assert_eq!(
            resource::path(&after, node).unwrap(),
            resource::path(&before, node).unwrap()
        );
    }
    let Reply::Inspected { sources, .. } =
        reply(state.dispatch(Command::InspectSelection, Context::default()))
    else {
        panic!("selection");
    };
    assert!(sources.subtree_roots.contains(&source));
    assert_eq!(fs::read_to_string(dir.0.join("real/a")).unwrap(), "content");
    assert_eq!(
        request(tree.resolve(dir.0.join("alias/a"))).node,
        alias.node
    );
    assert_eq!(request(tree.resolve(dir.0.join("real/a"))).node, source);
}

#[cfg(windows)]
#[test]
fn t_job_windows_directory_links_keep_intrinsic_type_and_referents() {
    use std::os::windows::fs::{FileTypeExt, symlink_dir};
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    symlink_dir("absent", dir.0.join("link")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let source = request(tree.resolve(dir.0.join("link")));
    let entry = source.entry().unwrap();
    let decoded = Entry::decode(&entry.encode()).unwrap();
    assert_eq!(
        super::io::Signature::entry(&decoded, false),
        super::io::Signature::read(&dir.0.join("link"), false).unwrap()
    );
    let results = done(
        &tree
            .start_operation(plan(&tree, "link", Some("dst"), OperationKind::Copy))
            .unwrap(),
    );
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        fs::symlink_metadata(dir.0.join("dst/link"))
            .unwrap()
            .file_type()
            .is_symlink_dir()
    );
    assert_eq!(
        fs::read_link(dir.0.join("dst/link")).unwrap(),
        std::path::PathBuf::from("absent")
    );
    fs::create_dir(dir.0.join("absent")).unwrap();
    fs::write(dir.0.join("absent/keep"), "referent").unwrap();
    for path in ["link", "dst/link"] {
        let results = done(
            &tree
                .start_operation(plan(&tree, path, None, OperationKind::Delete))
                .unwrap(),
        );
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(fs::symlink_metadata(dir.0.join(path)).is_err());
    }
    assert_eq!(
        fs::read_to_string(dir.0.join("absent/keep")).unwrap(),
        "referent"
    );
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_job_case_different_overwrite_retires_the_confirmed_occurrence() {
    for kind in [OperationKind::Copy, OperationKind::Move] {
        let dir = Directory::new();
        fs::create_dir(dir.0.join("src")).unwrap();
        fs::create_dir(dir.0.join("dst")).unwrap();
        fs::write(dir.0.join("src/Name"), "new").unwrap();
        fs::write(dir.0.join("dst/name"), "old").unwrap();
        if !dir.0.join("dst/Name").exists() {
            return;
        }
        let tree = request(Filetree::open(dir.0.clone()));
        let old = request(tree.resolve(dir.0.join("dst/name")));
        let mut operation = plan(&tree, "src/Name", Some("dst"), kind);
        let source = operation.nodes[0];
        let parent = operation.target.as_ref().unwrap().node;
        let state = selection(&tree, &mut operation);
        let job = tree.start_operation(operation).unwrap();
        until(|| job.status().confirmation.is_some() || job.status().terminal);
        job.confirm(job.status().confirmation.unwrap().token, true)
            .unwrap();
        let results = done(&job);
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(
            results[0].sync_error.is_none(),
            "{:?}",
            results[0].sync_error
        );
        assert!(!tree.source().contains(old.node));
        assert_eq!(tree.source().node(parent).unwrap().child_count(), 1);
        let output = request(tree.resolve(dir.0.join("dst/Name")));
        assert_eq!(
            output.entry().unwrap().name,
            resource::observed_name(&dir.0.join("dst/Name")).unwrap()
        );
        if kind == OperationKind::Move {
            assert_eq!(output.node, source);
        }
        assert_eq!(fs::read_to_string(dir.0.join("dst/Name")).unwrap(), "new");
        assert!(!state.status().unwrap().locked);
    }
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_job_case_different_directory_merge_preserves_actual_destination_name() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src/Name")).unwrap();
    fs::create_dir_all(dir.0.join("dst/name")).unwrap();
    fs::write(dir.0.join("src/Name/new"), "new").unwrap();
    fs::write(dir.0.join("dst/name/keep"), "keep").unwrap();
    if !dir.0.join("dst/Name").exists() {
        return;
    }
    let tree = request(Filetree::open(dir.0.clone()));
    let old = request(tree.resolve(dir.0.join("dst/name")));
    let operation = plan(&tree, "src/Name", Some("dst"), OperationKind::Copy);
    let parent = operation.target.as_ref().unwrap().node;
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error.is_none(),
        "{:?}",
        results[0].sync_error
    );
    assert_eq!(tree.source().node(parent).unwrap().child_count(), 1);
    let output = request(tree.resolve(dir.0.join("dst/Name")));
    assert_eq!(output.node, old.node);
    assert_eq!(output.entry().unwrap().name, "name");
    assert_eq!(
        fs::read_to_string(dir.0.join("dst/name/keep")).unwrap(),
        "keep"
    );
    assert_eq!(
        fs::read_to_string(dir.0.join("dst/name/new")).unwrap(),
        "new"
    );
}

#[test]
fn t_job_cancel_confirmation_releases_own_lock_and_rejects_duplicate_job() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("a"), "new").unwrap();
    fs::write(dir.0.join("dst/a"), "old").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut first = plan(&tree, "a", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut first);
    let second = OperationPlan {
        prepare_move: false,
        source: first.source.clone(),
        nodes: first.nodes.clone(),
        target: first.target.clone(),
        task: first.task.clone(),
        name: None,
        kind: first.kind,
    };
    let job = tree.start_operation(first).unwrap();
    until(|| job.status().confirmation.is_some());
    let rejected = OperationPlan {
        source: second.source.clone(),
        nodes: second.nodes.clone(),
        target: None,
        task: second.task.clone(),
        name: None,
        kind: second.kind,
        prepare_move: false,
    };
    assert!(tree.start_operation(rejected).is_err());
    assert!(state.status().unwrap().locked);
    let duplicate = tree.start_operation(second).unwrap();
    until(|| duplicate.status().terminal);
    assert_eq!(duplicate.status().error.unwrap().code, ErrorCode::Busy);
    assert!(state.status().unwrap().locked);
    job.cancel();
    until(|| job.status().terminal);
    assert!(job.status().cancelled);
    assert!(job.status().cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
    assert_eq!(fs::read_to_string(dir.0.join("dst/a")).unwrap(), "old");
}

#[test]
fn t_job_conflicts_and_actual_descendant_aliases_preserve_both_sides() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src/sub")).unwrap();
    fs::create_dir_all(dir.0.join("dst/src")).unwrap();
    fs::write(dir.0.join("src/a"), "source").unwrap();
    fs::write(dir.0.join("dst/src/keep"), "keep").unwrap();
    fs::write(dir.0.join("file"), "source file").unwrap();
    fs::create_dir(dir.0.join("dst/file")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    for operation in [
        plan(&tree, "src", Some("dst"), OperationKind::Move),
        plan(&tree, "file", Some("dst"), OperationKind::Copy),
        plan(&tree, "src", Some("src/sub"), OperationKind::Copy),
    ] {
        let results = done(&tree.start_operation(operation).unwrap());
        assert_eq!(results[0].status, ItemStatus::Failed);
    }
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(dir.0.join("src/sub"), dir.0.join("alias")).unwrap();
        let results = done(
            &tree
                .start_operation(plan(&tree, "src", Some("alias"), OperationKind::Move))
                .unwrap(),
        );
        assert_eq!(results[0].status, ItemStatus::Failed);
    }
    assert_eq!(fs::read_to_string(dir.0.join("src/a")).unwrap(), "source");
    assert!(dir.0.join("dst/src/keep").exists());
    assert!(dir.0.join("dst/file").is_dir());
}

#[test]
fn t_job_same_parent_rename_and_empty_directory_replacement_preserve_identity() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src/sub")).unwrap();
    fs::create_dir_all(dir.0.join("dst/src")).unwrap();
    fs::write(dir.0.join("src/sub/a"), "a").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Move);
    let source = operation.nodes[0];
    selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().confirmation.is_some());
    job.confirm(job.status().confirmation.unwrap().token, true)
        .unwrap();
    let result = done(&job);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    let mut operation = plan(&tree, "dst/src", Some("dst"), OperationKind::Move);
    operation.name = Some("renamed".into());
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    assert_eq!(
        tree.inspect(tree.source(), source).unwrap().path().unwrap(),
        dir.0.join("dst/renamed")
    );
    assert!(dir.0.join("dst/renamed/sub/a").exists());
}

#[test]
fn t_job_large_copy_cancellation_keeps_destination_and_removes_private_output() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    let file = fs::File::create(dir.0.join("large")).unwrap();
    file.set_len(256 * 1024 * 1024).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "large", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().bytes != 0 || job.status().terminal);
    assert!(
        !job.status().terminal,
        "copy finished before cancellation test could act"
    );
    let start = Instant::now();
    job.cancel();
    until(|| job.status().terminal);
    assert!(job.status().cancelled);
    assert!(!dir.0.join("dst/large").exists());
    assert_eq!(fs::read_dir(dir.0.join("dst")).unwrap().count(), 0);
    assert!(job.status().cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
    eprintln!(
        "copy cancellation stop: {:?}; streamed bytes={}",
        start.elapsed(),
        job.status().bytes
    );
}

#[test]
fn t_job_external_topology_change_keeps_io_results_and_reports_cleanup_stale() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src")).unwrap();
    fs::create_dir_all(dir.0.join("dst/src")).unwrap();
    fs::write(dir.0.join("src/a"), "a").unwrap();
    fs::write(dir.0.join("src/z"), "z").unwrap();
    fs::write(dir.0.join("dst/src/z"), "old").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let root = operation.nodes[0];
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().confirmation.is_some());
    let token = job.status().confirmation.unwrap().token;
    let current = tree.source();
    let z = current
        .node(root)
        .unwrap()
        .children()
        .find(|id| resource::entry(&current, *id).unwrap().name == "z")
        .unwrap();
    reply(tree.data().submit(Action::Batch(Batch {
        base_revision: current.revision(),
        operations: vec![Operation::Remove { node: z.into() }],
    })));
    let _ = job.confirm(token, true);
    until(|| job.status().terminal);
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    let results = job.results(0, job.status().results).unwrap();
    assert!(
        results
            .iter()
            .any(|result| result.source.ends_with("src/a") && result.status == ItemStatus::Success)
    );
    assert!(!state.status().unwrap().locked);
    assert_eq!(fs::read_to_string(dir.0.join("dst/src/z")).unwrap(), "old");
}

#[test]
#[ignore = "requires FILETREE_TEST_VOLUME on a separate filesystem"]
fn t_job_cross_filesystem_directory_move_retains_all_admitted_identities() {
    let volume = std::env::var_os("FILETREE_TEST_VOLUME").expect("separate test filesystem");
    let target = std::path::PathBuf::from(volume).join(format!("yoz-job-{}", uuid::Uuid::new_v4()));
    fs::create_dir(&target).unwrap();
    let target = Directory(target);
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src/sub")).unwrap();
    fs::write(dir.0.join("src/a"), "a").unwrap();
    fs::write(dir.0.join("src/sub/b"), "b").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(target.0.clone())));
    assert_ne!(
        resource::entry(&operation.source, operation.nodes[0])
            .unwrap()
            .identity
            .volume,
        operation
            .target
            .as_ref()
            .unwrap()
            .entry()
            .unwrap()
            .identity
            .volume
    );
    let root = operation.nodes[0];
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    assert_eq!(
        tree.inspect(tree.source(), root).unwrap().path().unwrap(),
        target.0.join("src")
    );
    assert!(!dir.0.join("src").exists());
    assert_eq!(fs::read_to_string(target.0.join("src/sub/b")).unwrap(), "b");
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
#[ignore = "requires FILETREE_TEST_VOLUME on a separate filesystem"]
fn t_job_cross_filesystem_move_coordinates_watched_items_until_publication() {
    use std::sync::mpsc;
    struct Hold(mpsc::Sender<()>, mpsc::Receiver<()>);
    impl NativeAction for Hold {
        fn bytes(&self) -> usize {
            0
        }
        fn apply(self: Box<Self>, _: &mut Engine) -> Result<Reply> {
            let _ = self.0.send(());
            let _ = self.1.recv();
            Ok(Reply::NoChange)
        }
    }
    let volume = std::env::var_os("FILETREE_TEST_VOLUME").expect("separate test filesystem");
    let target = std::path::PathBuf::from(volume).join(format!("yoz-job-{}", uuid::Uuid::new_v4()));
    fs::create_dir(&target).unwrap();
    let target = Directory(target);
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("src/sub")).unwrap();
    fs::write(dir.0.join("src/sub/small"), "content").unwrap();
    fs::File::create(dir.0.join("src/large"))
        .unwrap()
        .set_len(128 * 1024 * 1024)
        .unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let Outcome::State(view_state) = tree
        .create_state(
            None,
            DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            },
        )
        .wait()
    else {
        panic!("watch state")
    };
    let _view = view_state.attach().unwrap();
    let large = request(tree.resolve(dir.0.join("src/large")));
    let small = request(tree.resolve(dir.0.join("src/sub/small")));
    let mut operation = plan(&tree, "src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(target.0.clone())));
    assert_ne!(
        operation
            .target
            .as_ref()
            .unwrap()
            .entry()
            .unwrap()
            .identity
            .volume,
        resource::entry(&operation.source, operation.nodes[0])
            .unwrap()
            .identity
            .volume
    );
    let root = operation.nodes[0];
    until(|| tree.watch_status().covered.contains(&root) && !tree.data().has_work());
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().bytes > 1024 * 1024 || job.status().terminal);
    assert!(
        !job.status().terminal,
        "copy completed before queue congestion"
    );
    let (entered, ready) = mpsc::channel();
    let (release, wait) = mpsc::channel();
    let held = tree
        .data()
        .submit(Action::Native(Box::new(Hold(entered, wait))));
    ready.recv_timeout(Duration::from_secs(15)).unwrap();
    /* The worker can finish IO while its publication waits behind this owner action. */
    until(|| !dir.0.join("src/large").exists());
    let coordinated = tree.index.lock().unwrap().moving == Some(large.node);
    std::thread::sleep(Duration::from_millis(200));
    release.send(()).unwrap();
    reply(held);
    let results = done(&job);
    assert!(
        coordinated,
        "source removal must remain coordinated until owner publication"
    );
    assert!(
        results
            .iter()
            .all(|result| result.status == ItemStatus::Success && result.sync_error.is_none())
    );
    assert_eq!(
        resource::path(&tree.source(), root).unwrap(),
        target.0.join("src")
    );
    assert_eq!(
        resource::path(&tree.source(), large.node).unwrap(),
        target.0.join("src/large")
    );
    assert_eq!(
        resource::path(&tree.source(), small.node).unwrap(),
        target.0.join("src/sub/small")
    );
    assert_eq!(
        fs::read_to_string(target.0.join("src/sub/small")).unwrap(),
        "content"
    );
    assert!(!dir.0.join("src").exists());
    assert!(!state.status().unwrap().locked);
    assert!(tree.index.lock().unwrap().moving.is_none());
}

#[cfg(unix)]
#[test]
fn t_job_move_relative_link_to_unknown_target_ends_old_children() {
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("private/target")).unwrap();
    fs::create_dir_all(dir.0.join("dst/private/target")).unwrap();
    fs::write(dir.0.join("private/target/child"), "content").unwrap();
    std::os::unix::fs::symlink("private/target", dir.0.join("link")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let old = request(tree.resolve(dir.0.join("link/child")));
    let mut operation = plan(&tree, "link", Some("dst"), OperationKind::Move);
    let link = operation.nodes[0];
    selection(&tree, &mut operation);
    let _denied = super::tests::DeniedDirectory::new(dir.0.join("dst/private"));
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error.is_none(),
        "{:?}",
        results[0].sync_error
    );
    assert!(!tree.source().contains(old.node));
    let moved = resource::entry(&tree.source(), link).unwrap();
    assert!(moved.target_unknown);
    assert!(moved.target.is_none());
    assert!(dir.0.join("private/target/child").exists());
}

#[cfg(unix)]
#[test]
fn t_job_directory_move_reconciles_loaded_link_descendants() {
    use std::os::unix::fs::symlink;
    for prepared in [false, true] {
        let dir = Directory::new();
        for path in [
            "src/inside",
            "external",
            "gone",
            "switch",
            "dst/switch",
            "dst",
        ] {
            fs::create_dir_all(dir.0.join(path)).unwrap();
        }
        for path in [
            "src/inside/keep",
            "external/keep",
            "gone/old",
            "switch/old",
            "dst/switch/new",
        ] {
            fs::write(dir.0.join(path), "content").unwrap();
        }
        symlink("inside", dir.0.join("src/internal")).unwrap();
        symlink("../../external", dir.0.join("src/inside/nested")).unwrap();
        symlink(
            dir.0.join("src/inside"),
            dir.0.join("src/absolute-internal"),
        )
        .unwrap();
        fs::create_dir_all(dir.0.join("src/unseen/deep")).unwrap();
        symlink(dir.0.join("external"), dir.0.join("src/absolute")).unwrap();
        symlink("../gone", dir.0.join("src/a-gone")).unwrap();
        symlink("../switch", dir.0.join("src/switched")).unwrap();
        symlink("../src/inside", dir.0.join("src/through-root-name")).unwrap();
        symlink("../appeared", dir.0.join("src/z-appeared")).unwrap();
        fs::create_dir(dir.0.join("dst/appeared")).unwrap();
        symlink(dir.0.join("dst"), dir.0.join("src/cycle")).unwrap();
        let tree = request(Filetree::open(dir.0.clone()));
        let internal = request(tree.resolve(dir.0.join("src/internal/keep")));
        let nested = request(tree.resolve(dir.0.join("src/internal/nested/keep")));
        let absolute_internal = request(tree.resolve(dir.0.join("src/absolute-internal/keep")));
        let absolute = request(tree.resolve(dir.0.join("src/absolute/keep")));
        let gone = request(tree.resolve(dir.0.join("src/a-gone/old")));
        let switched = request(tree.resolve(dir.0.join("src/switched/old")));
        let renamed = request(tree.resolve(dir.0.join("src/through-root-name/keep")));
        let cycle_child = request(tree.resolve(dir.0.join("src/cycle/appeared")));
        let appeared = request(tree.resolve(dir.0.join("src/z-appeared")));
        let before = tree.source();
        let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Move);
        let root = operation.nodes[0];
        if prepared {
            selection(&tree, &mut operation);
        }
        let results = done(&tree.start_operation(operation).unwrap());
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(
            results[0].sync_error.is_none(),
            "{:?}",
            results[0].sync_error
        );
        let after = tree.source();
        for id in [internal.node, absolute.node, renamed.node] {
            assert!(after.contains(id));
        }
        for id in [
            gone.node,
            switched.node,
            cycle_child.node,
            nested.node,
            absolute_internal.node,
        ] {
            assert!(
                !after.contains(id),
                "obsolete link child survived directory move"
            );
            assert!(before.contains(id));
        }
        for name in [
            "internal",
            "absolute",
            "through-root-name",
            "switched",
            "z-appeared",
            "a-gone",
            "cycle",
        ] {
            let link = before
                .node(root)
                .unwrap()
                .children()
                .find(|id| resource::entry(&before, *id).unwrap().name == name)
                .unwrap();
            let entry = resource::entry(&after, link).unwrap();
            let observed = Entry::read(&dir.0.join("dst/src").join(name)).unwrap();
            assert_eq!(entry.target, observed.target, "{name}");
            assert_eq!(entry.target_unknown, observed.target_unknown);
        }
        let cycle = before.node(cycle_child.node).unwrap().parent.unwrap();
        assert!(resource::entry(&after, cycle).unwrap().cycle);
        assert!(!after.node(cycle).unwrap().data.can_expand);
        assert!(after.node(appeared.node).unwrap().data.can_expand);
        let sorted: Vec<_> = after
            .node(root)
            .unwrap()
            .children()
            .map(|id| resource::entry(&after, id).unwrap().sort_key())
            .collect();
        assert!(sorted.windows(2).all(|pair| pair[0] < pair[1]));
        assert!(
            after
                .node(root)
                .unwrap()
                .children()
                .all(|id| resource::entry(&after, id).unwrap().name != "unseen")
        );
        assert!(dir.0.join("dst/src/unseen/deep").is_dir());
        assert_eq!(
            request(tree.resolve(dir.0.join("dst/src/internal/keep"))).node,
            internal.node
        );
        assert_eq!(
            request(tree.resolve(dir.0.join("dst/src/absolute/keep"))).node,
            absolute.node
        );
    }
}

#[cfg(unix)]
#[test]
fn t_job_directory_move_updates_cycle_boundaries_below_preserved_links() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("src")).unwrap();
    fs::create_dir_all(dir.0.join("external/sub")).unwrap();
    fs::write(dir.0.join("external/sub/keep"), "content").unwrap();
    symlink("external/sub", dir.0.join("destination")).unwrap();
    symlink(dir.0.join("external"), dir.0.join("src/alias")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let old = request(tree.resolve(dir.0.join("src/alias/sub/keep")));
    let folder = old.source.node(old.node).unwrap().parent.unwrap();
    let link = old.source.node(folder).unwrap().parent.unwrap();
    let mut operation = plan(&tree, "src", Some("destination"), OperationKind::Move);
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    assert!(!resource::entry(&tree.source(), link).unwrap().cycle);
    assert!(resource::entry(&tree.source(), folder).unwrap().cycle);
    assert!(!tree.source().contains(old.node));
    assert!(dir.0.join("external/sub/keep").exists());
    let outside = Directory::new();
    let mut operation = plan(&tree, "destination/src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(outside.0.clone())));
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    assert!(!resource::entry(&tree.source(), folder).unwrap().cycle);
    assert!(tree.source().node(folder).unwrap().data.can_expand);
    assert_eq!(
        tree.source().node(folder).unwrap().completeness,
        Completeness::Unknown
    );
    assert_ne!(
        request(tree.resolve(outside.0.join("src/alias/sub/keep"))).node,
        old.node
    );
}

#[cfg(unix)]
#[test]
fn t_job_directory_move_does_not_inherit_old_unknown_link_targets() {
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = Directory::new();
    for path in ["src", "private/target", "dst/private/target"] {
        fs::create_dir_all(dir.0.join(path)).unwrap();
    }
    fs::write(dir.0.join("private/target/child"), "content").unwrap();
    std::os::unix::fs::symlink("../private/target", dir.0.join("src/link")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let old = request(tree.resolve(dir.0.join("src/link/child")));
    let link = old.source.node(old.node).unwrap().parent.unwrap();
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Move);
    selection(&tree, &mut operation);
    let _denied = super::tests::DeniedDirectory::new(dir.0.join("dst/private"));
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    let entry = resource::entry(&tree.source(), link).unwrap();
    assert!(entry.target_unknown);
    assert!(entry.target.is_none());
    assert!(!tree.source().contains(old.node));
}

#[test]
fn t_directory_move_defers_related_reads_and_preserves_their_lease() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("src")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    for i in 0..1100 {
        fs::write(dir.0.join("src").join(format!("file-{i:04}")), "content").unwrap();
    }
    let tree = request(Filetree::open(dir.0.clone()));
    let source = request(tree.resolve(dir.0.join("src")));
    let target = request(tree.resolve(dir.0.join("dst")));
    tree.data()
        .acknowledge_publication(tree.source().revision());
    let Outcome::State(state) = tree
        .create_state(
            Some(Root::ChildrenOf(source.node)),
            DisplayOptions::default(),
        )
        .wait()
    else {
        panic!("state");
    };
    let view = state.attach().unwrap();
    until(|| tree.source().node(source.node).unwrap().child_count() == 512);
    let lease = Arc::new(std::sync::Mutex::new(None));
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::job_owner::Read {
                node: source.node,
                task: None,
                lease: lease.clone(),
            }))),
    );
    assert!(lease.lock().unwrap().is_some());
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::job_owner::BeginMove {
                tree: tree.clone(),
                source: source.clone(),
                token: None,
            }))),
    );
    drop(view);
    reply(
        tree.data()
            .submit(Action::RequestChildren(vec![tree.root()], true)),
    );
    until(|| tree.source().node(tree.root()).unwrap().load_state == LoadState::Loading);
    fs::rename(dir.0.join("src"), dir.0.join("dst/src")).unwrap();
    let snapshot = tree.source();
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::job_owner::Publish {
                tree: tree.clone(),
                source: source.clone(),
                target: Some(target),
                entry: Some(Entry::read(&dir.0.join("dst/src")).unwrap()),
                moved: true,
                replaced: None,
                token: None,
                result: Arc::new(std::sync::Mutex::new(None)),
                descendants: Some(super::job_owner::MovedDescendants {
                    source: snapshot,
                    entries: Vec::new(),
                }),
            }))),
    );
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::job_owner::EndMove {
                tree: tree.clone(),
                node: source.node,
            }))),
    );
    until(|| {
        tree.data()
            .acknowledge_publication(tree.source().revision());
        let current = tree.source();
        let node = current
            .node(source.node)
            .expect("moved root survives its parent refresh");
        assert!(node.error.is_none(), "{:?}", node.error);
        node.completeness == Completeness::Complete
            && node.load_state == LoadState::Idle
            && current.node(tree.root()).unwrap().load_state == LoadState::Idle
    });
    assert_eq!(tree.source().node(source.node).unwrap().child_count(), 1100);
    assert_eq!(
        resource::path(&tree.source(), source.node).unwrap(),
        dir.0.join("dst/src")
    );
    assert!(tree.index.lock().unwrap().moving.is_none());
}

#[test]
fn t_directory_move_publication_rejects_members_loaded_after_observation() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("src")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let source = request(tree.resolve(dir.0.join("src")));
    let target = request(tree.resolve(dir.0.join("dst")));
    let snapshot = tree.source();
    fs::rename(dir.0.join("src"), dir.0.join("dst/src")).unwrap();
    reply(tree.data().submit(Action::Batch(Batch {
        base_revision: snapshot.revision(),
        operations: vec![Operation::Insert {
            key: "late".into(),
            parent: Some(source.node.into()),
            position: Position::Last,
            data: NodeData::default(),
            completeness: Completeness::Complete,
        }],
    })));
    let before = tree.source();
    let result = tree
        .data()
        .submit(Action::Native(Box::new(super::job_owner::Publish {
            tree: tree.clone(),
            source: source.clone(),
            target: Some(target),
            entry: Some(Entry::read(&dir.0.join("dst/src")).unwrap()),
            moved: true,
            replaced: None,
            token: None,
            result: Arc::new(std::sync::Mutex::new(None)),
            descendants: Some(super::job_owner::MovedDescendants {
                source: snapshot,
                entries: Vec::new(),
            }),
        })))
        .wait();
    assert!(
        matches!(result, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Stale)
    );
    assert_eq!(tree.source().revision(), before.revision());
    assert_eq!(
        resource::path(&tree.source(), source.node).unwrap(),
        dir.0.join("src")
    );
}

#[cfg(unix)]
#[test]
fn t_failed_directory_rename_releases_read_coordination() {
    use std::os::unix::fs::PermissionsExt;
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("readonly/src")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "readonly/src", Some("dst"), OperationKind::Move);
    let node = operation.nodes[0];
    let state = selection(&tree, &mut operation);
    let parent = dir.0.join("readonly");
    let permissions = fs::metadata(&parent).unwrap().permissions();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o500)).unwrap();
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().terminal);
    fs::set_permissions(&parent, permissions).unwrap();
    let result = done(&job);
    assert_eq!(result[0].status, ItemStatus::Failed);
    assert!(result[0].error.is_some());
    assert!(tree.index.lock().unwrap().moving.is_none());
    assert!(!state.status().unwrap().locked);
    assert_eq!(
        resource::path(&tree.source(), node).unwrap(),
        parent.join("src")
    );
    reply(
        tree.data()
            .submit(Action::RequestChildren(vec![node], true)),
    );
    until(|| tree.source().node(node).unwrap().completeness == Completeness::Complete);
}

#[cfg(unix)]
#[test]
fn t_job_moving_a_browsed_relative_link_retargets_its_children() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("real")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("real/keep"), "keep").unwrap();
    std::os::unix::fs::symlink("real", dir.0.join("link")).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let old = request(tree.resolve(dir.0.join("link/keep")));
    let mut operation = plan(&tree, "link", Some("dst"), OperationKind::Move);
    let link = operation.nodes[0];
    selection(&tree, &mut operation);
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error.is_none(),
        "{:?}",
        results[0].sync_error
    );
    assert!(!tree.source().contains(old.node));
    assert!(!tree.source().node(link).unwrap().data.can_expand);
    assert!(dir.0.join("real/keep").exists());
    assert_eq!(
        fs::read_link(dir.0.join("dst/link")).unwrap(),
        std::path::PathBuf::from("real")
    );
}

#[cfg(unix)]
#[test]
#[ignore = "requires FILETREE_TEST_VOLUME on a separate filesystem"]
fn t_job_cross_filesystem_partial_move_keeps_successful_child_identity() {
    use std::os::unix::ffi::OsStrExt;
    let volume = std::env::var_os("FILETREE_TEST_VOLUME").expect("separate test filesystem");
    let target = std::path::PathBuf::from(volume).join(format!("yoz-job-{}", uuid::Uuid::new_v4()));
    fs::create_dir(&target).unwrap();
    let target = Directory(target);
    let dir = Directory::new();
    fs::create_dir(dir.0.join("src")).unwrap();
    fs::write(dir.0.join("src/a"), "a").unwrap();
    let fifo = std::ffi::CString::new(dir.0.join("src/fifo").as_os_str().as_bytes()).unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(dir.0.clone()));
    let old = request(tree.resolve(dir.0.join("src/a")));
    let mut operation = plan(&tree, "src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(target.0.clone())));
    let root = operation.nodes[0];
    selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    let results = done(&job);
    assert!(results.iter().any(|result| result.node == old.node
        && result.status == ItemStatus::Success
        && result.sync_error.is_none()));
    assert!(
        results
            .iter()
            .any(|result| result.node == root && result.status == ItemStatus::Failed)
    );
    assert_eq!(
        tree.inspect(tree.source(), old.node)
            .unwrap()
            .path()
            .unwrap(),
        target.0.join("src/a")
    );
    assert!(dir.0.join("src/fifo").exists());
    assert!(!dir.0.join("src/a").exists());
}

#[test]
fn t_job_unviewed_multi_page_directory_and_finished_handle_release_memory() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("src")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    for i in 0..1100 {
        fs::write(dir.0.join(format!("src/file-{i:04}")), "x").unwrap();
    }
    let tree = request(Filetree::open(dir.0.clone()));
    /* A released Lua facade leaves its last UI acknowledgement behind. */
    tree.data()
        .acknowledge_publication(tree.source().revision());
    let memory = tree.data().memory();
    let job = tree
        .start_operation(plan(&tree, "src", Some("dst"), OperationKind::Copy))
        .unwrap();
    let results = done(&job);
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error.is_none(),
        "{:?}",
        results[0].sync_error
    );
    assert_eq!(fs::read_dir(dir.0.join("dst/src")).unwrap().count(), 1100);
    drop(results);
    drop(job);
    drop(tree);
    until(|| memory.used() == 0);
}

#[test]
fn t_job_leased_read_restarts_after_ancestor_move_without_a_related_view() {
    let dir = Directory::new();
    for path in ["parent/src", "copydst", "movedst", "idle"] {
        fs::create_dir_all(dir.0.join(path)).unwrap();
    }
    for index in 0..1100 {
        fs::write(dir.0.join(format!("parent/src/file-{index:04}")), "x").unwrap();
    }
    let tree = request(Filetree::open(dir.0.clone()));
    let idle = request(tree.resolve(dir.0.join("idle"))).node;
    let Outcome::State(state) = tree
        .create_state(Some(Root::ChildrenOf(idle)), DisplayOptions::default())
        .wait()
    else {
        panic!("state");
    };
    let _view = state.attach().unwrap();
    until(|| {
        tree.source().node(idle).unwrap().completeness == Completeness::Complete
            && !tree.data().has_work()
    });
    let copy = plan(&tree, "parent/src", Some("copydst"), OperationKind::Copy);
    let source = copy.nodes[0];
    let move_parent = plan(&tree, "parent", Some("movedst"), OperationKind::Move);
    tree.data()
        .acknowledge_publication(tree.source().revision());
    let copying = tree.start_operation(copy).unwrap();
    until(|| tree.source().node(source).unwrap().child_count() == 512);
    let moved = done(&tree.start_operation(move_parent).unwrap());
    assert_eq!(moved[0].status, ItemStatus::Success);
    let started = Instant::now();
    while !copying.status().terminal && started.elapsed() < Duration::from_secs(15) {
        tree.data()
            .acknowledge_publication(tree.source().revision());
        std::thread::sleep(Duration::from_millis(1));
    }
    let completed = copying.status().terminal;
    if !completed {
        copying.cancel();
        until(|| copying.status().terminal);
    }
    assert!(completed, "restarted directory read lost its lease");
    /* The fixed input path is now stale, but the lease must finish instead of losing its demand. */
    assert_eq!(tree.source().node(source).unwrap().child_count(), 1100);
    assert_eq!(
        tree.source().node(source).unwrap().completeness,
        Completeness::Complete
    );
    assert_eq!(copying.status().results, 1);
    let result = copying.results(0, 1).unwrap();
    assert_eq!(result[0].status, ItemStatus::Failed);
    assert_eq!(
        result[0].sync_error.as_ref().unwrap().code,
        ErrorCode::Stale
    );
    assert!(
        fs::read_dir(dir.0.join("copydst/src"))
            .unwrap()
            .next()
            .is_none()
    );
}

#[test]
fn t_job_late_copy_publication_reuses_observed_output_but_cannot_replace_new_occurrence() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("a"), "source").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let source = request(tree.resolve(dir.0.join("a")));
    let target = request(tree.resolve(dir.0.join("dst")));
    fs::write(dir.0.join("dst/a"), "output").unwrap();
    let observed = Entry::read(&dir.0.join("dst/a")).unwrap();
    let output = request(tree.resolve(dir.0.join("dst/a")));
    let result = Arc::new(std::sync::Mutex::new(None));
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::job_owner::Publish {
                tree: tree.clone(),
                source: source.clone(),
                target: Some(target.clone()),
                entry: Some(observed.clone()),
                moved: false,
                descendants: None,
                token: None,
                replaced: None,
                result: result.clone(),
            }))),
    );
    assert_eq!(result.lock().unwrap().as_ref().unwrap().node, output.node);
    fs::rename(dir.0.join("dst/a"), dir.0.join("dst/saved")).unwrap();
    fs::write(dir.0.join("dst/a"), "replacement").unwrap();
    let replacement = request(tree.resolve(dir.0.join("dst/a")));
    let result = tree
        .data()
        .submit(Action::Native(Box::new(super::job_owner::Publish {
            tree: tree.clone(),
            source,
            target: Some(target),
            entry: Some(observed),
            moved: false,
            descendants: None,
            token: None,
            replaced: None,
            result: Arc::new(std::sync::Mutex::new(None)),
        })))
        .wait();
    let Outcome::Reply(Reply::Rejected { error }) = result else {
        panic!("stale completion");
    };
    assert_eq!(error.code, ErrorCode::Stale);
    assert!(tree.source().contains(replacement.node));
    assert_eq!(
        resource::entry(&tree.source(), replacement.node)
            .unwrap()
            .identity,
        replacement.entry().unwrap().identity
    );
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_case_different_publication_reuses_output_and_removes_confirmed_old_name() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("Name"), "source").unwrap();
    fs::write(dir.0.join("dst/name"), "old").unwrap();
    if !dir.0.join("dst/Name").exists() {
        return;
    }
    let tree = request(Filetree::open(dir.0.clone()));
    let source = request(tree.resolve(dir.0.join("Name")));
    let old = request(tree.resolve(dir.0.join("dst/name")));
    let target = request(tree.resolve(dir.0.join("dst")));
    let captured = Arc::new(std::sync::Mutex::new(None));
    reply(tree.data().submit(Action::Native(Box::new(
        super::job_owner::CaptureReplacement {
            tree: tree.clone(),
            parent: target.clone(),
            name: "name".into(),
            signature: super::io::Signature::entry(&old.entry().unwrap(), false),
            result: captured.clone(),
        },
    ))));
    fs::write(dir.0.join("output"), "output").unwrap();
    fs::rename(dir.0.join("output"), dir.0.join("dst/Name")).unwrap();
    let observed = request(tree.resolve(dir.0.join("dst/Name")));
    let result = Arc::new(std::sync::Mutex::new(None));
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::job_owner::Publish {
                tree: tree.clone(),
                source,
                target: Some(target.clone()),
                entry: Some(observed.entry().unwrap()),
                moved: false,
                descendants: None,
                token: None,
                replaced: captured.lock().unwrap().take(),
                result: result.clone(),
            }))),
    );
    assert_eq!(result.lock().unwrap().as_ref().unwrap().node, observed.node);
    assert!(!tree.source().contains(old.node));
    assert_eq!(tree.source().node(target.node).unwrap().child_count(), 1);
}

#[test]
fn t_job_same_parent_sorting_does_not_stale_another_prepared_selection() {
    let dir = Directory::new();
    fs::write(dir.0.join("a"), "a").unwrap();
    fs::write(dir.0.join("b"), "b").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "a", Some("."), OperationKind::Move);
    operation.name = Some("z".into());
    let mut other = OperationPlan {
        source: operation.source.clone(),
        nodes: operation.nodes.clone(),
        kind: OperationKind::Delete,
        prepare_move: false,
        target: None,
        name: None,
        task: None,
    };
    let state = selection(&tree, &mut other);
    let context = other.task.unwrap();
    let result = done(&tree.start_operation(operation).unwrap());
    assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
    let prepared = reply(state.dispatch(
        Command::PrepareSources {
            lock: context.lock,
            retry: false,
        },
        Context::default(),
    ));
    assert!(matches!(prepared, Reply::Ready { .. }));
    reply(state.submit(Action::Unlock(state.id(), context.lock)));
}

#[cfg(unix)]
#[test]
fn t_job_target_directory_rename_during_copy_cleans_the_original_directory() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::File::create(dir.0.join("large"))
        .unwrap()
        .set_len(256 * 1024 * 1024)
        .unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let job = tree
        .start_operation(plan(&tree, "large", Some("dst"), OperationKind::Copy))
        .unwrap();
    until(|| job.status().bytes != 0 || job.status().terminal);
    assert!(
        !job.status().terminal,
        "copy finished before directory rename"
    );
    fs::rename(dir.0.join("dst"), dir.0.join("relocated")).unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(
        fs::read_dir(dir.0.join("relocated")).unwrap().count(),
        0,
        "private output was left behind in the renamed directory"
    );
}

#[cfg(unix)]
#[test]
fn t_job_copy_preserves_new_directory_permissions_and_keeps_merge_permissions() {
    use std::os::unix::fs::PermissionsExt;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("private")).unwrap();
    fs::create_dir(dir.0.join("readonly")).unwrap();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::create_dir_all(dir.0.join("merged/private")).unwrap();
    fs::write(dir.0.join("private/file"), "value").unwrap();
    fs::write(dir.0.join("readonly/file"), "value").unwrap();
    fs::set_permissions(dir.0.join("private"), fs::Permissions::from_mode(0o700)).unwrap();
    fs::set_permissions(dir.0.join("readonly"), fs::Permissions::from_mode(0o555)).unwrap();
    fs::set_permissions(
        dir.0.join("merged/private"),
        fs::Permissions::from_mode(0o750),
    )
    .unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    for (source, destination, mode) in [
        ("private", "dst", 0o700),
        ("readonly", "dst", 0o555),
        ("private", "merged", 0o750),
    ] {
        let result = done(
            &tree
                .start_operation(plan(&tree, source, Some(destination), OperationKind::Copy))
                .unwrap(),
        );
        assert_eq!(result[0].status, ItemStatus::Success);
        assert!(result[0].sync_error.is_none(), "{:?}", result[0].sync_error);
        let path = dir.0.join(destination).join(source);
        assert_eq!(
            fs::metadata(&path).unwrap().permissions().mode() & 0o777,
            mode
        );
        assert!(path.join("file").exists());
        fs::set_permissions(path, fs::Permissions::from_mode(0o700)).unwrap();
    }
    fs::set_permissions(dir.0.join("readonly"), fs::Permissions::from_mode(0o700)).unwrap();
}

#[test]
fn t_job_confirmation_outlives_preparation_deadline_without_unlocking_selection() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("dst")).unwrap();
    fs::write(dir.0.join("file"), "new").unwrap();
    fs::write(dir.0.join("dst/file"), "old").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let mut operation = plan(&tree, "file", Some("dst"), OperationKind::Copy);
    let state = prepare_selection(
        &tree,
        &mut operation,
        Some(Instant::now() + Duration::from_millis(250)),
    );
    let job = tree.start_operation(operation).unwrap();
    until(|| job.status().confirmation.is_some());
    std::thread::sleep(Duration::from_millis(350));
    assert!(
        state.status().unwrap().locked,
        "preparation timeout released an executing task"
    );
    job.cancel();
    until(|| job.status().terminal);
    assert!(job.status().cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
}
