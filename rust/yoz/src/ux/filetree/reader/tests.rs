use super::super::tests::{Directory, request};
use super::super::{Entry, Filetree};
use super::*;
use crate::ux::treeview::*;
use std::fs;
use std::path::Path;
use std::time::Instant;

fn filesystem_engine(
    path: &Path,
    names: &[&str],
) -> (Engine, Arc<Mutex<super::super::index::Index>>) {
    let mut entry = Entry::read(path).unwrap();
    entry.anchor = Some(path.to_owned());
    let mut records = vec![Record::new("root", entry.node_data())];
    records.extend(names.iter().map(|&name| {
        Record {
            key: name.into(),
            parent: Some(
                name.rsplit_once('/')
                    .map_or("root", |(parent, _)| parent)
                    .into(),
            ),
            data: Entry::read(&path.join(name)).unwrap().node_data(),
            completeness: Some(Completeness::Complete),
        }
    }));
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let mut index = super::super::index::Index::default();
    for name in std::iter::once("root").chain(names.iter().copied()) {
        index
            .insert(engine.source(), engine.source().id(name).unwrap())
            .unwrap();
    }
    (engine, Arc::new(Mutex::new(index)))
}

fn start_read(engine: &mut Engine, node: NodeId) -> ReadToken {
    engine
        .request_children(&[node], true)
        .unwrap()
        .into_effects()
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } if token.node == node => Some(*token),
            _ => None,
        })
        .expect("admitted read")
}

#[test]
fn t_scan_initialization_cancels_before_io_and_during_cached_member_alignment() {
    let directory = Directory::new();
    fs::write(directory.0.join("seed"), b"content").unwrap();
    let (mut engine, _) = filesystem_engine(&directory.0, &[]);
    let root = engine.source().id("root").unwrap();
    let staging = Arc::new(AtomicUsize::new(0));
    let cancelled = AtomicBool::new(true);
    let result = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &cancelled,
    );
    assert!(matches!(result, Err(error) if error.code == ErrorCode::Stale));
    assert_eq!(staging.load(Ordering::Acquire), 0);

    /* Synthetic cached members exercise initialization only; no large directory is scanned. */
    let mut entry = Entry::read(&directory.0.join("seed")).unwrap();
    let operations = (0..50_000)
        .map(|index| {
            entry.name = format!("cached-{index:05}").into();
            Operation::Insert {
                key: format!("cached-{index:05}").into(),
                parent: Some(root.into()),
                position: Position::Last,
                data: entry.node_data(),
                completeness: Completeness::Complete,
            }
        })
        .collect();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations,
        })
        .unwrap();
    let before = engine.memory.used();
    cancelled.store(false, Ordering::Release);
    let finished = AtomicBool::new(false);
    let ready = std::sync::Barrier::new(2);
    std::thread::scope(|scope| {
        scope.spawn(|| {
            ready.wait();
            while staging.load(Ordering::Acquire) < 512 * 1024 {
                if finished.load(Ordering::Acquire) {
                    return;
                }
                std::thread::yield_now();
            }
            cancelled.store(true, Ordering::Release);
        });
        ready.wait();
        let result = Scan::new(
            engine.source(),
            root,
            Reservation::new(engine.memory.clone(), staging.clone()),
            &cancelled,
        );
        finished.store(true, Ordering::Release);
        assert!(matches!(result, Err(error) if error.code == ErrorCode::Stale));
    });
    assert!(cancelled.load(Ordering::Acquire));
    assert_eq!(staging.load(Ordering::Acquire), 0);
    assert_eq!(engine.memory.used(), before);
}

#[test]
fn t_wide_cached_scan_fits_the_existing_staging_limit() {
    let directory = Directory::new();
    fs::write(directory.0.join("seed"), b"content").unwrap();
    let (mut engine, _) = filesystem_engine(&directory.0, &[]);
    let root = engine.source().id("root").unwrap();
    let mut entry = Entry::read(&directory.0.join("seed")).unwrap();
    for first in (0..100_000).step_by(2048) {
        let operations = (first..(first + 2048).min(100_000))
            .map(|index| {
                entry.name = format!("cached-{index:06}").into();
                Operation::Insert {
                    key: format!("cached-{index:06}").into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                    data: entry.node_data(),
                    completeness: Completeness::Complete,
                }
            })
            .collect();
        engine
            .apply_batch(Batch {
                base_revision: engine.source().revision(),
                operations,
            })
            .unwrap();
    }
    let before = engine.memory.used();
    let staging = Arc::new(AtomicUsize::new(0));
    let cancelled = AtomicBool::new(false);
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &cancelled,
    )
    .unwrap_or_else(|error| {
        panic!("100k captured children must fit the existing scan budget: {error:?}")
    });
    let page = scan
        .page(
            root,
            Reservation::new(engine.memory.clone(), staging.clone()),
            &cancelled,
        )
        .unwrap();
    assert!(page.done);
    assert_eq!(page.members.len(), 1);
    assert!(staging.load(Ordering::Acquire) <= 32 * super::super::scan::PAGE_BYTES);
    drop(scan);
    assert!(
        staging.load(Ordering::Acquire) > 0,
        "the returned page keeps its own reservation"
    );
    drop(page);
    assert_eq!(staging.load(Ordering::Acquire), 0);
    assert_eq!(engine.memory.used(), before);
}

