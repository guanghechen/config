use super::test_support::*;
use super::*;
use crate::test_support::{TempDir, eventually};
use crate::ux::treeview::*;
use std::fs;
use std::time::Duration;

#[test]
fn t_captured_resources_allow_metadata_loads_but_validate_the_entire_occurrence_chain() {
    let directory = TempDir::new();
    let mut root = Entry::read(directory.path()).unwrap();
    root.anchor = Some(directory.path().to_path_buf());
    let mut branch = root.clone();
    branch.anchor = None;
    branch.name = "branch".into();
    branch.identity.file += 1;
    let mut leaf = branch.clone();
    leaf.name = "leaf".into();
    leaf.kind = Kind::File;
    leaf.identity.file += 1;
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records: vec![
                Record {
                    key: "root".into(),
                    parent: None,
                    data: root.node_data(),
                    completeness: None,
                },
                Record {
                    key: "branch".into(),
                    parent: Some("root".into()),
                    data: branch.node_data(),
                    completeness: None,
                },
                Record {
                    key: "leaf".into(),
                    parent: Some("branch".into()),
                    data: leaf.node_data(),
                    completeness: None,
                },
            ],
        })
        .unwrap();
    let resource = Resource {
        source: engine.source().clone(),
        node: engine.source().id("leaf").unwrap(),
    };
    for key in ["leaf", "branch", "root"] {
        let id = engine.source().id(key).unwrap();
        for replacement in [false, true] {
            let mut changed = engine.clone();
            let mut entry = resource::entry(changed.source(), id).unwrap();
            entry.size += 10;
            entry.modified = Some(123);
            if replacement {
                entry.identity.file += 10;
            }
            changed
                .apply_batch(Batch {
                    base_revision: changed.source().revision(),
                    operations: vec![Operation::Update {
                        node: id.into(),
                        patch: NodePatch {
                            payload: Some(entry.node_data().payload),
                            completeness: Some(Completeness::Complete),
                            ..NodePatch::default()
                        },
                    }],
                })
                .unwrap();
            let result = resource.check_current(changed.source(), false);
            if replacement {
                assert_eq!(result.unwrap_err().code, ErrorCode::Stale, "{key}");
            } else {
                result.unwrap();
            }
        }
    }
    let root_id = engine.source().id("root").unwrap();
    let mut moved = engine.clone();
    moved
        .apply_batch(Batch {
            base_revision: moved.source().revision(),
            operations: vec![Operation::Reparent {
                node: resource.node.into(),
                parent: Some(root_id.into()),
                position: Position::Last,
            }],
        })
        .unwrap();
    assert_eq!(
        resource
            .check_current(moved.source(), false)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );

    let mut link = branch;
    link.kind = Kind::Link;
    link.link = Some("target".into());
    link.target = Some((Kind::Directory, root.identity));
    let branch_id = engine.source().id("branch").unwrap();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Update {
                node: branch_id.into(),
                patch: NodePatch {
                    payload: Some(link.node_data().payload),
                    ..NodePatch::default()
                },
            }],
        })
        .unwrap();
    let through_link = Resource {
        source: engine.source().clone(),
        node: resource.node,
    };
    let link_resource = Resource {
        source: engine.source().clone(),
        node: branch_id,
    };
    link.target.as_mut().unwrap().1.file += 100;
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Update {
                node: branch_id.into(),
                patch: NodePatch {
                    payload: Some(link.node_data().payload),
                    ..NodePatch::default()
                },
            }],
        })
        .unwrap();
    assert_eq!(
        through_link
            .check_current(engine.source(), false)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    link_resource.check_current(engine.source(), false).unwrap();
    assert_eq!(
        link_resource
            .check_current(engine.source(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
}

#[test]
fn t_insertion_positions_preserve_directory_order_and_exclude_the_moving_entry() {
    let directory = TempDir::new();
    let base = Entry::read(directory.path()).unwrap();
    let mut entries = Vec::new();
    for name in ["0", "a", "A", "aa", "Z", "z", "文"] {
        for kind in [Kind::File, Kind::Directory] {
            let mut entry = base.clone();
            entry.name = name.into();
            entry.kind = kind;
            entries.push(entry);
        }
    }
    entries.sort_by_key(Entry::sort_key);
    let mut candidates = entries.clone();
    for name in ["!", "文x"] {
        for kind in [Kind::File, Kind::Directory] {
            let mut entry = base.clone();
            entry.name = name.into();
            entry.kind = kind;
            candidates.push(entry);
        }
    }
    for count in [0, 1, entries.len()] {
        let mut engine = Engine::new(Limits::default()).unwrap();
        engine
            .apply_batch(Batch {
                base_revision: engine.source().revision(),
                operations: vec![Operation::Insert {
                    key: "root".into(),
                    parent: None,
                    position: Position::Last,
                    data: base.node_data(),
                    completeness: Completeness::Complete,
                }],
            })
            .unwrap();
        let parent = engine.source().id("root").unwrap();
        for (index, entry) in entries.iter().take(count).enumerate() {
            engine
                .apply_batch(Batch {
                    base_revision: engine.source().revision(),
                    operations: vec![Operation::Insert {
                        key: format!("child-{index}").into(),
                        parent: Some(parent.into()),
                        position: Position::Last,
                        data: entry.node_data(),
                        completeness: Completeness::Complete,
                    }],
                })
                .unwrap();
        }
        let source = engine.source();
        let children: Vec<_> = source.node(parent).unwrap().children().collect();
        for entry in &candidates {
            for excluded in std::iter::once(None).chain(children.iter().copied().map(Some)) {
                let expected = children
                    .iter()
                    .copied()
                    .zip(&entries)
                    .find(|(id, old)| Some(*id) != excluded && old.sort_key() >= entry.sort_key())
                    .map(|(id, _)| id);
                let actual =
                    match resource::position(source, Some(parent), entry, excluded).unwrap() {
                        Position::Last => None,
                        Position::Before(node) => Some(source.resolve(&node).unwrap()),
                        other => panic!("unexpected insertion position: {other:?}"),
                    };
                assert_eq!(
                    actual, expected,
                    "count={count}, name={:?}, kind={:?}, excluded={excluded:?}",
                    entry.name, entry.kind,
                );
            }
        }
    }
}

#[test]
fn t_resource_errors_classify_missing_paths_independently_of_the_message() {
    for (kind, code) in [
        (std::io::ErrorKind::NotFound, ErrorCode::NotFound),
        (std::io::ErrorKind::NotADirectory, ErrorCode::ProviderError),
        (
            std::io::ErrorKind::PermissionDenied,
            ErrorCode::ProviderError,
        ),
    ] {
        let error = resource::io_error("resolve", std::io::Error::new(kind, "arbitrary detail"));
        assert_eq!(error.code, code);
        assert!(error.message.contains("arbitrary detail"));
    }
    let error = resource::io_error(
        "copy",
        std::io::Error::other(Error::limit("staging capacity")),
    );
    assert_eq!(error.code, ErrorCode::ResourceLimit);
    assert!(error.message.contains("staging capacity"));
}

#[test]
fn t_bounded_directory_states_do_not_read_descendants_or_parent_siblings() {
    let directory = TempDir::new();
    fs::create_dir_all(directory.path().join("sub/nested")).unwrap();
    fs::write(directory.path().join("sub/nested/deep.txt"), b"deep").unwrap();
    fs::write(directory.path().join("visible.txt"), b"visible").unwrap();
    let data = request(Filetree::open(directory.path().to_path_buf()));
    let Outcome::State(state) = ticket(data.create_state(
        None,
        DisplayOptions {
            mode: Mode::List,
            list_depth: Some(0),
            context_label: Some("../".into()),
            ..DisplayOptions::default()
        },
    )) else {
        panic!("expected bounded state")
    };
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    eventually(|| !data.data().has_work());
    let sub = child(&data, data.root(), "sub");
    let source = data.source();
    assert_eq!(
        source.node(sub).unwrap().completeness,
        Completeness::Unknown
    );
    assert_eq!(source.node(sub).unwrap().child_count(), 0);
    let parent = source.node(data.root()).unwrap().parent.unwrap();
    assert_ne!(
        source.node(parent).unwrap().completeness,
        Completeness::Complete
    );
    eventually(|| state.snapshot().is_ok_and(|frame| frame.len() == 3));
    let frame = state.snapshot().unwrap();
    let listing = request(data.listing(frame.clone(), 0, frame.len(), false));
    assert_eq!(listing.rows.len(), 3);
    assert_eq!(listing.rows[0].node, data.root());
    assert_eq!(listing.rows[2].size, "7B");
    let Outcome::State(preview) = ticket(data.create_state(
        Some(Root::ChildrenOf(sub)),
        DisplayOptions {
            mode: Mode::List,
            list_depth: Some(0),
            ..DisplayOptions::default()
        },
    )) else {
        panic!("expected bounded preview")
    };
    let _preview = preview.attach().unwrap();
    loaded(&data, sub);
    eventually(|| !data.data().has_work());
    let nested = child(&data, sub, "nested");
    assert_eq!(
        data.source().node(nested).unwrap().completeness,
        Completeness::Unknown
    );
}

#[test]
#[cfg(unix)]
fn t_listing_parent_context_uses_captured_metadata_without_changing_row_identity() {
    use std::os::unix::fs::PermissionsExt;
    let directory = TempDir::new();
    let parent = directory.path().join("parent");
    let current = parent.join("current");
    fs::create_dir_all(&current).unwrap();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o755)).unwrap();
    fs::set_permissions(&current, fs::Permissions::from_mode(0o700)).unwrap();
    let data = request(Filetree::open(current));
    let Outcome::State(state) = ticket(data.create_state(
        None,
        DisplayOptions {
            mode: Mode::List,
            list_depth: Some(0),
            context_label: Some("../".into()),
            ..DisplayOptions::default()
        },
    )) else {
        panic!("expected state")
    };
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    eventually(|| state.snapshot().is_ok_and(|frame| frame.len() == 1));
    let frame = state.snapshot().unwrap();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o700)).unwrap();
    let own = request(data.listing(frame.clone(), 0, 1, false));
    let context = request(data.listing(frame, 0, 1, true));
    assert_eq!(own.rows[0].permissions, "drwx------");
    assert_eq!(context.rows[0].permissions, "drwxr-xr-x");
    assert_eq!(own.rows[0].node, context.rows[0].node);
    assert_eq!(context.rows[0].node, data.root());
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_private_copy_output_stays_out_of_browse_refresh_watch_and_alias_resolution() {
    use std::ffi::OsStr;
    use std::os::unix::fs::{PermissionsExt, symlink};
    use std::sync::atomic::AtomicBool;

    let fixture = TempDir::new();
    let source = fixture.path().join("seed");
    fs::write(&source, "contents").unwrap();
    fs::create_dir(fixture.path().join(".yoz-filetree-user.tmp")).unwrap();
    let tree = request(Filetree::open(fixture.path().to_path_buf()));
    let state = state(&tree, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&tree, tree.root());
    watching(&tree, tree.root());

    let target = io::Destination {
        path: fixture.path().join("target"),
        parent: io::Signature::read(fixture.path(), true).unwrap(),
        expected: None,
    };
    let mut staged = io::staging::Staging::new(
        &target,
        fs::Permissions::from_mode(0o755),
        super::memory::Memory::new(tree.data().memory()),
    )
    .unwrap();
    let nested = staged
        .create_directory(0, OsStr::new("nested"), fs::Permissions::from_mode(0o755))
        .unwrap();
    staged
        .copy(
            &mut io::Copier::default(),
            &source,
            &io::Signature::read(&source, false).unwrap(),
            nested,
            OsStr::new("file"),
            &AtomicBool::new(false),
            |_| {},
        )
        .unwrap();
    let private = fs::read_dir(fixture.path())
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .find(|path| io::staging::private_directory(Entry::read(path).unwrap().identity))
        .unwrap();
    symlink(&private, fixture.path().join("alias")).unwrap();
    symlink(private.join("nested"), fixture.path().join("nested-alias")).unwrap();
    ticket(
        tree.data()
            .submit(Action::RequestChildren(vec![tree.root()], true)),
    );
    loaded(&tree, tree.root());
    let names = || {
        let source = tree.source();
        source
            .node(tree.root())
            .unwrap()
            .children()
            .map(|node| resource::entry(&source, node).unwrap().name)
            .collect::<Vec<_>>()
    };
    assert!(names().contains(&".yoz-filetree-user.tmp".into()));
    assert!(!names().contains(&private.file_name().unwrap().to_owned()));
    assert!(!names().contains(&"target".into()));
    for path in [
        private.clone(),
        private.join("nested/file"),
        fixture.path().join("alias/nested/file"),
        fixture.path().join("nested-alias/file"),
    ] {
        let resolving = tree.resolve(path);
        eventually(|| resolving.poll().is_some());
        assert!(
            matches!(resolving.poll().unwrap(), Err(error) if error.code == ErrorCode::NotFound)
        );
    }
    let alias = request(tree.resolve(fixture.path().join("nested-alias")));
    ticket(
        tree.data()
            .submit(Action::RequestChildren(vec![alias.node], true)),
    );
    eventually(|| tree.source().node(alias.node).unwrap().error.is_some());
    assert_eq!(tree.source().node(alias.node).unwrap().child_count(), 0);

    staged.publish(&target).unwrap();
    eventually(|| names().contains(&"target".into()));
    assert!(!names().contains(&private.file_name().unwrap().to_owned()));
    let copied = request(tree.resolve(target.path.join("nested/file")));
    assert_eq!(copied.entry().unwrap().kind, Kind::File);
    assert_eq!(fs::read(copied.path().unwrap()).unwrap(), b"contents");
}

