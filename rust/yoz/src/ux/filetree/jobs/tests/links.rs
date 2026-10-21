use super::super::*;
use crate::test_support::TempDir;
#[cfg(unix)]
use crate::test_support::eventually;
use crate::ux::filetree::test_support::*;
use std::fs;

#[cfg(unix)]
#[test]
fn t_move_captures_physical_paths_after_confirmation_without_following_final_links() {
    let _operations = operations();
    use std::os::unix::fs::symlink;
    let directory = TempDir::new();
    fs::create_dir_all(directory.path().join("actual-a/inner")).unwrap();
    fs::create_dir(directory.path().join("source")).unwrap();
    fs::write(directory.path().join("referent"), "keep").unwrap();
    symlink("../referent", directory.path().join("source/file")).unwrap();
    fs::write(directory.path().join("actual-a/inner/file"), "old").unwrap();
    symlink("actual-a", directory.path().join("route")).unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let job = tree
        .start_operation(plan(
            &tree,
            "source/file",
            Some("route/inner"),
            OperationKind::Move,
        ))
        .unwrap();
    eventually(|| job.status().confirmation.is_some());
    fs::rename(
        directory.path().join("actual-a"),
        directory.path().join("actual-b"),
    )
    .unwrap();
    fs::remove_file(directory.path().join("route")).unwrap();
    symlink("actual-b", directory.path().join("route")).unwrap();
    job.confirm(job.status().confirmation.unwrap().token, true)
        .unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Success);
    let source = results[0]
        .source_physical()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| results[0].source());
    assert_eq!(
        source,
        fs::canonicalize(directory.path().join("source"))
            .unwrap()
            .join("file")
    );
    let target = results[0]
        .target_physical()
        .map(Path::to_path_buf)
        .or_else(|| results[0].target())
        .unwrap();
    assert_eq!(
        target,
        fs::canonicalize(directory.path().join("actual-b/inner"))
            .unwrap()
            .join("file")
    );
    assert!(fs::symlink_metadata(target).unwrap().is_symlink());
    assert_eq!(
        fs::read_to_string(directory.path().join("referent")).unwrap(),
        "keep"
    );
}

#[cfg(unix)]
#[test]
fn t_job_links_are_copied_and_replaced_without_modifying_referents() {
    let _operations = operations();
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("a"), "new").unwrap();
    fs::write(dir.path().join("referent"), "unchanged").unwrap();
    symlink("../referent", dir.path().join("dst/a")).unwrap();
    symlink("missing-relative", dir.path().join("link")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let job = tree
        .start_operation(plan(&tree, "a", Some("dst"), OperationKind::Copy))
        .unwrap();
    eventually(|| job.status().confirmation.is_some());
    job.confirm(job.status().confirmation.unwrap().token, true)
        .unwrap();
    assert_eq!(done(&job)[0].status, ItemStatus::Success);
    assert_eq!(
        fs::read_to_string(dir.path().join("referent")).unwrap(),
        "unchanged"
    );
    assert!(
        !fs::symlink_metadata(dir.path().join("dst/a"))
            .unwrap()
            .is_symlink()
    );
    let job = tree
        .start_operation(plan(&tree, "link", Some("dst"), OperationKind::Copy))
        .unwrap();
    assert_eq!(done(&job)[0].status, ItemStatus::Success);
    assert_eq!(
        fs::read_link(dir.path().join("dst/link")).unwrap(),
        std::path::PathBuf::from("missing-relative")
    );
}

#[cfg(unix)]
#[test]
fn t_job_copy_unknown_link_keeps_incomplete_children_after_read_failure() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    std::os::unix::fs::symlink("loop", dir.path().join("loop")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
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
        results[0].sync_error().is_none(),
        "{:?}",
        results[0].sync_error()
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
    eventually(|| tree.source().node(copied).unwrap().load_state == LoadState::Error);
    let source = tree.source();
    let node = source.node(copied).unwrap();
    assert_eq!(node.completeness, Completeness::Unknown);
    assert_eq!(node.error.as_ref().unwrap().code, ErrorCode::ProviderError);
}

