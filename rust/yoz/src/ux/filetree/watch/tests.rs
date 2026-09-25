use super::*;
use crate::ux::filetree::{Entry, tests::Directory};
use std::fs;

#[test]
#[ignore = "explicit real OS notification latency measurement"]
fn t_native_watch_notification_latency() {
    let directory = Directory::new();
    let engine = Engine::new(Limits::default()).unwrap();
    let _memory = engine.memory.enter();
    let entry = Entry::read(&directory.0).unwrap();
    let target = Target {
        identity: entry.identity,
        path: Arc::new(directory.0.clone()),
        nodes: Arc::new(Vec::new()),
        _memory: Arc::new(Charge::new(1024)),
    };
    let mut backend = backend::Backend::new().unwrap();
    backend.add(1, &target).unwrap();
    let startup = Instant::now();
    while !backend.ready() {
        backend.poll().unwrap();
        assert!(
            startup.elapsed() < Duration::from_secs(5),
            "watch did not become ready"
        );
        std::thread::sleep(Duration::from_millis(1));
    }
    let mut times = Vec::new();
    for index in 0..20 {
        backend.poll().unwrap();
        let began = Instant::now();
        fs::write(directory.0.join(format!("event-{index}")), b"data").unwrap();
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
        times[9], times[18], times[19]
    );
    backend.remove(1);
}

#[test]
fn t_watch_restarts_after_retained_memory_recovers() {
    let until = |predicate: &mut dyn FnMut() -> bool| {
        let started = Instant::now();
        while !predicate() {
            assert!(
                started.elapsed() < Duration::from_secs(10),
                "watch recovery timed out"
            );
            std::thread::sleep(Duration::from_millis(1));
        }
    };
    let directory = Directory::new();
    let mut entry = Entry::read(&directory.0).unwrap();
    entry.anchor = Some(directory.0.clone());
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
    until(&mut || interest.lock().unwrap().status.covered.as_ref() == [root]);
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
    until(&mut || previous.upgrade().is_none());

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
    until(&mut || {
        let status = &interest.lock().unwrap().status;
        status.error.is_none() && status.covered.as_ref() == [root]
    });
}

