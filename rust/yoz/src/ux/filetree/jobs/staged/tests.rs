use super::*;
use crate::ux::filetree::jobs_tests::{done, plan, selection};
use crate::ux::filetree::tests::{Directory as Fixture, request};

struct DuringCopy {
    job: Job,
    action: Mutex<Option<Box<dyn FnOnce(&Job) + Send>>>,
}

impl Listener for DuringCopy {
    fn wake(&self) {
        if self.job.status().bytes == 0 {
            return;
        }
        let mut action = self.action.lock().unwrap();
        if let Some(action) = action.take() {
            action(&self.job);
        }
    }
    fn close(&self) {}
    fn is_closed(&self) -> bool {
        false
    }
}

fn observed_job(
    tree: &Filetree,
    operation: OperationPlan,
    action: impl FnOnce(&Job) + Send + 'static,
) -> (Job, Arc<dyn Listener>) {
    let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
    let job = tree.start_operation(operation).unwrap();
    let listener: Arc<dyn Listener> = Arc::new(DuringCopy {
        job: job.clone(),
        action: Mutex::new(Some(Box::new(action))),
    });
    tree.data().listen(&listener).unwrap();
    drop(execution);
    (job, listener)
}

#[test]
fn t_staged_job_does_not_deliver_or_clear_unpublished_successes_after_target_conflict() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir(fixture.0.join("destination")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let tree = request(Filetree::open(fixture.0.clone()));
    let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let output = fixture.0.join("destination/source");
    let competing = output.clone();
    let (job, _listener) = observed_job(&tree, operation, move |job| {
        assert_eq!(job.status().results, 0);
        assert!(job.results(0, 1).is_err());
        assert!(!competing.exists());
        fs::create_dir(&competing).unwrap();
        fs::write(competing.join("external"), "keep").unwrap();
    });
    let results = done(&job);
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(
        job.status().processed,
        2,
        "unpublished work remains processed, not successful"
    );
    assert!(results[0].error().is_some());
    assert_eq!(fs::read(output.join("external")).unwrap(), b"keep");
    assert!(!output.join("file").exists());
    assert_eq!(
        fs::read_dir(fixture.0.join("destination")).unwrap().count(),
        1
    );
    assert!(!state.status().unwrap().locked);
    assert_eq!(state.snapshot().unwrap().summary.known_roots, 1);
}

#[test]
fn t_staged_job_rejects_a_replaced_source_root_without_publishing_its_old_prefix() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir(fixture.0.join("destination")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let tree = request(Filetree::open(fixture.0.clone()));
    let operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let path = fixture.0.clone();
    let (job, _listener) = observed_job(&tree, operation, move |_| {
        fs::rename(path.join("source"), path.join("original")).unwrap();
        fs::create_dir(path.join("source")).unwrap();
        fs::write(path.join("source/file"), "replacement").unwrap();
    });
    let results = done(&job);
    assert!(
        results
            .iter()
            .all(|result| result.status == ItemStatus::Failed)
    );
    assert!(!fixture.0.join("destination/source").exists());
    assert_eq!(
        fs::read(fixture.0.join("source/file")).unwrap(),
        b"replacement"
    );
    assert_eq!(
        fs::read(fixture.0.join("original/file")).unwrap(),
        b"contents"
    );
    assert_eq!(
        fs::read_dir(fixture.0.join("destination")).unwrap().count(),
        0
    );
}

#[test]
fn t_staged_job_keeps_committed_io_when_model_publication_exceeds_capacity() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir(fixture.0.join("destination")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let tree = request(Filetree::open(fixture.0.clone()));
    let operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let memory = tree.data().memory();
    let held = Arc::new(Mutex::new(None));
    let pressure = held.clone();
    let (job, _listener) = observed_job(&tree, operation, move |_| {
        let _guard = memory.enter();
        *pressure.lock().unwrap() = Some(Charge::new(Limits::default().memory_bytes));
    });
    let results = done(&job);
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].status, ItemStatus::Success);
    assert_eq!(
        results[0].sync_error().unwrap().code,
        ErrorCode::ResourceLimit
    );
    assert_eq!(
        fs::read(fixture.0.join("destination/source/file")).unwrap(),
        b"contents"
    );
    assert_eq!(
        fs::read_dir(fixture.0.join("destination")).unwrap().count(),
        1
    );
    held.lock().unwrap().take();
}