#[cfg(unix)]
#[test]
fn t_job_link_operations_ignore_refreshed_directory_referent() {
    let _operations = operations();
    for kind in [
        OperationKind::Copy,
        OperationKind::Move,
        OperationKind::Delete,
    ] {
        for prepared in [false, true] {
            let dir = TempDir::new();
            fs::create_dir(dir.path().join("dst")).unwrap();
            fs::create_dir(dir.path().join("referent")).unwrap();
            fs::write(dir.path().join("referent/content"), "old").unwrap();
            std::os::unix::fs::symlink(dir.path().join("referent"), dir.path().join("link"))
                .unwrap();
            let tree = request(Filetree::open(dir.path().to_path_buf()));
            let mut operation = plan(
                &tree,
                "link",
                (kind != OperationKind::Delete).then_some("dst"),
                kind,
            );
            let state = prepared.then(|| selection(&tree, &mut operation));
            let node = operation.nodes[0];
            let before = resource::entry(&operation.source, node).unwrap();
            fs::rename(dir.path().join("referent"), dir.path().join("previous")).unwrap();
            fs::create_dir(dir.path().join("referent")).unwrap();
            fs::write(dir.path().join("referent/content"), "new").unwrap();
            let refreshed = request(tree.resolve(dir.path().join("link")));
            let after = refreshed.entry().unwrap();
            assert_eq!(refreshed.node, node);
            assert_eq!(before.identity, after.identity);
            assert_eq!(before.link, after.link);
            assert_ne!(before.target, after.target);

            let results = done(&tree.start_operation(operation).unwrap());
            assert_eq!(results.len(), 1);
            assert_eq!(results[0].status, ItemStatus::Success);
            assert!(
                results[0].sync_error().is_none(),
                "{:?}",
                results[0].sync_error()
            );
            assert_eq!(
                fs::read_to_string(dir.path().join("referent/content")).unwrap(),
                "new"
            );
            assert_eq!(
                fs::read_to_string(dir.path().join("previous/content")).unwrap(),
                "old"
            );
            if kind == OperationKind::Delete {
                assert!(!tree.source().contains(node));
            } else {
                assert_eq!(
                    fs::read_link(dir.path().join("dst/link")).unwrap(),
                    dir.path().join("referent")
                );
                if kind == OperationKind::Move {
                    assert_eq!(
                        resource::path(&tree.source(), node).unwrap(),
                        dir.path().join("dst/link")
                    );
                } else {
                    assert_eq!(
                        fs::read_link(dir.path().join("link")).unwrap(),
                        dir.path().join("referent")
                    );
                }
            }
            if kind != OperationKind::Copy {
                assert!(fs::symlink_metadata(dir.path().join("link")).is_err());
            }
            if let Some(state) = state {
                assert!(!state.status().unwrap().locked);
            }
        }
    }
}

#[cfg(windows)]
#[test]
fn t_job_windows_directory_links_keep_intrinsic_type_and_referents() {
    let _operations = operations();
    use std::os::windows::fs::{FileTypeExt, symlink_dir};
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    symlink_dir("absent", dir.path().join("link")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let source = request(tree.resolve(dir.path().join("link")));
    let entry = source.entry().unwrap();
    let decoded = Entry::decode(&entry.encode()).unwrap();
    assert_eq!(
        super::super::io::Signature::entry(&decoded, false),
        super::super::io::Signature::read(&dir.path().join("link"), false).unwrap()
    );
    let results = done(
        &tree
            .start_operation(plan(&tree, "link", Some("dst"), OperationKind::Copy))
            .unwrap(),
    );
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        fs::symlink_metadata(dir.path().join("dst/link"))
            .unwrap()
            .file_type()
            .is_symlink_dir()
    );
    assert_eq!(
        fs::read_link(dir.path().join("dst/link")).unwrap(),
        std::path::PathBuf::from("absent")
    );
    fs::create_dir(dir.path().join("absent")).unwrap();
    fs::write(dir.path().join("absent/keep"), "referent").unwrap();
    for path in ["link", "dst/link"] {
        let results = done(
            &tree
                .start_operation(plan(&tree, path, None, OperationKind::Delete))
                .unwrap(),
        );
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(fs::symlink_metadata(dir.path().join(path)).is_err());
    }
    assert_eq!(
        fs::read_to_string(dir.path().join("absent/keep")).unwrap(),
        "referent"
    );
}

