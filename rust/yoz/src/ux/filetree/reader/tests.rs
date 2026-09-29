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
                    fields: Some(new.fields),
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
                    fields: Some(data.fields),
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
                    fields: Some(metadata.node_data().fields),
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
        let (lease, _) = engine.lease_children(link).unwrap();
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
                        fields: Some(metadata.node_data().fields),
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
        assert_eq!(engine.leased_reads.get(&lease), Some(&link));
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
                        fields: Some(metadata.node_data().fields),
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
    let leases: Vec<_> = children
        .iter()
        .map(|&node| engine.lease_children(node).unwrap().0)
        .collect();
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
        leases
            .iter()
            .all(|lease| engine.leased_reads.contains_key(lease))
    );
}

#[test]
fn t_dirty_ancestor_refresh_admits_when_requested_capacity_is_full() {
    struct QueueRefresh {
        dirty: Dirty,
        root: NodeId,
        children: Vec<NodeId>,
        leases: usize,
    }
    impl NativeAction for QueueRefresh {
        fn bytes(&self) -> usize {
            self.children.len() * 8 + 64
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            let mut effects = engine
                .request_children(&self.children, true)?
                .into_effects();
            for &node in self.children.iter().take(self.leases) {
                effects.extend(engine.lease_children(node)?.1.into_effects());
            }
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

    for (count, leases) in [(255, 0), (256, 0), (256, 4)] {
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
            leases,
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
                "dirty ancestor did not make progress with {count} requests and {leases} leases"
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
