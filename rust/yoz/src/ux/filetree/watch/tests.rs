use super::super::test_support::*;
use super::super::{Entry, Filetree, work};
use super::*;
use crate::test_support::{TempDir, eventually, isolated, percentile};
use crate::ux::treeview::test_support::hold;
use std::fs;

#[cfg(target_os = "linux")]
#[test]
fn t_linux_watch_wait_observes_buffered_control_and_filesystem_events() {
    let directory = TempDir::new();
    let wake = backend::wake().unwrap();
    let mut backend = backend::Backend::new(Arc::new(|| {})).unwrap();
    // A controller update arriving just before wait must not be lost.
    wake.notify_one();
    let started = Instant::now();
    backend.wait(&wake, Some(Duration::from_secs(2))).unwrap();
    assert!(started.elapsed() < Duration::from_secs(1));
    let entry = Entry::read(directory.path()).unwrap();
    backend
        .add(
            1,
            &Target {
                identity: entry.identity,
                path: Arc::new(directory.path().to_path_buf()),
                nodes: Arc::new(vec![NodeId(1)]),
                names: None,
                _memory: Arc::new(Charge::new(1024)),
            },
        )
        .unwrap();
    fs::write(directory.path().join("changed"), b"data").unwrap();
    backend.wait(&wake, Some(Duration::from_secs(2))).unwrap();
    assert!(backend.poll().unwrap().contains(&1));
    // No periodic watcher wakeup is needed once both event sources have drained.
    let started = Instant::now();
    backend
        .wait(&wake, Some(Duration::from_millis(25)))
        .unwrap();
    assert!(started.elapsed() >= Duration::from_millis(20));
}

#[test]
#[ignore = "explicit real OS notification latency measurement"]
fn t_native_watch_notification_latency() {
    let directory = TempDir::new();
    let engine = Engine::new(Limits::default()).unwrap();
    let _memory = engine.memory.enter();
    let entry = Entry::read(directory.path()).unwrap();
    let target = Target {
        identity: entry.identity,
        path: Arc::new(directory.path().to_path_buf()),
        nodes: Arc::new(vec![NodeId(1)]),
        names: None,
        _memory: Arc::new(Charge::new(1024)),
    };
    let mut backend = backend::Backend::new(Arc::new(|| {})).unwrap();
    backend.add(1, &target).unwrap();
    eventually(|| {
        backend.poll().unwrap();
        backend.ready()
    });
    let mut times = Vec::new();
    for index in 0..20 {
        backend.poll().unwrap();
        let began = Instant::now();
        fs::write(directory.path().join(format!("event-{index}")), b"data").unwrap();
        loop {
            if backend.poll().unwrap().contains(&1) {
                times.push(began.elapsed().as_secs_f64() * 1000.0);
                break;
            }
            assert!(
                began.elapsed() < Duration::from_secs(5),
                "missing OS watch event"
            );
            std::thread::sleep(Duration::from_millis(1));
        }
    }
    times.sort_by(f64::total_cmp);
    println!(
        "OS watch notification, 20 samples, 1ms polling: p50_ms={:.3} p95_ms={:.3} max_ms={:.3}",
        percentile(&times, 0.5),
        percentile(&times, 0.95),
        percentile(&times, 1.0)
    );
    backend.remove(1);
}

#[test]
fn t_watch_restarts_after_retained_memory_recovers() {
    let directory = TempDir::new();
    let mut entry = Entry::read(directory.path()).unwrap();
    entry.anchor = Some(directory.path().to_path_buf());
    let mut engine = Engine::new(Limits {
        memory_bytes: 2 * 1024 * 1024,
        ..Limits::default()
    })
    .unwrap();
    let _memory = engine.memory.enter();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("root", entry.node_data())],
        })
        .unwrap();
    let root = engine.source().id("root").unwrap();
    let state = engine
        .create_state(Root::ChildrenOf(root), DisplayOptions::default())
        .unwrap();
    engine.states.get_mut(&state).unwrap().views = 1;
    let mut index = super::super::index::Index::default();
    index.insert(engine.source(), root).unwrap();
    let data = DataHandle::new(Limits::default()).unwrap();
    let interest = Arc::new(Mutex::new(Interest::default()));
    let dirty: Dirty = Arc::new(Mutex::new(Map::default()));
    let mut watcher = Watcher::new(interest.clone(), dirty);
    watcher.publish(&engine, &data.downgrade(), &index);
    eventually(|| interest.lock().unwrap().status.covered.as_ref() == [root]);
    let previous = Arc::downgrade(&watcher.controller.as_ref().unwrap().shared);

    /* Charge the budget without allocating a large payload. */
    let pressure = Charge::new(engine.limits.memory_bytes);
    interest.lock().unwrap().version += 1;
    watcher.publish(&engine, &data.downgrade(), &index);
    assert!(watcher.controller.is_none());
    assert_eq!(
        interest.lock().unwrap().status.error.as_ref().unwrap().code,
        ErrorCode::ResourceLimit
    );
    drop(pressure);
    eventually(|| previous.upgrade().is_none());

    /* Partial recovery can still leave too little headroom for a new controller. */
    let pressure = Charge::new(engine.limits.memory_bytes - engine.memory.used() - 256 * 1024);
    watcher.publish(&engine, &data.downgrade(), &index);
    assert!(watcher.controller.is_none());
    assert_eq!(
        interest.lock().unwrap().status.error.as_ref().unwrap().code,
        ErrorCode::ResourceLimit
    );
    drop(pressure);
    interest.lock().unwrap().version += 1;
    watcher.publish(&engine, &data.downgrade(), &index);
    assert!(
        watcher.controller.is_some(),
        "watcher did not restart after budget recovery"
    );
    eventually(|| {
        let status = &interest.lock().unwrap().status;
        status.error.is_none() && status.covered.as_ref() == [root]
    });
}