#[test]
fn t_scan_sparse_order_tracks_paged_renames_replacements_and_ambiguous_links() {
    let directory = Directory::new();
    let names: Vec<_> = (0..4096).map(|index| format!("a-{index:04}")).collect();
    for (number, name) in names.iter().enumerate() {
        if number != 1199 {
            fs::write(directory.0.join(name), b"original").unwrap();
        }
    }
    fs::hard_link(
        directory.0.join(&names[1198]),
        directory.0.join(&names[1199]),
    )
    .unwrap();
    let refs: Vec<_> = names.iter().map(String::as_str).collect();
    let (mut engine, index) = filesystem_engine(&directory.0, &refs);
    let root = engine.source().id("root").unwrap();
    let original: Vec<_> = names
        .iter()
        .map(|name| engine.source().id(name).unwrap())
        .collect();
    for number in 0..800 {
        fs::rename(
            directory.0.join(&names[number]),
            directory.0.join(format!("z-{number:04}")),
        )
        .unwrap();
        if number < 150 {
            fs::write(directory.0.join(&names[number]), b"replacement").unwrap();
        }
    }
    fs::hard_link(
        directory.0.join(&names[1100]),
        directory.0.join("new-hardlink"),
    )
    .unwrap();
    fs::rename(
        directory.0.join(&names[1101]),
        directory.0.join("moved-hardlink"),
    )
    .unwrap();
    fs::hard_link(
        directory.0.join("moved-hardlink"),
        directory.0.join("another-hardlink"),
    )
    .unwrap();
    for number in [1198, 1199] {
        fs::rename(
            directory.0.join(&names[number]),
            directory.0.join(format!("old-link-{number}")),
        )
        .unwrap();
    }
    fs::create_dir(directory.0.join("new-directory")).unwrap();
    let token = start_read(&mut engine, root);
    let staging = Arc::new(AtomicUsize::new(0));
    let cancelled = AtomicBool::new(false);
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &cancelled,
    )
    .unwrap();
    let mut sequence = 0;
    loop {
        sequence += 1;
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &cancelled,
            )
            .unwrap();
        let done = page.done;
        Box::new(Completion {
            token,
            sequence,
            page,
            index: index.clone(),
        })
        .apply(&mut engine)
        .unwrap();
        let entries: Vec<_> = engine
            .source()
            .node(root)
            .unwrap()
            .children()
            .map(|id| resource::entry(engine.source(), id).unwrap())
            .collect();
        assert!(
            entries
                .windows(2)
                .all(|pair| !pair[0].sort_cmp(&pair[1]).is_gt()),
            "every committed page preserves order"
        );
        if done {
            break;
        }
    }
    assert!(sequence > 2);
    let mut expected: Vec<_> = fs::read_dir(&directory.0)
        .unwrap()
        .map(|entry| Entry::read(&entry.unwrap().path()).unwrap())
        .collect();
    expected.sort_by(Entry::sort_cmp);
    let actual: Vec<_> = engine
        .source()
        .node(root)
        .unwrap()
        .children()
        .map(|id| resource::entry(engine.source(), id).unwrap().name)
        .collect();
    assert_eq!(
        actual,
        expected
            .into_iter()
            .map(|entry| entry.name)
            .collect::<Vec<_>>()
    );
    let current = index.lock().unwrap();
    for number in 0..800 {
        assert_eq!(
            current.child(Some(root), std::ffi::OsStr::new(&format!("z-{number:04}"))),
            Some(original[number])
        );
        if number < 150 {
            assert_ne!(
                current.child(Some(root), std::ffi::OsStr::new(&names[number])),
                Some(original[number])
            );
        }
    }
    assert_eq!(
        current.child(Some(root), std::ffi::OsStr::new(&names[1100])),
        Some(original[1100])
    );
    assert_ne!(
        current.child(Some(root), std::ffi::OsStr::new("new-hardlink")),
        Some(original[1100])
    );
    for number in [1101, 1198, 1199] {
        assert!(!engine.source().contains(original[number]));
    }
    drop(scan);
    assert_eq!(staging.load(Ordering::Acquire), 0);
}

