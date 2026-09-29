use super::super::tests::{Directory, request};
use super::*;
use std::fs;

fn install(tree: &Filetree, path: &Path) -> Install {
    let (source, before) = {
        let index = tree.index.lock().unwrap_or_else(|error| error.into_inner());
        (tree.source(), index.clone())
    };
    Install {
        source,
        before,
        entries: observe(path).unwrap(),
        index: tree.index.clone(),
        resolved: Arc::new(Mutex::new(None)),
    }
}

#[cfg(unix)]
#[test]
fn t_delayed_resolve_preserves_children_after_target_aba() {
    for existing in [false, true] {
        let dir = Directory::new();
        let target = dir.0.join("target");
        let path = dir.0.join("link");
        fs::create_dir(&target).unwrap();
        if existing {
            fs::write(target.join("child"), b"old").unwrap();
        }
        std::os::unix::fs::symlink("target", &path).unwrap();
        let tree = request(Filetree::open(dir.0.clone()));
        let link = request(tree.resolve(path.clone()));
        let original = link.entry().unwrap();
        let initial = existing.then(|| request(tree.resolve(path.join("child"))));

        fs::rename(&target, dir.0.join("original")).unwrap();
        fs::create_dir(&target).unwrap();
        let delayed = install(&tree, &path);
        assert_ne!(delayed.entries.last().unwrap().target, original.target);
        let before = delayed.source.clone();
        fs::rename(&target, dir.0.join("observed")).unwrap();
        fs::rename(dir.0.join("original"), &target).unwrap();
        fs::write(target.join("child"), b"confirmed").unwrap();
        let child = request(tree.resolve(path.join("child")));
        let current = tree.source();
        assert_eq!(current.node(child.node).unwrap().parent, Some(link.node));
        assert_eq!(resource::entry(&current, link.node).unwrap(), original);
        if let Some(initial) = initial {
            assert_eq!(initial.node, child.node);
            assert_ne!(initial.entry().unwrap().size, child.entry().unwrap().size);
        }
        assert_eq!(
            before.node(link.node).unwrap().subtree_revision
                == current.node(link.node).unwrap().subtree_revision,
            existing
        );

        let error = wait(tree.data().submit(Action::Native(Box::new(delayed)))).unwrap_err();
        assert_eq!(error.code, ErrorCode::Stale);
        assert_eq!(tree.source().revision(), current.revision());
        assert!(tree.source().contains(child.node));
    }
}

