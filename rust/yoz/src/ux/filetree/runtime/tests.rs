use super::super::tests::{Directory, request};
use super::*;
use std::fs;

/** A real Filetree Job with explicitly delivered browse pages, independent of worker timing. */
pub(in super::super) fn paged_job_tree(path: &Path, known: Option<&str>) -> Filetree {
    let data = DataHandle::new(Limits::default()).unwrap();
    let mut anchor = Entry::read(path).unwrap();
    anchor.anchor = Some(path.to_owned());
    let mut records = vec![Record {
        key: "root".into(),
        parent: None,
        data: anchor.node_data(),
        completeness: Some(Completeness::Complete),
    }];
    for name in ["dst", "src"] {
        records.push(Record {
            key: name.into(),
            parent: Some("root".into()),
            data: Entry::read(&path.join(name)).unwrap().node_data(),
            completeness: Some(if name == "src" && known.is_some() {
                Completeness::Complete
            } else {
                Completeness::Unknown
            }),
        });
    }
    if let Some(name) = known {
        records.push(Record {
            key: "known".into(),
            parent: Some("src".into()),
            data: Entry::read(&path.join("src").join(name))
                .unwrap()
                .node_data(),
            completeness: Some(Completeness::Complete),
        });
    }
    wait(
        data.submit(Action::Batch(Batch {
            base_revision: data.source().revision(),
            operations: records
                .into_iter()
                .map(|record| Operation::Insert {
                    key: record.key,
                    parent: record.parent,
                    position: Position::Last,
                    data: record.data,
                    completeness: record.completeness.unwrap(),
                })
                .collect(),
        })),
    )
    .unwrap();
    let source = data.source();
    let mut index = Index::default();
    for name in ["root", "src", "dst", "known"] {
        if let Some(node) = source.id(name) {
            index.insert(&source, node).unwrap();
        }
    }
    Filetree {
        root: source.id("root").unwrap(),
        data,
        index: Arc::new(Mutex::new(index)),
        interest: Arc::new(Mutex::new(super::super::watch::Interest::default())),
        dirty: Arc::new(Mutex::new(Map::default())),
        reader_work: Arc::new(AtomicBool::new(false)),
        annotations: Arc::new(Mutex::new(super::super::annotations::Annotations::default())),
    }
}

pub(in super::super) fn begin_job_read(tree: &Filetree, parent: NodeId) -> ReadToken {
    wait(
        tree.data()
            .submit(Action::RequestChildren(vec![parent], false)),
    )
    .unwrap()
    .into_effects()
    .into_iter()
    .find_map(|effect| match effect {
        Effect::NeedChildren { token, .. } => Some(token),
        _ => None,
    })
    .unwrap()
}

pub(in super::super) fn deliver_job_page(
    tree: &Filetree,
    token: ReadToken,
    sequence: u64,
    records: Vec<Record>,
    done: bool,
) {
    struct Page {
        tree: Filetree,
        token: ReadToken,
        sequence: u64,
        records: Vec<Record>,
        done: bool,
    }
    impl NativeAction for Page {
        fn bytes(&self) -> usize {
            128 + self.records.len() * 512
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            let mut candidate = engine.clone();
            let keys: Vec<_> = self
                .records
                .iter()
                .map(|record| record.key.clone())
                .collect();
            let reply =
                candidate.children_page(self.token, self.sequence, self.records, self.done)?;
            let mut index = self.tree.index.lock().unwrap();
            let mut next = index.clone();
            for key in keys {
                next.insert(candidate.source(), candidate.source().id(&key).unwrap())?;
            }
            candidate.memory.check()?;
            *index = next;
            *engine = candidate;
            Ok(reply)
        }
    }
    wait(tree.data().submit(Action::Native(Box::new(Page {
        tree: tree.clone(),
        token,
        sequence,
        records,
        done,
    }))))
    .unwrap();
}