#[test]
fn t_ancestor_refresh_releases_saturated_reads_and_preserves_explicit_requests() {
    struct RefreshOverRequests {
        root: NodeId,
        children: Vec<NodeId>,
    }
    impl NativeAction for RefreshOverRequests {
        fn bytes(&self) -> usize {
            self.children.len() * 8 + 8
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            let mut effects = Vec::new();
            for node in self.children {
                effects.extend(engine.request_children(&[node], false)?.into_effects());
            }
            assert_eq!(engine.reads.len(), engine.limits.concurrent_reads);
            effects.extend(engine.request_children(&[self.root], true)?.into_effects());
            Ok(engine.applied(None, effects))
        }
    }

    let directory = TempDir::new();
    for index in 0..6 {
        fs::create_dir(directory.path().join(format!("child-{index}"))).unwrap();
    }
    let data = request(Filetree::open(directory.path().to_path_buf()));
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![data.root()], true)),
    );
    loaded(&data, data.root());
    let children: Vec<_> = data
        .source()
        .node(data.root())
        .unwrap()
        .children()
        .collect();
    ticket(
        data.data()
            .submit(Action::Native(Box::new(RefreshOverRequests {
                root: data.root(),
                children: children.clone(),
            }))),
    );
    for node in children {
        loaded(&data, node);
    }
    loaded(&data, data.root());
    eventually(|| !data.data().has_work());
}