#[test]
fn t_staged_partial_copy_cleans_only_successful_source_nodes_and_loads_target_on_demand() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir(fixture.0.join("destination")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let fifo = std::ffi::CString::new(fixture.0.join("source/fifo").as_os_str().as_encoded_bytes())
        .unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(fixture.0.clone()));
    let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    let results = done(&job);
    assert!(
        results
            .iter()
            .any(|result| result.status == ItemStatus::Success && result.source().ends_with("file"))
    );
    assert!(
        results
            .iter()
            .any(|result| result.status == ItemStatus::Failed && result.source().ends_with("fifo"))
    );
    assert_eq!(
        fs::read(fixture.0.join("destination/source/file")).unwrap(),
        b"contents"
    );
    assert!(!fixture.0.join("destination/source/fifo").exists());
    let copied = request(tree.resolve(fixture.0.join("destination/source")));
    assert_eq!(tree.source().node(copied.node).unwrap().child_count(), 0);
    let file = request(tree.resolve(fixture.0.join("source/file")));
    let fifo = request(tree.resolve(fixture.0.join("source/fifo")));
    let Outcome::Reply(Reply::Inspected { sources, .. }) = state
        .dispatch(Command::InspectSelection, Context::default())
        .wait()
    else {
        panic!("selection");
    };
    assert!(!sources.subtree_roots.contains(&file.node));
    assert!(sources.subtree_roots.contains(&fifo.node));
    assert!(!state.status().unwrap().locked);
}

#[test]
fn t_staged_partial_results_keep_execution_paths_after_both_parents_move() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir(fixture.0.join("destination")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let fifo = std::ffi::CString::new(fixture.0.join("source/fifo").as_os_str().as_encoded_bytes())
        .unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(fixture.0.clone()));
    let job = tree
        .start_operation(plan(
            &tree,
            "source",
            Some("destination"),
            OperationKind::Copy,
        ))
        .unwrap();
    let before = done(&job);
    let copied = before
        .iter()
        .find(|result| result.status == ItemStatus::Success)
        .unwrap();
    let item = copied.item;
    assert!(
        copied.node.is_none(),
        "history need not materialize a browse occurrence"
    );
    let captured_source = fixture.0.join("source/file");
    let captured_target = fixture.0.join("destination/source/file");
    for (source, name) in [
        ("source", "renamed-source"),
        ("destination", "renamed-destination"),
    ] {
        let mut operation = plan(&tree, source, Some(""), OperationKind::Move);
        operation.name = Some(name.into());
        let results = done(&tree.start_operation(operation).unwrap());
        assert!(
            results
                .iter()
                .all(|result| result.status == ItemStatus::Success)
        );
    }
    let results = job.results(0, job.status().results).unwrap();
    let copied = results.iter().find(|result| result.item == item).unwrap();
    assert_eq!(copied.source(), captured_source);
    assert_eq!(copied.target(), Some(captured_target));
    assert_eq!(
        fs::read(fixture.0.join("renamed-destination/source/file")).unwrap(),
        b"contents"
    );
}

struct BeforeCleanup {
    job: Job,
    action: Mutex<Option<Box<dyn FnOnce(&Job) + Send>>>,
}

impl Listener for BeforeCleanup {
    fn wake(&self) {
        if self.job.status().phase != JobPhase::Cleanup {
            return;
        }
        let action = self.action.lock().unwrap().take();
        if let Some(action) = action {
            action(&self.job);
        }
    }
    fn close(&self) {}
    fn is_closed(&self) -> bool {
        false
    }
}

#[test]
fn t_partial_cleanup_rechecks_bound_parent_identity_before_admitting_successes() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir_all(fixture.0.join("destination/source")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let fifo = std::ffi::CString::new(fixture.0.join("source/fifo").as_os_str().as_encoded_bytes())
        .unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(fixture.0.clone()));
    let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let source = operation.nodes[0];
    let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
    let job = tree.start_operation(operation).unwrap();
    let path = fixture.0.clone();
    let listener: Arc<dyn Listener> = Arc::new(BeforeCleanup {
        job: job.clone(),
        action: Mutex::new(Some(Box::new(move |_| {
            fs::rename(path.join("source"), path.join("original")).unwrap();
            fs::create_dir(path.join("source")).unwrap();
            fs::hard_link(path.join("original/file"), path.join("source/file")).unwrap();
        }))),
    });
    tree.data().listen(&listener).unwrap();
    drop(execution);
    let deadline = Instant::now() + Duration::from_secs(10);
    while !job.status().terminal {
        assert!(Instant::now() < deadline, "cleanup timed out");
        std::thread::sleep(Duration::from_millis(1));
    }
    let results = job.results(0, job.status().results).unwrap();
    assert!(
        results
            .iter()
            .any(|result| result.status == ItemStatus::Success)
    );
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    assert_eq!(tree.source().node(source).unwrap().child_count(), 0);
    assert!(!state.status().unwrap().locked);
    assert_eq!(state.snapshot().unwrap().summary.known_roots, 1);
    assert_eq!(
        fs::read(fixture.0.join("destination/source/file")).unwrap(),
        b"contents"
    );
}

