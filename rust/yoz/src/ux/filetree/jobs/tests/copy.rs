use super::super::*;
use crate::test_support::{TempDir, eventually};
use crate::ux::filetree::test_support::*;
use std::fs;

#[test]
fn t_job_copy_merge_skip_continues_and_cleans_discovered_success_only() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src")).unwrap();
    fs::create_dir_all(dir.path().join("dst/src")).unwrap();
    fs::write(dir.path().join("src/a"), "new a").unwrap();
    fs::write(dir.path().join("src/b"), "new b").unwrap();
    let names: Vec<_> = fs::read_dir(dir.path().join("src"))
        .unwrap()
        .map(|entry| entry.unwrap().file_name())
        .collect();
    let completed = &names[0];
    let conflicting = &names[1];
    fs::write(dir.path().join("src").join(completed), "new a").unwrap();
    fs::write(dir.path().join("src").join(conflicting), "new b").unwrap();
    fs::write(dir.path().join("dst/src").join(conflicting), "old b").unwrap();
    fs::write(dir.path().join("dst/src/keep"), "keep").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let destination = request(tree.resolve(dir.path().join("dst/src")));
    let Outcome::State(destination_state) = tree
        .create_state(
            Some(Root::ChildrenOf(destination.node)),
            DisplayOptions::default(),
        )
        .wait()
    else {
        panic!("destination state");
    };
    let _destination_view = destination_state.attach().unwrap();
    eventually(|| {
        tree.source().node(destination.node).unwrap().completeness == Completeness::Complete
    });
    let mut plan = plan(&tree, "src", Some("dst"), OperationKind::Copy);
    let root = plan.nodes[0];
    let state = selection(&tree, &mut plan);
    let job = tree.start_operation(plan).unwrap();
    eventually(|| job.status().confirmation.is_some() || job.status().terminal);
    let pending = job
        .status()
        .confirmation
        .unwrap_or_else(|| panic!("{:?}", job.status().error));
    assert_eq!(pending.source, dir.path().join("src").join(conflicting));
    assert!(
        tree.index
            .lock()
            .unwrap()
            .child(Some(destination.node), completed)
            .is_some(),
        "completed siblings must be published before exposing a confirmation"
    );
    job.confirm(pending.token, false).unwrap();
    assert!(job.confirm(pending.token, true).is_err());
    let results = done(&job);
    assert!(results.iter().any(
        |result| result.source() == dir.path().join("src").join(completed)
            && result.status == ItemStatus::Success
            && result.sync_error().is_none()
    ));
    assert!(results.iter().any(|result| result.source()
        == dir.path().join("src").join(conflicting)
        && result.status == ItemStatus::Skipped));
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/src").join(completed)).unwrap(),
        "new a"
    );
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/src").join(conflicting)).unwrap(),
        "old b"
    );
    assert!(dir.path().join("dst/src/keep").exists());
    assert!(!state.status().unwrap().locked);
    assert!(
        tree.index
            .lock()
            .unwrap()
            .child(Some(root), conflicting)
            .is_none(),
        "skipped input stays lazy"
    );
    let b = request(tree.resolve(dir.path().join("src").join(conflicting))).node;
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
        .child(Some(root), completed)
        .unwrap();
    assert!(!sources.subtree_roots.contains(&a));
    assert!(sources.subtree_roots.contains(&b));
}