#[cfg(unix)]
#[test]
fn t_resolve_reorders_links_when_directory_targets_appear_and_disappear() {
    let dir = TempDir::new();
    let workspace = dir.path().join("workspace");
    fs::create_dir(&workspace).unwrap();
    fs::write(workspace.join("a"), b"content").unwrap();
    std::os::unix::fs::symlink("../target", workspace.join("zlink")).unwrap();
    let data = request(Filetree::open(workspace.clone()));
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![data.root()], true)),
    );
    loaded(&data, data.root());
    let link = child(&data, data.root(), "zlink");
    let names = || {
        let source = data.source();
        source
            .node(data.root())
            .unwrap()
            .children()
            .map(|id| source.node(id).unwrap().data.label.to_string())
            .collect::<Vec<_>>()
    };
    assert_eq!(names(), ["a", "zlink"]);
    for directory in [true, false] {
        if directory {
            fs::create_dir(dir.path().join("target")).unwrap();
        } else {
            fs::remove_dir(dir.path().join("target")).unwrap();
        }
        let resolved = request(data.resolve(workspace.join("zlink")));
        assert_eq!(resolved.node, link);
        assert_eq!(resolved.entry().unwrap().directory(), directory);
        let expected = if directory {
            ["zlink", "a"]
        } else {
            ["a", "zlink"]
        };
        assert_eq!(names(), expected);
        ticket(
            data.data()
                .submit(Action::RequestChildren(vec![data.root()], true)),
        );
        loaded(&data, data.root());
        assert_eq!(names(), expected);
    }
}