fn scan_stages(count: usize) {
    let directory = Directory::new();
    let names: Vec<_> = (0..count).map(|index| format!("file-{index:06}")).collect();
    for name in &names {
        fs::write(directory.0.join(name), b"test").unwrap();
    }
    let names: Vec<_> = names.iter().map(String::as_str).collect();
    for loaded in [false, true] {
        let (mut engine, index) =
            filesystem_engine(&directory.0, if loaded { &names } else { &[] });
        let root = engine.source().id("root").unwrap();
        let original: Vec<_> = engine.source().node(root).unwrap().children().collect();
        let token = start_read(&mut engine, root);
        let staging = Arc::new(AtomicUsize::new(0));
        let cancelled = AtomicBool::new(false);
        let start = Instant::now();
        let created = Scan::new(
            engine.source(),
            root,
            Reservation::new(engine.memory.clone(), staging.clone()),
            &cancelled,
        );
        let initialization = start.elapsed();
        let mut scan = match created {
            Ok(scan) => scan,
            Err(error) => {
                println!(
                    "scan_stage count={count} loaded={loaded} outcome={:?} initialize_ms={:.3}",
                    error.code,
                    initialization.as_secs_f64() * 1000.0
                );
                assert_eq!(staging.load(Ordering::Acquire), 0);
                continue;
            }
        };
        let mut peak = staging.load(Ordering::Acquire);
        let mut times = [std::time::Duration::ZERO; 2];
        let mut pages = 0;
        let mut failure = None;
        loop {
            let start = Instant::now();
            let result = scan.page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &cancelled,
            );
            times[0] += start.elapsed();
            peak = peak.max(staging.load(Ordering::Acquire));
            let page = match result {
                Ok(page) => page,
                Err(error) => {
                    failure = Some(error.code);
                    break;
                }
            };
            pages += 1;
            let done = page.done;
            let start = Instant::now();
            Box::new(Completion {
                token,
                sequence: pages,
                page,
                index: index.clone(),
            })
            .apply(&mut engine)
            .unwrap();
            times[1] += start.elapsed();
            if done {
                break;
            }
        }
        if failure.is_none() {
            let children: Vec<_> = engine.source().node(root).unwrap().children().collect();
            assert_eq!(children.len(), count);
            assert_eq!(
                engine.source().node(root).unwrap().completeness,
                Completeness::Complete
            );
            for (id, name) in children.iter().zip(&names) {
                assert_eq!(resource::entry(engine.source(), *id).unwrap().name, *name);
            }
            if loaded {
                assert_eq!(children, original);
            }
        }
        let start = Instant::now();
        drop(scan);
        let retired = start.elapsed();
        assert_eq!(staging.load(Ordering::Acquire), 0);
        println!(
            "scan_stage count={count} loaded={loaded} outcome={:?} initialize_ms={:.3} io_ms={:.3} apply_ms={:.3} retire_ms={:.3} pages={pages} staging_peak={peak}",
            failure,
            initialization.as_secs_f64() * 1000.0,
            times[0].as_secs_f64() * 1000.0,
            times[1].as_secs_f64() * 1000.0,
            retired.as_secs_f64() * 1000.0
        );
    }
}

#[test]
#[ignore = "explicit native cold/warm scan measurement"]
fn t_scan_stages_1000() {
    scan_stages(1_000);
}

#[test]
#[ignore = "explicit native cold/warm scan measurement"]
fn t_scan_stages_10000() {
    scan_stages(10_000);
}

#[test]
#[ignore = "explicit native cold/warm scan capacity measurement"]
fn t_scan_stages_100000() {
    scan_stages(100_000);
}

#[test]
fn t_cancelled_worker_keeps_its_scan_pending_until_retirement() {
    let directory = Directory::new();
    let (mut engine, index) = filesystem_engine(&directory.0, &[]);
    let root = engine.source().id("root").unwrap();
    let token = start_read(&mut engine, root);
    let mut reader = Reader::new(
        index,
        Arc::new(Mutex::new(crate::ux::treeview::storage::Map::default())),
        Arc::new(Mutex::new(super::super::watch::Interest::default())),
    );
    let scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), reader.staging.clone()),
        &AtomicBool::new(false),
    )
    .unwrap();
    let slot = Arc::new(Slot {
        node: root,
        scan: Mutex::new(Some(scan)),
        cancelled: AtomicBool::new(false),
        running: AtomicBool::new(true),
    });
    reader.slots.insert(token.work, slot.clone());
    let owner = DataHandle::new(Limits::default()).unwrap();
    let data = owner.downgrade();
    drop(owner);
    let queued = ScanWork {
        slot,
        data: data.clone(),
        started: false,
    };

    assert!(reader.effect(&Effect::CancelChildren { token }));
    engine.children_cancelled(token).unwrap();
    reader.publish(&engine, &data);
    assert!(reader.staging.load(Ordering::Acquire) > 0);
    assert!(
        reader.pending_work.load(Ordering::Acquire),
        "a cancelled queued worker still owns its scan reservation"
    );

    let replacement = start_read(&mut engine, root);
    reader.effect(&Effect::NeedChildren {
        token: replacement,
        sequence: 1,
    });
    reader.publish(&engine, &data);
    assert!(reader.pending.contains_key(&replacement.work));
    assert!(!reader.slots.contains_key(&replacement.work));

    drop(queued);
    assert!(reader.staging.load(Ordering::Acquire) > 0);
    assert!(
        !reader.can_start_work(replacement),
        "worker exit between retention and admission cannot bypass cached scan reclamation"
    );

    /* End this replacement demand so retirement can also be observed without new work. */
    reader.effect(&Effect::CancelChildren { token: replacement });
    engine.children_cancelled(replacement).unwrap();
    reader.publish(&engine, &data);
    assert_eq!(reader.staging.load(Ordering::Acquire), 0);
    assert!(!reader.pending_work.load(Ordering::Acquire));
}