#[test]
fn t_partial_cleanup_reserves_scratch_before_reading_success_metadata() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir_all(fixture.0.join("destination/source")).unwrap();
    fs::write(fixture.0.join("source/file"), "contents").unwrap();
    let fifo = std::ffi::CString::new(fixture.0.join("source/fifo").as_os_str().as_encoded_bytes())
        .unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(fixture.0.clone()));
    let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let source = operation.nodes[0];
    let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
    let job = tree.start_operation(operation).unwrap();
    let path = fixture.0.clone();
    let held = Arc::new(Mutex::new(None));
    let pressure = held.clone();
    let listener: Arc<dyn Listener> = Arc::new(BeforeCleanup {
        job: job.clone(),
        action: Mutex::new(Some(Box::new(move |job| {
            fs::remove_file(path.join("source/file")).unwrap();
            let memory = &job.0.task_memory;
            *pressure.lock().unwrap() =
                Some(memory.reserve(RESULT_LIMIT - memory.used() - 512).unwrap());
        }))),
    });
    tree.data().listen(&listener).unwrap();
    drop(execution);
    let deadline = Instant::now() + Duration::from_secs(10);
    while !job.status().terminal {
        assert!(Instant::now() < deadline, "cleanup timed out");
        std::thread::sleep(Duration::from_millis(1));
    }
    let results = job.results(0, job.status().results).unwrap();
    assert!(
        results
            .iter()
            .any(|result| result.status == ItemStatus::Success)
    );
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::ResourceLimit
    );
    assert_eq!(tree.source().node(source).unwrap().child_count(), 0);
    assert!(!state.status().unwrap().locked);
    assert_eq!(state.snapshot().unwrap().summary.known_roots, 1);
    assert_eq!(
        fs::read(fixture.0.join("destination/source/file")).unwrap(),
        b"contents"
    );
    held.lock().unwrap().take();
}

#[test]
fn t_partial_cleanup_capacity_failure_after_admission_keeps_all_selection_stamps() {
    struct LimitNodes;
    impl NativeAction for LimitNodes {
        fn bytes(&self) -> usize {
            0
        }
        fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
            engine.limits.nodes = engine.source().len() + 128;
            Ok(Reply::NoChange)
        }
    }
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir_all(fixture.0.join("destination/source")).unwrap();
    for index in 0..160 {
        fs::write(fixture.0.join(format!("source/file-{index:03}")), b"data").unwrap();
    }
    let fifo = std::ffi::CString::new(fixture.0.join("source/fifo").as_os_str().as_encoded_bytes())
        .unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    let tree = request(Filetree::open(fixture.0.clone()));
    request(tree.resolve(fixture.0.join("destination/source")));
    let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let source = operation.nodes[0];
    let state = selection(&tree, &mut operation);
    work::wait(tree.data().submit(Action::Native(Box::new(LimitNodes)))).unwrap();
    let job = tree.start_operation(operation).unwrap();
    let deadline = Instant::now() + Duration::from_secs(10);
    while !job.status().terminal {
        assert!(Instant::now() < deadline, "cleanup timed out");
        std::thread::sleep(Duration::from_millis(1));
    }
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::ResourceLimit
    );
    let admitted = tree.source().node(source).unwrap().child_count();
    assert!(admitted > 0 && admitted < 160, "{admitted}");
    let results = job.results(0, job.status().results).unwrap();
    assert_eq!(
        results
            .iter()
            .filter(|result| result.status == ItemStatus::Success)
            .count(),
        160
    );
    assert!(
        results
            .iter()
            .filter(|result| result.status == ItemStatus::Success)
            .all(|result| result.node.is_none())
    );
    assert!(!state.status().unwrap().locked);
    let Outcome::Reply(Reply::Inspected { sources, .. }) = state
        .dispatch(Command::InspectSelection, Context::default())
        .wait()
    else {
        panic!("selection");
    };
    assert_eq!(sources.subtree_roots.as_ref(), &[source]);
    for index in 0..160 {
        assert_eq!(
            fs::read(
                fixture
                    .0
                    .join(format!("destination/source/file-{index:03}"))
            )
            .unwrap(),
            b"data"
        );
    }
}