#[cfg(unix)]
#[test]
fn t_failed_link_read_reorders_siblings_after_target_disappears() {
    let dir = TempDir::new();
    let workspace = dir.path().join("workspace");
    fs::create_dir(&workspace).unwrap();
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(workspace.join("a"), b"content").unwrap();
    std::os::unix::fs::symlink("../target", workspace.join("zlink")).unwrap();
    let data = request(Filetree::open(workspace));
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![data.root()], true)),
    );
    loaded(&data, data.root());
    let link = child(&data, data.root(), "zlink");
    let names = || {
        let source = data.source();
        source
            .node(data.root())
            .unwrap()
            .children()
            .map(|id| source.node(id).unwrap().data.label.to_string())
            .collect::<Vec<_>>()
    };
    assert_eq!(names(), ["zlink", "a"]);
    fs::remove_dir(dir.path().join("target")).unwrap();
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![link], true)),
    );
    loaded(&data, link);
    assert!(!resource::entry(&data.source(), link).unwrap().directory());
    assert_eq!(names(), ["a", "zlink"]);
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![data.root()], true)),
    );
    loaded(&data, data.root());
    assert_eq!(names(), ["a", "zlink"]);
}

#[cfg(unix)]
#[test]
fn t_resolve_retargeted_link_replaces_child_on_first_attempt() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(dir.path().join("target/child"), "content").unwrap();
    std::os::unix::fs::symlink("target", dir.path().join("link")).unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let old = request(data.resolve(dir.path().join("link/child")));
    let link = old.source.node(old.node).unwrap().parent.unwrap();
    fs::rename(dir.path().join("target"), dir.path().join("previous")).unwrap();
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::rename(
        dir.path().join("previous/child"),
        dir.path().join("target/child"),
    )
    .unwrap();
    let new = request(data.resolve(dir.path().join("link/child")));
    assert_ne!(new.node, old.node);
    assert_eq!(new.entry().unwrap().identity, old.entry().unwrap().identity);
    assert_eq!(new.source.node(new.node).unwrap().parent, Some(link));
    assert!(!new.source.contains(old.node));
    assert!(old.source.contains(old.node));
    assert_eq!(
        request(data.resolve(dir.path().join("link/child"))).node,
        new.node
    );
}