#[cfg(unix)]
#[test]
fn t_job_move_relative_link_to_unknown_target_ends_old_children() {
    let _operations = operations();
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("private/target")).unwrap();
    fs::create_dir_all(dir.path().join("dst/private/target")).unwrap();
    fs::write(dir.path().join("private/target/child"), "content").unwrap();
    std::os::unix::fs::symlink("private/target", dir.path().join("link")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(tree.resolve(dir.path().join("link/child")));
    let mut operation = plan(&tree, "link", Some("dst"), OperationKind::Move);
    let link = operation.nodes[0];
    selection(&tree, &mut operation);
    let _denied = DeniedDirectory::new(dir.path().join("dst/private"));
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error().is_none(),
        "{:?}",
        results[0].sync_error()
    );
    assert!(!tree.source().contains(old.node));
    let moved = resource::entry(&tree.source(), link).unwrap();
    assert!(moved.target_unknown);
    assert!(moved.target.is_none());
    assert!(dir.path().join("private/target/child").exists());
}

#[cfg(unix)]
#[test]
fn t_job_directory_move_reconciles_loaded_link_descendants() {
    let _operations = operations();
    use std::os::unix::fs::symlink;
    for prepared in [false, true] {
        let dir = TempDir::new();
        for path in [
            "src/inside",
            "external",
            "gone",
            "switch",
            "dst/switch",
            "dst",
        ] {
            fs::create_dir_all(dir.path().join(path)).unwrap();
        }
        for path in [
            "src/inside/keep",
            "external/keep",
            "gone/old",
            "switch/old",
            "dst/switch/new",
        ] {
            fs::write(dir.path().join(path), "content").unwrap();
        }
        symlink("inside", dir.path().join("src/internal")).unwrap();
        symlink("../../external", dir.path().join("src/inside/nested")).unwrap();
        symlink(
            dir.path().join("src/inside"),
            dir.path().join("src/absolute-internal"),
        )
        .unwrap();
        fs::create_dir_all(dir.path().join("src/unseen/deep")).unwrap();
        symlink(dir.path().join("external"), dir.path().join("src/absolute")).unwrap();
        symlink("../gone", dir.path().join("src/a-gone")).unwrap();
        symlink("../switch", dir.path().join("src/switched")).unwrap();
        symlink("../src/inside", dir.path().join("src/through-root-name")).unwrap();
        symlink("../appeared", dir.path().join("src/z-appeared")).unwrap();
        fs::create_dir(dir.path().join("dst/appeared")).unwrap();
        symlink(dir.path().join("dst"), dir.path().join("src/cycle")).unwrap();
        let tree = request(Filetree::open(dir.path().to_path_buf()));
        let internal = request(tree.resolve(dir.path().join("src/internal/keep")));
        let nested = request(tree.resolve(dir.path().join("src/internal/nested/keep")));
        let absolute_internal =
            request(tree.resolve(dir.path().join("src/absolute-internal/keep")));
        let absolute = request(tree.resolve(dir.path().join("src/absolute/keep")));
        let gone = request(tree.resolve(dir.path().join("src/a-gone/old")));
        let switched = request(tree.resolve(dir.path().join("src/switched/old")));
        let renamed = request(tree.resolve(dir.path().join("src/through-root-name/keep")));
        let cycle_child = request(tree.resolve(dir.path().join("src/cycle/appeared")));
        let appeared = request(tree.resolve(dir.path().join("src/z-appeared")));
        let before = tree.source();
        let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Move);
        let root = operation.nodes[0];
        if prepared {
            selection(&tree, &mut operation);
        }
        let results = done(&tree.start_operation(operation).unwrap());
        assert_eq!(results[0].status, ItemStatus::Success);
        assert!(
            results[0].sync_error().is_none(),
            "{:?}",
            results[0].sync_error()
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
            let observed = Entry::read(&dir.path().join("dst/src").join(name)).unwrap();
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
        assert!(dir.path().join("dst/src/unseen/deep").is_dir());
        assert_eq!(
            request(tree.resolve(dir.path().join("dst/src/internal/keep"))).node,
            internal.node
        );
        assert_eq!(
            request(tree.resolve(dir.path().join("dst/src/absolute/keep"))).node,
            absolute.node
        );
    }
}