#[test]
fn t_recovery_targets_preserve_priority_deduplication_and_capacity() {
    let directory = TempDir::new();
    let targets: Vec<_> = (0..LIMIT)
        .map(|index| {
            let path = directory.path().join(format!("target-{index}"));
            fs::create_dir(&path).unwrap();
            Target {
                identity: Entry::read(&path).unwrap().identity,
                path: Arc::new(path),
                nodes: Arc::new(vec![NodeId(index as u64 + 1)]),
                names: None,
                _memory: Arc::new(Charge::new(0)),
            }
        })
        .collect();
    let root = targets[0].identity;
    let visible = targets[1].identity;
    let recoveries = [
        ("root-parent", 0, 100),
        ("visible-parent", 2, 101),
        ("visible-parent/.", 3, 102),
        ("late-parent", LIMIT, 103),
    ]
    .into_iter()
    .map(|(name, priority, node)| {
        let path = directory.path().join(name);
        fs::create_dir_all(&path).unwrap();
        Recovery {
            path: Arc::new(path),
            nodes: Arc::new(vec![NodeId(node)]),
            priority,
            _memory: Arc::new(Charge::new(0)),
        }
    })
    .collect();
    let (targets, limited, error) = recovery_targets(Desired {
        targets,
        recoveries,
        root_targets: 1,
        limited: false,
    })
    .unwrap();
    assert!(error.is_none());
    assert_eq!(limited, !backend::RECURSIVE);
    assert_eq!(
        targets.len(),
        if backend::RECURSIVE { LIMIT + 3 } else { LIMIT }
    );
    assert_eq!(targets[0].identity, root);
    assert_eq!(targets[1].nodes.as_slice(), &[NodeId(100)]);
    assert_eq!(targets[2].identity, visible);
    assert_eq!(targets[3].nodes.as_slice(), &[NodeId(101), NodeId(102)]);
    assert_eq!(
        targets
            .iter()
            .any(|target| target.nodes.contains(&NodeId(103))),
        backend::RECURSIVE
    );
}

#[test]
fn t_watch_delivery_clears_only_its_recovered_queue_error() {
    let directory = TempDir::new();
    let entry = Entry::read(directory.path()).unwrap();
    let data = DataHandle::new(Limits {
        queued_actions: 1,
        ..Limits::default()
    })
    .unwrap();
    assert!(matches!(
        data.submit(Action::Import(Import {
            base_revision: data.source().revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("root", entry.node_data())],
        }))
        .wait(),
        Outcome::Reply(Reply::Applied { .. })
    ));
    let node = data.source().id("root").unwrap();
    let revision = data.source().revision();
    let interest = Arc::new(Mutex::new(Interest::default()));
    let dirty: Dirty = Arc::new(Mutex::new(Map::default()));
    let controller = Controller::new(interest.clone(), dirty.clone(), data.downgrade()).unwrap();
    controller.update(Desired {
        targets: vec![Target {
            identity: entry.identity,
            path: Arc::new(directory.path().to_path_buf()),
            nodes: Arc::new(vec![node]),
            names: None,
            _memory: Arc::new(Charge::new(0)),
        }],
        recoveries: Vec::new(),
        root_targets: 1,
        limited: false,
    });
    eventually(|| {
        interest.lock().unwrap().status.covered.contains(&node)
            && dirty.lock().unwrap().get(&node).is_some()
    });
    *dirty.lock().unwrap() = Map::default();
    let (held, release) = hold(&data);
    let queued = data.submit(Action::CreateState(
        Root::ChildrenOf(node),
        DisplayOptions::default(),
    ));
    fs::write(directory.path().join("first"), "content").unwrap();
    eventually(|| {
        interest
            .lock()
            .unwrap()
            .status
            .error
            .as_ref()
            .is_some_and(|error| {
                error.code == ErrorCode::ResourceLimit
                    && error.message.as_ref() == "action queue capacity exceeded"
            })
    });
    release.send(()).unwrap();
    held.wait();
    assert!(matches!(queued.wait(), Outcome::State(_)));
    eventually(|| dirty.lock().unwrap().get(&node).is_some());
    eventually(|| interest.lock().unwrap().status.error.is_none());
    assert_eq!(data.source().revision(), revision);

    let other = Error::new(ErrorCode::ProviderError, "another watch failure");
    let mut watcher = Watcher::new(interest.clone(), dirty.clone());
    watcher.error(other.clone());
    let generation = dirty.lock().unwrap().get(&node).unwrap().generation;
    fs::write(directory.path().join("second"), "content").unwrap();
    eventually(|| dirty.lock().unwrap().get(&node).unwrap().generation != generation);
    std::thread::sleep(Duration::from_millis(50));
    assert_eq!(interest.lock().unwrap().status.error, Some(other));
}