#[cfg(unix)]
#[test]
fn t_link_target_permission_failure_preserves_children_and_selection() {
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    for mode in ["read", "resolve", "scan"]
        .into_iter()
        .chain(cfg!(any(target_os = "macos", target_os = "linux")).then_some("watch"))
    {
        let dir = TempDir::new();
        fs::create_dir_all(dir.path().join("private/target")).unwrap();
        fs::write(dir.path().join("private/target/child"), "content").unwrap();
        std::os::unix::fs::symlink("private/target", dir.path().join("link")).unwrap();
        let data = request(Filetree::open(dir.path().join("link")));
        let state = state(&data, Mode::Tree);
        let _view = (mode == "watch").then(|| state.attach().unwrap());
        ticket(
            data.data()
                .submit(Action::RequestChildren(vec![data.root()], true)),
        );
        loaded(&data, data.root());
        if mode == "watch" {
            watching(&data, data.root());
        }
        let old = child(&data, data.root(), "child");
        let before = data.source();
        ticket(state.dispatch(
            Command::Select {
                targets: Targets::Nodes(vec![old].into()),
                action: SelectAction::Select,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        ));
        let denied = DeniedDirectory::new(dir.path().join("private"));
        assert!(
            Entry::read(&dir.path().join("link"))
                .unwrap()
                .target_unknown
        );
        match mode {
            "resolve" => {
                request(data.resolve(dir.path().join("link")));
            }
            "scan" => {
                let parent = data.source().node(data.root()).unwrap().parent.unwrap();
                ticket(
                    data.data()
                        .submit(Action::RequestChildren(vec![parent], true)),
                );
                loaded(&data, parent);
            }
            _ => {}
        }
        if mode == "resolve" || mode == "scan" {
            assert!(data.source().contains(old));
            assert_ne!(
                data.source().node(data.root()).unwrap().completeness,
                Completeness::Complete
            );
        }
        if mode != "watch" {
            ticket(
                data.data()
                    .submit(Action::RequestChildren(vec![data.root()], true)),
            );
        }
        eventually(|| {
            let source = data.source();
            let root = source.node(data.root()).unwrap();
            root.load_state == LoadState::Error && !data.data().has_work()
        });
        let failed = data.source();
        assert!(failed.contains(old), "unknown target removed a known child");
        let root = failed.node(data.root()).unwrap();
        assert_eq!(root.load_state, LoadState::Error);
        assert_ne!(root.completeness, Completeness::Complete);
        assert_eq!(
            resource::entry(&failed, data.root()).unwrap().target,
            resource::entry(&before, data.root()).unwrap().target
        );
        assert!(
            !data
                .data()
                .events()
                .iter()
                .any(|event| matches!(event, Effect::RootUnavailable { .. }))
        );
        drop(denied);
        if mode == "watch" {
            eventually(|| data.source().node(data.root()).unwrap().error.is_none());
            watching(&data, data.root());
        } else {
            ticket(data.refresh(&state).unwrap());
            loaded(&data, data.root());
        }
        assert_eq!(child(&data, data.root(), "child"), old);
        let Outcome::Reply(Reply::Inspected { sources, .. }) =
            ticket(state.dispatch(Command::InspectSelection, Context::default()))
        else {
            panic!("selection");
        };
        assert!(sources.subtree_roots.contains(&old));
        assert!(before.contains(old));
    }
}

#[test]
#[cfg(unix)]
fn t_parent_components_preserve_final_symlink_in_open_and_resolve() {
    use std::os::unix::fs::symlink;
    use std::path::PathBuf;
    let dir = TempDir::new();
    let base = fs::canonicalize(dir.path()).unwrap();
    fs::create_dir_all(base.join("real/nested")).unwrap();
    fs::create_dir(base.join("real/target")).unwrap();
    symlink("real/nested", base.join("jump")).unwrap();
    symlink("target", base.join("real/link")).unwrap();
    let path = base.join("jump/../link");
    let opened = request(Filetree::open(path.clone()));
    let resource = opened.inspect(opened.source(), opened.root()).unwrap();
    assert_eq!(resource.entry().unwrap().kind, Kind::Link);
    assert_eq!(resource.path().unwrap(), base.join("real/link"));
    let data = request(Filetree::open(base.clone()));
    let resolved = request(data.resolve(path));
    assert_eq!(resolved.entry().unwrap().kind, Kind::Link);
    assert_eq!(
        resolved.entry().unwrap().link,
        Some(PathBuf::from("target"))
    );
    assert_eq!(resolved.path().unwrap(), base.join("real/link"));
    assert_eq!(
        request(data.resolve(base.join("real/link"))).node,
        resolved.node
    );
    assert_ne!(
        request(data.resolve(base.join("real/target"))).node,
        resolved.node
    );
}

#[test]
fn t_open_loads_only_ancestors_then_direct_children_in_raw_name_order() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("sub/deep"), b"x").unwrap();
    for name in ["b", "A2", "a1", "z\nline", ".hidden"] {
        fs::write(dir.path().join(name), b"x").unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 0);
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let source = data.source();
    let names: Vec<_> = source
        .node(data.root())
        .unwrap()
        .children()
        .map(|id| source.node(id).unwrap().data.label.to_string())
        .collect();
    assert_eq!(names, ["sub", ".hidden", "a1", "A2", "b", "z\\nline"]);
    let sub = child(&data, data.root(), "sub");
    assert_eq!(
        source.node(sub).unwrap().completeness,
        Completeness::Unknown
    );
    assert_eq!(source.node(sub).unwrap().child_count(), 0);
    let deep = request(data.resolve(dir.path().join("sub/deep")));
    assert_eq!(deep.path().unwrap(), dir.path().join("sub/deep"));
    assert_eq!(
        data.source().node(sub).unwrap().completeness,
        Completeness::Unknown
    );
}