#[test]
fn t_recovery_targets_preserve_priority_deduplication_and_capacity() {
    let directory = Directory::new();
    let targets: Vec<_> = (0..LIMIT)
        .map(|index| {
            let path = directory.0.join(format!("target-{index}"));
            fs::create_dir(&path).unwrap();
            Target {
                identity: Entry::read(&path).unwrap().identity,
                path: Arc::new(path),
                nodes: Arc::new(vec![NodeId(index as u64 + 1)]),
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
        let path = directory.0.join(name);
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
    assert!(limited);
    assert_eq!(targets.len(), LIMIT);
    assert_eq!(targets[0].identity, root);
    assert_eq!(targets[1].nodes.as_slice(), &[NodeId(100)]);
    assert_eq!(targets[2].identity, visible);
    assert_eq!(targets[3].nodes.as_slice(), &[NodeId(101), NodeId(102)]);
    assert!(
        targets
            .iter()
            .all(|target| !target.nodes.contains(&NodeId(103)))
    );
}

#[test]
fn t_watch_delivery_clears_only_its_recovered_queue_error() {
    use std::sync::mpsc;
    struct Hold(mpsc::Sender<()>, mpsc::Receiver<()>);
    impl NativeAction for Hold {
        fn bytes(&self) -> usize {
            0
        }
        fn apply(self: Box<Self>, _: &mut Engine) -> Result<Reply> {
            self.0.send(()).unwrap();
            let _ = self.1.recv();
            Ok(Reply::NoChange)
        }
    }
    let until = |predicate: &mut dyn FnMut() -> bool| {
        let started = Instant::now();
        while !predicate() {
            assert!(
                started.elapsed() < Duration::from_secs(10),
                "watch delivery timed out"
            );
            std::thread::sleep(Duration::from_millis(1));
        }
    };
    let directory = Directory::new();
    let entry = Entry::read(&directory.0).unwrap();
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
            path: Arc::new(directory.0.clone()),
            nodes: Arc::new(vec![node]),
            _memory: Arc::new(Charge::new(0)),
        }],
        recoveries: Vec::new(),
        root_targets: 1,
        limited: false,
    });
    until(&mut || {
        interest.lock().unwrap().status.covered.contains(&node)
            && dirty.lock().unwrap().get(&node).is_some()
    });
    *dirty.lock().unwrap() = Map::default();
    let (started, ready) = mpsc::channel();
    let (release, wait) = mpsc::channel();
    let held = data.submit(Action::Native(Box::new(Hold(started, wait))));
    ready.recv_timeout(Duration::from_secs(10)).unwrap();
    let queued = data.submit(Action::CreateState(
        Root::ChildrenOf(node),
        DisplayOptions::default(),
    ));
    fs::write(directory.0.join("first"), "content").unwrap();
    until(&mut || {
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
    until(&mut || dirty.lock().unwrap().get(&node).is_some());
    until(&mut || interest.lock().unwrap().status.error.is_none());
    assert_eq!(data.source().revision(), revision);

    let other = Error::new(ErrorCode::ProviderError, "another watch failure");
    let mut watcher = Watcher::new(interest.clone(), dirty.clone());
    watcher.error(other.clone());
    let generation = dirty.lock().unwrap().get(&node).unwrap().generation;
    fs::write(directory.0.join("second"), "content").unwrap();
    until(&mut || dirty.lock().unwrap().get(&node).unwrap().generation != generation);
    std::thread::sleep(Duration::from_millis(50));
    assert_eq!(interest.lock().unwrap().status.error, Some(other));
}

#[test]
fn t_watch_path_registration_failure_retries_without_false_coverage() {
    let until = |predicate: &mut dyn FnMut() -> bool| {
        let started = Instant::now();
        while !predicate() {
            assert!(
                started.elapsed() < Duration::from_secs(10),
                "watch wait timed out"
            );
            std::thread::sleep(Duration::from_millis(1));
        }
    };
    let directory = Directory::new();
    let before = directory.0.join("before");
    let parked = directory.0.join("parked");
    let after = directory.0.join("after");
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
            _memory: Arc::new(Charge::new(0)),
        }],
        recoveries: Vec::new(),
        root_targets: 1,
        limited: false,
    };
    controller.update(desired(before.clone()));
    until(&mut || interest.lock().unwrap().status.covered.as_ref() == [node]);

    /* The desired path was replaced after discovery, so registration must reject its identity. */
    fs::rename(&before, &parked).unwrap();
    fs::create_dir(&after).unwrap();
    controller.update(desired(after.clone()));
    until(&mut || interest.lock().unwrap().status.error.is_some());
    let failed = interest.lock().unwrap().status.clone();
    assert_eq!(failed.directories, 0);
    assert!(failed.covered.is_empty());
    assert_eq!(failed.error.unwrap().code, ErrorCode::Stale);

    /* A second failed attempt at the same desired path must actually retry the backend. */
    fs::remove_dir(&after).unwrap();
    controller.update(desired(after.clone()));
    until(&mut || interest.lock().unwrap().status.revision > failed.revision);
    let failed = interest.lock().unwrap().status.clone();
    assert_eq!(failed.directories, 0);
    assert!(failed.covered.is_empty());
    assert_eq!(failed.error.unwrap().code, ErrorCode::ProviderError);

    fs::rename(&parked, &after).unwrap();
    controller.update(desired(after.clone()));
    until(&mut || {
        let status = &interest.lock().unwrap().status;
        status.error.is_none() && status.directories == 1 && status.covered.as_ref() == [node]
    });
    until(&mut || dirty.lock().unwrap().get(&node).is_some() && !data.has_work());
    *dirty.lock().unwrap() = Map::default();
    fs::write(after.join("created"), "content").unwrap();
    until(&mut || dirty.lock().unwrap().get(&node).is_some());
}
