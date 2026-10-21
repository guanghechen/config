use super::super::*;
use crate::test_support::{TempDir, eventually};
use crate::ux::filetree::test_support::*;
use crate::ux::treeview::test_support::hold;
use std::fs;

#[test]
fn t_move_preparation_follows_overwrite_confirmation_and_rechecks_source_identity() {
    let _operations = operations();
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("dest")).unwrap();
    fs::write(directory.path().join("a"), "source").unwrap();
    fs::write(directory.path().join("dest/a"), "destination").unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let mut operation = plan(&tree, "a", Some("dest"), OperationKind::Move);
    operation.prepare_move = true;
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().confirmation.is_some());
    let overwrite = job.status().confirmation.unwrap();
    assert!(!overwrite.prepare_move);
    job.confirm(overwrite.token, true).unwrap();
    eventually(|| {
        job.status()
            .confirmation
            .is_some_and(|request| request.prepare_move)
    });
    let preparation = job.status().confirmation.unwrap();
    assert_eq!(
        preparation.source,
        fs::canonicalize(directory.path()).unwrap().join("a")
    );
    assert_eq!(
        fs::read(directory.path().join("dest/a")).unwrap(),
        b"destination"
    );
    fs::rename(
        directory.path().join("a"),
        directory.path().join("original"),
    )
    .unwrap();
    fs::write(directory.path().join("a"), "replacement").unwrap();
    job.confirm(preparation.token, true).unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(
        fs::read(directory.path().join("a")).unwrap(),
        b"replacement"
    );
    assert_eq!(
        fs::read(directory.path().join("dest/a")).unwrap(),
        b"destination"
    );
}

#[test]
fn t_cancel_during_move_preparation_keeps_files_and_releases_selection() {
    let _operations = operations();
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("dest")).unwrap();
    fs::write(directory.path().join("a"), "source").unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let mut operation = plan(&tree, "a", Some("dest"), OperationKind::Move);
    operation.prepare_move = true;
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    eventually(|| {
        job.status()
            .confirmation
            .is_some_and(|request| request.prepare_move)
    });
    job.cancel();
    eventually(|| job.status().terminal);
    assert!(job.status().cancelled);
    assert!(!state.status().unwrap().locked);
    assert!(directory.path().join("a").exists());
    assert!(!directory.path().join("dest/a").exists());
    assert_eq!(state.snapshot().unwrap().summary.known_roots, 1);
}

#[test]
fn t_replaced_source_is_rejected_before_move_preparation_is_requested() {
    let _operations = operations();
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("dest")).unwrap();
    fs::write(directory.path().join("a"), "source").unwrap();
    fs::write(directory.path().join("dest/a"), "destination").unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let mut operation = plan(&tree, "a", Some("dest"), OperationKind::Move);
    operation.prepare_move = true;
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().confirmation.is_some());
    let overwrite = job.status().confirmation.unwrap();
    assert!(!overwrite.prepare_move);
    fs::rename(
        directory.path().join("a"),
        directory.path().join("original"),
    )
    .unwrap();
    fs::write(directory.path().join("a"), "replacement").unwrap();
    job.confirm(overwrite.token, true).unwrap();
    eventually(|| {
        let status = job.status();
        assert!(
            !status
                .confirmation
                .is_some_and(|request| request.prepare_move)
        );
        status.terminal
    });
    assert_eq!(done(&job)[0].status, ItemStatus::Failed);
    assert_eq!(
        fs::read(directory.path().join("a")).unwrap(),
        b"replacement"
    );
    assert_eq!(
        fs::read(directory.path().join("dest/a")).unwrap(),
        b"destination"
    );
}

#[test]
fn t_job_move_keeps_occurrence_and_delete_discovers_unloaded_children() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src/sub")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("src/sub/a"), "a").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut move_plan = plan(&tree, "src", Some("dst"), OperationKind::Move);
    let root = move_plan.nodes[0];
    let state = selection(&tree, &mut move_plan);
    let result = done(&tree.start_operation(move_plan).unwrap());
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    assert_eq!(
        tree.inspect(tree.source(), root).unwrap().path().unwrap(),
        dir.path().join("dst/src")
    );
    assert!(!state.status().unwrap().locked);
    let mut delete_plan = plan(&tree, "dst/src", None, OperationKind::Delete);
    let state = selection(&tree, &mut delete_plan);
    let result = done(&tree.start_operation(delete_plan).unwrap());
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    assert!(!tree.source().contains(root));
    assert!(!dir.path().join("dst/src").exists());
    assert!(!state.status().unwrap().locked);
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_job_case_only_rename_preserves_occurrence_and_actual_spelling() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::write(dir.path().join("original"), "content").unwrap();
    if !dir.path().join("ORIGINAL").exists() {
        return;
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
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
        resource::observed_name(&dir.path().join("original")).unwrap(),
        "Original"
    );
    assert_eq!(
        request(tree.resolve(dir.path().join("ORIGINAL"))).node,
        node
    );
}