#[test]
fn t_scan_work_rejected_before_execution_does_not_wake_owner() {
    struct Counter(Arc<AtomicUsize>);
    impl NativeReader for Counter {
        fn publish(&mut self, _: &Engine, _: &WeakDataHandle) {
            self.0.fetch_add(1, Ordering::Release);
        }
        fn effect(&mut self, _: &Effect) -> bool {
            false
        }
        fn needs_poll(&self) -> bool {
            false
        }
    }

    let directory = Directory::new();
    let (engine, _) = filesystem_engine(&directory.0, &[]);
    let polls = Arc::new(AtomicUsize::new(0));
    let data =
        DataHandle::with_reader(Limits::default(), Some(Box::new(Counter(polls.clone())))).unwrap();
    let deadline = Instant::now() + std::time::Duration::from_secs(5);
    while !data.is_idle() {
        assert!(Instant::now() < deadline);
        std::thread::yield_now();
    }
    let before = polls.load(Ordering::Acquire);
    let slot = Arc::new(Slot {
        node: engine.source().id("root").unwrap(),
        scan: Mutex::new(None),
        cancelled: AtomicBool::new(false),
        running: AtomicBool::new(true),
    });
    drop(ScanWork {
        slot: slot.clone(),
        data: data.downgrade(),
        started: false,
    });
    assert!(!slot.running.load(Ordering::Acquire));
    while !data.is_idle() {
        assert!(Instant::now() < deadline);
        std::thread::yield_now();
    }
    assert_eq!(
        polls.load(Ordering::Acquire),
        before,
        "a rejected queue submission must preserve the owner's retry backoff"
    );

    slot.running.store(true, Ordering::Release);
    drop(ScanWork {
        slot: slot.clone(),
        data: data.downgrade(),
        started: true,
    });
    while !data.is_idle() {
        assert!(Instant::now() < deadline);
        std::thread::yield_now();
    }
    assert!(!slot.running.load(Ordering::Acquire));
    assert_eq!(
        polls.load(Ordering::Acquire),
        before + 1,
        "completed execution must wake the owner to reclaim cancelled scans"
    );
}

#[cfg(unix)]
#[test]
fn t_delayed_probe_preserves_new_target_children() {
    let dir = Directory::new();
    let target = dir.0.join("target");
    let path = dir.0.join("link");
    std::os::unix::fs::symlink("target", &path).unwrap();
    let tree = request(Filetree::open(dir.0.clone()));
    let link = request(tree.resolve(path.clone()));
    assert!(!link.source.node(link.node).unwrap().data.can_expand);
    let delayed = Probe {
        observed: false,
        source: link.source.clone(),
        node: link.node,
        path: path.clone(),
        entry: Ok(Some(Entry::read(&path).unwrap())),
        index: tree.index.clone(),
    };
    fs::create_dir(&target).unwrap();
    fs::write(target.join("child"), b"confirmed").unwrap();
    let child = request(tree.resolve(path.join("child")));
    assert_eq!(
        child.source.node(child.node).unwrap().parent,
        Some(link.node)
    );
    let revision = tree.source().revision();
    let error = wait(tree.data().submit(Action::Native(Box::new(delayed)))).unwrap_err();
    assert_eq!(error.code, ErrorCode::Stale);
    assert_eq!(tree.source().revision(), revision);
    assert!(tree.source().contains(child.node));
}