#[test]
fn t_directory_copy_and_merge_keep_unbrowsed_descendants_lazy() {
    let _operations = operations();
    for merge in [false, true] {
        let dir = TempDir::new();
        fs::create_dir(dir.path().join("src")).unwrap();
        fs::create_dir(dir.path().join("dst")).unwrap();
        if merge {
            fs::create_dir(dir.path().join("dst/src")).unwrap();
        }
        for index in 0..24 {
            fs::write(dir.path().join(format!("src/{index:02}")), b"data").unwrap();
        }
        let tree = request(Filetree::open(dir.path().to_path_buf()));
        let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Copy);
        let source = operation.nodes[0];
        let state = selection(&tree, &mut operation);
        let before = tree.source().len();
        let job = tree.start_operation(operation).unwrap();
        let results = done(&job);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(results[0].sync_error().is_none());
        assert!(matches!(job.status().cleanup, Some(Ok(()))));
        assert!(state.snapshot().unwrap().summary.is_empty());
        assert_eq!(tree.source().node(source).unwrap().child_count(), 0);
        assert_eq!(
            tree.source().node(source).unwrap().completeness,
            Completeness::Unknown
        );
        assert!(tree.source().len() <= before + 1);
        let copied = request(tree.resolve(dir.path().join("dst/src")));
        assert_eq!(tree.source().node(copied.node).unwrap().child_count(), 0);
        let Outcome::State(browse) = tree
            .create_state(
                Some(Root::ChildrenOf(copied.node)),
                DisplayOptions::default(),
            )
            .wait()
        else {
            panic!("browse state");
        };
        let _view = browse.attach().unwrap();
        eventually(|| {
            tree.source().node(copied.node).unwrap().completeness == Completeness::Complete
        });
        assert_eq!(tree.source().node(copied.node).unwrap().child_count(), 24);
        assert_eq!(tree.source().node(source).unwrap().child_count(), 0);
        for index in 0..24 {
            assert_eq!(
                fs::read(dir.path().join(format!("dst/src/{index:02}"))).unwrap(),
                b"data"
            );
        }
    }
}