#[test]
fn t_private_traversal_directory_replacement_invalidates_loaded_success_cleanup() {
    let fixture = Fixture::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir_all(fixture.0.join("destination/source")).unwrap();
    for index in 0..8 {
        fs::write(fixture.0.join(format!("source/file-{index}")), b"data").unwrap();
    }
    let names: Vec<_> = fs::read_dir(fixture.0.join("source"))
        .unwrap()
        .map(|entry| entry.unwrap().file_name())
        .collect();
    fs::write(fixture.0.join("destination/source").join(&names[1]), b"old").unwrap();
    let tree = request(Filetree::open(fixture.0.clone()));
    let root = request(tree.resolve(fixture.0.join("source"))).node;
    work::wait(
        tree.data()
            .submit(Action::RequestChildren(vec![root], false)),
    )
    .unwrap();
    let deadline = Instant::now() + Duration::from_secs(10);
    while tree.source().node(root).unwrap().completeness != Completeness::Complete {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(1));
    }
    let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let job = tree.start_operation(operation).unwrap();
    while job.status().confirmation.is_none() {
        assert!(!job.status().terminal);
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(1));
    }
    let confirmation = job.status().confirmation.unwrap();
    assert_eq!(
        fs::read(fixture.0.join("destination/source").join(&names[0])).unwrap(),
        b"data"
    );
    fs::rename(fixture.0.join("source"), fixture.0.join("original")).unwrap();
    fs::create_dir(fixture.0.join("source")).unwrap();
    for name in &names {
        fs::hard_link(
            fixture.0.join("original").join(name),
            fixture.0.join("source").join(name),
        )
        .unwrap();
    }
    job.confirm(confirmation.token, false).unwrap();
    while !job.status().terminal {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(1));
    }
    assert_eq!(job.status().error.unwrap().code, ErrorCode::Stale);
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    let Outcome::Reply(Reply::Inspected { sources, .. }) = state
        .dispatch(Command::InspectSelection, Context::default())
        .wait()
    else {
        panic!("selection");
    };
    assert_eq!(sources.subtree_roots.as_ref(), &[root]);
    assert!(!state.status().unwrap().locked);
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum CapacityCase {
    Complete,
    Loaded,
    LateSkip,
    Merge,
    Cancel,
    NestedLong,
}

/** Set up an already-loaded Source from real entries without claiming browse Scan capacity. */
struct LoadedFixture {
    tree: Filetree,
    parent: NodeId,
    entries: Vec<Entry>,
}

impl NativeAction for LoadedFixture {
    fn bytes(&self) -> usize {
        self.entries
            .iter()
            .map(|entry| entry.encoded_len() * 2 + 256)
            .sum()
    }

    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut candidate = engine.clone();
        let mut operations = self
            .entries
            .into_iter()
            .map(|entry| {
                Ok(Operation::Insert {
                    key: resource::key()?,
                    parent: Some(self.parent.into()),
                    position: Position::Last,
                    data: entry.node_data(),
                    completeness: Completeness::Complete,
                })
            })
            .collect::<Result<Vec<_>>>()?;
        operations.push(Operation::Update {
            node: self.parent.into(),
            patch: NodePatch {
                completeness: Some(Completeness::Complete),
                ..NodePatch::default()
            },
        });
        let reply = candidate.apply_batch(Batch {
            base_revision: candidate.source().revision(),
            operations: operations.clone(),
        })?;
        let mut index = self.tree.index.lock().unwrap();
        let mut next = index.clone();
        next.update(engine.source(), candidate.source(), &operations)?;
        candidate.memory.check()?;
        *engine = candidate;
        *index = next;
        Ok(reply)
    }
}