#[cfg(unix)]
#[test]
fn t_delayed_parent_page_preserves_new_target_children() {
    for (restored, existing) in [(false, false), (true, false), (true, true)] {
        let dir = Directory::new();
        let workspace = dir.0.join("workspace");
        let target = dir.0.join("target");
        fs::create_dir(&workspace).unwrap();
        fs::create_dir(&target).unwrap();
        if existing {
            fs::write(target.join("child"), b"old").unwrap();
        }
        let path = workspace.join("link");
        std::os::unix::fs::symlink("../target", &path).unwrap();
        let names: &[&str] = if existing {
            &["link", "link/child"]
        } else {
            &["link"]
        };
        let (mut engine, index) = filesystem_engine(&workspace, names);
        let root = engine.source().id("root").unwrap();
        let link = engine.source().id("link").unwrap();
        let original = resource::entry(engine.source(), link).unwrap();
        let token = start_read(&mut engine, root);
        fs::rename(&target, dir.0.join("original")).unwrap();
        fs::create_dir(&target).unwrap();
        let staging = Arc::new(AtomicUsize::new(0));
        let mut scan = Scan::new(
            engine.source(),
            root,
            Reservation::new(engine.memory.clone(), staging.clone()),
            &AtomicBool::new(false),
        )
        .unwrap();
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging),
                &AtomicBool::new(false),
            )
            .unwrap();
        assert!(page.done);
        let baseline = page.source.clone();
        fs::rename(&target, dir.0.join("observed")).unwrap();
        if restored {
            fs::rename(dir.0.join("original"), &target).unwrap();
        } else {
            fs::create_dir(&target).unwrap();
        }
        fs::write(target.join("child"), b"confirmed").unwrap();
        let new = Entry::read(&path).unwrap().node_data();
        let mut operations = Vec::new();
        if !restored {
            operations.push(Operation::Update {
                node: link.into(),
                patch: NodePatch {
                    payload: Some(new.payload),
                    can_expand: Some(new.can_expand),
                    completeness: Some(Completeness::Unknown),
                    ..NodePatch::default()
                },
            });
        } else {
            assert_eq!(Entry::read(&path).unwrap(), original);
        }
        let key = if existing {
            "link/child"
        } else {
            "confirmed-child"
        };
        let data = Entry::read(&path.join("child")).unwrap().node_data();
        operations.push(if existing {
            Operation::Update {
                node: engine.source().id(key).unwrap().into(),
                patch: NodePatch {
                    payload: Some(data.payload),
                    ..NodePatch::default()
                },
            }
        } else {
            Operation::Insert {
                key: key.into(),
                parent: Some(link.into()),
                position: Position::Last,
                data,
                completeness: Completeness::Complete,
            }
        });
        engine
            .apply_batch(Batch {
                base_revision: engine.source().revision(),
                operations,
            })
            .unwrap();
        let child = engine.source().id(key).unwrap();
        index
            .lock()
            .unwrap()
            .insert(engine.source(), child)
            .unwrap();
        if existing {
            assert_eq!(
                baseline.node(link).unwrap().subtree_revision,
                engine.source().node(link).unwrap().subtree_revision
            );
            assert_ne!(
                resource::entry(&baseline, child).unwrap().size,
                resource::entry(engine.source(), child).unwrap().size
            );
        }
        assert!(engine.check_read(token, 1).is_ok());
        let effects = Box::new(Completion {
            token,
            sequence: 1,
            page,
            index,
        })
        .apply(&mut engine)
        .unwrap()
        .into_effects();
        assert!(engine.source().contains(child));
        assert!(effects.iter().any(|effect| {
                matches!(effect, Effect::NeedChildren { token: next, sequence: 1 } if next.node == root && *next != token)
            }));
    }
}

#[test]
fn t_completed_parent_page_preserves_new_children_of_missing_member() {
    let dir = Directory::new();
    let workspace = dir.0.join("workspace");
    let nested = workspace.join("nested");
    fs::create_dir_all(&nested).unwrap();
    let (mut engine, index) = filesystem_engine(&workspace, &["nested"]);
    let root = engine.source().id("root").unwrap();
    let parent = engine.source().id("nested").unwrap();
    let token = start_read(&mut engine, root);
    fs::rename(&nested, dir.0.join("previous")).unwrap();
    let staging = Arc::new(AtomicUsize::new(0));
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &AtomicBool::new(false),
    )
    .unwrap();
    let page = scan
        .page(
            root,
            Reservation::new(engine.memory.clone(), staging),
            &AtomicBool::new(false),
        )
        .unwrap();
    assert!(page.done && page.members.is_empty());
    fs::rename(dir.0.join("previous"), &nested).unwrap();
    fs::write(nested.join("child"), b"confirmed").unwrap();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Insert {
                key: "confirmed-child".into(),
                parent: Some(parent.into()),
                position: Position::Last,
                data: Entry::read(&nested.join("child")).unwrap().node_data(),
                completeness: Completeness::Complete,
            }],
        })
        .unwrap();
    let child = engine.source().id("confirmed-child").unwrap();
    index
        .lock()
        .unwrap()
        .insert(engine.source(), child)
        .unwrap();
    assert!(engine.check_read(token, 1).is_ok());
    let effects = Box::new(Completion {
        token,
        sequence: 1,
        page,
        index,
    })
    .apply(&mut engine)
    .unwrap()
    .into_effects();
    assert!(engine.source().contains(child));
    assert!(effects.iter().any(|effect| {
            matches!(effect, Effect::NeedChildren { token: next, sequence: 1 } if next.node == root && *next != token)
        }));
}

#[test]
fn t_completed_parent_page_preserves_new_descendant_metadata() {
    let dir = Directory::new();
    let workspace = dir.0.join("workspace");
    let nested = workspace.join("nested");
    fs::create_dir_all(&nested).unwrap();
    fs::write(nested.join("child"), b"old").unwrap();
    let (mut engine, index) = filesystem_engine(&workspace, &["nested", "nested/child"]);
    let root = engine.source().id("root").unwrap();
    let parent = engine.source().id("nested").unwrap();
    let child = engine.source().id("nested/child").unwrap();
    let token = start_read(&mut engine, root);
    fs::rename(&nested, dir.0.join("previous")).unwrap();
    let staging = Arc::new(AtomicUsize::new(0));
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &AtomicBool::new(false),
    )
    .unwrap();
    let page = scan
        .page(
            root,
            Reservation::new(engine.memory.clone(), staging),
            &AtomicBool::new(false),
        )
        .unwrap();
    assert!(page.done && page.members.is_empty());
    let baseline = page.source.clone();
    fs::rename(dir.0.join("previous"), &nested).unwrap();
    fs::write(nested.join("child"), b"confirmed").unwrap();
    let metadata = Entry::read(&nested.join("child")).unwrap();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Update {
                node: child.into(),
                patch: NodePatch {
                    payload: Some(metadata.node_data().payload),
                    ..NodePatch::default()
                },
            }],
        })
        .unwrap();
    assert_eq!(
        baseline.node(parent).unwrap().subtree_revision,
        engine.source().node(parent).unwrap().subtree_revision
    );
    assert!(engine.check_read(token, 1).is_ok());
    let effects = Box::new(Completion {
        token,
        sequence: 1,
        page,
        index,
    })
    .apply(&mut engine)
    .unwrap()
    .into_effects();
    assert!(engine.source().contains(child));
    assert_eq!(resource::entry(engine.source(), child).unwrap(), metadata);
    assert!(effects.iter().any(|effect| {
            matches!(effect, Effect::NeedChildren { token: next, sequence: 1 } if next.node == root && *next != token)
        }));
}

