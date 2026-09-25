use super::*;
use crate::ux::treeview::*;
use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant};

pub(super) struct Directory(pub(super) PathBuf);
impl Directory {
    pub(super) fn new() -> Self {
        let path = std::env::temp_dir().join(format!("yoz-filetree-{}", uuid::Uuid::new_v4()));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
fn until(mut predicate: impl FnMut() -> bool) {
    let start = Instant::now();
    while !predicate() {
        assert!(
            start.elapsed() < Duration::from_secs(10),
            "Filetree wait timed out"
        );
        std::thread::sleep(Duration::from_millis(1));
    }
}
pub(super) fn request<T: Clone>(request: Request<T>) -> T {
    until(|| request.poll().is_some());
    request
        .poll()
        .unwrap()
        .unwrap_or_else(|error| panic!("{error:?}"))
}
fn ticket(ticket: Ticket) -> Outcome {
    until(|| ticket.poll().is_some());
    let result = ticket.poll().unwrap();
    if let Outcome::Reply(Reply::Rejected { error }) = &result {
        panic!("{error:?}");
    }
    result
}
fn state(data: &Filetree, mode: Mode) -> StateHandle {
    let Outcome::State(state) = ticket(data.create_state(
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
fn loaded(data: &Filetree, node: NodeId) {
    until(|| {
        let source = data.source();
        let node = source.node(node).unwrap();
        assert!(node.error.is_none(), "{:?}", node.error);
        node.completeness == Completeness::Complete && node.load_state == LoadState::Idle
    });
}
fn child(data: &Filetree, parent: NodeId, name: &str) -> NodeId {
    let source = data.source();
    source
        .node(parent)
        .unwrap()
        .children()
        .find(|id| resource::entry(&source, *id).unwrap().name == name)
        .unwrap()
}

#[test]
fn t_ancestor_refresh_releases_saturated_reads_and_preserves_leases() {
    struct RefreshOverLeases {
        root: NodeId,
        children: Vec<NodeId>,
    }
    impl NativeAction for RefreshOverLeases {
        fn bytes(&self) -> usize {
            self.children.len() * 8 + 8
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            let mut effects = Vec::new();
            for node in self.children {
                effects.extend(engine.lease_children(node)?.1.into_effects());
            }
            assert_eq!(engine.reads.len(), engine.limits.concurrent_reads);
            effects.extend(engine.request_children(&[self.root], true)?.into_effects());
            Ok(engine.applied(None, effects))
        }
    }

    let directory = Directory::new();
    for index in 0..6 {
        fs::create_dir(directory.0.join(format!("child-{index}"))).unwrap();
    }
    let data = request(Filetree::open(directory.0.clone()));
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
            .submit(Action::Native(Box::new(RefreshOverLeases {
                root: data.root(),
                children: children.clone(),
            }))),
    );
    for node in children {
        loaded(&data, node);
    }
    loaded(&data, data.root());
    until(|| !data.data().has_work());
}

#[cfg(unix)]
pub(super) struct DeniedDirectory(PathBuf, fs::Permissions);
#[cfg(unix)]
impl DeniedDirectory {
    pub(super) fn new(path: PathBuf) -> Self {
        use std::os::unix::fs::PermissionsExt;
        let permissions = fs::metadata(&path).unwrap().permissions();
        fs::set_permissions(&path, fs::Permissions::from_mode(0)).unwrap();
        Self(path, permissions)
    }
}
#[cfg(unix)]
impl Drop for DeniedDirectory {
    fn drop(&mut self) {
        fs::set_permissions(&self.0, self.1.clone()).unwrap();
    }
}

#[cfg(unix)]
#[test]
fn t_resolve_reorders_links_when_directory_targets_appear_and_disappear() {
    let dir = Directory::new();
    let workspace = dir.0.join("workspace");
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
            fs::create_dir(dir.0.join("target")).unwrap();
        } else {
            fs::remove_dir(dir.0.join("target")).unwrap();
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
    let dir = Directory::new();
    let workspace = dir.0.join("workspace");
    fs::create_dir(&workspace).unwrap();
    fs::create_dir(dir.0.join("target")).unwrap();
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
    fs::remove_dir(dir.0.join("target")).unwrap();
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
    let dir = Directory::new();
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::write(dir.0.join("target/child"), "content").unwrap();
    std::os::unix::fs::symlink("target", dir.0.join("link")).unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let old = request(data.resolve(dir.0.join("link/child")));
    let link = old.source.node(old.node).unwrap().parent.unwrap();
    fs::rename(dir.0.join("target"), dir.0.join("previous")).unwrap();
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::rename(dir.0.join("previous/child"), dir.0.join("target/child")).unwrap();
    let new = request(data.resolve(dir.0.join("link/child")));
    assert_ne!(new.node, old.node);
    assert_eq!(new.entry().unwrap().identity, old.entry().unwrap().identity);
    assert_eq!(new.source.node(new.node).unwrap().parent, Some(link));
    assert!(!new.source.contains(old.node));
    assert!(old.source.contains(old.node));
    assert_eq!(
        request(data.resolve(dir.0.join("link/child"))).node,
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
        let dir = Directory::new();
        fs::create_dir_all(dir.0.join("private/target")).unwrap();
        fs::write(dir.0.join("private/target/child"), "content").unwrap();
        std::os::unix::fs::symlink("private/target", dir.0.join("link")).unwrap();
        let data = request(Filetree::open(dir.0.join("link")));
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
        let denied = DeniedDirectory::new(dir.0.join("private"));
        assert!(Entry::read(&dir.0.join("link")).unwrap().target_unknown);
        match mode {
            "resolve" => {
                request(data.resolve(dir.0.join("link")));
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
        until(|| {
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
            until(|| data.source().node(data.root()).unwrap().error.is_none());
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
    let dir = Directory::new();
    let base = fs::canonicalize(&dir.0).unwrap();
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
    let dir = Directory::new();
    fs::create_dir(dir.0.join("sub")).unwrap();
    fs::write(dir.0.join("sub/deep"), b"x").unwrap();
    for name in ["b", "A2", "a1", "z\nline", ".hidden"] {
        fs::write(dir.0.join(name), b"x").unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
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
    let deep = request(data.resolve(dir.0.join("sub/deep")));
    assert_eq!(deep.path().unwrap(), dir.0.join("sub/deep"));
    assert_eq!(
        data.source().node(sub).unwrap().completeness,
        Completeness::Unknown
    );
}

#[test]
fn t_refresh_preserves_metadata_identity_and_rename_but_replaces_new_resources() {
    let dir = Directory::new();
    fs::write(dir.0.join("a"), b"a").unwrap();
    fs::write(dir.0.join("gone"), b"gone").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let old = data.source();
    let a = child(&data, data.root(), "a");
    let gone = child(&data, data.root(), "gone");
    fs::write(dir.0.join("a"), b"different-size").unwrap();
    fs::remove_file(dir.0.join("gone")).unwrap();
    fs::rename(dir.0.join("a"), dir.0.join("renamed")).unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| data.source().node(gone).is_none());
    loaded(&data, data.root());
    assert_eq!(child(&data, data.root(), "renamed"), a);
    assert_eq!(resource::path(&old, a).unwrap(), dir.0.join("a"));
    assert_eq!(
        resource::path(&data.source(), a).unwrap(),
        dir.0.join("renamed")
    );
    fs::write(dir.0.join("replacement"), b"new").unwrap();
    fs::rename(dir.0.join("replacement"), dir.0.join("renamed")).unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| data.source().node(a).is_none());
    loaded(&data, data.root());
    assert_ne!(child(&data, data.root(), "renamed"), a);
}

#[cfg(unix)]
#[test]
fn t_list_keeps_aliases_and_stops_ancestor_symlink_cycles() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("sub")).unwrap();
    fs::write(dir.0.join("sub/file"), b"x").unwrap();
    symlink("sub", dir.0.join("alias")).unwrap();
    symlink("..", dir.0.join("sub/cycle")).unwrap();
    let data = request(Filetree::open(dir.0.clone()));
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
    let dir = Directory::new();
    for i in 0..1300 {
        fs::write(dir.0.join(format!("file-{i:04}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
    data.data()
        .acknowledge_publication(data.source().revision());
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    until(|| data.source().node(data.root()).unwrap().child_count() > 0);
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 512);
    std::thread::sleep(Duration::from_millis(35));
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 512);
    until(|| {
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
    let dir = Directory::new();
    fs::write(dir.0.join("Original"), b"x").unwrap();
    fs::write(dir.0.join("z-last"), b"x").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let original = child(&data, data.root(), "Original");
    if dir.0.join("original").exists() {
        let resolved = request(data.resolve(dir.0.join("original")));
        assert_eq!(resolved.node, original);
        assert_eq!(resolved.path().unwrap(), dir.0.join("Original"));
        assert_eq!(data.source().node(data.root()).unwrap().child_count(), 2);
    }
    fs::write(dir.0.join("a-first"), b"x").unwrap();
    let first = request(data.resolve(dir.0.join("a-first")));
    assert_eq!(
        data.source().node(data.root()).unwrap().child_at(0),
        Some(first.node)
    );
}

#[test]
fn t_replaced_entry_root_is_unavailable_and_never_rebinds_old_state() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("root")).unwrap();
    fs::write(dir.0.join("root/old"), b"x").unwrap();
    let data = request(Filetree::open(dir.0.join("root")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let old = data.source();
    fs::rename(dir.0.join("root"), dir.0.join("previous")).unwrap();
    fs::create_dir(dir.0.join("root")).unwrap();
    fs::write(dir.0.join("root/new"), b"x").unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| !data.source().contains(data.root()));
    until(|| state.snapshot().unwrap().is_empty());
    assert!(old.contains(data.root()));
    assert!(data.data().events().iter().any(
        |event| matches!(event, Effect::RootUnavailable { node, .. } if *node == data.root())
    ));
    let current = request(data.resolve(dir.0.join("root")));
    assert_ne!(current.node, data.root());
    assert!(state.snapshot().unwrap().is_empty());
}

#[cfg(unix)]
#[test]
fn t_hardlink_ambiguity_ends_old_occurrence_and_native_names_remain_lossless() {
    #[cfg(not(target_os = "macos"))]
    use std::os::unix::ffi::OsStringExt;
    let dir = Directory::new();
    fs::write(dir.0.join("a"), b"x").unwrap();
    fs::hard_link(dir.0.join("a"), dir.0.join("b")).unwrap();
    #[cfg(not(target_os = "macos"))]
    let name = std::ffi::OsString::from_vec(vec![b'c', 0xff, b'\n']);
    #[cfg(target_os = "macos")]
    let name = std::ffi::OsString::from("c文\n");
    fs::write(dir.0.join(&name), b"x").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let a = child(&data, data.root(), "a");
    let b = child(&data, data.root(), "b");
    let raw = request(data.resolve(dir.0.join(&name)));
    assert_eq!(raw.path().unwrap(), dir.0.join(&name));
    assert_eq!(
        raw.source.node(raw.node).unwrap().data.label.as_ref(),
        display_name(&name)
    );
    fs::rename(dir.0.join("a"), dir.0.join("renamed")).unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| !data.source().contains(a));
    loaded(&data, data.root());
    assert_ne!(child(&data, data.root(), "renamed"), a);
    assert_eq!(child(&data, data.root(), "b"), b);
}

#[test]
fn t_detach_retires_a_paused_native_read_without_another_page() {
    let dir = Directory::new();
    for i in 0..800 {
        fs::write(dir.0.join(format!("file-{i}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
    data.data()
        .acknowledge_publication(data.source().revision());
    let state = state(&data, Mode::Tree);
    let view = state.attach().unwrap();
    until(|| data.source().node(data.root()).unwrap().child_count() == 512);
    drop(view);
    until(|| data.source().node(data.root()).unwrap().load_state == LoadState::Idle);
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 512);
    assert_eq!(
        data.source().node(data.root()).unwrap().completeness,
        Completeness::Partial
    );
}

#[test]
#[ignore = "explicit release-mode real filesystem measurement"]
fn t_native_wide_directory_performance() {
    let dir = Directory::new();
    for i in 0..50_000 {
        fs::write(dir.0.join(format!("file-{i:05}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
    let start = Instant::now();
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    until(|| data.source().node(data.root()).unwrap().child_count() >= 512);
    let first = start.elapsed();
    loaded(&data, data.root());
    let initial = start.elapsed();
    let mut samples = Vec::new();
    for _ in 0..5 {
        let epoch = data.source().node(data.root()).unwrap().request_epoch;
        let start = Instant::now();
        ticket(data.refresh(&state).unwrap());
        until(|| data.source().node(data.root()).unwrap().request_epoch > epoch);
        loaded(&data, data.root());
        samples.push(start.elapsed().as_secs_f64() * 1000.0);
    }
    samples.sort_by(f64::total_cmp);
    println!(
        "filetree real 50k: first512_ms={:.3}, initial_ms={:.3}, refresh_n=5 p50_ms={:.3} max_ms={:.3}",
        first.as_secs_f64() * 1000.0,
        initial.as_secs_f64() * 1000.0,
        samples[2],
        samples[4]
    );
}

#[test]
fn t_refresh_preserves_unambiguous_rename_when_original_name_is_recreated() {
    let dir = Directory::new();
    fs::write(dir.0.join("a"), b"old").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let a = child(&data, data.root(), "a");
    fs::rename(dir.0.join("a"), dir.0.join("z")).unwrap();
    fs::write(dir.0.join("a"), b"new").unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| data.source().node(data.root()).unwrap().child_count() == 2);
    loaded(&data, data.root());
    assert_eq!(child(&data, data.root(), "z"), a);
    assert_ne!(child(&data, data.root(), "a"), a);
    assert_eq!(request(data.resolve(dir.0.join("z"))).node, a);
}

#[cfg(unix)]
#[test]
fn t_directory_symlink_target_replacement_keeps_link_but_ends_old_children() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::write(dir.0.join("target/old"), b"x").unwrap();
    symlink("target", dir.0.join("alias")).unwrap();
    let data = request(Filetree::open(dir.0.join("alias")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let old = child(&data, data.root(), "old");
    fs::rename(dir.0.join("target"), dir.0.join("previous")).unwrap();
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::write(dir.0.join("target/new"), b"new").unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| {
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
    let dir = Directory::new();
    fs::create_dir(dir.0.join("before")).unwrap();
    for i in 0..900 {
        fs::write(dir.0.join("before").join(format!("file-{i:04}")), b"").unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
    data.data()
        .acknowledge_publication(data.source().revision());
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let folder = child(&data, data.root(), "before");
    until(|| data.source().node(folder).unwrap().child_count() == 512);
    fs::rename(dir.0.join("before"), dir.0.join("after")).unwrap();
    ticket(
        data.data()
            .submit(Action::RequestChildren(vec![data.root()], true)),
    );
    until(|| resource::entry(&data.source(), folder).unwrap().name == "after");
    until(|| {
        data.data()
            .acknowledge_publication(data.source().revision());
        let source = data.source();
        let node = source.node(folder).unwrap();
        assert!(node.error.is_none(), "{:?}", node.error);
        node.completeness == Completeness::Complete && node.load_state == LoadState::Idle
    });
    assert_eq!(data.source().node(folder).unwrap().child_count(), 900);
}

fn watching(data: &Filetree, node: NodeId) {
    let mut stable = None;
    until(|| {
        let status = data.watch_status();
        assert!(status.error.is_none(), "{:?}", status.error);
        let source = data.source();
        let ready = status.covered.contains(&node)
            && source.node(node).is_some_and(|node| {
                node.load_state == LoadState::Idle && node.completeness == Completeness::Complete
            })
            && !data.data().has_work()
            && data.data().queue_depth() == 0;
        if ready {
            stable.get_or_insert(Instant::now());
        } else {
            stable = None;
        }
        stable.is_some_and(|time| time.elapsed() >= Duration::from_millis(35))
    });
}

#[cfg(any(target_os = "macos", target_os = "linux", windows))]
#[test]
fn t_native_watch_coalesces_changes_and_releases_when_view_detaches() {
    let dir = Directory::new();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let view = state.attach().unwrap();
    watching(&data, data.root());
    let revision = data.source().revision();
    std::thread::sleep(Duration::from_millis(180));
    assert_eq!(
        data.source().revision(),
        revision,
        "quiet directories must not be rescanned periodically"
    );
    let start = Instant::now();
    for name in ["a", "b", "c"] {
        fs::write(dir.0.join(name), b"x").unwrap();
    }
    until(|| data.source().node(data.root()).unwrap().child_count() == 3);
    assert!(start.elapsed() >= Duration::from_millis(130));
    watching(&data, data.root());
    let a = child(&data, data.root(), "a");
    fs::rename(dir.0.join("a"), dir.0.join("renamed")).unwrap();
    until(|| resource::entry(&data.source(), a).unwrap().name == "renamed");
    drop(view);
    until(|| data.watch_status().directories == 0 && !data.data().has_work());
    fs::write(dir.0.join("after-detach"), b"x").unwrap();
    std::thread::sleep(Duration::from_millis(200));
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 3);
    let _view = state.attach().unwrap();
    until(|| data.source().node(data.root()).unwrap().child_count() == 4);
    watching(&data, data.root());
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_watch_budget_prefers_visible_directories() {
    let dir = Directory::new();
    for i in 0..60 {
        fs::create_dir(dir.0.join(format!("dir-{i:02}"))).unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    until(|| data.watch_status().directories == 50 && data.watch_status().limited);
    let source = data.source();
    let uncovered = source
        .node(data.root())
        .unwrap()
        .children()
        .find(|id| !data.watch_status().covered.contains(id))
        .unwrap();
    let budget = data.data().memory();
    let _memory = budget.enter();
    data.set_viewports(vec![watch::Viewport {
        state: state.id(),
        root: Root::ChildrenOf(data.root()),
        nodes: vec![uncovered].into(),
        _memory: crate::ux::treeview::memory::Charge::new(8),
    }])
    .unwrap();
    until(|| data.watch_status().covered.contains(&uncovered));
    assert_eq!(data.watch_status().directories, 50);
    assert!(data.watch_status().limited);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_overlapping_viewports_preserve_each_roots_visible_ancestors() {
    let dir = Directory::new();
    for i in 0..60 {
        fs::create_dir(dir.0.join(format!("dir-{i:02}"))).unwrap();
    }
    fs::create_dir_all(dir.0.join("zz-parent/narrow")).unwrap();
    fs::write(dir.0.join("zz-parent/narrow/leaf"), "content").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let wide = state(&data, Mode::List);
    let _wide_view = wide.attach().unwrap();
    watching(&data, data.root());
    let parent = child(&data, data.root(), "zz-parent");
    loaded(&data, parent);
    let narrow_root = child(&data, parent, "narrow");
    loaded(&data, narrow_root);
    let leaf = child(&data, narrow_root, "leaf");
    let Outcome::State(narrow) = ticket(data.create_state(
        Some(Root::ChildrenOf(narrow_root)),
        DisplayOptions {
            mode: Mode::List,
            ..DisplayOptions::default()
        },
    )) else {
        panic!("state");
    };
    let _narrow_view = narrow.attach().unwrap();
    watching(&data, narrow_root);
    until(|| data.watch_status().directories == 50 && data.watch_status().limited);
    assert!(!data.watch_status().covered.contains(&parent));
    let marker = data
        .source()
        .node(data.root())
        .unwrap()
        .children()
        .find(|id| *id != parent && !data.watch_status().covered.contains(id))
        .unwrap();
    data.set_viewports(vec![
        watch::Viewport {
            state: narrow.id(),
            root: Root::ChildrenOf(narrow_root),
            nodes: vec![leaf].into(),
            _memory: crate::ux::treeview::memory::Charge::new(8),
        },
        watch::Viewport {
            state: wide.id(),
            root: Root::ChildrenOf(data.root()),
            nodes: vec![leaf, marker].into(),
            _memory: crate::ux::treeview::memory::Charge::new(16),
        },
    ])
    .unwrap();
    until(|| data.watch_status().covered.contains(&marker));
    let status = data.watch_status();
    assert!(status.covered.contains(&parent));
    assert!(status.covered.contains(&narrow_root));
    assert_eq!(status.directories, 50);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_directory_aliases_share_os_watch_and_refresh_each_occurrence() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("target")).unwrap();
    for i in 0..55 {
        symlink("target", dir.0.join(format!("alias-{i:02}"))).unwrap();
    }
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    until(|| data.watch_status().covered.len() == 57);
    assert_eq!(data.watch_status().directories, 2);
    assert!(!data.watch_status().limited);
    fs::write(dir.0.join("target/new"), b"x").unwrap();
    until(|| {
        let source = data.source();
        source
            .node(data.root())
            .unwrap()
            .children()
            .all(|id| source.node(id).unwrap().child_count() == 1)
    });
}

#[test]
fn t_data_release_reclaims_native_resources_after_retained_frames_are_dropped() {
    let dir = Directory::new();
    fs::write(dir.0.join("file"), b"x").unwrap();
    for _ in 0..100 {
        let data = request(Filetree::open(dir.0.clone()));
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
        until(|| weak.upgrade().is_none());
        assert!(budget.used() > 0);
        drop(frame);
        drop(source);
        until(|| budget.used() == 0);
    }
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_shared_alias_roots_watch_each_occurrence_parent() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    for name in ["target", "p1", "p2"] {
        fs::create_dir(dir.0.join(name)).unwrap();
    }
    fs::write(dir.0.join("target/old"), "old").unwrap();
    symlink("../target", dir.0.join("p1/alias")).unwrap();
    symlink("../target", dir.0.join("p2/alias")).unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let first = request(data.resolve(dir.0.join("p1/alias"))).node;
    let second = request(data.resolve(dir.0.join("p2/alias"))).node;
    let mut states = Vec::new();
    let mut views = Vec::new();
    for root in [first, second] {
        let Outcome::State(state) =
            ticket(data.create_state(Some(Root::ChildrenOf(root)), DisplayOptions::default()))
        else {
            panic!("state");
        };
        views.push(state.attach().unwrap());
        states.push(state);
    }
    watching(&data, first);
    watching(&data, second);
    assert_eq!(data.watch_status().directories, 4);
    fs::remove_file(dir.0.join("p2/alias")).unwrap();
    until(|| !data.source().contains(second));
    until(|| states[1].snapshot().unwrap().is_empty());
    assert!(data.source().contains(first));
    fs::write(dir.0.join("target/new"), "new").unwrap();
    until(|| data.source().node(first).unwrap().child_count() == 2);
    assert_eq!(fs::read_to_string(dir.0.join("target/old")).unwrap(), "old");
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_link_root_observes_referent_recreation_outside_its_occurrence_parent() {
    use std::os::unix::fs::symlink;
    for absolute in [false, true] {
        let dir = Directory::new();
        fs::create_dir(dir.0.join("links")).unwrap();
        fs::create_dir(dir.0.join("target")).unwrap();
        fs::write(dir.0.join("target/old"), "old").unwrap();
        if absolute {
            for index in 0..55 {
                fs::create_dir(dir.0.join(format!("target/sub-{index:02}"))).unwrap();
            }
        }
        let target = if absolute {
            dir.0.join("target")
        } else {
            PathBuf::from("../target")
        };
        symlink(target, dir.0.join("links/alias")).unwrap();
        let data = request(Filetree::open(dir.0.join("links/alias")));
        let state = state(&data, if absolute { Mode::List } else { Mode::Tree });
        let _view = state.attach().unwrap();
        watching(&data, data.root());
        assert_eq!(
            data.watch_status().directories,
            if absolute { 50 } else { 3 }
        );
        assert_eq!(data.watch_status().limited, absolute);
        let old = child(&data, data.root(), "old");
        fs::remove_dir_all(dir.0.join("target")).unwrap();
        until(|| !data.source().node(data.root()).unwrap().data.can_expand);
        until(|| data.watch_status().directories == 2 && !data.data().has_work());
        std::thread::sleep(Duration::from_millis(200));
        fs::create_dir(dir.0.join("target")).unwrap();
        fs::write(dir.0.join("target/new"), "new").unwrap();
        until(|| data.source().node(data.root()).unwrap().child_count() == 1);
        watching(&data, data.root());
        assert!(!data.source().contains(old));
        child(&data, data.root(), "new");
    }
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_busy_recovery_probe_retries_without_another_event() {
    /* Saturate only this subprocess's shared IO pool, leaving parallel tests independent. */
    if std::env::var_os("YOZ_FILETREE_BUSY_CHILD").is_none() {
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "ux::filetree::tests::t_busy_recovery_probe_retries_without_another_event",
                "--nocapture",
            ])
            .env("YOZ_FILETREE_BUSY_CHILD", "1")
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "{}\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
        return;
    }
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Condvar, Mutex};
    let dir = Directory::new();
    fs::create_dir(dir.0.join("target")).unwrap();
    std::os::unix::fs::symlink("target", dir.0.join("link")).unwrap();
    let data = request(Filetree::open(dir.0.join("link")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    fs::remove_dir(dir.0.join("target")).unwrap();
    until(|| !data.source().node(data.root()).unwrap().data.can_expand && !data.data().has_work());
    until(|| data.watch_status().directories == 1);
    let gate = Arc::new((Mutex::new(false), Condvar::new()));
    let started = Arc::new(AtomicUsize::new(0));
    for _ in 0..4 {
        let gate = gate.clone();
        let started = started.clone();
        work::submit(Box::new(move || {
            started.fetch_add(1, Ordering::Release);
            let mut open = gate.0.lock().unwrap();
            while !*open {
                open = gate.1.wait(open).unwrap();
            }
        }))
        .unwrap();
    }
    until(|| started.load(Ordering::Acquire) == 4);
    for _ in 0..256 {
        work::submit(Box::new(|| {})).unwrap();
    }
    let full = work::Request::<()>::run(|| Ok(()));
    assert!(matches!(full.poll(), Some(Err(error)) if error.code == ErrorCode::Busy));
    let watch_revision = data.watch_status().revision;
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::write(dir.0.join("target/recovered"), "content").unwrap();
    /* Keep the queue full across the native event merge window without surfacing retries. */
    let paused = Instant::now();
    while paused.elapsed() < Duration::from_millis(500) {
        let status = data.watch_status();
        assert!(status.error.is_none(), "{:?}", status.error);
        assert_eq!(status.revision, watch_revision);
        std::thread::sleep(Duration::from_millis(1));
    }
    *gate.0.lock().unwrap() = true;
    gate.1.notify_all();
    until(|| data.source().node(data.root()).unwrap().child_count() == 1);
    watching(&data, data.root());
    child(&data, data.root(), "recovered");
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_nested_directory_links_observe_referent_recreation() {
    for mode in [Mode::Tree, Mode::List] {
        let dir = Directory::new();
        fs::create_dir(dir.0.join("workspace")).unwrap();
        fs::create_dir(dir.0.join("target")).unwrap();
        fs::write(dir.0.join("target/old"), "old").unwrap();
        std::os::unix::fs::symlink("../target", dir.0.join("workspace/link")).unwrap();
        let data = request(Filetree::open(dir.0.join("workspace")));
        let state = state(&data, mode);
        let view = state.attach().unwrap();
        watching(&data, data.root());
        let link = child(&data, data.root(), "link");
        if mode == Mode::Tree {
            ticket(state.dispatch(
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![link].into()),
                    value: true,
                    scope: Scope::SelfOnly,
                },
                Context::default(),
            ));
        }
        watching(&data, link);
        let registered = data.watch_status().directories;
        let old = child(&data, link, "old");
        fs::remove_dir_all(dir.0.join("target")).unwrap();
        until(|| !data.source().node(link).unwrap().data.can_expand);
        /* Do not let a lingering referent watch mask the missing parent recovery watch. */
        until(|| {
            data.watch_status().directories < registered
                && !data.data().has_work()
                && data.data().queue_depth() == 0
        });
        std::thread::sleep(Duration::from_millis(200));
        fs::create_dir(dir.0.join("target")).unwrap();
        fs::write(dir.0.join("target/new"), "new").unwrap();
        until(|| data.source().node(link).unwrap().child_count() == 1);
        watching(&data, link);
        assert!(!data.source().contains(old));
        child(&data, link, "new");
        assert_eq!(data.watch_status().directories, 3);
        drop(view);
        until(|| data.watch_status().directories == 0);
    }
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
#[ignore = "native 50-watch stress; run with a file descriptor limit of at least 4096"]
fn t_native_link_watch_budget_stress() {
    let dir = Directory::new();
    fs::create_dir_all(dir.0.join("workspace/visible")).unwrap();
    for index in 0..55 {
        let parent = dir.0.join(format!("external-{index:02}"));
        fs::create_dir_all(parent.join("target")).unwrap();
        std::os::unix::fs::symlink(
            parent.join("target"),
            dir.0.join(format!("workspace/link-{index:02}")),
        )
        .unwrap();
    }
    let data = request(Filetree::open(dir.0.join("workspace")));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let visible = child(&data, data.root(), "visible");
    let link = child(&data, data.root(), "link-54");
    data.set_viewports(vec![watch::Viewport {
        state: state.id(),
        root: Root::ChildrenOf(data.root()),
        nodes: vec![visible, link].into(),
        _memory: crate::ux::treeview::memory::Charge::new(16),
    }])
    .unwrap();
    until(|| {
        let status = data.watch_status();
        status.limited
            && status.directories == 50
            && status.covered.contains(&visible)
            && status.covered.contains(&link)
    });
    watching(&data, link);
    fs::write(dir.0.join("workspace/visible/new"), "visible").unwrap();
    until(|| data.source().node(visible).unwrap().child_count() == 1);
    fs::remove_dir(dir.0.join("external-54/target")).unwrap();
    until(|| !data.source().node(link).unwrap().data.can_expand);
    std::thread::sleep(Duration::from_millis(250));
    fs::create_dir(dir.0.join("external-54/target")).unwrap();
    fs::write(dir.0.join("external-54/target/new"), "recovered").unwrap();
    until(|| data.source().node(link).unwrap().child_count() == 1);
    assert!(data.watch_status().directories <= 50);
    child(&data, link, "new");
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_alias_recovery_budget_counts_resolved_parent_identities() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("workspace")).unwrap();
    fs::create_dir_all(dir.0.join("external/repeat")).unwrap();
    fs::create_dir(dir.0.join("external/target")).unwrap();
    fs::write(dir.0.join("external/target/old"), "old").unwrap();
    for index in 0..55 {
        let target = format!("../external/{}target", "repeat/../".repeat(index));
        std::os::unix::fs::symlink(target, dir.0.join(format!("workspace/link-{index:02}")))
            .unwrap();
    }
    let data = request(Filetree::open(dir.0.join("workspace")));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    until(|| data.watch_status().directories == 3);
    assert!(
        !data.watch_status().limited,
        "raw paths must not consume the physical watch budget"
    );
    let links: Vec<_> = data
        .source()
        .node(data.root())
        .unwrap()
        .children()
        .collect();
    assert_eq!(links.len(), 55);
    until(|| {
        links
            .iter()
            .all(|node| data.source().node(*node).unwrap().child_count() == 1)
    });
    fs::remove_dir_all(dir.0.join("external/target")).unwrap();
    until(|| {
        links
            .iter()
            .all(|node| !data.source().node(*node).unwrap().data.can_expand)
    });
    until(|| data.watch_status().directories == 2 && !data.data().has_work());
    std::thread::sleep(Duration::from_millis(200));
    fs::create_dir(dir.0.join("external/target")).unwrap();
    fs::write(dir.0.join("external/target/new"), "new").unwrap();
    until(|| {
        links
            .iter()
            .all(|node| data.source().node(*node).unwrap().child_count() == 1)
    });
    for link in links {
        child(&data, link, "new");
    }
    assert_eq!(data.watch_status().directories, 3);
    assert!(!data.watch_status().limited);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_watched_directory_link_recovers_when_its_target_returns() {
    use std::os::unix::fs::symlink;
    let dir = Directory::new();
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::write(dir.0.join("target/old"), b"x").unwrap();
    symlink("target", dir.0.join("alias")).unwrap();
    let data = request(Filetree::open(dir.0.join("alias")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let old = child(&data, data.root(), "old");
    fs::remove_dir_all(dir.0.join("target")).unwrap();
    until(|| !data.source().node(data.root()).unwrap().data.can_expand);
    assert!(!data.source().contains(old));
    fs::create_dir(dir.0.join("target")).unwrap();
    fs::write(dir.0.join("target/new"), b"x").unwrap();
    until(|| data.source().node(data.root()).unwrap().child_count() == 1);
    watching(&data, data.root());
    child(&data, data.root(), "new");
}

#[test]
fn t_refresh_identity_swap_updates_path_lookup_without_losing_occurrences() {
    let dir = Directory::new();
    fs::write(dir.0.join("a"), b"a").unwrap();
    fs::write(dir.0.join("b"), b"b").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let a = child(&data, data.root(), "a");
    let b = child(&data, data.root(), "b");
    fs::rename(dir.0.join("a"), dir.0.join("temporary")).unwrap();
    fs::rename(dir.0.join("b"), dir.0.join("a")).unwrap();
    fs::rename(dir.0.join("temporary"), dir.0.join("b")).unwrap();
    ticket(data.refresh(&state).unwrap());
    until(|| resource::entry(&data.source(), a).unwrap().name == "b");
    loaded(&data, data.root());
    assert_eq!(request(data.resolve(dir.0.join("a"))).node, b);
    assert_eq!(request(data.resolve(dir.0.join("b"))).node, a);
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 2);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_directory_watch_observes_in_place_file_writes_without_replacing_identity() {
    let dir = Directory::new();
    fs::write(dir.0.join("file"), "a").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let file = child(&data, data.root(), "file");
    let old = data.inspect(data.source(), file).unwrap();
    fs::write(dir.0.join("file"), "changed contents").unwrap();
    until(|| resource::entry(&data.source(), file).unwrap().size == 16);
    assert_eq!(old.entry().unwrap().size, 1);
    assert_eq!(child(&data, data.root(), "file"), file);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_watched_directory_rename_keeps_following_file_metadata() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("before")).unwrap();
    fs::write(dir.0.join("before/file"), "a").unwrap();
    let data = request(Filetree::open(dir.0.clone()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let folder = child(&data, data.root(), "before");
    watching(&data, folder);
    let file = child(&data, folder, "file");
    fs::rename(dir.0.join("before"), dir.0.join("café")).unwrap();
    until(|| resource::entry(&data.source(), folder).unwrap().name == "café");
    watching(&data, folder);
    fs::write(dir.0.join("café/file"), "new contents").unwrap();
    until(|| resource::entry(&data.source(), file).unwrap().size == 12);
    assert_eq!(child(&data, data.root(), "café"), folder);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_unicode_directory_watch_updates_existing_files() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("目录-café")).unwrap();
    fs::write(dir.0.join("目录-café/file"), "a").unwrap();
    let data = request(Filetree::open(dir.0.join("目录-café")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let file = child(&data, data.root(), "file");
    fs::write(dir.0.join("目录-café/file"), "changed").unwrap();
    until(|| resource::entry(&data.source(), file).unwrap().size == 7);
}

#[test]
fn t_details_reads_current_metadata_for_the_captured_resource() {
    let directory = Directory::new();
    let path = directory.0.join("details");
    fs::write(&path, b"old").unwrap();
    let data = request(Filetree::open(directory.0.clone()));
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
    let other = request(Filetree::open(directory.0.clone()));
    assert!(other.details(resource).poll().unwrap().is_err());
}

#[cfg(unix)]
#[test]
fn t_details_rejects_replaced_ancestors_even_when_the_leaf_identity_is_unchanged() {
    let directory = Directory::new();
    let parent = directory.0.join("parent");
    fs::create_dir(&parent).unwrap();
    fs::write(parent.join("file"), b"content").unwrap();
    let data = request(Filetree::open(directory.0.clone()));
    let resource = request(data.resolve(parent.join("file")));
    fs::rename(&parent, directory.0.join("old-parent")).unwrap();
    fs::create_dir(&parent).unwrap();
    fs::hard_link(directory.0.join("old-parent/file"), parent.join("file")).unwrap();
    assert_eq!(
        resource.entry().unwrap().identity,
        Entry::read(&parent.join("file")).unwrap().identity
    );
    let details = data.details(resource);
    until(|| details.poll().is_some());
    assert!(matches!(details.poll().unwrap(), Err(error) if error.code == ErrorCode::Stale));
}

#[cfg(unix)]
#[test]
fn t_details_inspects_the_link_and_rejects_a_replaced_target() {
    let directory = Directory::new();
    fs::write(directory.0.join("target"), b"target contents").unwrap();
    std::os::unix::fs::symlink("target", directory.0.join("alias")).unwrap();
    let data = request(Filetree::open(directory.0.clone()));
    let resource = request(data.resolve(directory.0.join("alias")));
    let details = request(data.details(resource.clone()));
    assert_eq!(details.path, directory.0.join("alias"));
    assert_eq!(details.size, 6);
    fs::rename(directory.0.join("target"), directory.0.join("old-target")).unwrap();
    fs::write(directory.0.join("target"), b"replacement").unwrap();
    let details = data.details(resource);
    until(|| details.poll().is_some());
    assert!(matches!(details.poll().unwrap(), Err(error) if error.code == ErrorCode::Stale));
}