#[cfg(unix)]
#[test]
fn t_job_publication_rejects_retargeted_destination_directory() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("real")).unwrap();
    fs::write(dir.path().join("a"), "source").unwrap();
    std::os::unix::fs::symlink("real", dir.path().join("dst")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let source = request(tree.resolve(dir.path().join("a")));
    let target = request(tree.resolve(dir.path().join("dst")));
    fs::copy(dir.path().join("a"), dir.path().join("dst/a")).unwrap();
    let observed = Entry::read(&dir.path().join("dst/a")).unwrap();
    fs::rename(dir.path().join("real"), dir.path().join("previous")).unwrap();
    fs::create_dir(dir.path().join("real")).unwrap();
    let refreshed = request(tree.resolve(dir.path().join("dst")));
    assert_eq!(refreshed.node, target.node);
    assert_ne!(
        refreshed.entry().unwrap().target,
        target.entry().unwrap().target
    );
    let result = tree
        .data()
        .submit(Action::Native(Box::new(super::super::job_owner::Publish {
            tree: tree.clone(),
            source: Some(source.clone()),
            anchor: source.clone(),
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
    assert!(!dir.path().join("dst/a").exists());
    assert_eq!(
        fs::read_to_string(dir.path().join("previous/a")).unwrap(),
        "source"
    );
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_job_case_different_overwrite_retires_the_confirmed_occurrence() {
    let _operations = operations();
    for kind in [OperationKind::Copy, OperationKind::Move] {
        let dir = TempDir::new();
        fs::create_dir(dir.path().join("src")).unwrap();
        fs::create_dir(dir.path().join("dst")).unwrap();
        fs::write(dir.path().join("src/Name"), "new").unwrap();
        fs::write(dir.path().join("dst/name"), "old").unwrap();
        if !dir.path().join("dst/Name").exists() {
            return;
        }
        let tree = request(Filetree::open(dir.path().to_path_buf()));
        let old = request(tree.resolve(dir.path().join("dst/name")));
        let mut operation = plan(&tree, "src/Name", Some("dst"), kind);
        let source = operation.nodes[0];
        let parent = operation.target.as_ref().unwrap().node;
        let state = selection(&tree, &mut operation);
        let job = tree.start_operation(operation).unwrap();
        eventually(|| job.status().confirmation.is_some() || job.status().terminal);
        job.confirm(job.status().confirmation.unwrap().token, true)
            .unwrap();
        let results = done(&job);
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(
            results[0].sync_error().is_none(),
            "{:?}",
            results[0].sync_error()
        );
        assert!(!tree.source().contains(old.node));
        assert_eq!(tree.source().node(parent).unwrap().child_count(), 1);
        let output = request(tree.resolve(dir.path().join("dst/Name")));
        assert_eq!(
            output.entry().unwrap().name,
            resource::observed_name(&dir.path().join("dst/Name")).unwrap()
        );
        if kind == OperationKind::Move {
            assert_eq!(output.node, source);
        }
        assert_eq!(
            fs::read_to_string(dir.path().join("dst/Name")).unwrap(),
            "new"
        );
        assert!(!state.status().unwrap().locked);
    }
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_job_case_different_directory_merge_preserves_actual_destination_name() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src/Name")).unwrap();
    fs::create_dir_all(dir.path().join("dst/name")).unwrap();
    fs::write(dir.path().join("src/Name/new"), "new").unwrap();
    fs::write(dir.path().join("dst/name/keep"), "keep").unwrap();
    if !dir.path().join("dst/Name").exists() {
        return;
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(tree.resolve(dir.path().join("dst/name")));
    let operation = plan(&tree, "src/Name", Some("dst"), OperationKind::Copy);
    let parent = operation.target.as_ref().unwrap().node;
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error().is_none(),
        "{:?}",
        results[0].sync_error()
    );
    assert_eq!(tree.source().node(parent).unwrap().child_count(), 1);
    let output = request(tree.resolve(dir.path().join("dst/Name")));
    assert_eq!(output.node, old.node);
    assert_eq!(output.entry().unwrap().name, "name");
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/name/keep")).unwrap(),
        "keep"
    );
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/name/new")).unwrap(),
        "new"
    );
}

#[test]
fn t_job_conflicts_and_actual_descendant_aliases_preserve_both_sides() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src/sub")).unwrap();
    fs::create_dir_all(dir.path().join("dst/src")).unwrap();
    fs::write(dir.path().join("src/a"), "source").unwrap();
    fs::write(dir.path().join("dst/src/keep"), "keep").unwrap();
    fs::write(dir.path().join("file"), "source file").unwrap();
    fs::create_dir(dir.path().join("dst/file")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
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
        std::os::unix::fs::symlink(dir.path().join("src/sub"), dir.path().join("alias")).unwrap();
        let results = done(
            &tree
                .start_operation(plan(&tree, "src", Some("alias"), OperationKind::Move))
                .unwrap(),
        );
        assert_eq!(results[0].status, ItemStatus::Failed);
    }
    assert_eq!(
        fs::read_to_string(dir.path().join("src/a")).unwrap(),
        "source"
    );
    assert!(dir.path().join("dst/src/keep").exists());
    assert!(dir.path().join("dst/file").is_dir());
}

#[test]
fn t_job_large_copy_cancellation_keeps_destination_and_removes_private_output() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    let file = fs::File::create(dir.path().join("large")).unwrap();
    file.set_len(256 * 1024 * 1024).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "large", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().bytes != 0 || job.status().terminal);
    assert!(
        !job.status().terminal,
        "copy finished before cancellation test could act"
    );
    let start = Instant::now();
    job.cancel();
    eventually(|| job.status().terminal);
    assert!(job.status().cancelled);
    assert!(!dir.path().join("dst/large").exists());
    assert_eq!(fs::read_dir(dir.path().join("dst")).unwrap().count(), 0);
    assert!(job.status().cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
    eprintln!(
        "copy cancellation stop: {:?}; streamed bytes={}",
        start.elapsed(),
        job.status().bytes
    );
}

#[test]
fn t_job_cancel_flushes_completed_small_copies_before_selection_cleanup() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("src")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("src/a"), "done").unwrap();
    fs::write(dir.path().join("src/b"), "grow").unwrap();
    let names: Vec<_> = fs::read_dir(dir.path().join("src"))
        .unwrap()
        .map(|entry| entry.unwrap().file_name())
        .collect();
    let completed = &names[0];
    let growing = &names[1];
    fs::write(dir.path().join("src").join(completed), "done").unwrap();
    fs::write(dir.path().join("src").join(growing), "grow").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let b = request(tree.resolve(dir.path().join("src").join(growing)));
    assert_eq!(b.entry().unwrap().size, 4);
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Copy);
    let root = operation.nodes[0];
    let target = operation.target.as_ref().unwrap().node;
    let state = selection(&tree, &mut operation);
    /* The admitted metadata remains small; the opened file grows before IO.
     * Cancellation during its stream must still publish the completed prefix. */
    fs::OpenOptions::new()
        .write(true)
        .open(dir.path().join("src").join(growing))
        .unwrap()
        .set_len(256 * 1024 * 1024)
        .unwrap();
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().bytes > 4 || job.status().terminal);
    assert!(!job.status().terminal, "copy completed before cancellation");
    job.cancel();
    eventually(|| job.status().terminal);
    let status = job.status();
    assert!(status.cancelled);
    assert!(status.cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
    assert_eq!(
        fs::read(dir.path().join("dst/src").join(completed)).unwrap(),
        b"done"
    );
    assert!(!dir.path().join("dst/src").join(growing).exists());
    assert_eq!(fs::read_dir(dir.path().join("dst/src")).unwrap().count(), 1);
    let a = {
        let index = tree.index.lock().unwrap();
        let copied_root = index
            .child(Some(target), std::ffi::OsStr::new("src"))
            .unwrap();
        #[cfg(not(any(target_os = "macos", target_os = "linux")))]
        assert!(index.child(Some(copied_root), completed).is_some());
        #[cfg(any(target_os = "macos", target_os = "linux"))]
        assert!(index.child(Some(copied_root), completed).is_none());
        index.child(Some(root), completed).unwrap()
    };
    let copied = request(tree.resolve(dir.path().join("dst/src").join(completed)));
    assert_eq!(
        copied.path().unwrap(),
        dir.path().join("dst/src").join(completed)
    );
    let results = job.results(0, status.results).unwrap();
    assert!(
        results[0].node.is_none(),
        "the result keeps its original detached identity"
    );
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(results[0].sync_error().is_none());
    let Reply::Inspected { sources, .. } =
        reply(state.dispatch(Command::InspectSelection, Context::default()))
    else {
        panic!("selection");
    };
    assert!(!sources.subtree_roots.contains(&a));
    assert!(sources.subtree_roots.contains(&b.node));
}