fn capacity_case(count: usize, case: CapacityCase) {
    let fixture = Fixture::new();
    let prefix = if case == CapacityCase::NestedLong {
        "long-ancestor-component/".repeat(24)
    } else {
        String::new()
    };
    let source = format!("{prefix}source");
    let destination = format!("{prefix}destination");
    fs::create_dir_all(fixture.0.join(&source)).unwrap();
    fs::create_dir_all(fixture.0.join(&destination)).unwrap();
    if matches!(case, CapacityCase::Merge | CapacityCase::LateSkip) {
        fs::create_dir(fixture.0.join(&destination).join("source")).unwrap();
    }
    let name = |index: usize| {
        if case == CapacityCase::NestedLong {
            format!("branch-{:02}/entry-{index:05}.txt", index / 1000)
        } else {
            format!("entry-{index:05}.txt")
        }
    };
    if case == CapacityCase::NestedLong {
        for index in (0..count).step_by(1000) {
            fs::create_dir(
                fixture
                    .0
                    .join(&source)
                    .join(format!("branch-{:02}", index / 1000)),
            )
            .unwrap();
        }
    }
    for index in 0..count {
        fs::write(fixture.0.join(&source).join(name(index)), b"data").unwrap();
    }
    let skipped = if case == CapacityCase::LateSkip {
        let name = fs::read_dir(fixture.0.join(&source))
            .unwrap()
            .last()
            .unwrap()
            .unwrap()
            .file_name();
        fs::write(
            fixture.0.join(&destination).join("source").join(&name),
            b"existing",
        )
        .unwrap();
        Some(name)
    } else {
        None
    };
    let tree = request(Filetree::open(fixture.0.clone()));
    if case == CapacityCase::Loaded {
        let parent = request(tree.resolve(fixture.0.join(&source))).node;
        let entries = (0..count)
            .map(|index| Entry::read(&fixture.0.join(&source).join(name(index))).unwrap())
            .collect();
        work::wait(tree.data().submit(Action::Native(Box::new(LoadedFixture {
            tree: tree.clone(),
            parent,
            entries,
        }))))
        .unwrap();
    }
    let mut operation = plan(&tree, &source, Some(&destination), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    let source_node = operation.nodes[0];
    let started = Instant::now();
    let deadline = if case == CapacityCase::LateSkip && count >= 100_000 {
        Duration::from_secs(900)
    } else {
        Duration::from_secs(300)
    };
    let job = tree.start_operation(operation).unwrap();
    let memory = job.0.task_memory.clone();
    let mut peak = 0;
    let mut task_peak = 0;
    while !job.status().terminal {
        if case == CapacityCase::LateSkip
            && let Some(confirmation) = job.status().confirmation
        {
            job.confirm(confirmation.token, false).unwrap();
        }
        if case == CapacityCase::Cancel && job.status().bytes >= 40_000
            || started.elapsed() >= deadline
        {
            job.cancel();
        }
        assert!(
            started.elapsed() < deadline + Duration::from_secs(30),
            "copy cancellation timeout"
        );
        peak = peak.max(tree.data().memory().used());
        task_peak = task_peak.max(memory.used());
        std::thread::sleep(Duration::from_millis(5));
    }
    let elapsed = started.elapsed();
    let status = job.status();
    eprintln!(
        "capacity terminal case={case:?} files={count} bytes={} results={} error={:?} first_error={:?}",
        status.bytes,
        status.results,
        status.error,
        job.results(0, status.results.min(1))
            .unwrap()
            .first()
            .and_then(|result| result.error())
            .cloned()
    );
    assert!(
        matches!(status.cleanup, Some(Ok(()))),
        "{:?}",
        status.cleanup
    );
    assert!(!state.status().unwrap().locked);
    let complete = status.error.is_none() && case != CapacityCase::LateSkip;
    if case == CapacityCase::Cancel {
        assert!(status.cancelled);
        assert!(!complete);
    } else {
        assert!(!status.cancelled, "copy exceeded its deadline");
        assert!(status.error.is_none(), "{:?}", status.error);
    }
    assert_eq!(state.snapshot().unwrap().summary.is_empty(), complete);
    let mut successes = 0;
    for first in (0..status.results).step_by(512) {
        for result in job
            .results(first, (first + 512).min(status.results))
            .unwrap()
        {
            assert!(result.sync_error().is_none());
            if result.status == ItemStatus::Success {
                successes += 1;
                let node = if let Some(node) = result.node {
                    node
                } else {
                    let path = result.source();
                    let mut node = source_node;
                    let index = tree.index.lock().unwrap();
                    for component in path
                        .strip_prefix(fixture.0.join(&source))
                        .unwrap()
                        .components()
                    {
                        node = index
                            .child(Some(node), component.as_os_str())
                            .expect("successful frontier was admitted");
                    }
                    node
                };
                assert_eq!(
                    tree.inspect(tree.source(), node).unwrap().path().unwrap(),
                    result.source()
                );
                assert!(result.target().as_ref().unwrap().exists());
            }
        }
    }
    assert!(successes > 0);
    let mut copied = 0;
    for index in 0..count {
        let target = fixture
            .0
            .join(&destination)
            .join("source")
            .join(name(index));
        if skipped.as_deref() == Some(std::ffi::OsStr::new(&name(index))) {
            assert_eq!(fs::read(target).unwrap(), b"existing");
        } else if target.exists() {
            assert_eq!(fs::read(target).unwrap(), b"data");
            copied += 1;
        } else {
            assert!(!complete, "missing copied file {index}");
        }
        assert_eq!(
            fs::read(fixture.0.join(&source).join(name(index))).unwrap(),
            b"data"
        );
    }
    assert!(status.bytes >= copied * 4 && status.bytes <= count as u64 * 4);
    if complete {
        assert_eq!(status.bytes, copied * 4);
        assert_eq!(copied as usize, count);
        assert_eq!(status.results, 1);
        assert_eq!(
            tree.source().node(source_node).unwrap().child_count(),
            if case == CapacityCase::Loaded {
                count
            } else {
                0
            },
            "copy must not materialize additional source children"
        );
        assert_eq!(
            tree.source().node(source_node).unwrap().completeness,
            if case == CapacityCase::Loaded {
                Completeness::Complete
            } else {
                Completeness::Unknown
            }
        );
    } else {
        assert!((copied as usize) < count);
        assert_eq!(successes, copied as usize);
        let inspected = state
            .dispatch(Command::InspectSelection, Context::default())
            .wait();
        let Outcome::Reply(Reply::Inspected { sources, .. }) = inspected else {
            panic!("selection inspection");
        };
        assert!(!sources.summary.is_empty());
        assert!(!sources.subtree_roots.contains(&source_node));
        if case == CapacityCase::LateSkip {
            assert_eq!(copied as usize, count - 1);
            assert_eq!(status.results, count + 1);
            assert_eq!(
                tree.source().node(source_node).unwrap().child_count(),
                count - 1
            );
        }
        for result in job.results(0, 1).unwrap() {
            if result.status == ItemStatus::Success {
                if let Some(node) = result.node {
                    assert!(!sources.subtree_roots.contains(&node));
                }
            }
        }
    }
    assert_eq!(
        fs::read_dir(fixture.0.join(&destination)).unwrap().count(),
        usize::from(copied > 0 || complete)
    );
    eprintln!(
        "capacity case={case:?} files={count} copied={copied} completion_ms={} sampled_data_peak={} sampled_task_peak={} task_limit={} terminal_task_bytes={} source_nodes={} terminal_error={:?}",
        elapsed.as_millis(),
        peak,
        task_peak,
        RESULT_LIMIT,
        memory.used(),
        tree.source().len(),
        status.error
    );
    let first = status.results / 2;
    let page = job
        .results(first, (first + 512).min(status.results))
        .unwrap();
    let captured = page[0].source();
    drop(job);
    assert!(
        memory.used() > 0,
        "caller-held pages retain their own charge"
    );
    assert_eq!(page[0].source(), captured);
    drop(page);
    assert_eq!(memory.used(), 0);
}

#[test]
#[ignore = "creates and verifies 50k real files; run without concurrent load"]
fn t_staged_50k_copy_completes_with_default_task_capacity_and_selection_cleanup() {
    capacity_case(50_000, CapacityCase::Complete);
}

#[test]
#[ignore = "creates and verifies 100k real files; run without concurrent load"]
fn t_staged_100k_copy_completes_with_default_task_capacity_and_keeps_source_lazy() {
    capacity_case(100_000, CapacityCase::Complete);
}

#[test]
fn t_partial_frontier_uses_bounded_batches_and_survives_held_pages() {
    capacity_case(384, CapacityCase::LateSkip);
}

#[test]
#[ignore = "creates and verifies 50k files with a directly loaded Source; run without concurrent load"]
fn t_staged_50k_loaded_copy_completes_with_default_task_capacity() {
    capacity_case(50_000, CapacityCase::Loaded);
}

#[test]
#[ignore = "creates and verifies 100k files with a directly loaded Source; run without concurrent load"]
fn t_staged_100k_loaded_copy_completes_with_default_task_capacity() {
    capacity_case(100_000, CapacityCase::Loaded);
}

#[test]
#[ignore = "copies 99999 files, skips the last enumerated file, and checks cleanup; run without concurrent load"]
fn t_copy_capacity_100k_partial_frontier_cleans_only_successes() {
    capacity_case(100_000, CapacityCase::LateSkip);
}

#[test]
#[ignore = "creates and verifies 10k real files; run without concurrent load"]
fn t_copy_capacity_merge_preserves_default_budget_and_selection_cleanup() {
    capacity_case(10_000, CapacityCase::Merge);
}

#[test]
#[ignore = "creates 50k files and cancels after at least 10k copies; run without concurrent load"]
fn t_copy_capacity_cancel_preserves_paged_results_and_partial_cleanup() {
    capacity_case(50_000, CapacityCase::Cancel);
}

#[test]
#[ignore = "creates and verifies 10k files in nested long paths; run without concurrent load"]
fn t_copy_capacity_nested_long_paths_preserve_results_and_cleanup() {
    capacity_case(10_000, CapacityCase::NestedLong);
}

#[test]
fn t_fd_pressure_fails_one_job_without_stalling_another_and_allows_retry() {
    use std::time::{Duration, Instant};

    if std::env::var_os("FILETREE_TWO_JOB_FD_CHILD").is_none() {
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "ux::filetree::jobs::staged::tests::t_fd_pressure_fails_one_job_without_stalling_another_and_allows_retry", "--nocapture", "--test-threads=1"])
            .env("FILETREE_TWO_JOB_FD_CHILD", "1").output().unwrap();
        assert!(
            output.status.success(),
            "{}\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
        return;
    }
    struct AfterFirstItem {
        job: Job,
        action: Mutex<Option<Box<dyn FnOnce() + Send>>>,
    }
    impl Listener for AfterFirstItem {
        fn wake(&self) {
            if self.job.status().processed == 0 {
                return;
            }
            let action = self.action.lock().unwrap().take();
            if let Some(action) = action {
                action();
            }
        }
        fn close(&self) {}
        fn is_closed(&self) -> bool {
            false
        }
    }
    let fixture = Fixture::new();
    for name in ["source", "destination-a", "destination-b"] {
        fs::create_dir(fixture.0.join(name)).unwrap();
    }
    for index in 0..12 {
        fs::write(fixture.0.join(format!("source/{index:02}")), "data").unwrap();
    }
    fs::write(fixture.0.join("single"), "other job").unwrap();
    let tree = request(Filetree::open(fixture.0.clone()));
    let first_plan = plan(&tree, "source", Some("destination-a"), OperationKind::Copy);
    let other_plan = plan(&tree, "single", Some("destination-b"), OperationKind::Copy);
    let execution = EXECUTOR.lock().unwrap();
    let first = tree.start_operation(first_plan).unwrap();
    let concurrent = Arc::new(Mutex::new(None));
    let recorded = concurrent.clone();
    let other_tree = tree.clone();
    let listener: Arc<dyn Listener> = Arc::new(AfterFirstItem {
        job: first.clone(),
        action: Mutex::new(Some(Box::new(move || {
            /* Hold the first writer between items while the second encounters a hard fd limit. */
            let execution = EXECUTOR.lock().unwrap();
            let other = other_tree.start_operation(other_plan).unwrap();
            let deadline = Instant::now() + Duration::from_secs(5);
            while other.status().phase == JobPhase::Preparing {
                assert!(Instant::now() < deadline);
                std::thread::yield_now();
            }
            std::thread::sleep(Duration::from_millis(20));
            let mut limit: libc::rlimit = unsafe { std::mem::zeroed() };
            assert_eq!(
                unsafe { libc::getrlimit(libc::RLIMIT_NOFILE, &mut limit) },
                0
            );
            limit.rlim_cur = limit.rlim_cur.min(64);
            assert_eq!(unsafe { libc::setrlimit(libc::RLIMIT_NOFILE, &limit) }, 0);
            let mut held = Vec::new();
            loop {
                match fs::File::open("/dev/null") {
                    Ok(file) => held.push(file),
                    Err(error) => {
                        assert_eq!(error.raw_os_error(), Some(libc::EMFILE));
                        break;
                    }
                }
            }
            drop(execution);
            while !other.status().terminal {
                assert!(
                    Instant::now() < deadline,
                    "fd failure must terminate without holding the execution slot"
                );
                std::thread::sleep(Duration::from_millis(1));
            }
            *recorded.lock().unwrap() = Some(other);
            drop(held);
        }))),
    });
    tree.data().listen(&listener).unwrap();
    drop(execution);
    let first_results = done(&first);
    let other = concurrent
        .lock()
        .unwrap()
        .take()
        .expect("second real Job ran");
    let other_results = done(&other);
    assert_eq!(first_results.len(), 1);
    assert_eq!(other_results.len(), 1);
    assert_eq!(first_results[0].status, ItemStatus::Success);
    assert!(first_results[0].sync_error().is_none());
    assert_eq!(other_results[0].status, ItemStatus::Failed);
    assert!(other_results[0].error().is_some());
    assert!(!fixture.0.join("destination-b/single").exists());
    assert_eq!(fs::read(fixture.0.join("single")).unwrap(), b"other job");
    let retry = tree
        .start_operation(plan(
            &tree,
            "single",
            Some("destination-b"),
            OperationKind::Copy,
        ))
        .unwrap();
    assert_eq!(done(&retry)[0].status, ItemStatus::Success);
    assert_eq!(
        fs::read(fixture.0.join("destination-b/single")).unwrap(),
        b"other job"
    );
    for index in 0..12 {
        assert_eq!(
            fs::read(fixture.0.join(format!("destination-a/source/{index:02}"))).unwrap(),
            b"data"
        );
    }
}