#[cfg(unix)]
#[test]
fn t_job_move_to_same_entry_through_alias_preserves_both_occurrences() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("real")).unwrap();
    fs::write(dir.path().join("real/a"), "content").unwrap();
    std::os::unix::fs::symlink("real", dir.path().join("alias")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let alias = request(tree.resolve(dir.path().join("alias/a")));
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
    assert_eq!(
        fs::read_to_string(dir.path().join("real/a")).unwrap(),
        "content"
    );
    assert_eq!(
        request(tree.resolve(dir.path().join("alias/a"))).node,
        alias.node
    );
    assert_eq!(
        request(tree.resolve(dir.path().join("real/a"))).node,
        source
    );
}

#[test]
fn t_job_same_parent_rename_and_empty_directory_replacement_preserve_identity() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src/sub")).unwrap();
    fs::create_dir_all(dir.path().join("dst/src")).unwrap();
    fs::write(dir.path().join("src/sub/a"), "a").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Move);
    let source = operation.nodes[0];
    selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().confirmation.is_some());
    job.confirm(job.status().confirmation.unwrap().token, true)
        .unwrap();
    let result = done(&job);
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    let mut operation = plan(&tree, "dst/src", Some("dst"), OperationKind::Move);
    operation.name = Some("renamed".into());
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    assert_eq!(
        tree.inspect(tree.source(), source).unwrap().path().unwrap(),
        dir.path().join("dst/renamed")
    );
    assert!(dir.path().join("dst/renamed/sub/a").exists());
}

#[test]
#[ignore = "requires FILETREE_TEST_VOLUME on a separate filesystem"]
fn t_job_cross_filesystem_directory_move_retains_all_admitted_identities() {
    let _operations = operations();
    let volume = std::env::var_os("FILETREE_TEST_VOLUME").expect("separate test filesystem");
    let target = TempDir::new_in(std::path::Path::new(&volume));
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src/sub")).unwrap();
    fs::write(dir.path().join("src/a"), "a").unwrap();
    fs::write(dir.path().join("src/sub/b"), "b").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(target.path().to_path_buf())));
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
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    assert_eq!(
        tree.inspect(tree.source(), root).unwrap().path().unwrap(),
        target.path().join("src")
    );
    assert!(!dir.path().join("src").exists());
    assert_eq!(
        fs::read_to_string(target.path().join("src/sub/b")).unwrap(),
        "b"
    );
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
#[ignore = "requires FILETREE_TEST_VOLUME on a separate filesystem"]
fn t_job_cross_filesystem_move_coordinates_watched_items_until_publication() {
    let _operations = operations();
    let volume = std::env::var_os("FILETREE_TEST_VOLUME").expect("separate test filesystem");
    let target = TempDir::new_in(std::path::Path::new(&volume));
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("src/sub")).unwrap();
    fs::write(dir.path().join("src/sub/small"), "content").unwrap();
    fs::File::create(dir.path().join("src/large"))
        .unwrap()
        .set_len(128 * 1024 * 1024)
        .unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
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
    let large = request(tree.resolve(dir.path().join("src/large")));
    let small = request(tree.resolve(dir.path().join("src/sub/small")));
    let mut operation = plan(&tree, "src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(target.path().to_path_buf())));
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
    eventually(|| tree.watch_status().covered.contains(&root) && !tree.data().has_work());
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().bytes > 1024 * 1024 || job.status().terminal);
    assert!(
        !job.status().terminal,
        "copy completed before queue congestion"
    );
    let (held, release) = hold(tree.data());
    /* The worker can finish IO while its publication waits behind this owner action. */
    eventually(|| !dir.path().join("src/large").exists());
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
            .all(|result| result.status == ItemStatus::Success && result.sync_error().is_none())
    );
    assert_eq!(
        resource::path(&tree.source(), root).unwrap(),
        target.path().join("src")
    );
    assert_eq!(
        resource::path(&tree.source(), large.node).unwrap(),
        target.path().join("src/large")
    );
    assert_eq!(
        resource::path(&tree.source(), small.node).unwrap(),
        target.path().join("src/sub/small")
    );
    assert_eq!(
        fs::read_to_string(target.path().join("src/sub/small")).unwrap(),
        "content"
    );
    assert!(!dir.path().join("src").exists());
    assert!(!state.status().unwrap().locked);
    assert!(tree.index.lock().unwrap().moving.is_none());
}