#[test]
fn t_refresh_preserves_metadata_identity_and_rename_but_replaces_new_resources() {
    let dir = TempDir::new();
    fs::write(dir.path().join("a"), b"a").unwrap();
    fs::write(dir.path().join("gone"), b"gone").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let old = data.source();
    let a = child(&data, data.root(), "a");
    let gone = child(&data, data.root(), "gone");
    fs::write(dir.path().join("a"), b"different-size").unwrap();
    fs::remove_file(dir.path().join("gone")).unwrap();
    fs::rename(dir.path().join("a"), dir.path().join("renamed")).unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| data.source().node(gone).is_none());
    loaded(&data, data.root());
    assert_eq!(child(&data, data.root(), "renamed"), a);
    assert_eq!(resource::path(&old, a).unwrap(), dir.path().join("a"));
    assert_eq!(
        resource::path(&data.source(), a).unwrap(),
        dir.path().join("renamed")
    );
    fs::write(dir.path().join("replacement"), b"new").unwrap();
    fs::rename(dir.path().join("replacement"), dir.path().join("renamed")).unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| data.source().node(a).is_none());
    loaded(&data, data.root());
    assert_ne!(child(&data, data.root(), "renamed"), a);
}

#[cfg(unix)]
#[test]
fn t_list_keeps_aliases_and_stops_ancestor_symlink_cycles() {
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("sub")).unwrap();
    fs::write(dir.path().join("sub/file"), b"x").unwrap();
    symlink("sub", dir.path().join("alias")).unwrap();
    symlink("..", dir.path().join("sub/cycle")).unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let sub = child(&data, data.root(), "sub");
    let alias = child(&data, data.root(), "alias");
    loaded(&data, sub);
    loaded(&data, alias);
    assert_ne!(child(&data, sub, "file"), child(&data, alias, "file"));
    for parent in [sub, alias] {
        let cycle = child(&data, parent, "cycle");
        let source = data.source();
        assert!(resource::entry(&source, cycle).unwrap().cycle);
        assert!(!source.node(cycle).unwrap().data.can_expand);
    }
}

#[test]
fn t_native_pages_wait_for_publication_ack_and_preserve_complete_order() {
    let dir = TempDir::new();
    for i in 0..1300 {
        fs::write(dir.path().join(format!("file-{i:04}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    data.data()
        .acknowledge_publication(data.source().revision());
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    eventually(|| data.source().node(data.root()).unwrap().child_count() > 0);
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 512);
    std::thread::sleep(Duration::from_millis(35));
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 512);
    eventually(|| {
        data.data()
            .acknowledge_publication(data.source().revision());
        let source = data.source();
        let node = source.node(data.root()).unwrap();
        assert!(node.error.is_none(), "{:?}", node.error);
        node.completeness == Completeness::Complete
    });
    let source = data.source();
    let names: Vec<_> = source
        .node(data.root())
        .unwrap()
        .children()
        .map(|id| source.node(id).unwrap().data.label.to_string())
        .collect();
    assert_eq!(
        names,
        (0..1300)
            .map(|i| format!("file-{i:04}"))
            .collect::<Vec<_>>()
    );
    assert!(data.data().events().iter().all(|effect| !matches!(
        effect,
        Effect::NeedChildren { .. } | Effect::CancelChildren { .. }
    )));
}

#[cfg(any(target_os = "macos", windows))]
#[test]
fn t_resolve_case_alias_reuses_actual_directory_entry_and_keeps_sort_order() {
    let dir = TempDir::new();
    fs::write(dir.path().join("Original"), b"x").unwrap();
    fs::write(dir.path().join("z-last"), b"x").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let original = child(&data, data.root(), "Original");
    if dir.path().join("original").exists() {
        let resolved = request(data.resolve(dir.path().join("original")));
        assert_eq!(resolved.node, original);
        assert_eq!(resolved.path().unwrap(), dir.path().join("Original"));
        assert_eq!(data.source().node(data.root()).unwrap().child_count(), 2);
    }
    fs::write(dir.path().join("a-first"), b"x").unwrap();
    let first = request(data.resolve(dir.path().join("a-first")));
    assert_eq!(
        data.source().node(data.root()).unwrap().child_at(0),
        Some(first.node)
    );
}

#[test]
fn t_replaced_entry_root_is_unavailable_and_never_rebinds_old_state() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("root")).unwrap();
    fs::write(dir.path().join("root/old"), b"x").unwrap();
    let data = request(Filetree::open(dir.path().join("root")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let old = data.source();
    fs::rename(dir.path().join("root"), dir.path().join("previous")).unwrap();
    fs::create_dir(dir.path().join("root")).unwrap();
    fs::write(dir.path().join("root/new"), b"x").unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| !data.source().contains(data.root()));
    eventually(|| state.snapshot().unwrap().is_empty());
    assert!(old.contains(data.root()));
    assert!(data.data().events().iter().any(
        |event| matches!(event, Effect::RootUnavailable { node, .. } if *node == data.root())
    ));
    let current = request(data.resolve(dir.path().join("root")));
    assert_ne!(current.node, data.root());
    assert!(state.snapshot().unwrap().is_empty());
}

#[cfg(unix)]
#[test]
fn t_hardlink_ambiguity_ends_old_occurrence_and_native_names_remain_lossless() {
    #[cfg(not(target_os = "macos"))]
    use std::os::unix::ffi::OsStringExt;
    let dir = TempDir::new();
    fs::write(dir.path().join("a"), b"x").unwrap();
    fs::hard_link(dir.path().join("a"), dir.path().join("b")).unwrap();
    #[cfg(not(target_os = "macos"))]
    let name = std::ffi::OsString::from_vec(vec![b'c', 0xff, b'\n']);
    #[cfg(target_os = "macos")]
    let name = std::ffi::OsString::from("c文\n");
    fs::write(dir.path().join(&name), b"x").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let a = child(&data, data.root(), "a");
    let b = child(&data, data.root(), "b");
    let raw = request(data.resolve(dir.path().join(&name)));
    assert_eq!(raw.path().unwrap(), dir.path().join(&name));
    assert_eq!(
        raw.source.node(raw.node).unwrap().data.label.as_ref(),
        display_name(&name)
    );
    fs::rename(dir.path().join("a"), dir.path().join("renamed")).unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| !data.source().contains(a));
    loaded(&data, data.root());
    assert_ne!(child(&data, data.root(), "renamed"), a);
    assert_eq!(child(&data, data.root(), "b"), b);
}