#[test]
fn t_job_external_topology_change_keeps_io_results_and_reports_cleanup_stale() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src")).unwrap();
    fs::create_dir_all(dir.path().join("dst/src")).unwrap();
    fs::write(dir.path().join("src/a"), "a").unwrap();
    fs::write(dir.path().join("src/z"), "z").unwrap();
    let names: Vec<_> = fs::read_dir(dir.path().join("src"))
        .unwrap()
        .map(|entry| entry.unwrap().file_name())
        .collect();
    let completed = names[0].clone();
    let conflicting = names[1].clone();
    fs::write(dir.path().join("dst/src").join(&conflicting), "old").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    request(tree.resolve(dir.path().join("src").join(&conflicting)));
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let root = operation.nodes[0];
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().confirmation.is_some());
    let token = job.status().confirmation.unwrap().token;
    let current = tree.source();
    let z = current
        .node(root)
        .unwrap()
        .children()
        .find(|id| resource::entry(&current, *id).unwrap().name == conflicting)
        .unwrap();
    reply(tree.data().submit(Action::Batch(Batch {
        base_revision: current.revision(),
        operations: vec![Operation::Remove { node: z.into() }],
    })));
    let _ = job.confirm(token, true);
    eventually(|| job.status().terminal);
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    let results = job.results(0, job.status().results).unwrap();
    assert!(results.iter().any(|result| result.source()
        == dir.path().join("src").join(&completed)
        && result.status == ItemStatus::Success));
    assert!(!state.status().unwrap().locked);
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/src").join(&conflicting)).unwrap(),
        "old"
    );
}