#[test]
fn t_directory_move_defers_related_reads_and_preserves_explicit_requests() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("src")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    for i in 0..1100 {
        fs::write(
            dir.path().join("src").join(format!("file-{i:04}")),
            "content",
        )
        .unwrap();
    }
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let source = request(tree.resolve(dir.path().join("src")));
    let target = request(tree.resolve(dir.path().join("dst")));
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
    eventually(|| tree.source().node(source.node).unwrap().child_count() == 512);
    reply(
        tree.data()
            .submit(Action::RequestChildren(vec![source.node], false)),
    );
    reply(tree.data().submit(Action::Native(Box::new(
        super::super::job_owner::BeginMove {
            tree: tree.clone(),
            source: source.clone(),
            token: None,
        },
    ))));
    drop(view);
    reply(
        tree.data()
            .submit(Action::RequestChildren(vec![tree.root()], true)),
    );
    eventually(|| tree.source().node(tree.root()).unwrap().load_state == LoadState::Loading);
    fs::rename(dir.path().join("src"), dir.path().join("dst/src")).unwrap();
    let snapshot = tree.source();
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::super::job_owner::Publish {
                tree: tree.clone(),
                source: Some(source.clone()),
                anchor: source.clone(),
                target: Some(target),
                entry: Some(Entry::read(&dir.path().join("dst/src")).unwrap()),
                moved: true,
                replaced: None,
                token: None,
                result: Arc::new(std::sync::Mutex::new(None)),
                descendants: Some(super::super::job_owner::MovedDescendants {
                    source: snapshot,
                    entries: Vec::new(),
                }),
            }))),
    );
    reply(
        tree.data()
            .submit(Action::Native(Box::new(super::super::job_owner::EndMove {
                tree: tree.clone(),
                node: source.node,
            }))),
    );
    eventually(|| {
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
        dir.path().join("dst/src")
    );
    assert!(tree.index.lock().unwrap().moving.is_none());
}

#[test]
fn t_directory_move_publication_rejects_members_loaded_after_observation() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("src")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let source = request(tree.resolve(dir.path().join("src")));
    let target = request(tree.resolve(dir.path().join("dst")));
    let snapshot = tree.source();
    fs::rename(dir.path().join("src"), dir.path().join("dst/src")).unwrap();
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
        .submit(Action::Native(Box::new(super::super::job_owner::Publish {
            tree: tree.clone(),
            source: Some(source.clone()),
            anchor: source.clone(),
            target: Some(target),
            entry: Some(Entry::read(&dir.path().join("dst/src")).unwrap()),
            moved: true,
            replaced: None,
            token: None,
            result: Arc::new(std::sync::Mutex::new(None)),
            descendants: Some(super::super::job_owner::MovedDescendants {
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
        dir.path().join("src")
    );
}

#[cfg(unix)]
#[test]
fn t_failed_directory_rename_releases_read_coordination() {
    let _operations = operations();
    use std::os::unix::fs::PermissionsExt;
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("readonly/src")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "readonly/src", Some("dst"), OperationKind::Move);
    let node = operation.nodes[0];
    let state = selection(&tree, &mut operation);
    let parent = dir.path().join("readonly");
    let permissions = fs::metadata(&parent).unwrap().permissions();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o500)).unwrap();
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().terminal);
    fs::set_permissions(&parent, permissions).unwrap();
    let result = done(&job);
    assert_eq!(result[0].status, ItemStatus::Failed);
    assert!(result[0].error().is_some());
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
    eventually(|| tree.source().node(node).unwrap().completeness == Completeness::Complete);
}

#[cfg(unix)]
#[test]
#[ignore = "requires FILETREE_TEST_VOLUME on a separate filesystem"]
fn t_job_cross_filesystem_partial_move_keeps_successful_child_identity() {
    let _operations = operations();
    use std::os::unix::ffi::OsStrExt;
    let volume = std::env::var_os("FILETREE_TEST_VOLUME").expect("separate test filesystem");
    let target = TempDir::new_in(std::path::Path::new(&volume));
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("src")).unwrap();
    fs::write(dir.path().join("src/a"), "a").unwrap();
    let fifo = std::ffi::CString::new(dir.path().join("src/fifo").as_os_str().as_bytes()).unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(tree.resolve(dir.path().join("src/a")));
    let mut operation = plan(&tree, "src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(target.path().to_path_buf())));
    let root = operation.nodes[0];
    selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    let results = done(&job);
    assert!(results.iter().any(|result| result.node == Some(old.node)
        && result.status == ItemStatus::Success
        && result.sync_error().is_none()));
    assert!(
        results
            .iter()
            .any(|result| result.node == Some(root) && result.status == ItemStatus::Failed)
    );
    assert_eq!(
        tree.inspect(tree.source(), old.node)
            .unwrap()
            .path()
            .unwrap(),
        target.path().join("src/a")
    );
    assert!(dir.path().join("src/fifo").exists());
    assert!(!dir.path().join("src/a").exists());
}