#[cfg(unix)]
#[test]
fn t_delayed_failure_preserves_newer_descendant_metadata() {
    for unavailable in [false, true] {
        let dir = Directory::new();
        let workspace = dir.0.join("workspace");
        let target = dir.0.join("target");
        fs::create_dir(&workspace).unwrap();
        fs::create_dir(&target).unwrap();
        fs::write(target.join("child"), b"old").unwrap();
        let path = workspace.join("link");
        std::os::unix::fs::symlink("../target", &path).unwrap();
        let (mut engine, index) = filesystem_engine(&workspace, &["link", "link/child"]);
        let link = engine.source().id("link").unwrap();
        let child = engine.source().id("link/child").unwrap();
        let token = start_read(&mut engine, link);
        let baseline = engine.source().clone();
        let identity = resource::entry(&baseline, link).unwrap().identity;
        if unavailable {
            fs::rename(&path, dir.0.join("saved-link")).unwrap();
        } else {
            fs::rename(&target, dir.0.join("original")).unwrap();
            fs::create_dir(&target).unwrap();
        }
        let error = match Scan::new(
            &baseline,
            link,
            Reservation::new(engine.memory.clone(), Arc::new(AtomicUsize::new(0))),
            &AtomicBool::new(false),
        ) {
            Ok(_) => panic!("changed resource must fail enumeration"),
            Err(error) => error,
        };
        let failure = Failure {
            source: baseline.clone(),
            token,
            sequence: 1,
            error,
            context: Some((path.clone(), identity)),
            unavailable: unavailable.then(|| (path.clone(), identity)),
            retargeted: (!unavailable).then(|| (path.clone(), Entry::read(&path).unwrap())),
            dirty: Arc::new(Mutex::new(crate::ux::treeview::storage::Map::default())),
            index,
        };
        if unavailable {
            fs::rename(dir.0.join("saved-link"), &path).unwrap();
        } else {
            fs::rename(&target, dir.0.join("observed")).unwrap();
            fs::rename(dir.0.join("original"), &target).unwrap();
        }
        fs::write(target.join("child"), b"confirmed").unwrap();
        let metadata = Entry::read(&path.join("child")).unwrap();
        engine
            .apply_batch(Batch {
                base_revision: engine.source().revision(),
                operations: vec![Operation::Update {
                    node: child.into(),
                    patch: NodePatch {
                        payload: Some(metadata.node_data().payload),
                        ..NodePatch::default()
                    },
                }],
            })
            .unwrap();
        assert_ne!(
            resource::entry(&baseline, child).unwrap().size,
            metadata.size
        );
        assert_eq!(
            baseline.node(link).unwrap().subtree_revision,
            engine.source().node(link).unwrap().subtree_revision
        );
        assert!(engine.check_read(token, 1).is_ok());
        let effects = Box::new(failure).apply(&mut engine).unwrap().into_effects();
        assert!(engine.source().contains(child));
        assert_eq!(resource::entry(engine.source(), child).unwrap(), metadata);
        assert!(engine.manual_reads.contains(&link));
        assert!(effects.iter().any(|effect| {
                matches!(effect, Effect::NeedChildren { token: next, sequence: 1 } if next.node == link && *next != token)
            }));
    }
}

#[test]
fn t_parent_page_preserves_unrelated_subtree_progress() {
    let dir = Directory::new();
    fs::create_dir(dir.0.join("nested")).unwrap();
    fs::write(dir.0.join("file"), b"old").unwrap();
    let (mut engine, index) = filesystem_engine(&dir.0, &["nested", "file"]);
    let root = engine.source().id("root").unwrap();
    let nested = engine.source().id("nested").unwrap();
    let file = engine.source().id("file").unwrap();
    let token = start_read(&mut engine, root);
    fs::write(dir.0.join("file"), b"observed").unwrap();
    let staging = Arc::new(AtomicUsize::new(0));
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &AtomicBool::new(false),
    )
    .unwrap();
    let page = scan
        .page(
            root,
            Reservation::new(engine.memory.clone(), staging),
            &AtomicBool::new(false),
        )
        .unwrap();
    fs::write(dir.0.join("nested/child"), b"confirmed").unwrap();
    let metadata = Entry::read(&dir.0.join("nested")).unwrap();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![
                Operation::Update {
                    node: nested.into(),
                    patch: NodePatch {
                        payload: Some(metadata.node_data().payload),
                        ..NodePatch::default()
                    },
                },
                Operation::Insert {
                    key: "confirmed-child".into(),
                    parent: Some(nested.into()),
                    position: Position::Last,
                    data: Entry::read(&dir.0.join("nested/child"))
                        .unwrap()
                        .node_data(),
                    completeness: Completeness::Complete,
                },
            ],
        })
        .unwrap();
    let child = engine.source().id("confirmed-child").unwrap();
    index
        .lock()
        .unwrap()
        .insert(engine.source(), child)
        .unwrap();
    Box::new(Completion {
        token,
        sequence: 1,
        page,
        index,
    })
    .apply(&mut engine)
    .unwrap();
    assert!(engine.source().contains(child));
    assert_eq!(resource::entry(engine.source(), nested).unwrap(), metadata);
    assert_eq!(resource::entry(engine.source(), file).unwrap().size, 8);
    assert_eq!(
        engine.source().node(root).unwrap().completeness,
        Completeness::Complete
    );
    assert!(engine.reads.is_empty());
}