#[test]
fn t_job_unviewed_multi_page_directory_and_finished_handle_release_memory() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("src")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    for i in 0..1100 {
        fs::write(dir.path().join(format!("src/file-{i:04}")), "x").unwrap();
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
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
        results[0].sync_error().is_none(),
        "{:?}",
        results[0].sync_error()
    );
    assert_eq!(
        fs::read_dir(dir.path().join("dst/src")).unwrap().count(),
        1100
    );
    #[cfg(any(target_os = "macos", target_os = "linux"))]
    {
        let copied = request(tree.resolve(dir.path().join("dst/src")));
        let source = tree.source();
        assert_eq!(source.node(copied.node).unwrap().child_count(), 0);
        assert_eq!(
            source.node(copied.node).unwrap().completeness,
            Completeness::Unknown
        );
        let leaf = request(tree.resolve(dir.path().join("dst/src/file-0000")));
        assert_eq!(leaf.path().unwrap(), dir.path().join("dst/src/file-0000"));
        assert_eq!(tree.source().node(copied.node).unwrap().child_count(), 1);
    }
    drop(results);
    drop(job);
    drop(tree);
    eventually(|| memory.used() == 0);
}

#[test]
fn t_job_late_copy_publication_reuses_observed_output_but_cannot_replace_new_occurrence() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("a"), "source").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let source = request(tree.resolve(dir.path().join("a")));
    let target = request(tree.resolve(dir.path().join("dst")));
    fs::write(dir.path().join("dst/a"), "output").unwrap();
    let observed = Entry::read(&dir.path().join("dst/a")).unwrap();
    let output = request(tree.resolve(dir.path().join("dst/a")));
    let result = Arc::new(std::sync::Mutex::new(None));
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::super::job_owner::Publish {
                tree: tree.clone(),
                source: Some(source.clone()),
                anchor: source.clone(),
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
    fs::rename(dir.path().join("dst/a"), dir.path().join("dst/saved")).unwrap();
    fs::write(dir.path().join("dst/a"), "replacement").unwrap();
    let replacement = request(tree.resolve(dir.path().join("dst/a")));
    let result = tree
        .data()
        .submit(Action::Native(Box::new(super::super::job_owner::Publish {
            tree: tree.clone(),
            source: Some(source.clone()),
            anchor: source.clone(),
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

#[test]
fn t_job_copy_publication_batch_keeps_successes_around_a_stale_item() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    for name in ["a", "b", "c"] {
        fs::write(dir.path().join(name), "source").unwrap();
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let target = request(tree.resolve(dir.path().join("dst")));
    let sources: Vec<_> = ["a", "b", "c"]
        .into_iter()
        .map(|name| request(tree.resolve(dir.path().join(name))))
        .collect();
    fs::write(dir.path().join("dst/b"), "output").unwrap();
    let old_b = Entry::read(&dir.path().join("dst/b")).unwrap();
    fs::rename(dir.path().join("dst/b"), dir.path().join("saved-b")).unwrap();
    fs::write(dir.path().join("dst/b"), "replacement").unwrap();
    let replacement = request(tree.resolve(dir.path().join("dst/b")));
    let mut items = Vec::new();
    for (name, source) in ["a", "b", "c"].into_iter().zip(sources) {
        let entry = if name == "b" {
            old_b.clone()
        } else {
            fs::write(dir.path().join("dst").join(name), "output").unwrap();
            Entry::read(&dir.path().join("dst").join(name)).unwrap()
        };
        items.push(super::super::job_owner::CopyPublication {
            source: Some(source.clone()),
            anchor: source.clone(),
            target: target.clone(),
            entry,
        });
    }
    let results = Arc::new(std::sync::Mutex::new(vec![None; items.len()]));
    reply(tree.data().submit(Action::Native(Box::new(
        super::super::job_owner::PublishCopies {
            tree: tree.clone(),
            items,
            results: results.clone(),
        },
    ))));
    let results = results.lock().unwrap();
    assert!(results[0].is_none());
    assert_eq!(results[1].as_ref().unwrap().code, ErrorCode::Stale);
    assert!(results[2].is_none());
    let index = tree.index.lock().unwrap();
    for name in ["a", "c"] {
        let node = index
            .child(Some(target.node), std::ffi::OsStr::new(name))
            .unwrap();
        assert_eq!(resource::entry(&tree.source(), node).unwrap().name, name);
    }
    assert_eq!(
        index.child(Some(target.node), std::ffi::OsStr::new("b")),
        Some(replacement.node)
    );
    assert_eq!(
        resource::entry(&tree.source(), replacement.node)
            .unwrap()
            .identity,
        replacement.entry().unwrap().identity
    );
    assert_eq!(fs::read(dir.path().join("dst/b")).unwrap(), b"replacement");
}

#[test]
fn t_job_copy_publication_preserves_a_prefix_when_the_batch_exceeds_capacity() {
    struct OneMoreNode;
    impl NativeAction for OneMoreNode {
        fn bytes(&self) -> usize {
            0
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            engine.limits.nodes = engine.source().len() + 1;
            Ok(Reply::NoChange)
        }
    }

    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    for name in ["a", "b", "c"] {
        fs::write(dir.path().join(name), "source").unwrap();
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let target = request(tree.resolve(dir.path().join("dst")));
    let sources: Vec<_> = ["a", "b", "c"]
        .into_iter()
        .map(|name| request(tree.resolve(dir.path().join(name))))
        .collect();
    let items = ["a", "b", "c"]
        .into_iter()
        .zip(sources)
        .map(|(name, source)| {
            let path = dir.path().join("dst").join(name);
            fs::write(&path, "output").unwrap();
            super::super::job_owner::CopyPublication {
                source: Some(source.clone()),
                anchor: source.clone(),
                target: target.clone(),
                entry: Entry::read(&path).unwrap(),
            }
        })
        .collect();
    reply(tree.data().submit(Action::Native(Box::new(OneMoreNode))));
    let results = Arc::new(std::sync::Mutex::new(vec![None; 3]));
    reply(tree.data().submit(Action::Native(Box::new(
        super::super::job_owner::PublishCopies {
            tree: tree.clone(),
            items,
            results: results.clone(),
        },
    ))));
    let results = results.lock().unwrap();
    assert!(results[0].is_none());
    assert_eq!(results[1].as_ref().unwrap().code, ErrorCode::ResourceLimit);
    assert_eq!(results[2].as_ref().unwrap().code, ErrorCode::ResourceLimit);
    let index = tree.index.lock().unwrap();
    assert!(
        index
            .child(Some(target.node), std::ffi::OsStr::new("a"))
            .is_some()
    );
    assert!(
        index
            .child(Some(target.node), std::ffi::OsStr::new("b"))
            .is_none()
    );
    assert!(
        index
            .child(Some(target.node), std::ffi::OsStr::new("c"))
            .is_none()
    );
    assert_eq!(tree.source().node(target.node).unwrap().child_count(), 1);
    for name in ["a", "b", "c"] {
        assert_eq!(
            fs::read(dir.path().join("dst").join(name)).unwrap(),
            b"output"
        );
    }
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_case_different_publication_reuses_output_and_removes_confirmed_old_name() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("Name"), "source").unwrap();
    fs::write(dir.path().join("dst/name"), "old").unwrap();
    if !dir.path().join("dst/Name").exists() {
        return;
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let source = request(tree.resolve(dir.path().join("Name")));
    let old = request(tree.resolve(dir.path().join("dst/name")));
    let target = request(tree.resolve(dir.path().join("dst")));
    let captured = Arc::new(std::sync::Mutex::new(None));
    reply(tree.data().submit(Action::Native(Box::new(
        super::super::job_owner::CaptureReplacement {
            tree: tree.clone(),
            parent: target.clone(),
            name: "name".into(),
            signature: super::super::io::Signature::entry(&old.entry().unwrap(), false),
            result: captured.clone(),
        },
    ))));
    fs::write(dir.path().join("output"), "output").unwrap();
    fs::rename(dir.path().join("output"), dir.path().join("dst/Name")).unwrap();
    let observed = request(tree.resolve(dir.path().join("dst/Name")));
    let result = Arc::new(std::sync::Mutex::new(None));
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::super::job_owner::Publish {
                tree: tree.clone(),
                source: Some(source.clone()),
                anchor: source.clone(),
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

#[cfg(unix)]
#[test]
fn t_job_target_directory_rename_during_copy_cleans_the_original_directory() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::File::create(dir.path().join("large"))
        .unwrap()
        .set_len(256 * 1024 * 1024)
        .unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let job = tree
        .start_operation(plan(&tree, "large", Some("dst"), OperationKind::Copy))
        .unwrap();
    eventually(|| job.status().bytes != 0 || job.status().terminal);
    assert!(
        !job.status().terminal,
        "copy finished before directory rename"
    );
    fs::rename(dir.path().join("dst"), dir.path().join("relocated")).unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(
        fs::read_dir(dir.path().join("relocated")).unwrap().count(),
        0,
        "private output was left behind in the renamed directory"
    );
}

#[cfg(unix)]
#[test]
fn t_job_copy_preserves_new_directory_permissions_and_keeps_merge_permissions() {
    let _operations = operations();
    use std::os::unix::fs::PermissionsExt;
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("private")).unwrap();
    fs::create_dir(dir.path().join("readonly")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::create_dir_all(dir.path().join("merged/private")).unwrap();
    fs::write(dir.path().join("private/file"), "value").unwrap();
    fs::write(dir.path().join("readonly/file"), "value").unwrap();
    fs::set_permissions(
        dir.path().join("private"),
        fs::Permissions::from_mode(0o700),
    )
    .unwrap();
    fs::set_permissions(
        dir.path().join("readonly"),
        fs::Permissions::from_mode(0o555),
    )
    .unwrap();
    fs::set_permissions(
        dir.path().join("merged/private"),
        fs::Permissions::from_mode(0o750),
    )
    .unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
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
        assert!(
            result[0].sync_error().is_none(),
            "{:?}",
            result[0].sync_error()
        );
        let path = dir.path().join(destination).join(source);
        assert_eq!(
            fs::metadata(&path).unwrap().permissions().mode() & 0o777,
            mode
        );
        assert!(path.join("file").exists());
        fs::set_permissions(path, fs::Permissions::from_mode(0o700)).unwrap();
    }
    fs::set_permissions(
        dir.path().join("readonly"),
        fs::Permissions::from_mode(0o700),
    )
    .unwrap();
}

#[test]
fn t_copy_keeps_completed_io_when_batch_submission_exceeds_the_budget() {
    let _operations = operations();
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("dst")).unwrap();
    fs::write(directory.path().join("source"), b"contents").unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let source = request(tree.resolve(directory.path().join("source")));
    let target = request(tree.resolve(directory.path().join("dst")));
    /* The first copied bytes exhaust the budget after admission and before publication. */
    let memory = tree.data().memory();
    let charge = Arc::new(Mutex::new(None));
    let held = charge.clone();
    let (job, _listener) = start_observed(
        &tree,
        OperationPlan {
            kind: OperationKind::Copy,
            source: source.source.clone(),
            nodes: vec![source.node].into(),
            target: Some(target.clone()),
            name: None,
            task: None,
            prepare_move: false,
        },
        |status| status.bytes > 0,
        move |_| {
            let _guard = memory.enter();
            *held.lock().unwrap() = Some(Charge::new(Limits::default().memory_bytes));
        },
    );
    let status = finished(&job);
    assert!(charge.lock().unwrap().is_some());
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
    assert_eq!(
        fs::read(directory.path().join("source")).unwrap(),
        b"contents"
    );
    assert_eq!(
        fs::read(directory.path().join("dst/source")).unwrap(),
        b"contents"
    );
    assert_eq!(
        fs::read_dir(directory.path().join("dst")).unwrap().count(),
        1
    );
    assert!(
        tree.index
            .lock()
            .unwrap()
            .child(Some(target.node), std::ffi::OsStr::new("source"))
            .is_none()
    );
}