#[test]
fn t_watch_path_registration_failure_retries_without_false_coverage() {
    let directory = TempDir::new();
    let before = directory.path().join("before");
    let parked = directory.path().join("parked");
    let after = directory.path().join("after");
    fs::create_dir(&before).unwrap();
    let entry = Entry::read(&before).unwrap();
    let data = DataHandle::new(Limits::default()).unwrap();
    assert!(matches!(
        data.submit(Action::Import(Import {
            base_revision: data.source().revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("directory", entry.node_data())],
        }))
        .wait(),
        Outcome::Reply(Reply::Applied { .. })
    ));
    let node = data.source().id("directory").unwrap();
    let interest = Arc::new(Mutex::new(Interest::default()));
    let dirty: Dirty = Arc::new(Mutex::new(Map::default()));
    let controller = Controller::new(interest.clone(), dirty.clone(), data.downgrade()).unwrap();
    let desired = |path: PathBuf| Desired {
        targets: vec![Target {
            identity: entry.identity,
            path: Arc::new(path),
            nodes: Arc::new(vec![node]),
            names: None,
            _memory: Arc::new(Charge::new(0)),
        }],
        recoveries: Vec::new(),
        root_targets: 1,
        limited: false,
    };
    controller.update(desired(before.clone()));
    eventually(|| interest.lock().unwrap().status.covered.as_ref() == [node]);

    /* The desired path was replaced after discovery, so registration must reject its identity. */
    fs::rename(&before, &parked).unwrap();
    fs::create_dir(&after).unwrap();
    controller.update(desired(after.clone()));
    eventually(|| interest.lock().unwrap().status.error.is_some());
    let failed = interest.lock().unwrap().status.clone();
    assert_eq!(failed.directories, 0);
    assert!(failed.covered.is_empty());
    assert_eq!(failed.error.unwrap().code, ErrorCode::Stale);

    /* A second failed attempt at the same desired path must actually retry the backend. */
    fs::remove_dir(&after).unwrap();
    controller.update(desired(after.clone()));
    eventually(|| interest.lock().unwrap().status.revision > failed.revision);
    let failed = interest.lock().unwrap().status.clone();
    assert_eq!(failed.directories, 0);
    assert!(failed.covered.is_empty());
    assert_eq!(failed.error.unwrap().code, ErrorCode::NotFound);

    fs::rename(&parked, &after).unwrap();
    controller.update(desired(after.clone()));
    eventually(|| {
        let status = &interest.lock().unwrap().status;
        status.error.is_none() && status.directories == 1 && status.covered.as_ref() == [node]
    });
    eventually(|| dirty.lock().unwrap().get(&node).is_some() && !data.has_work());
    *dirty.lock().unwrap() = Map::default();
    fs::write(after.join("created"), "content").unwrap();
    eventually(|| dirty.lock().unwrap().get(&node).is_some());
}