#[test]
fn t_parent_pages_accept_their_earlier_metadata_updates() {
    let dir = Directory::new();
    let names: Vec<_> = (0..=super::super::scan::PAGE_ITEMS)
        .map(|index| format!("file-{index:04}"))
        .collect();
    for name in &names {
        fs::write(dir.0.join(name), b"old").unwrap();
    }
    let refs: Vec<_> = names.iter().map(String::as_str).collect();
    let (mut engine, index) = filesystem_engine(&dir.0, &refs);
    let root = engine.source().id("root").unwrap();
    let token = start_read(&mut engine, root);
    for name in &names {
        fs::write(dir.0.join(name), b"observed").unwrap();
    }
    let staging = Arc::new(AtomicUsize::new(0));
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &AtomicBool::new(false),
    )
    .unwrap();
    let mut sequence = 1;
    loop {
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &AtomicBool::new(false),
            )
            .unwrap();
        let done = page.done;
        Box::new(Completion {
            token,
            sequence,
            page,
            index: index.clone(),
        })
        .apply(&mut engine)
        .unwrap();
        if done {
            break;
        }
        sequence += 1;
        assert!(engine.check_read(token, sequence).is_ok());
    }
    assert!(sequence > 1);
    let parent = engine.source().node(root).unwrap();
    assert_eq!(parent.completeness, Completeness::Complete);
    assert_eq!(parent.child_count(), names.len());
    assert!(
        parent
            .children()
            .all(|id| resource::entry(engine.source(), id).unwrap().size == 8)
    );
    assert!(engine.reads.is_empty());
}

#[test]
fn t_ancestor_refresh_precedes_queued_descendant_restart() {
    let mut engine = Engine::new(Limits {
        concurrent_reads: 4,
        ..Limits::default()
    })
    .unwrap();
    let mut records = vec![Record::new("root", NodeData::branch("root"))];
    records.extend((0..6).map(|index| Record {
        key: format!("child-{index}").into(),
        parent: Some("root".into()),
        data: NodeData::branch(format!("child-{index}")),
        completeness: Some(Completeness::Complete),
    }));
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let root = engine.source().id("root").unwrap();
    let children: Vec<_> = engine.source().node(root).unwrap().children().collect();
    engine.request_children(&children, false).unwrap();
    assert_eq!(engine.reads.len(), engine.limits.concurrent_reads);
    let token = engine.reads.values().next().unwrap().token;
    engine.request_children(&[root], true).unwrap();

    let effects = restart(&mut engine, token).unwrap().into_effects();
    assert!(
        effects.iter().any(|effect| {
            matches!(effect, Effect::NeedChildren { token, .. } if token.node == root)
        }),
        "the ancestor must receive the released slot before queued descendants"
    );
    assert!(
        children
            .iter()
            .all(|node| engine.manual_reads.contains(node))
    );
}