fn private_copy_read_scope(tighten_later: bool, confirmed_member: bool) {
    use crate::ux::filetree::jobs_tests::selection;
    use crate::ux::filetree::{OperationKind, OperationPlan};
    let directory = Directory::new();
    fs::create_dir(directory.0.join("src")).unwrap();
    fs::create_dir(directory.0.join("dst")).unwrap();
    fs::write(directory.0.join("src/one"), b"data").unwrap();
    fs::write(directory.0.join("src/two"), b"data").unwrap();
    let names: Vec<_> = fs::read_dir(directory.0.join("src"))
        .unwrap()
        .map(|entry| entry.unwrap().file_name().into_string().unwrap())
        .collect();
    if tighten_later {
        fs::create_dir(directory.0.join("dst/src")).unwrap();
        fs::write(directory.0.join("dst/src").join(&names[0]), b"old").unwrap();
    }
    let tree = paged_job_tree(&directory.0, (!tighten_later).then_some(names[0].as_str()));
    let source = tree.source();
    let src = source.id("src").unwrap();
    let target = Resource {
        node: source.id("dst").unwrap(),
        source,
    };
    let token = begin_job_read(&tree, src);
    deliver_job_page(&tree, token, 1, Vec::new(), false);
    assert_eq!(
        tree.source().node(src).unwrap().completeness,
        Completeness::Partial
    );
    let mut operation = OperationPlan {
        kind: OperationKind::Copy,
        source: tree.source(),
        nodes: vec![src].into(),
        target: Some(target),
        name: None,
        task: None,
        prepare_move: false,
    };
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(10);
    if tighten_later {
        while job.status().confirmation.is_none() {
            assert!(!job.status().terminal);
            assert!(std::time::Instant::now() < deadline);
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        let confirmation = job.status().confirmation.unwrap();
        let record = Record::new(
            "first",
            Entry::read(
                &directory
                    .0
                    .join("src")
                    .join(&names[usize::from(!confirmed_member)]),
            )
            .unwrap()
            .node_data(),
        );
        deliver_job_page(&tree, token, 2, vec![record], true);
        let next = begin_job_read(&tree, src);
        deliver_job_page(&tree, next, 1, Vec::new(), false);
        job.confirm(confirmation.token, true).unwrap();
    }
    while !job.status().terminal {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    assert!(
        !directory.0.join("dst/src").join(&names[1]).exists(),
        "private copy used an item outside the original Complete read scope"
    );
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    assert!(!state.status().unwrap().locked);
    assert!(!state.snapshot().unwrap().summary.is_empty());
    if tighten_later {
        assert_eq!(
            fs::read(directory.0.join("dst/src").join(&names[0])).unwrap(),
            if confirmed_member {
                b"data".as_slice()
            } else {
                b"old".as_slice()
            }
        );
    } else {
        #[cfg(any(target_os = "macos", target_os = "linux"))]
        assert!(!directory.0.join("dst/src").exists());
    }
}

#[test]
fn t_private_copy_obeys_complete_read_scope_at_claim() {
    private_copy_read_scope(false, true);
}

#[test]
fn t_private_copy_obeys_complete_read_scope_after_capture() {
    private_copy_read_scope(true, true);
}

#[test]
fn t_private_copy_rechecks_waiting_confirmation_against_latest_read_scope() {
    private_copy_read_scope(true, false);
}

#[test]
#[cfg(unix)]
fn t_private_parent_chain_tracks_browse_materialization_without_rebinding_history() {
    use crate::ux::filetree::jobs_tests::selection;
    use crate::ux::filetree::{ItemStatus, OperationKind, OperationPlan};
    for materialized in [false, true] {
        let directory = Directory::new();
        fs::create_dir_all(directory.0.join("src/branch/sub")).unwrap();
        fs::create_dir_all(directory.0.join("dst/src/branch/sub")).unwrap();
        fs::write(directory.0.join("src/branch/sub/file"), b"data").unwrap();
        fs::write(directory.0.join("dst/src/branch/sub/file"), b"old").unwrap();
        let fifo = std::ffi::CString::new(
            directory
                .0
                .join("src/branch/sub/fifo")
                .as_os_str()
                .as_encoded_bytes(),
        )
        .unwrap();
        assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
        let tree = paged_job_tree(&directory.0, None);
        let source = tree.source();
        let src = source.id("src").unwrap();
        let target = Resource {
            node: source.id("dst").unwrap(),
            source,
        };
        let token = begin_job_read(&tree, src);
        let mut operation = OperationPlan {
            kind: OperationKind::Copy,
            source: tree.source(),
            nodes: vec![src].into(),
            target: Some(target),
            name: None,
            task: None,
            prepare_move: false,
        };
        let state = selection(&tree, &mut operation);
        let job = tree.start_operation(operation).unwrap();
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(10);
        while job.status().confirmation.is_none() {
            assert!(!job.status().terminal);
            assert!(std::time::Instant::now() < deadline);
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        let confirmation = job.status().confirmation.unwrap();
        assert!(confirmation.node.is_none());
        if materialized {
            deliver_job_page(
                &tree,
                token,
                1,
                vec![Record::new(
                    "branch",
                    Entry::read(&directory.0.join("src/branch"))
                        .unwrap()
                        .node_data(),
                )],
                true,
            );
            let branch = tree.source().id("branch").unwrap();
            let read = begin_job_read(&tree, branch);
            deliver_job_page(
                &tree,
                read,
                1,
                vec![Record::new(
                    "sub",
                    Entry::read(&directory.0.join("src/branch/sub"))
                        .unwrap()
                        .node_data(),
                )],
                true,
            );
            let sub = tree.source().id("sub").unwrap();
            let read = begin_job_read(&tree, sub);
            let records = ["fifo", "file"]
                .into_iter()
                .map(|name| {
                    Record::new(
                        name,
                        Entry::read(&directory.0.join("src/branch/sub").join(name))
                            .unwrap()
                            .node_data(),
                    )
                })
                .collect();
            deliver_job_page(&tree, read, 1, records, true);
        } else {
            deliver_job_page(&tree, token, 1, Vec::new(), true);
        }
        let refresh = begin_job_read(&tree, src);
        deliver_job_page(&tree, refresh, 1, Vec::new(), false);
        job.confirm(confirmation.token, true).unwrap();
        while !job.status().terminal {
            assert!(std::time::Instant::now() < deadline);
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        assert_eq!(
            fs::read(directory.0.join("dst/src/branch/sub/file")).unwrap(),
            if materialized {
                b"data".as_slice()
            } else {
                b"old".as_slice()
            }
        );
        assert!(!state.status().unwrap().locked);
        if materialized {
            assert!(job.status().cleanup.unwrap().is_ok());
            let results = job.results(0, job.status().results).unwrap();
            let copied = results
                .iter()
                .find(|result| result.source().ends_with("sub/file"))
                .unwrap();
            assert_eq!(copied.status, ItemStatus::Success);
            assert!(
                copied.node.is_none(),
                "browse validation cannot rewrite captured result identity"
            );
        } else {
            assert_eq!(
                job.status().cleanup.unwrap().unwrap_err().code,
                ErrorCode::Stale
            );
        }
    }
}

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

#[test]
fn t_accepted_refresh_is_not_settled_while_its_scan_waits_for_a_move() {
    let directory = Directory::new();
    fs::write(directory.0.join("before"), b"old").unwrap();
    let tree = request(Filetree::open(directory.0.clone()));
    let Outcome::State(state) = tree.create_state(None, DisplayOptions::default()).wait() else {
        panic!("state");
    };
    wait(
        tree.data()
            .submit(Action::RequestChildren(vec![tree.root()], true)),
    )
    .unwrap();
    let started = std::time::Instant::now();
    while !tree.is_settled() {
        assert!(started.elapsed() < std::time::Duration::from_secs(5));
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    assert_eq!(tree.source().node(tree.root()).unwrap().child_count(), 1);
    tree.index.lock().unwrap().moving = Some(tree.root());
    fs::write(directory.0.join("after"), b"new").unwrap();
    wait(tree.refresh(&state).unwrap()).unwrap();
    assert!(
        !tree.data().has_work(),
        "the postponed scan has not acquired a read slot"
    );
    assert!(
        !tree.is_settled(),
        "accepting a refresh cannot finish its deferred scan"
    );
    assert_eq!(tree.source().node(tree.root()).unwrap().child_count(), 1);
    tree.index.lock().unwrap().moving = None;
    tree.data().wake();
    while !tree.is_settled() {
        assert!(started.elapsed() < std::time::Duration::from_secs(5));
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    let source = tree.source();
    assert_eq!(source.node(tree.root()).unwrap().child_count(), 2);
    assert!(source.node(tree.root()).unwrap().error.is_none());
}

#[test]
fn t_settled_refresh_keeps_a_failed_or_unavailable_root_distinct_from_success() {
    let directory = Directory::new();
    let path = directory.0.join("browse");
    fs::create_dir(&path).unwrap();
    fs::write(path.join("file"), b"contents").unwrap();
    let tree = request(Filetree::open(path.clone()));
    let Outcome::State(state) = tree.create_state(None, DisplayOptions::default()).wait() else {
        panic!("state");
    };
    wait(
        tree.data()
            .submit(Action::RequestChildren(vec![tree.root()], true)),
    )
    .unwrap();
    let started = std::time::Instant::now();
    while !tree.is_settled() {
        assert!(started.elapsed() < std::time::Duration::from_secs(5));
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    fs::rename(&path, directory.0.join("moved")).unwrap();
    wait(tree.refresh(&state).unwrap()).unwrap();
    while !tree.is_settled() {
        assert!(started.elapsed() < std::time::Duration::from_secs(5));
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    assert!(
        tree.source()
            .node(tree.root())
            .is_none_or(|node| node.error.is_some())
    );
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