#[test]
fn t_private_traversal_rejects_an_ancestor_move_without_loading_the_browse_source() {
    let dir = Fixture::new();
    for path in ["parent/src", "copydst", "movedst", "idle"] {
        fs::create_dir_all(dir.0.join(path)).unwrap();
    }
    for index in 0..1100 {
        fs::write(dir.0.join(format!("parent/src/file-{index:04}")), "x").unwrap();
    }
    let tree = request(Filetree::open(dir.0.clone()));
    let idle = request(tree.resolve(dir.0.join("idle"))).node;
    let Outcome::State(state) = tree
        .create_state(Some(Root::ChildrenOf(idle)), DisplayOptions::default())
        .wait()
    else {
        panic!("state");
    };
    let _view = state.attach().unwrap();
    let deadline = Instant::now() + Duration::from_secs(15);
    while tree.source().node(idle).unwrap().completeness != Completeness::Complete
        || tree.data().has_work()
    {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(1));
    }
    let copy = plan(&tree, "parent/src", Some("copydst"), OperationKind::Copy);
    let source = copy.nodes[0];
    let move_parent = plan(&tree, "parent", Some("movedst"), OperationKind::Move);
    struct BetweenItems {
        job: Job,
        action: std::sync::Mutex<Option<Box<dyn FnOnce() + Send>>>,
    }
    impl Listener for BetweenItems {
        fn wake(&self) {
            if self.job.status().processed == 0 {
                return;
            }
            let action = self.action.lock().unwrap().take();
            if let Some(action) = action {
                action();
            }
        }
        fn close(&self) {}
        fn is_closed(&self) -> bool {
            false
        }
    }
    let execution = EXECUTOR.lock().unwrap();
    let copying = tree.start_operation(copy).unwrap();
    let moving_tree = tree.clone();
    let listener: Arc<dyn Listener> = Arc::new(BetweenItems {
        job: copying.clone(),
        action: std::sync::Mutex::new(Some(Box::new(move || {
            assert_eq!(moving_tree.source().node(source).unwrap().child_count(), 0);
            let moved = done(&moving_tree.start_operation(move_parent).unwrap());
            assert_eq!(moved[0].status, ItemStatus::Success);
        }))),
    });
    tree.data().listen(&listener).unwrap();
    drop(execution);
    let deadline = Instant::now() + Duration::from_secs(15);
    while !copying.status().terminal {
        assert!(
            Instant::now() < deadline,
            "private traversal must stop after input moves"
        );
        std::thread::sleep(Duration::from_millis(1));
    }
    assert_eq!(
        copying.status().error.as_ref().unwrap().code,
        ErrorCode::Stale
    );
    let result = copying.results(0, copying.status().results).unwrap();
    assert_eq!(tree.source().node(source).unwrap().child_count(), 0);
    assert_eq!(
        tree.source().node(source).unwrap().completeness,
        Completeness::Unknown
    );
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].status, ItemStatus::Failed);
    assert_eq!(result[0].error().unwrap().code, ErrorCode::Stale);
    assert!(!dir.0.join("copydst/src").exists());
    assert_eq!(
        fs::read_dir(dir.0.join("movedst/parent/src"))
            .unwrap()
            .count(),
        1100
    );
}
