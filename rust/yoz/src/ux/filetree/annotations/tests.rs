use super::*;
use crate::test_support::{TempDir, eventually, percentile};
use std::collections::BTreeMap;
use std::fs;
use std::time::Instant;

/// The result of a request, which may fail.
fn request<T: Clone>(value: Request<T>) -> Result<T> {
    eventually(|| value.poll())
}
fn create_state(tree: &Filetree, root: Root, display: DisplayOptions) -> StateHandle {
    let Outcome::State(state) = tree.create_state(Some(root), display).wait() else {
        panic!("state")
    };
    state
}

#[test]
fn t_diagnostics_replace_clear_and_reject_old_batches_without_loading_nodes() {
    let directory = TempDir::new();
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let state = create_state(
        &tree,
        Root::Forest(vec![tree.root()].into()),
        DisplayOptions::default(),
    );
    let frame = state.snapshot().unwrap();
    let source = tree.source();
    let path = directory.path().join("unloaded/deeper/file");
    request(tree.set_diagnostics(1, 7, 1, Some(path.clone()), [1, 2, 0, 0])).unwrap();
    request(tree.set_diagnostics(2, 7, 1, Some(path.clone()), [3, 0, 0, 0])).unwrap();
    let old = tree.annotations.lock().unwrap().clone();
    assert_eq!(
        request(tree.annotations(frame.clone(), 0, 1)).unwrap().rows[0].diagnostics,
        [4, 2, 0, 0]
    );
    request(tree.set_diagnostics(
        1,
        7,
        2,
        Some(directory.path().join("other/file")),
        [0, 0, 1, 0],
    ))
    .unwrap();
    assert_eq!(
        request(tree.annotations(frame.clone(), 0, 1)).unwrap().rows[0].diagnostics,
        [3, 0, 1, 0]
    );
    request(tree.set_diagnostics(2, 7, 2, None, [0; 4])).unwrap();
    assert_eq!(
        request(tree.set_diagnostics(2, 7, 1, Some(path), [5, 0, 0, 0]))
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert_eq!(tree.annotation_revision(), 4);
    assert_eq!(
        request(tree.annotations(frame, 0, 1)).unwrap().rows[0].diagnostics,
        [0, 0, 1, 0]
    );
    assert_eq!(
        old.lookup(&canonical_prefix(directory.path()), true)
            .diagnostics,
        [4, 2, 0, 0]
    );
    assert_eq!(tree.source().revision(), source.revision());
    assert_eq!(tree.source().len(), source.len());
}

#[test]
fn t_git_native_snapshots_and_visible_navigation_leave_source_and_frames_unchanged() {
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("sub")).unwrap();
    for file in ["a", "b", "sub/c"] {
        fs::write(directory.path().join(file), "content").unwrap();
    }
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let a = request(tree.resolve(directory.path().join("a")))
        .unwrap()
        .node;
    let b = request(tree.resolve(directory.path().join("b")))
        .unwrap()
        .node;
    request(tree.resolve(directory.path().join("sub/c"))).unwrap();
    let state = create_state(
        &tree,
        Root::ChildrenOf(tree.root()),
        DisplayOptions::default(),
    );
    let frame = state.snapshot().unwrap();
    let source_revision = tree.source().revision();
    let snapshot = Arc::new(git::Snapshot::new(
        BTreeMap::from([(
            git_path(&directory.path().join("sub/c")).unwrap(),
            git::Entry {
                relative: b"sub/c".to_vec(),
                unstaged: 4,
                ..git::Entry::default()
            },
        )]),
        None,
    ));
    request(tree.set_git(directory.path().to_path_buf(), 1, Some(snapshot), None)).unwrap();
    request(tree.set_diagnostics(1, 1, 1, Some(directory.path().join("a")), [1, 0, 0, 0])).unwrap();
    request(tree.set_diagnostics(1, 2, 1, Some(directory.path().join("b")), [0, 1, 0, 0])).unwrap();
    let ai = frame.position(a).unwrap();
    let bi = frame.position(b).unwrap();
    assert_eq!(
        request(tree.next_annotation(frame.clone(), Some(ai), AnnotationKind::Warning, true))
            .unwrap(),
        Some(bi)
    );
    assert_eq!(
        request(tree.next_annotation(frame.clone(), Some(bi), AnnotationKind::Error, true))
            .unwrap(),
        Some(ai)
    );
    let git = request(tree.next_annotation(frame.clone(), None, AnnotationKind::Git, true))
        .unwrap()
        .unwrap();
    assert_eq!(
        resource::entry(frame.source(), frame.row(git).unwrap().id)
            .unwrap()
            .name,
        "sub"
    );
    let rows = request(tree.annotations(frame.clone(), 0, frame.len())).unwrap();
    assert_eq!(rows.rows[git].git, 4);
    assert!(rows.rows[git].unstaged);
    request(tree.set_git(directory.path().to_path_buf(), 2, None, None)).unwrap();
    assert_eq!(
        request(tree.next_annotation(frame.clone(), None, AnnotationKind::Git, true)).unwrap(),
        None
    );
    assert_eq!(
        request(tree.set_git(directory.path().to_path_buf(), 1, None, None))
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert_eq!(tree.source().revision(), source_revision);
    assert_eq!(state.snapshot().unwrap().id, frame.id);
    let filtered = create_state(
        &tree,
        Root::ChildrenOf(tree.root()),
        DisplayOptions {
            pattern: "b".into(),
            ..DisplayOptions::default()
        },
    )
    .snapshot()
    .unwrap();
    assert_eq!(
        request(tree.next_annotation(filtered.clone(), None, AnnotationKind::Error, true)).unwrap(),
        None
    );
    let expected = filtered.position(b);
    assert_eq!(
        request(tree.next_annotation(filtered, None, AnnotationKind::Warning, false)).unwrap(),
        expected
    );
}

#[cfg(unix)]
#[test]
fn t_alias_annotations_share_physical_status_without_duplicate_directory_counts() {
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("real")).unwrap();
    fs::write(directory.path().join("real/file"), "content").unwrap();
    std::os::unix::fs::symlink("real", directory.path().join("alias")).unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let real = request(tree.resolve(directory.path().join("real"))).unwrap();
    let alias = request(tree.resolve(directory.path().join("alias"))).unwrap();
    let file = request(tree.resolve(directory.path().join("alias/file"))).unwrap();
    request(tree.set_diagnostics(
        1,
        9,
        1,
        Some(directory.path().join("real/file")),
        [2, 0, 0, 0],
    ))
    .unwrap();
    for node in [real.node, alias.node, file.node] {
        let state = create_state(
            &tree,
            Root::Forest(vec![node].into()),
            DisplayOptions::default(),
        );
        let rows = request(tree.annotations(state.snapshot().unwrap(), 0, 1)).unwrap();
        assert_eq!(rows.rows[0].diagnostics, [2, 0, 0, 0]);
    }
    let root = tree
        .annotations
        .lock()
        .unwrap()
        .lookup(&canonical_prefix(directory.path()), true);
    assert_eq!(root.diagnostics, [2, 0, 0, 0]);
    let state = create_state(
        &tree,
        Root::Forest(vec![tree.root()].into()),
        DisplayOptions::default(),
    );
    assert_eq!(
        request(tree.annotations(state.snapshot().unwrap(), 0, 1))
            .unwrap()
            .rows[0]
            .diagnostics,
        [4, 0, 0, 0]
    );
}