#[test]
fn t_dirty_ancestor_refresh_admits_when_requested_capacity_is_full() {
    struct QueueRefresh {
        dirty: Dirty,
        root: NodeId,
        children: Vec<NodeId>,
    }
    impl NativeAction for QueueRefresh {
        fn bytes(&self) -> usize {
            self.children.len() * 8 + 64
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            let effects = engine
                .request_children(&self.children, true)?
                .into_effects();
            self.dirty.lock().unwrap().insert(
                self.root,
                Demand {
                    generation: resource::sequence()?,
                    observed: false,
                },
            );
            Ok(engine.applied(None, effects))
        }
    }

    for count in [255, 256] {
        let directory = Directory::new();
        let mut entry = super::super::Entry::read(&directory.0).unwrap();
        entry.anchor = Some(directory.0.clone());
        let mut records = vec![Record::new("root", entry.node_data())];
        for index in 0..count {
            let path = directory.0.join(format!("child-{index}"));
            std::fs::create_dir(&path).unwrap();
            std::fs::write(path.join("file"), b"content").unwrap();
            records.push(Record {
                key: format!("child-{index}").into(),
                parent: Some("root".into()),
                data: super::super::Entry::read(&path).unwrap().node_data(),
                completeness: Some(Completeness::Complete),
            });
        }
        let dirty: Dirty = Arc::new(Mutex::new(crate::ux::treeview::storage::Map::default()));
        let reader = Reader::new(
            Arc::new(Mutex::new(super::super::index::Index::default())),
            dirty.clone(),
            Arc::new(Mutex::new(super::super::watch::Interest::default())),
        );
        let data = DataHandle::with_reader(
            Limits {
                concurrent_reads: 4,
                queued_reads: 256,
                ..Limits::default()
            },
            Some(Box::new(reader)),
        )
        .unwrap();
        wait(data.submit(Action::Import(Import {
            base_revision: data.source().revision(),
            scope: DataScope::Forest,
            records,
        })))
        .unwrap();
        let root = data.source().id("root").unwrap();
        let children: Vec<_> = data.source().node(root).unwrap().children().collect();
        wait(data.submit(Action::Native(Box::new(QueueRefresh {
            dirty: dirty.clone(),
            root,
            children: children.clone(),
        }))))
        .unwrap();
        let started = Instant::now();
        loop {
            let source = data.source();
            if dirty.lock().unwrap().is_empty()
                && !data.has_work()
                && children.iter().all(|id| {
                    source.node(*id).is_some_and(|node| {
                        node.load_state == LoadState::Idle
                            && node.completeness == Completeness::Complete
                            && node.child_count() == 1
                    })
                })
            {
                break;
            }
            assert!(
                started.elapsed() < std::time::Duration::from_secs(10),
                "dirty ancestor did not make progress with {count} requests"
            );
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
    }
}

#[test]
fn t_probe_retries_and_no_change_do_not_publish_watch_errors() {
    let mut engine = Engine::new(Limits {
        queued_reads: 0,
        ..Limits::default()
    })
    .unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("root", NodeData::default())],
        })
        .unwrap();
    let node = engine.source().id("root").unwrap();
    let dirty: Dirty = Arc::new(Mutex::new(crate::ux::treeview::storage::Map::default()));
    dirty.lock().unwrap().insert(
        node,
        Demand {
            generation: 1,
            observed: false,
        },
    );
    let interest = Arc::new(Mutex::new(super::super::watch::Interest::default()));
    let mut reader = Reader::new(
        Arc::new(Mutex::new(super::super::index::Index::default())),
        dirty.clone(),
        interest.clone(),
    );
    let data = DataHandle::new(Limits::default()).unwrap();
    for code in [
        Some(ErrorCode::Busy),
        Some(ErrorCode::Busy),
        Some(ErrorCode::Stale),
        None,
    ] {
        let request = Request::run(move || match code {
            Some(code) => Err(Error::new(code, "retry probe")),
            None => Ok(Reply::NoChange),
        });
        let started = Instant::now();
        while request.poll().is_none() {
            assert!(started.elapsed() < std::time::Duration::from_secs(10));
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        reader.probes.insert(node, (request, 1));
        reader.publish(&engine, &data.downgrade());
        let status = &interest.lock().unwrap().status;
        assert_eq!(status.revision, 0);
        assert!(status.error.is_none());
        assert_eq!(dirty.lock().unwrap().get(&node).is_some(), code.is_some());
    }
}

#[test]
#[ignore = "explicit release-mode directory stage measurement"]
fn t_native_directory_stages() {
    let dir = Directory::new();
    for i in 0..50_000 {
        std::fs::write(dir.0.join(format!("file-{i:05}")), b"").unwrap();
    }
    let mut entry = super::super::Entry::read(&dir.0).unwrap();
    entry.anchor = Some(dir.0.clone());
    let mut engine = Engine::new(Limits::default()).unwrap();
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
    let Reply::Applied { effects, .. } = engine.request_children(&[root], true).unwrap() else {
        panic!("request")
    };
    let Effect::NeedChildren { token, .. } = effects[0] else {
        panic!("read")
    };
    let staging = Arc::new(AtomicUsize::new(0));
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &AtomicBool::new(false),
    )
    .unwrap();
    let index = Arc::new(Mutex::new(super::super::index::Index::default()));
    let mut times = [0.0; 3];
    let mut count = 0;
    let mut visited = 0;
    println!("native stages: begin scan");
    loop {
        count += 1;
        let start = Instant::now();
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &AtomicBool::new(false),
            )
            .unwrap();
        times[0] += start.elapsed().as_secs_f64();
        let done = page.done;
        let start = Instant::now();
        Box::new(Completion {
            token,
            sequence: count,
            page,
            index: index.clone(),
        })
        .apply(&mut engine)
        .unwrap();
        times[1] += start.elapsed().as_secs_f64();
        let start = Instant::now();
        for (_, frame) in engine.project() {
            visited += frame.unwrap().visited_nodes;
        }
        times[2] += start.elapsed().as_secs_f64();
        if done {
            break;
        }
    }
    println!(
        "50k native stages pages={count} io_ms={:.3} apply_ms={:.3} projection_ms={:.3} visited={visited} retained={}",
        times[0] * 1000.0,
        times[1] * 1000.0,
        times[2] * 1000.0,
        engine.memory.used()
    );
}