#[test]
fn t_detach_retires_a_paused_native_read_without_another_page() {
    let dir = TempDir::new();
    for i in 0..800 {
        fs::write(dir.path().join(format!("file-{i}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    data.data()
        .acknowledge_publication(data.source().revision());
    let state = state(&data, Mode::Tree);
    let view = state.attach().unwrap();
    eventually(|| data.source().node(data.root()).unwrap().child_count() == 512);
    drop(view);
    eventually(|| data.source().node(data.root()).unwrap().load_state == LoadState::Idle);
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 512);
    assert_eq!(
        data.source().node(data.root()).unwrap().completeness,
        Completeness::Partial
    );
}

#[test]
fn t_refresh_preserves_unambiguous_rename_when_original_name_is_recreated() {
    let dir = TempDir::new();
    fs::write(dir.path().join("a"), b"old").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let a = child(&data, data.root(), "a");
    fs::rename(dir.path().join("a"), dir.path().join("z")).unwrap();
    fs::write(dir.path().join("a"), b"new").unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| data.source().node(data.root()).unwrap().child_count() == 2);
    loaded(&data, data.root());
    assert_eq!(child(&data, data.root(), "z"), a);
    assert_ne!(child(&data, data.root(), "a"), a);
    assert_eq!(request(data.resolve(dir.path().join("z"))).node, a);
}

#[cfg(unix)]
#[test]
fn t_directory_symlink_target_replacement_keeps_link_but_ends_old_children() {
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(dir.path().join("target/old"), b"x").unwrap();
    symlink("target", dir.path().join("alias")).unwrap();
    let data = request(Filetree::open(dir.path().join("alias")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let old = child(&data, data.root(), "old");
    fs::rename(dir.path().join("target"), dir.path().join("previous")).unwrap();
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(dir.path().join("target/new"), b"new").unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| {
        !data.source().contains(old) || data.source().node(data.root()).unwrap().error.is_some()
    });
    assert!(
        !data.source().contains(old),
        "old target children survived replacement"
    );
    loaded(&data, data.root());
    assert!(data.source().contains(data.root()));
    child(&data, data.root(), "new");
}

#[test]
fn t_directory_rename_restarts_a_paused_child_scan_at_its_current_path() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("before")).unwrap();
    for i in 0..900 {
        fs::write(dir.path().join("before").join(format!("file-{i:04}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    data.data()
        .acknowledge_publication(data.source().revision());
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let folder = child(&data, data.root(), "before");
    eventually(|| data.source().node(folder).unwrap().child_count() == 512);
    fs::rename(dir.path().join("before"), dir.path().join("after")).unwrap();
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![data.root()], true)),
    );
    eventually(|| resource::entry(&data.source(), folder).unwrap().name == "after");
    eventually(|| {
        data.data()
            .acknowledge_publication(data.source().revision());
        let source = data.source();
        let node = source.node(folder).unwrap();
        assert!(node.error.is_none(), "{:?}", node.error);
        node.completeness == Completeness::Complete && node.load_state == LoadState::Idle
    });
    assert_eq!(data.source().node(folder).unwrap().child_count(), 900);
}

#[test]
fn t_data_release_reclaims_native_resources_after_retained_frames_are_dropped() {
    let dir = TempDir::new();
    fs::write(dir.path().join("file"), b"x").unwrap();
    for _ in 0..100 {
        let data = request(Filetree::open(dir.path().to_path_buf()));
        let state = state(&data, Mode::Tree);
        let view = state.attach().unwrap();
        loaded(&data, data.root());
        let frame = state.snapshot().unwrap();
        let source = data.source();
        let budget = data.data().memory();
        let weak = data.data().downgrade();
        drop(view);
        drop(state);
        drop(data);
        eventually(|| weak.upgrade().is_none());
        assert!(budget.used() > 0);
        drop(frame);
        drop(source);
        eventually(|| budget.used() == 0);
    }
}

#[test]
fn t_refresh_identity_swap_updates_path_lookup_without_losing_occurrences() {
    let dir = TempDir::new();
    fs::write(dir.path().join("a"), b"a").unwrap();
    fs::write(dir.path().join("b"), b"b").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let a = child(&data, data.root(), "a");
    let b = child(&data, data.root(), "b");
    fs::rename(dir.path().join("a"), dir.path().join("temporary")).unwrap();
    fs::rename(dir.path().join("b"), dir.path().join("a")).unwrap();
    fs::rename(dir.path().join("temporary"), dir.path().join("b")).unwrap();
    ticket(data.refresh(&state).unwrap());
    eventually(|| resource::entry(&data.source(), a).unwrap().name == "b");
    loaded(&data, data.root());
    assert_eq!(request(data.resolve(dir.path().join("a"))).node, b);
    assert_eq!(request(data.resolve(dir.path().join("b"))).node, a);
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 2);
}

#[test]
fn t_details_reads_current_metadata_for_the_captured_resource() {
    let directory = TempDir::new();
    let path = directory.path().join("details");
    fs::write(&path, b"old").unwrap();
    let data = request(Filetree::open(directory.path().to_path_buf()));
    let resource = request(data.resolve(path.clone()));
    fs::write(&path, b"current contents").unwrap();
    fs::OpenOptions::new()
        .write(true)
        .open(&path)
        .unwrap()
        .set_times(
            fs::FileTimes::new()
                .set_modified(std::time::UNIX_EPOCH + Duration::from_secs(946_684_800)),
        )
        .unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&path, fs::Permissions::from_mode(0o640)).unwrap();
    }
    let details = request(data.details(resource.clone()));
    assert_eq!(details.path, path);
    assert_eq!(details.size, 16);
    assert_eq!(details.modified.as_deref(), Some("2000-01-01T00:00:00Z"));
    assert!(details.accessed.is_some());
    assert_eq!(resource.entry().unwrap().size, 3);
    #[cfg(unix)]
    {
        assert_eq!(details.permissions, "rw-r-----");
        assert_eq!(details.mode & 0o777, 0o640);
    }
    let other = request(Filetree::open(directory.path().to_path_buf()));
    assert!(other.details(resource).poll().unwrap().is_err());
}