#[test]
fn t_native_git_retention_is_budgeted_before_queueing_and_shared_between_sources() {
    let directory = TempDir::new();
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let snapshot = Arc::new(git::Snapshot::new(
        (0..1000)
            .map(|index| {
                (
                    git_path(&directory.path().join(format!("nested/file-{index}"))).unwrap(),
                    git::Entry {
                        relative: format!("nested/file-{index}").into_bytes(),
                        unstaged: 4,
                        ..git::Entry::default()
                    },
                )
            })
            .collect(),
        None,
    ));
    let memory = tree.data().memory();
    let _guard = memory.enter();
    let before = memory.used();
    let pressure =
        Charge::new(tree.data().limits().memory_bytes - before - snapshot.retained_bytes() / 2);
    let rejected = tree.set_git(
        directory.path().to_path_buf(),
        1,
        Some(snapshot.clone()),
        None,
    );
    assert!(matches!(rejected.poll(), Some(Err(error)) if error.code == ErrorCode::ResourceLimit));
    assert_eq!(tree.annotation_revision(), 0);
    drop(pressure);
    assert_eq!(memory.used(), before);
    request(tree.set_git(
        directory.path().to_path_buf(),
        1,
        Some(snapshot.clone()),
        None,
    ))
    .unwrap();
    let first = memory.used();
    request(tree.set_git(
        directory.path().join("nested"),
        1,
        Some(snapshot.clone()),
        None,
    ))
    .unwrap();
    assert!(
        memory.used() - first < 4096,
        "a native snapshot allocation must be charged once"
    );
    request(tree.set_git(directory.path().to_path_buf(), 2, None, None)).unwrap();
    request(tree.set_git(directory.path().join("nested"), 2, None, None)).unwrap();
    assert!(memory.used() < before + snapshot.retained_bytes() / 10);
}