#[cfg(unix)]
#[test]
fn t_job_directory_move_updates_cycle_boundaries_below_preserved_links() {
    let _operations = operations();
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("src")).unwrap();
    fs::create_dir_all(dir.path().join("external/sub")).unwrap();
    fs::write(dir.path().join("external/sub/keep"), "content").unwrap();
    symlink("external/sub", dir.path().join("destination")).unwrap();
    symlink(dir.path().join("external"), dir.path().join("src/alias")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(tree.resolve(dir.path().join("src/alias/sub/keep")));
    let folder = old.source.node(old.node).unwrap().parent.unwrap();
    let link = old.source.node(folder).unwrap().parent.unwrap();
    let mut operation = plan(&tree, "src", Some("destination"), OperationKind::Move);
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    assert!(!resource::entry(&tree.source(), link).unwrap().cycle);
    assert!(resource::entry(&tree.source(), folder).unwrap().cycle);
    assert!(!tree.source().contains(old.node));
    assert!(dir.path().join("external/sub/keep").exists());
    let outside = TempDir::new();
    let mut operation = plan(&tree, "destination/src", None, OperationKind::Delete);
    operation.kind = OperationKind::Move;
    operation.target = Some(request(tree.resolve(outside.path().to_path_buf())));
    selection(&tree, &mut operation);
    let result = done(&tree.start_operation(operation).unwrap());
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    assert!(!resource::entry(&tree.source(), folder).unwrap().cycle);
    assert!(tree.source().node(folder).unwrap().data.can_expand);
    assert_eq!(
        tree.source().node(folder).unwrap().completeness,
        Completeness::Unknown
    );
    assert_ne!(
        request(tree.resolve(outside.path().join("src/alias/sub/keep"))).node,
        old.node
    );
}

#[cfg(unix)]
#[test]
fn t_job_directory_move_does_not_inherit_old_unknown_link_targets() {
    let _operations = operations();
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = TempDir::new();
    for path in ["src", "private/target", "dst/private/target"] {
        fs::create_dir_all(dir.path().join(path)).unwrap();
    }
    fs::write(dir.path().join("private/target/child"), "content").unwrap();
    std::os::unix::fs::symlink("../private/target", dir.path().join("src/link")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(tree.resolve(dir.path().join("src/link/child")));
    let link = old.source.node(old.node).unwrap().parent.unwrap();
    let mut operation = plan(&tree, "src", Some("dst"), OperationKind::Move);
    selection(&tree, &mut operation);
    let _denied = DeniedDirectory::new(dir.path().join("dst/private"));
    let result = done(&tree.start_operation(operation).unwrap());
    assert_eq!(result[0].status, ItemStatus::Success);
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    let entry = resource::entry(&tree.source(), link).unwrap();
    assert!(entry.target_unknown);
    assert!(entry.target.is_none());
    assert!(!tree.source().contains(old.node));
}

#[cfg(unix)]
#[test]
fn t_job_moving_a_browsed_relative_link_retargets_its_children() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("real")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("real/keep"), "keep").unwrap();
    std::os::unix::fs::symlink("real", dir.path().join("link")).unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(tree.resolve(dir.path().join("link/keep")));
    let mut operation = plan(&tree, "link", Some("dst"), OperationKind::Move);
    let link = operation.nodes[0];
    selection(&tree, &mut operation);
    let results = done(&tree.start_operation(operation).unwrap());
    assert_eq!(results[0].status, ItemStatus::Success);
    assert!(
        results[0].sync_error().is_none(),
        "{:?}",
        results[0].sync_error()
    );
    assert!(!tree.source().contains(old.node));
    assert!(!tree.source().node(link).unwrap().data.can_expand);
    assert!(dir.path().join("real/keep").exists());
    assert_eq!(
        fs::read_link(dir.path().join("dst/link")).unwrap(),
        std::path::PathBuf::from("real")
    );
}
