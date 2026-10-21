use super::super::*;
use crate::test_support::{TempDir, eventually};
use crate::ux::filetree::test_support::*;
use crate::ux::treeview::test_support::hold;
use std::fs;

#[test]
fn t_create_progress_counts_only_created_components() {
    let _operations = operations();
    let fixture = TempDir::new();
    fs::create_dir(fixture.path().join("existing")).unwrap();
    let tree = request(Filetree::open(fixture.path().to_path_buf()));
    let target = request(tree.resolve(fixture.path().to_path_buf()));
    let job = tree
        .start_create(CreatePlan {
            target,
            path: "existing/new/empty".into(),
            directory: false,
        })
        .unwrap();
    let results = done(&job);
    let status = job.status();
    assert_eq!(status.processed, 2);
    assert_eq!(results.len(), 2);
    assert_eq!(status.bytes, 0);
    assert_eq!(status.phase, JobPhase::Complete);
}

#[test]
fn t_create_reobserves_publication_conflicts_without_recreating_or_retargeting() {
    let _operations = operations();
    for race in ["sibling", "replacement", "parent"] {
        let directory = TempDir::new();
        let root = directory.path().join("parent");
        fs::create_dir(&root).unwrap();
        let sibling = root.join("sibling");
        let path = root.join("created");
        fs::write(&sibling, b"sibling").unwrap();
        let tree = request(Filetree::open(root.clone()));
        let target = tree.inspect(tree.source(), tree.root()).unwrap();
        let (gate, release) = hold(tree.data());
        let observed = tree.resolve(sibling);
        eventually(|| tree.data().queue_depth() >= 1);
        let job = tree
            .start_create(CreatePlan {
                target,
                path: "created".into(),
                directory: false,
            })
            .unwrap();
        eventually(|| tree.data().queue_depth() >= 2);
        let identity = Entry::read(&path).unwrap().identity;
        if race == "replacement" {
            fs::rename(&path, directory.path().join("original")).unwrap();
            fs::write(&path, b"replacement").unwrap();
        } else if race == "parent" {
            let original = directory.path().join("original-parent");
            fs::rename(&root, &original).unwrap();
            fs::create_dir(&root).unwrap();
            fs::hard_link(original.join("created"), &path).unwrap();
        }
        release.send(()).unwrap();
        work::wait(gate).unwrap();
        request(observed);
        let status = finished(&job);
        assert_eq!(status.results, 1);
        let results = job.results(0, 1).unwrap();
        assert_eq!(results[0].status, ItemStatus::Success);
        if race == "replacement" {
            assert_eq!(status.error.unwrap().code, ErrorCode::Stale);
            assert!(results[0].sync_error().is_some());
            assert_eq!(fs::read(&path).unwrap(), b"replacement");
            assert_eq!(
                Entry::read(&directory.path().join("original"))
                    .unwrap()
                    .identity,
                identity
            );
        } else if race == "parent" {
            assert!(status.error.is_some());
            assert!(results[0].sync_error().is_some());
            assert_eq!(Entry::read(&path).unwrap().identity, identity);
            assert_eq!(
                Entry::read(&directory.path().join("original-parent/created"))
                    .unwrap()
                    .identity,
                identity
            );
        } else {
            assert!(status.error.is_none(), "{:?}", status.error);
            assert!(results[0].sync_error().is_none());
            assert_eq!(Entry::read(&path).unwrap().identity, identity);
            assert_eq!(
                tree.inspect(tree.source(), results[0].node.unwrap())
                    .unwrap()
                    .entry()
                    .unwrap()
                    .identity,
                identity
            );
        }
    }
}

#[test]
fn t_create_parents_and_empty_file_preserves_existing_contents_on_collision() {
    let _operations = operations();
    let directory = TempDir::new();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let target = tree.inspect(tree.source(), tree.root()).unwrap();
    let plan = || CreatePlan {
        target: target.clone(),
        path: "notes/sub/file".into(),
        directory: false,
    };
    let job = tree.start_create(plan()).unwrap();
    let status = finished(&job);
    assert!(status.error.is_none(), "{:?}", status.error);
    assert_eq!(status.results, 3);
    assert!(
        job.results(0, 3)
            .unwrap()
            .iter()
            .all(|item| item.status == ItemStatus::Success && item.sync_error().is_none())
    );
    let path = directory.path().join("notes/sub/file");
    fs::write(&path, "keep").unwrap();
    let collided = tree.start_create(plan()).unwrap();
    assert!(finished(&collided).error.is_some());
    assert_eq!(fs::read_to_string(path).unwrap(), "keep");
    assert!(
        tree.start_create(CreatePlan {
            target,
            path: "../outside".into(),
            directory: false
        })
        .is_err()
    );
}

#[cfg(unix)]
#[test]
fn t_create_uses_default_permissions_with_process_umask() {
    let _operations = operations();
    use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};

    let directory = TempDir::new();
    let control_directory = directory.path().join("control-directory");
    fs::DirBuilder::new()
        .mode(0o755)
        .create(&control_directory)
        .unwrap();
    let control_file = directory.path().join("control-file");
    fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o666)
        .open(&control_file)
        .unwrap();
    let tree = request(Filetree::open(directory.path().to_path_buf()));
    let target = tree.inspect(tree.source(), tree.root()).unwrap();
    for (path, directory) in [("new/sub/file", false), ("empty-directory", true)] {
        let job = tree
            .start_create(CreatePlan {
                target: target.clone(),
                path: path.into(),
                directory,
            })
            .unwrap();
        let status = finished(&job);
        assert!(status.error.is_none(), "{:?}", status.error);
    }
    for (path, control) in [
        ("new", &control_directory),
        ("new/sub", &control_directory),
        ("empty-directory", &control_directory),
        ("new/sub/file", &control_file),
    ] {
        assert_eq!(
            fs::metadata(directory.path().join(path))
                .unwrap()
                .permissions()
                .mode()
                & 0o777,
            fs::metadata(control).unwrap().permissions().mode() & 0o777,
            "{path} must use the same defaults and umask as direct creation"
        );
    }
}

#[test]
fn t_create_rejects_replaced_destination_and_cancellation_keeps_published_parents() {
    let _operations = operations();
    let directory = TempDir::new();
    let base = directory.path().join("base");
    fs::create_dir(&base).unwrap();
    let tree = request(Filetree::open(base.clone()));
    let target = tree.inspect(tree.source(), tree.root()).unwrap();
    fs::rename(&base, directory.path().join("old")).unwrap();
    fs::create_dir(&base).unwrap();
    let stale = tree
        .start_create(CreatePlan {
            target,
            path: "file".into(),
            directory: false,
        })
        .unwrap();
    assert!(finished(&stale).error.is_some());
    assert!(!base.join("file").exists());
    let target = request(tree.resolve(base));
    let job = tree
        .start_create(CreatePlan {
            target,
            path: (0..64).map(|_| "p").collect(),
            directory: true,
        })
        .unwrap();
    eventually(|| {
        assert!(!job.status().terminal, "{:?}", job.status().error);
        job.status().results != 0
    });
    job.cancel();
    let status = finished(&job);
    assert!(status.cancelled);
    assert!(status.results > 0 && status.results < 64);
    for item in job.results(0, status.results).unwrap() {
        assert!(item.target().as_ref().unwrap().is_dir());
    }
}