#[cfg(unix)]
#[test]
fn t_retained_frames_reject_retargeted_file_and_directory_aliases() {
    for directory_target in [false, true] {
        let directory = TempDir::new();
        let suffix = if directory_target { "/file" } else { "" };
        for name in ["a", "b"] {
            if directory_target {
                fs::create_dir(directory.path().join(name)).unwrap();
            }
            fs::write(directory.path().join(format!("{name}{suffix}")), "content").unwrap();
        }
        let alias = directory.path().join("alias");
        std::os::unix::fs::symlink("a", &alias).unwrap();
        let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
        let resource =
            request(tree.resolve(directory.path().join(format!("alias{suffix}")))).unwrap();
        let state = create_state(
            &tree,
            Root::Forest(vec![resource.node].into()),
            DisplayOptions::default(),
        );
        let frame = state.snapshot().unwrap();
        request(tree.set_diagnostics(
            1,
            1,
            1,
            Some(directory.path().join(format!("b{suffix}"))),
            [9, 0, 0, 0],
        ))
        .unwrap();
        assert_eq!(
            request(tree.annotations(frame.clone(), 0, 1)).unwrap().rows[0].diagnostics,
            [0; 4]
        );
        assert_eq!(
            request(tree.next_annotation(frame.clone(), None, AnnotationKind::Error, true))
                .unwrap(),
            None
        );
        fs::remove_file(&alias).unwrap();
        std::os::unix::fs::symlink("b", &alias).unwrap();
        assert_eq!(
            request(tree.annotations(frame.clone(), 0, 1))
                .err()
                .unwrap()
                .code,
            ErrorCode::Stale
        );
        assert_eq!(
            request(tree.next_annotation(frame.clone(), None, AnnotationKind::Error, true))
                .unwrap_err()
                .code,
            ErrorCode::Stale
        );
        assert_eq!(tree.annotation_revision(), 1);
        assert_eq!(state.snapshot().unwrap().id, frame.id);
    }
}

#[cfg(unix)]
#[test]
fn t_retained_alias_frame_rejects_replacement_of_its_target() {
    let directory = TempDir::new();
    let target = directory.path().join("target");
    fs::write(&target, "before").unwrap();
    std::os::unix::fs::symlink("target", directory.path().join("alias")).unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let alias = request(tree.resolve(directory.path().join("alias"))).unwrap();
    let state = create_state(
        &tree,
        Root::Forest(vec![alias.node].into()),
        DisplayOptions::default(),
    );
    let frame = state.snapshot().unwrap();
    request(tree.set_diagnostics(1, 1, 1, Some(target.clone()), [1, 0, 0, 0])).unwrap();
    assert_eq!(
        request(tree.annotations(frame.clone(), 0, 1)).unwrap().rows[0].diagnostics,
        [1, 0, 0, 0]
    );
    fs::rename(&target, directory.path().join("old-target")).unwrap();
    fs::write(&target, "after").unwrap();
    assert_eq!(
        request(tree.annotations(frame, 0, 1)).err().unwrap().code,
        ErrorCode::Stale
    );
}