#[cfg(any(target_os = "macos", target_os = "linux", windows))]
#[test]
fn t_native_watch_reports_empty_root_removal() {
    let dir = TempDir::new();
    let root = dir.path().join("workspace");
    fs::create_dir(&root).unwrap();
    let data = request(Filetree::open(root.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    data.data().events();
    fs::remove_dir(&root).unwrap();
    eventually(|| !data.source().contains(data.root()));
    assert!(data.data().events().iter().any(
        |event| matches!(event, Effect::RootUnavailable { node, .. } if *node == data.root())
    ));
    eventually(|| data.watch_status().directories == 0);
}

#[cfg(target_os = "linux")]
#[test]
fn t_native_watch_parent_detects_pinned_root_removal_without_sibling_refresh() {
    let dir = TempDir::new();
    let root = dir.path().join("workspace");
    fs::create_dir(&root).unwrap();
    let _pinned = fs::File::open(&root).unwrap();
    let data = request(Filetree::open(root.clone()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    assert_eq!(data.watch_status().roots, 2);
    assert_eq!(data.watch_status().directories, 1);
    let revision = data.source().revision();
    fs::write(dir.path().join("unrelated"), b"sibling").unwrap();
    std::thread::sleep(Duration::from_millis(220));
    assert_eq!(
        data.source().revision(),
        revision,
        "parent watch must filter sibling names"
    );
    fs::remove_dir(&root).unwrap();
    eventually(|| !data.source().contains(data.root()));
}

#[cfg(any(target_os = "macos", target_os = "linux", windows))]
#[test]
fn t_zero_depth_grouped_list_watches_descendants_without_expansion() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dir")).unwrap();
    fs::write(dir.path().join("dir/old"), b"old").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let Outcome::State(state) = ticket(data.create_state(
        None,
        DisplayOptions {
            mode: Mode::Tree,
            compress: false,
            list_from_depth: Some(0),
            ..DisplayOptions::default()
        },
    )) else {
        panic!("expected state")
    };
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let folder = child(&data, data.root(), "dir");
    eventually(|| state.snapshot().is_ok_and(|frame| frame.len() == 2));
    watching(&data, folder);

    fs::write(dir.path().join("dir/new"), b"new").unwrap();
    eventually(|| state.snapshot().is_ok_and(|frame| frame.len() == 3));
    assert_eq!(data.source().node(folder).unwrap().child_count(), 2);
    child(&data, folder, "new");
}

#[cfg(any(target_os = "macos", target_os = "linux", windows))]
#[test]
fn t_native_watch_coalesces_changes_and_releases_when_view_detaches() {
    let dir = TempDir::new();
    let data = request(Filetree::open(dir.path().to_path_buf()));
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
        fs::write(dir.path().join(name), b"x").unwrap();
    }
    eventually(|| data.source().node(data.root()).unwrap().child_count() == 3);
    /* The burst waits for its events to settle before one re-read. */
    assert!(start.elapsed() >= Duration::from_millis(25));
    watching(&data, data.root());
    let a = child(&data, data.root(), "a");
    fs::rename(dir.path().join("a"), dir.path().join("renamed")).unwrap();
    eventually(|| resource::entry(&data.source(), a).unwrap().name == "renamed");
    drop(view);
    eventually(|| data.watch_status().directories == 0 && !data.data().has_work());
    fs::write(dir.path().join("after-detach"), b"x").unwrap();
    std::thread::sleep(Duration::from_millis(200));
    assert_eq!(data.source().node(data.root()).unwrap().child_count(), 3);
    let _view = state.attach().unwrap();
    eventually(|| data.source().node(data.root()).unwrap().child_count() == 4);
    watching(&data, data.root());
}

#[cfg(any(target_os = "macos", target_os = "linux", windows))]
#[test]
fn t_native_watch_publishes_continuous_changes_within_the_merge_limit() {
    let dir = TempDir::new();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    /* Changes every 10 ms never settle; the first of them still publish within the merge limit. */
    let start = Instant::now();
    let mut first_visible = None;
    let mut written = 0;
    while start.elapsed() < Duration::from_millis(600) {
        fs::write(dir.path().join(format!("file-{written:03}")), b"x").unwrap();
        written += 1;
        if first_visible.is_none() && data.source().node(data.root()).unwrap().child_count() > 0 {
            first_visible = Some(start.elapsed());
        }
        std::thread::sleep(Duration::from_millis(10));
    }
    let first_visible = first_visible.expect("changes published while they continued");
    assert!(
        first_visible < Duration::from_millis(400),
        "{first_visible:?}"
    );
    eventually(|| data.source().node(data.root()).unwrap().child_count() == written);
}

#[cfg(any(target_os = "macos", target_os = "linux", windows))]
#[test]
fn t_native_watch_spaces_re_reads_under_periodic_changes() {
    let dir = TempDir::new();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    /* Changes 50 ms apart settle between events, yet after the first re-read they merge for the whole window. */
    let start = Instant::now();
    let (mut revision, mut revisions, mut written) = (data.source().revision(), 0, 0);
    while start.elapsed() < Duration::from_millis(1000) {
        if start.elapsed() >= Duration::from_millis(50 * written as u64) {
            fs::write(dir.path().join(format!("file-{written:03}")), b"x").unwrap();
            written += 1;
        }
        if data.source().revision() != revision {
            revision = data.source().revision();
            revisions += 1;
        }
        std::thread::sleep(Duration::from_millis(1));
    }
    assert!(
        revisions <= 10,
        "{revisions} re-reads for {written} changes"
    );
    eventually(|| data.source().node(data.root()).unwrap().child_count() == written);
}

#[test]
fn t_watch_changes_settle_quietly_unless_activity_continues() {
    let ms = Duration::from_millis;
    let first = Instant::now() + ms(1000);
    /* Changes settle QUIET after their latest event, at most MERGE after the first. */
    assert_eq!(settled(first, first, None), first + QUIET);
    assert_eq!(settled(first, first + ms(20), None), first + ms(20) + QUIET);
    assert_eq!(settled(first, first + ms(140), None), first + MERGE);
    assert_eq!(settled(first, first, Some(first - MERGE)), first + QUIET);
    /* Changes that start within MERGE of the previous merged re-read merge for the whole window. */
    assert_eq!(settled(first, first, Some(first - ms(100))), first + MERGE);
    assert_eq!(
        settled(first, first + ms(140), Some(first - ms(1))),
        first + MERGE
    );
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_watch_budget_prefers_visible_directories() {
    let dir = TempDir::new();
    for i in 0..60 {
        fs::create_dir(dir.path().join(format!("dir-{i:02}"))).unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    if cfg!(target_os = "macos") {
        eventually(|| data.watch_status().directories == 61 && !data.watch_status().limited);
        assert_eq!(data.watch_status().roots, 1);
        let last = child(&data, data.root(), "dir-59");
        fs::write(dir.path().join("dir-59/new"), "covered").unwrap();
        eventually(|| data.source().node(last).unwrap().child_count() == 1);
        watching(&data, last);
        return;
    }
    eventually(|| {
        data.watch_status().roots == 50
            && data.watch_status().directories == 49
            && data.watch_status().limited
    });
    let source = data.source();
    let uncovered = source
        .node(data.root())
        .unwrap()
        .children()
        .find(|id| !data.watch_status().covered.contains(id))
        .unwrap();
    let budget = data.data().memory();
    let _memory = budget.enter();
    data.set_viewports(vec![super::Viewport {
        state: state.id(),
        root: Root::ChildrenOf(data.root()),
        nodes: vec![uncovered].into(),
        _memory: crate::ux::treeview::memory::Charge::new(8),
    }])
    .unwrap();
    eventually(|| data.watch_status().covered.contains(&uncovered));
    assert_eq!(data.watch_status().roots, 50);
    assert_eq!(data.watch_status().directories, 49);
    assert!(data.watch_status().limited);
}

#[cfg(target_os = "macos")]
#[test]
fn t_recursive_watch_keeps_wide_expansion_and_closed_cache_fresh() {
    let dir = TempDir::new();
    for index in 0..96 {
        let path = dir.path().join(format!("dir-{index:02}"));
        fs::create_dir(&path).unwrap();
        fs::write(path.join("seed"), "seed").unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let wide = state(&data, Mode::Tree);
    let view = wide.attach().unwrap();
    watching(&data, data.root());
    let nodes: Vec<_> = data
        .source()
        .node(data.root())
        .unwrap()
        .children()
        .collect();
    ticket(wide.dispatch(
        Command::SetExpanded {
            targets: Targets::Nodes(nodes.into()),
            value: true,
            scope: Scope::SelfOnly,
        },
        Context::default(),
    ));
    let first = child(&data, data.root(), "dir-00");
    let last = child(&data, data.root(), "dir-95");
    watching(&data, last);
    eventually(|| data.watch_status().directories == 97);
    assert_eq!(data.watch_status().roots, 1);
    assert!(!data.watch_status().limited);
    fs::write(
        dir.path().join("dir-95/new"),
        "outside the old fifty-directory cap",
    )
    .unwrap();
    eventually(|| data.source().node(last).unwrap().child_count() == 2);

    fs::rename(dir.path().join("dir-95"), dir.path().join("renamed")).unwrap();
    eventually(|| resource::entry(&data.source(), last).unwrap().name == "renamed");
    watching(&data, last);
    fs::write(dir.path().join("renamed/after-rename"), "fresh").unwrap();
    eventually(|| data.source().node(last).unwrap().child_count() == 3);

    ticket(wide.dispatch(
        Command::SetExpanded {
            targets: Targets::Nodes(vec![first].into()),
            value: false,
            scope: Scope::SelfOnly,
        },
        Context::default(),
    ));
    eventually(|| !data.watch_status().covered.contains(&first));
    assert_eq!(data.watch_status().roots, 1);
    fs::write(dir.path().join("dir-00/while-closed"), "fresh").unwrap();
    std::thread::sleep(Duration::from_millis(250));
    assert_eq!(data.source().node(first).unwrap().child_count(), 1);
    ticket(wide.dispatch(
        Command::SetExpanded {
            targets: Targets::Nodes(vec![first].into()),
            value: true,
            scope: Scope::SelfOnly,
        },
        Context::default(),
    ));
    eventually(|| data.source().node(first).unwrap().child_count() == 2);
    watching(&data, first);

    fs::remove_dir_all(dir.path().join("renamed")).unwrap();
    eventually(|| !data.source().contains(last));
    watching(&data, data.root());
    let Outcome::State(narrow) =
        ticket(data.create_state(Some(Root::ChildrenOf(first)), DisplayOptions::default()))
    else {
        panic!("state")
    };
    let _narrow = narrow.attach().unwrap();
    drop(view);
    watching(&data, first);
    eventually(|| data.watch_status().directories == 1);
    assert_eq!(data.watch_status().roots, 1);
    assert!(!data.watch_status().limited);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_overlapping_viewports_preserve_each_roots_visible_ancestors() {
    let dir = TempDir::new();
    for i in 0..60 {
        fs::create_dir(dir.path().join(format!("dir-{i:02}"))).unwrap();
    }
    fs::create_dir_all(dir.path().join("zz-parent/middle/narrow")).unwrap();
    fs::write(dir.path().join("zz-parent/middle/narrow/leaf"), "content").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let wide = state(&data, Mode::List);
    let _wide_view = wide.attach().unwrap();
    watching(&data, data.root());
    let parent = child(&data, data.root(), "zz-parent");
    loaded(&data, parent);
    let middle = child(&data, parent, "middle");
    loaded(&data, middle);
    let narrow_root = child(&data, middle, "narrow");
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
    if cfg!(target_os = "macos") {
        eventually(|| data.watch_status().directories == 64 && !data.watch_status().limited);
        assert_eq!(data.watch_status().roots, 1);
    } else {
        eventually(|| {
            data.watch_status().roots == 50
                && data.watch_status().directories == 49
                && data.watch_status().limited
        });
        assert!(!data.watch_status().covered.contains(&parent));
    }
    let marker = data
        .source()
        .node(data.root())
        .unwrap()
        .children()
        .find(|id| {
            *id != parent
                && (cfg!(target_os = "macos") || !data.watch_status().covered.contains(id))
        })
        .unwrap();
    data.set_viewports(vec![
        super::Viewport {
            state: narrow.id(),
            root: Root::ChildrenOf(narrow_root),
            nodes: vec![leaf].into(),
            _memory: crate::ux::treeview::memory::Charge::new(8),
        },
        super::Viewport {
            state: wide.id(),
            root: Root::ChildrenOf(data.root()),
            nodes: vec![leaf, marker].into(),
            _memory: crate::ux::treeview::memory::Charge::new(16),
        },
    ])
    .unwrap();
    eventually(|| data.watch_status().covered.contains(&marker));
    let status = data.watch_status();
    assert!(status.covered.contains(&parent));
    assert!(status.covered.contains(&narrow_root));
    assert_eq!(
        status.directories,
        if cfg!(target_os = "macos") { 64 } else { 49 }
    );
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_directory_aliases_share_os_watch_and_refresh_each_occurrence() {
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("target")).unwrap();
    for i in 0..55 {
        symlink("target", dir.path().join(format!("alias-{i:02}"))).unwrap();
    }
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    eventually(|| data.watch_status().covered.len() == 57);
    assert_eq!(data.watch_status().directories, 2);
    assert!(!data.watch_status().limited);
    fs::write(dir.path().join("target/new"), b"x").unwrap();
    eventually(|| {
        let source = data.source();
        source
            .node(data.root())
            .unwrap()
            .children()
            .all(|id| source.node(id).unwrap().child_count() == 1)
    });
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_shared_alias_roots_watch_each_occurrence_parent() {
    use std::os::unix::fs::symlink;
    let dir = TempDir::new();
    for name in ["target", "p1", "p2"] {
        fs::create_dir(dir.path().join(name)).unwrap();
    }
    fs::write(dir.path().join("target/old"), "old").unwrap();
    symlink("../target", dir.path().join("p1/alias")).unwrap();
    symlink("../target", dir.path().join("p2/alias")).unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let first = request(data.resolve(dir.path().join("p1/alias"))).node;
    let second = request(data.resolve(dir.path().join("p2/alias"))).node;
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
    fs::remove_file(dir.path().join("p2/alias")).unwrap();
    eventually(|| !data.source().contains(second));
    eventually(|| states[1].snapshot().unwrap().is_empty());
    assert!(data.source().contains(first));
    fs::write(dir.path().join("target/new"), "new").unwrap();
    eventually(|| data.source().node(first).unwrap().child_count() == 2);
    assert_eq!(
        fs::read_to_string(dir.path().join("target/old")).unwrap(),
        "old"
    );
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_link_root_observes_referent_recreation_outside_its_occurrence_parent() {
    use std::os::unix::fs::symlink;
    for absolute in [false, true] {
        let dir = TempDir::new();
        fs::create_dir(dir.path().join("links")).unwrap();
        fs::create_dir(dir.path().join("target")).unwrap();
        fs::write(dir.path().join("target/old"), "old").unwrap();
        if absolute {
            for index in 0..55 {
                fs::create_dir(dir.path().join(format!("target/sub-{index:02}"))).unwrap();
            }
        }
        let target = if absolute {
            dir.path().join("target")
        } else {
            PathBuf::from("../target")
        };
        symlink(target, dir.path().join("links/alias")).unwrap();
        let data = request(Filetree::open(dir.path().join("links/alias")));
        let state = state(&data, if absolute { Mode::List } else { Mode::Tree });
        let _view = state.attach().unwrap();
        watching(&data, data.root());
        assert_eq!(
            data.watch_status().directories,
            if absolute {
                if cfg!(target_os = "macos") { 58 } else { 50 }
            } else {
                3
            }
        );
        assert_eq!(
            data.watch_status().limited,
            absolute && !cfg!(target_os = "macos")
        );
        let old = child(&data, data.root(), "old");
        fs::remove_dir_all(dir.path().join("target")).unwrap();
        eventually(|| !data.source().node(data.root()).unwrap().data.can_expand);
        eventually(|| data.watch_status().directories == 2 && !data.data().has_work());
        std::thread::sleep(Duration::from_millis(200));
        fs::create_dir(dir.path().join("target")).unwrap();
        fs::write(dir.path().join("target/new"), "new").unwrap();
        eventually(|| data.source().node(data.root()).unwrap().child_count() == 1);
        watching(&data, data.root());
        assert!(!data.source().contains(old));
        child(&data, data.root(), "new");
    }
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_busy_recovery_probe_retries_without_another_event() {
    // Saturates the shared IO pool, which parallel tests also use.
    if !isolated(concat!(
        module_path!(),
        "::t_busy_recovery_probe_retries_without_another_event"
    )) {
        return;
    }
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Condvar, Mutex};
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("target")).unwrap();
    std::os::unix::fs::symlink("target", dir.path().join("link")).unwrap();
    let data = request(Filetree::open(dir.path().join("link")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    fs::remove_dir(dir.path().join("target")).unwrap();
    eventually(|| {
        !data.source().node(data.root()).unwrap().data.can_expand && !data.data().has_work()
    });
    eventually(|| data.watch_status().directories == 1);
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
    eventually(|| started.load(Ordering::Acquire) == 4);
    for _ in 0..256 {
        work::submit(Box::new(|| {})).unwrap();
    }
    let full = work::Request::<()>::run(|| Ok(()));
    assert!(matches!(full.poll(), Some(Err(error)) if error.code == ErrorCode::Busy));
    let watch_revision = data.watch_status().revision;
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(dir.path().join("target/recovered"), "content").unwrap();
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
    eventually(|| data.source().node(data.root()).unwrap().child_count() == 1);
    watching(&data, data.root());
    child(&data, data.root(), "recovered");
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_nested_directory_links_observe_referent_recreation() {
    for mode in [Mode::Tree, Mode::List] {
        let dir = TempDir::new();
        fs::create_dir(dir.path().join("workspace")).unwrap();
        fs::create_dir(dir.path().join("target")).unwrap();
        fs::write(dir.path().join("target/old"), "old").unwrap();
        std::os::unix::fs::symlink("../target", dir.path().join("workspace/link")).unwrap();
        let data = request(Filetree::open(dir.path().join("workspace")));
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
        fs::remove_dir_all(dir.path().join("target")).unwrap();
        eventually(|| !data.source().node(link).unwrap().data.can_expand);
        /* Do not let a lingering referent watch mask the missing parent recovery watch. */
        eventually(|| {
            data.watch_status().directories < registered
                && !data.data().has_work()
                && data.data().queue_depth() == 0
        });
        std::thread::sleep(Duration::from_millis(200));
        fs::create_dir(dir.path().join("target")).unwrap();
        fs::write(dir.path().join("target/new"), "new").unwrap();
        eventually(|| data.source().node(link).unwrap().child_count() == 1);
        watching(&data, link);
        assert!(!data.source().contains(old));
        child(&data, link, "new");
        assert_eq!(data.watch_status().directories, 3);
        drop(view);
        eventually(|| data.watch_status().directories == 0);
    }
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
#[ignore = "native watch-root budget stress; run with a file descriptor limit of at least 4096"]
fn t_native_link_watch_budget_stress() {
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("workspace/visible")).unwrap();
    for index in 0..55 {
        let parent = dir.path().join(format!("external-{index:02}"));
        fs::create_dir_all(parent.join("target")).unwrap();
        std::os::unix::fs::symlink(
            parent.join("target"),
            dir.path().join(format!("workspace/link-{index:02}")),
        )
        .unwrap();
    }
    let data = request(Filetree::open(dir.path().join("workspace")));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let visible = child(&data, data.root(), "visible");
    let link = child(&data, data.root(), "link-54");
    data.set_viewports(vec![super::Viewport {
        state: state.id(),
        root: Root::ChildrenOf(data.root()),
        nodes: vec![visible, link].into(),
        _memory: crate::ux::treeview::memory::Charge::new(16),
    }])
    .unwrap();
    eventually(|| {
        let status = data.watch_status();
        status.limited
            && (if cfg!(target_os = "macos") {
                status.roots
            } else {
                status.directories
            }) == 50
            && status.covered.contains(&visible)
            && status.covered.contains(&link)
    });
    watching(&data, link);
    fs::write(dir.path().join("workspace/visible/new"), "visible").unwrap();
    eventually(|| data.source().node(visible).unwrap().child_count() == 1);
    fs::remove_dir(dir.path().join("external-54/target")).unwrap();
    eventually(|| !data.source().node(link).unwrap().data.can_expand);
    std::thread::sleep(Duration::from_millis(250));
    fs::create_dir(dir.path().join("external-54/target")).unwrap();
    fs::write(dir.path().join("external-54/target/new"), "recovered").unwrap();
    eventually(|| data.source().node(link).unwrap().child_count() == 1);
    let status = data.watch_status();
    assert!(
        (if cfg!(target_os = "macos") {
            status.roots
        } else {
            status.directories
        }) <= 50
    );
    child(&data, link, "new");
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_alias_recovery_budget_counts_resolved_parent_identities() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("workspace")).unwrap();
    fs::create_dir_all(dir.path().join("external/repeat")).unwrap();
    fs::create_dir(dir.path().join("external/target")).unwrap();
    fs::write(dir.path().join("external/target/old"), "old").unwrap();
    for index in 0..55 {
        let target = format!("../external/{}target", "repeat/../".repeat(index));
        std::os::unix::fs::symlink(
            target,
            dir.path().join(format!("workspace/link-{index:02}")),
        )
        .unwrap();
    }
    let data = request(Filetree::open(dir.path().join("workspace")));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    eventually(|| data.watch_status().directories == 3);
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
    eventually(|| {
        links
            .iter()
            .all(|node| data.source().node(*node).unwrap().child_count() == 1)
    });
    fs::remove_dir_all(dir.path().join("external/target")).unwrap();
    eventually(|| {
        links
            .iter()
            .all(|node| !data.source().node(*node).unwrap().data.can_expand)
    });
    eventually(|| data.watch_status().directories == 2 && !data.data().has_work());
    std::thread::sleep(Duration::from_millis(200));
    fs::create_dir(dir.path().join("external/target")).unwrap();
    fs::write(dir.path().join("external/target/new"), "new").unwrap();
    eventually(|| {
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
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(dir.path().join("target/old"), b"x").unwrap();
    symlink("target", dir.path().join("alias")).unwrap();
    let data = request(Filetree::open(dir.path().join("alias")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let old = child(&data, data.root(), "old");
    fs::remove_dir_all(dir.path().join("target")).unwrap();
    eventually(|| !data.source().node(data.root()).unwrap().data.can_expand);
    assert!(!data.source().contains(old));
    fs::create_dir(dir.path().join("target")).unwrap();
    fs::write(dir.path().join("target/new"), b"x").unwrap();
    eventually(|| data.source().node(data.root()).unwrap().child_count() == 1);
    watching(&data, data.root());
    child(&data, data.root(), "new");
}

#[cfg(target_os = "macos")]
#[test]
fn t_narrow_symlink_workspace_keeps_its_anchor_subscription_only() {
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("target/sub")).unwrap();
    fs::write(dir.path().join("target/sub/seed"), "seed").unwrap();
    std::os::unix::fs::symlink("target", dir.path().join("alias")).unwrap();
    let data = request(Filetree::open(dir.path().join("alias")));
    let sub = request(data.resolve(dir.path().join("alias/sub"))).node;
    let Outcome::State(state) =
        ticket(data.create_state(Some(Root::ChildrenOf(sub)), DisplayOptions::default()))
    else {
        panic!("state")
    };
    let _view = state.attach().unwrap();
    watching(&data, sub);
    let status = data.watch_status();
    assert_eq!(status.roots, 1);
    assert_eq!(status.directories, 1);
    assert!(!status.covered.contains(&data.root()));
    assert!(!status.limited);
    fs::write(dir.path().join("target/sub/new"), "new").unwrap();
    eventually(|| data.source().node(sub).unwrap().child_count() == 2);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_directory_watch_observes_in_place_file_writes_without_replacing_identity() {
    let dir = TempDir::new();
    fs::write(dir.path().join("file"), "a").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let file = child(&data, data.root(), "file");
    let old = data.inspect(data.source(), file).unwrap();
    fs::write(dir.path().join("file"), "changed contents").unwrap();
    eventually(|| resource::entry(&data.source(), file).unwrap().size == 16);
    assert_eq!(old.entry().unwrap().size, 1);
    assert_eq!(child(&data, data.root(), "file"), file);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_watched_directory_rename_keeps_following_file_metadata() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("before")).unwrap();
    fs::write(dir.path().join("before/file"), "a").unwrap();
    let data = request(Filetree::open(dir.path().to_path_buf()));
    let state = state(&data, Mode::List);
    let _view = state.attach().unwrap();
    loaded(&data, data.root());
    let folder = child(&data, data.root(), "before");
    watching(&data, folder);
    let file = child(&data, folder, "file");
    fs::rename(dir.path().join("before"), dir.path().join("café")).unwrap();
    eventually(|| resource::entry(&data.source(), folder).unwrap().name == "café");
    watching(&data, folder);
    fs::write(dir.path().join("café/file"), "new contents").unwrap();
    eventually(|| resource::entry(&data.source(), file).unwrap().size == 12);
    assert_eq!(child(&data, data.root(), "café"), folder);
}

#[cfg(any(target_os = "macos", target_os = "linux"))]
#[test]
fn t_unicode_directory_watch_updates_existing_files() {
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("目录-café")).unwrap();
    fs::write(dir.path().join("目录-café/file"), "a").unwrap();
    let data = request(Filetree::open(dir.path().join("目录-café")));
    let state = state(&data, Mode::Tree);
    let _view = state.attach().unwrap();
    watching(&data, data.root());
    let file = child(&data, data.root(), "file");
    fs::write(dir.path().join("目录-café/file"), "changed").unwrap();
    eventually(|| resource::entry(&data.source(), file).unwrap().size == 7);
}