#[cfg(unix)]
#[test]
fn t_details_rejects_replaced_ancestors_even_when_the_leaf_identity_is_unchanged() {
    let directory = TempDir::new();
    let parent = directory.path().join("parent");
    fs::create_dir(&parent).unwrap();
    fs::write(parent.join("file"), b"content").unwrap();
    let data = request(Filetree::open(directory.path().to_path_buf()));
    let resource = request(data.resolve(parent.join("file")));
    fs::rename(&parent, directory.path().join("old-parent")).unwrap();
    fs::create_dir(&parent).unwrap();
    fs::hard_link(
        directory.path().join("old-parent/file"),
        parent.join("file"),
    )
    .unwrap();
    assert_eq!(
        resource.entry().unwrap().identity,
        Entry::read(&parent.join("file")).unwrap().identity
    );
    let details = data.details(resource);
    eventually(|| details.poll().is_some());
    assert!(matches!(details.poll().unwrap(), Err(error) if error.code == ErrorCode::Stale));
}

#[cfg(unix)]
#[test]
fn t_details_inspects_the_link_and_rejects_a_replaced_target() {
    let directory = TempDir::new();
    fs::write(directory.path().join("target"), b"target contents").unwrap();
    std::os::unix::fs::symlink("target", directory.path().join("alias")).unwrap();
    let data = request(Filetree::open(directory.path().to_path_buf()));
    let resource = request(data.resolve(directory.path().join("alias")));
    let details = request(data.details(resource.clone()));
    assert_eq!(details.path, directory.path().join("alias"));
    assert_eq!(details.size, 6);
    fs::rename(
        directory.path().join("target"),
        directory.path().join("old-target"),
    )
    .unwrap();
    fs::write(directory.path().join("target"), b"replacement").unwrap();
    let details = data.details(resource);
    eventually(|| details.poll().is_some());
    assert!(matches!(details.poll().unwrap(), Err(error) if error.code == ErrorCode::Stale));
}