#[cfg(unix)]
#[test]
fn t_unknown_alias_targets_do_not_hide_other_rows_and_deleted_links_are_stale() {
    let directory = TempDir::new();
    fs::write(directory.path().join("z-file"), "content").unwrap();
    std::os::unix::fs::symlink("a-loop", directory.path().join("a-loop")).unwrap();
    std::os::unix::fs::symlink("missing", directory.path().join("b-broken")).unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    for name in ["a-loop", "b-broken", "z-file"] {
        request(tree.resolve(directory.path().join(name))).unwrap();
    }
    let state = create_state(
        &tree,
        Root::ChildrenOf(tree.root()),
        DisplayOptions::default(),
    );
    let frame = state.snapshot().unwrap();
    request(tree.set_diagnostics(1, 1, 1, Some(directory.path().join("z-file")), [1, 0, 0, 0]))
        .unwrap();
    let rows = request(tree.annotations(frame.clone(), 0, frame.len())).unwrap();
    assert_eq!(
        rows.rows.iter().map(|row| row.diagnostics[0]).sum::<u64>(),
        1
    );
    assert_eq!(
        request(tree.next_annotation(frame.clone(), None, AnnotationKind::Error, true)).unwrap(),
        Some(frame.len() - 1)
    );
    fs::remove_file(directory.path().join("a-loop")).unwrap();
    assert_eq!(
        request(tree.annotations(frame, 0, 1)).err().unwrap().code,
        ErrorCode::Stale
    );
}

#[cfg(unix)]
#[test]
fn t_sparse_diagnostic_navigation_includes_differently_named_file_aliases() {
    let directory = TempDir::new();
    fs::create_dir(directory.path().join("sub")).unwrap();
    for index in 0..80 {
        fs::write(directory.path().join(format!("file-{index}")), "").unwrap();
    }
    fs::write(directory.path().join("target"), "content").unwrap();
    std::os::unix::fs::symlink("target", directory.path().join("alias")).unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let state = create_state(
        &tree,
        Root::ChildrenOf(tree.root()),
        DisplayOptions::default(),
    );
    let _view = state.attach().unwrap();
    let frame = eventually(|| {
        let frame = state.snapshot().unwrap();
        (frame.len() == 83).then_some(frame)
    });
    request(tree.set_diagnostics(1, 1, 1, Some(directory.path().join("target")), [1, 0, 0, 0]))
        .unwrap();
    assert!(tree.annotations.lock().unwrap().counts.len() < frame.len() / 4);
    let alias = frame
        .rows
        .iter()
        .position(|row| row.label.as_ref() == "alias")
        .unwrap();
    let target = frame
        .rows
        .iter()
        .position(|row| row.label.as_ref() == "target")
        .unwrap();
    assert_eq!(
        request(tree.next_annotation(frame.clone(), None, AnnotationKind::Error, true)).unwrap(),
        Some(alias)
    );
    assert_eq!(
        request(tree.next_annotation(frame.clone(), Some(alias), AnnotationKind::Error, true))
            .unwrap(),
        Some(target)
    );
    assert_eq!(
        request(tree.next_annotation(frame.clone(), Some(target), AnnotationKind::Error, false))
            .unwrap(),
        Some(alias)
    );
    let sub = frame
        .rows
        .iter()
        .position(|row| row.label.as_ref() == "sub")
        .unwrap();
    let status = Arc::new(git::Snapshot::new(
        ["target", "sub/unloaded"]
            .into_iter()
            .map(|name| {
                (
                    git_path(&directory.path().join(name)).unwrap(),
                    git::Entry {
                        relative: name.as_bytes().to_vec(),
                        unstaged: 4,
                        ..git::Entry::default()
                    },
                )
            })
            .collect(),
        None,
    ));
    request(tree.set_git(directory.path().to_path_buf(), 1, Some(status), None)).unwrap();
    assert_eq!(
        request(tree.next_annotation(frame.clone(), None, AnnotationKind::Git, true)).unwrap(),
        Some(sub)
    );
    assert_eq!(
        request(tree.next_annotation(frame.clone(), Some(sub), AnnotationKind::Git, true)).unwrap(),
        Some(alias)
    );
    let untracked = Arc::new(git::Snapshot::new(
        BTreeMap::from([(
            git_path(directory.path()).unwrap(),
            git::Entry {
                unstaged: 2,
                ..git::Entry::default()
            },
        )]),
        None,
    ));
    request(tree.set_git(directory.path().to_path_buf(), 2, Some(untracked), None)).unwrap();
    assert_eq!(
        request(tree.next_annotation(frame.clone(), Some(alias), AnnotationKind::Git, true))
            .unwrap(),
        Some(alias + 1)
    );
}