#[test]
fn t_delayed_resolve_cannot_replace_a_new_occurrence() {
    for known in [false, true] {
        let dir = Directory::new();
        let path = dir.0.join("file");
        fs::write(&path, b"old").unwrap();
        let tree = request(Filetree::open(dir.0.clone()));
        if known {
            request(tree.resolve(path.clone()));
        }
        let delayed = install(&tree, &path);
        fs::rename(&path, dir.0.join("previous")).unwrap();
        fs::write(&path, b"new").unwrap();
        let current = request(tree.resolve(path));
        let Outcome::State(state) = tree.create_state(None, DisplayOptions::default()).wait()
        else {
            panic!("state");
        };
        wait(state.dispatch(
            Command::Select {
                targets: Targets::Nodes(vec![current.node].into()),
                action: SelectAction::Select,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        ))
        .unwrap();
        tree.data().events();
        let revision = tree.source().revision();
        let error = wait(tree.data().submit(Action::Native(Box::new(delayed)))).unwrap_err();
        assert_eq!(error.code, ErrorCode::Stale);
        assert_eq!(tree.source().revision(), revision);
        assert_eq!(
            resource::entry(&tree.source(), current.node)
                .unwrap()
                .identity,
            current.entry().unwrap().identity
        );
        assert!(!tree.data().events().iter().any(|event| {
            matches!(event, Effect::NodeInvalidated { nodes } if nodes.contains(&current.node))
        }));
        let Reply::Inspected { sources, .. } =
            wait(state.dispatch(Command::InspectSelection, Context::default())).unwrap()
        else {
            panic!("selection");
        };
        assert!(
            sources.self_only_nodes.contains(&current.node)
                || sources.subtree_roots.contains(&current.node)
        );
    }
}

#[test]
fn t_delayed_resolve_preserves_unrelated_updates() {
    let dir = Directory::new();
    fs::write(dir.0.join("a"), b"old").unwrap();
    fs::write(dir.0.join("b"), b"old").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let a = request(tree.resolve(dir.0.join("a"))).node;
    request(tree.resolve(dir.0.join("b")));
    fs::write(dir.0.join("a"), b"updated").unwrap();
    let delayed = install(&tree, &dir.0.join("a"));
    fs::rename(dir.0.join("b"), dir.0.join("previous-b")).unwrap();
    fs::write(dir.0.join("b"), b"replacement").unwrap();
    let b = request(tree.resolve(dir.0.join("b")));
    let parent = resource::entry(&tree.source(), tree.root()).unwrap();
    wait(tree.data().submit(Action::Native(Box::new(delayed)))).unwrap();
    assert_eq!(resource::entry(&tree.source(), a).unwrap().size, 7);
    assert_eq!(
        resource::entry(&tree.source(), b.node).unwrap().identity,
        b.entry().unwrap().identity
    );
    assert_eq!(
        resource::entry(&tree.source(), tree.root()).unwrap(),
        parent
    );
}

#[test]
fn t_delayed_resolve_coalesces_identical_observations_and_pins_its_source() {
    let dir = Directory::new();
    let path = dir.0.join("file");
    fs::write(&path, b"old").unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let delayed = install(&tree, &path);
    let resolved = delayed.resolved.clone();
    let current = request(tree.resolve(path.clone()));
    wait(tree.data().submit(Action::Native(Box::new(delayed)))).unwrap();
    let installed = resolved.lock().unwrap().clone().unwrap();
    assert_eq!(installed.node, current.node);
    assert_eq!(
        installed.entry().unwrap().identity,
        current.entry().unwrap().identity
    );

    fs::rename(&path, dir.0.join("previous")).unwrap();
    fs::write(&path, b"new").unwrap();
    let replacement = request(tree.resolve(path.clone()));
    assert_ne!(replacement.node, installed.node);
    assert!(!tree.source().contains(installed.node));
    assert_eq!(installed.path().unwrap(), path);
    assert_eq!(
        installed.entry().unwrap().identity,
        current.entry().unwrap().identity
    );
}

#[test]
fn t_delayed_resolve_cannot_restore_a_removed_occurrence() {
    for known in [false, true] {
        let dir = Directory::new();
        let path = dir.0.join("file");
        fs::write(&path, b"old").unwrap();
        let tree = request(Filetree::open(dir.0.clone()));
        if known {
            request(tree.resolve(path.clone()));
        }
        let delayed = install(&tree, &path);
        fs::rename(&path, dir.0.join("previous")).unwrap();
        fs::write(&path, b"new").unwrap();
        let current = request(tree.resolve(path.clone()));
        fs::remove_file(&path).unwrap();
        wait(
            tree.data()
                .submit(Action::RequestChildren(vec![tree.root()], true)),
        )
        .unwrap();
        let started = std::time::Instant::now();
        while tree.data().has_work() {
            assert!(started.elapsed() < std::time::Duration::from_secs(10));
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        assert!(!tree.source().contains(current.node));
        let revision = tree.source().revision();
        let error = wait(tree.data().submit(Action::Native(Box::new(delayed)))).unwrap_err();
        assert_eq!(error.code, ErrorCode::Stale);
        assert_eq!(tree.source().revision(), revision);
        let source = tree.source();
        assert!(
            source
                .node(tree.root())
                .unwrap()
                .children()
                .all(|id| { resource::entry(&source, id).unwrap().name != "file" })
        );
    }
}