#[cfg(unix)]
#[test]
#[ignore = "explicit release-mode annotation scale measurement"]
fn t_annotations_wide_directory_with_loaded_aliases() {
    let directory = TempDir::new();
    fs::write(directory.path().join("file-49999"), "content").unwrap();
    let leaf = super::super::Entry::read(&directory.path().join("file-49999")).unwrap();
    let mut records: Vec<_> = (0..50_000)
        .map(|index| {
            let mut entry = leaf.clone();
            entry.name = format!("file-{index:05}").into();
            Record::new(format!("file-{index}"), entry.node_data())
        })
        .collect();
    for index in 0..128 {
        let path = directory.path().join(format!("alias-{index}"));
        std::os::unix::fs::symlink("file-49999", &path).unwrap();
        let entry = super::super::Entry::read(&path).unwrap();
        records.push(Record::new(format!("alias-{index}"), entry.node_data()));
    }
    let tree = request(Filetree::open(directory.path().to_path_buf())).unwrap();
    let reply = work::wait(tree.data().submit(Action::Import(Import {
        base_revision: tree.source().revision(),
        scope: DataScope::Children(tree.root()),
        records,
    })))
    .unwrap();
    assert!(matches!(reply, Reply::Applied { .. }));
    let state = create_state(
        &tree,
        Root::Forest(vec![tree.root()].into()),
        DisplayOptions::default(),
    );
    let frame = state.snapshot().unwrap();
    let mut times = Vec::new();
    for version in 1..=20 {
        request(tree.set_diagnostics(
            1,
            1,
            version,
            Some(directory.path().join("file-49999")),
            [1, 0, 0, 0],
        ))
        .unwrap();
        let start = Instant::now();
        let rows = request(tree.annotations(frame.clone(), 0, 1)).unwrap();
        assert_eq!(rows.rows[0].diagnostics, [129, 0, 0, 0]);
        times.push(start.elapsed().as_secs_f64() * 1000.0);
    }
    times.sort_by(f64::total_cmp);
    println!(
        "annotations synthetic 50k files + 128 real aliases, 20 samples: p50_ms={:.3} p95_ms={:.3} max_ms={:.3} retained={}",
        percentile(&times, 0.5),
        percentile(&times, 0.95),
        percentile(&times, 1.0),
        tree.data().memory().used()
    );
    let status = Arc::new(git::Snapshot::new(
        BTreeMap::from([(
            git_path(&directory.path().join("file-49999")).unwrap(),
            git::Entry {
                relative: b"file-49999".to_vec(),
                unstaged: 4,
                ..git::Entry::default()
            },
        )]),
        None,
    ));
    request(tree.set_git(directory.path().to_path_buf(), 1, Some(status), None)).unwrap();
    let state = create_state(
        &tree,
        Root::ChildrenOf(tree.root()),
        DisplayOptions::default(),
    );
    let frame = state.snapshot().unwrap();
    let expected = frame
        .rows
        .iter()
        .position(|row| row.label.as_ref() == "file-49999");
    times.clear();
    for _ in 0..20 {
        let start = Instant::now();
        assert_eq!(
            request(tree.next_annotation(frame.clone(), None, AnnotationKind::Git, true)).unwrap(),
            expected
        );
        times.push(start.elapsed().as_secs_f64() * 1000.0);
    }
    times.sort_by(f64::total_cmp);
    println!(
        "Git navigation 50k rows, 20 samples: p50_ms={:.3} p95_ms={:.3} max_ms={:.3}",
        percentile(&times, 0.5),
        percentile(&times, 0.95),
        percentile(&times, 1.0)
    );
}
