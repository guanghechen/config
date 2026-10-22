use super::super::*;
use crate::test_support::{TempDir, eventually};
use crate::ux::filetree::test_support::*;
use crate::ux::treeview::test_support::{Listening, listen};
use std::fs;

#[test]
fn t_job_confirmation_does_not_apply_to_replaced_target_and_other_job_progresses() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("a"), "new").unwrap();
    fs::write(dir.path().join("b"), "other").unwrap();
    fs::write(dir.path().join("dst/a"), "old").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let job = tree
        .start_operation(plan(&tree, "a", Some("dst"), OperationKind::Copy))
        .unwrap();
    eventually(|| job.status().confirmation.is_some());
    let token = job.status().confirmation.unwrap().token;
    assert_eq!(
        done(
            &tree
                .start_operation(plan(&tree, "b", Some("dst"), OperationKind::Copy))
                .unwrap()
        )[0]
        .status,
        ItemStatus::Success
    );
    fs::rename(dir.path().join("dst/a"), dir.path().join("dst/old")).unwrap();
    fs::write(dir.path().join("dst/a"), "replacement").unwrap();
    job.confirm(token, true).unwrap();
    let results = done(&job);
    assert_eq!(results[0].status, ItemStatus::Failed);
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/a")).unwrap(),
        "replacement"
    );
}

#[test]
fn t_job_rejected_plan_releases_prepared_lock_and_keeps_selection() {
    let _operations = operations();
    for failure in ["missing target", "invalid name", "memory limit"] {
        let dir = TempDir::new();
        fs::create_dir(dir.path().join("dst")).unwrap();
        fs::write(dir.path().join("a"), "content").unwrap();
        let tree = request(Filetree::open(dir.path().to_path_buf()));
        let mut operation = plan(&tree, "a", Some("dst"), OperationKind::Copy);
        let node = operation.nodes[0];
        let state = selection(&tree, &mut operation);
        let memory = tree.data().memory();
        let _memory = memory.enter();
        let pressure = (failure == "memory limit")
            .then(|| crate::ux::treeview::memory::Charge::new(tree.data().limits().memory_bytes));
        match failure {
            "invalid name" => operation.name = Some("bad/name".into()),
            "missing target" => operation.target = None,
            _ => {}
        }
        let expected = if pressure.is_some() {
            ErrorCode::ResourceLimit
        } else {
            ErrorCode::InvalidUpdate
        };
        assert!(matches!(tree.start_operation(operation), Err(error) if error.code == expected));
        drop(pressure);
        assert!(!state.status().unwrap().locked);
        let Reply::Inspected { sources, .. } =
            reply(state.dispatch(Command::InspectSelection, Context::default()))
        else {
            panic!("selection");
        };
        assert!(sources.subtree_roots.contains(&node));
        assert_eq!(fs::read_to_string(dir.path().join("a")).unwrap(), "content");
        assert!(!dir.path().join("dst/a").exists());
    }
}

#[test]
fn t_job_failed_claim_releases_only_its_unclaimed_selection_lock() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("a"), "original").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "a", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut operation);
    fs::rename(dir.path().join("a"), dir.path().join("prior")).unwrap();
    fs::write(dir.path().join("a"), "replacement").unwrap();
    request(tree.resolve(dir.path().join("a")));
    assert!(state.status().unwrap().locked);
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().terminal);
    assert_eq!(job.status().error.unwrap().code, ErrorCode::Stale);
    assert_eq!(
        job.status().cleanup.unwrap().unwrap_err().code,
        ErrorCode::Stale
    );
    assert!(!state.status().unwrap().locked);
    assert_eq!(
        fs::read_to_string(dir.path().join("a")).unwrap(),
        "replacement"
    );
    assert_eq!(
        fs::read_to_string(dir.path().join("prior")).unwrap(),
        "original"
    );
    assert!(!dir.path().join("dst/a").exists());
}

#[test]
fn t_job_cancel_confirmation_releases_own_lock_and_rejects_duplicate_job() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("a"), "new").unwrap();
    fs::write(dir.path().join("dst/a"), "old").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut first = plan(&tree, "a", Some("dst"), OperationKind::Copy);
    let state = selection(&tree, &mut first);
    let second = OperationPlan {
        prepare_move: false,
        source: first.source.clone(),
        nodes: first.nodes.clone(),
        target: first.target.clone(),
        task: first.task.clone(),
        name: None,
        kind: first.kind,
    };
    let job = tree.start_operation(first).unwrap();
    eventually(|| job.status().confirmation.is_some());
    let rejected = OperationPlan {
        source: second.source.clone(),
        nodes: second.nodes.clone(),
        target: None,
        task: second.task.clone(),
        name: None,
        kind: second.kind,
        prepare_move: false,
    };
    assert!(tree.start_operation(rejected).is_err());
    assert!(state.status().unwrap().locked);
    let duplicate = tree.start_operation(second).unwrap();
    eventually(|| duplicate.status().terminal);
    assert_eq!(duplicate.status().error.unwrap().code, ErrorCode::Busy);
    assert!(state.status().unwrap().locked);
    job.cancel();
    eventually(|| job.status().terminal);
    assert!(job.status().cancelled);
    assert!(job.status().cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
    assert_eq!(fs::read_to_string(dir.path().join("dst/a")).unwrap(), "old");
}

#[test]
fn t_job_same_parent_sorting_does_not_stale_another_prepared_selection() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::write(dir.path().join("a"), "a").unwrap();
    fs::write(dir.path().join("b"), "b").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "a", Some("."), OperationKind::Move);
    operation.name = Some("z".into());
    let mut other = OperationPlan {
        source: operation.source.clone(),
        nodes: operation.nodes.clone(),
        kind: OperationKind::Delete,
        prepare_move: false,
        target: None,
        name: None,
        task: None,
    };
    let state = selection(&tree, &mut other);
    let context = other.task.unwrap();
    let result = done(&tree.start_operation(operation).unwrap());
    assert!(
        result[0].sync_error().is_none(),
        "{:?}",
        result[0].sync_error()
    );
    let prepared = reply(state.dispatch(
        Command::PrepareSources {
            lock: context.lock,
            retry: false,
        },
        Context::default(),
    ));
    assert!(matches!(prepared, Reply::Ready { .. }));
    reply(state.submit(Action::Unlock(state.id(), context.lock)));
}

#[test]
fn t_job_confirmation_outlives_preparation_deadline_without_unlocking_selection() {
    let _operations = operations();
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("file"), "new").unwrap();
    fs::write(dir.path().join("dst/file"), "old").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "file", Some("dst"), OperationKind::Copy);
    let state = selection_with_deadline(
        &tree,
        &mut operation,
        Some(Instant::now() + Duration::from_millis(250)),
    );
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().confirmation.is_some());
    std::thread::sleep(Duration::from_millis(350));
    assert!(
        state.status().unwrap().locked,
        "preparation timeout released an executing task"
    );
    job.cancel();
    eventually(|| job.status().terminal);
    assert!(job.status().cleanup.unwrap().is_ok());
    assert!(!state.status().unwrap().locked);
}

/// Records the job's status on every wake, and with `cancel_on_item` cancels the job once an item is
/// processed. Reading the status on wake also verifies that notification does not hold the Job
/// status lock.
struct Observer {
    job: Job,
    statuses: Arc<Mutex<Vec<JobStatus>>>,
    _listening: Listening,
}

impl Observer {
    fn new(data: &DataHandle, job: Job, cancel_on_item: bool) -> Self {
        let statuses = Arc::new(Mutex::new(Vec::<JobStatus>::new()));
        let (observed, recorded) = (job.clone(), statuses.clone());
        let cancelled = AtomicBool::new(false);
        let listening = listen(data, move || {
            let mut statuses = recorded.lock().unwrap();
            // The data owner also wakes for its own work; record job publications, as consumers do.
            let Some(status) = observed.status_since(statuses.last().map(|status| status.revision))
            else {
                return;
            };
            let cancel = cancel_on_item && status.processed > 0 && !status.terminal;
            statuses.push(status);
            drop(statuses);
            if cancel && !cancelled.swap(true, Ordering::AcqRel) {
                observed.cancel();
            }
        });
        Self {
            job,
            statuses,
            _listening: listening,
        }
    }
}

/// Starts `operation` with an [`Observer`] registered before its IO begins.
fn observe(tree: &Filetree, operation: OperationPlan, cancel_on_item: bool) -> Observer {
    let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
    let job = tree.start_operation(operation).unwrap();
    let observer = Observer::new(tree.data(), job, cancel_on_item);
    drop(execution);
    observer
}

#[test]
fn t_job_processed_counts_survive_subtree_compaction_including_empty_files() {
    let _operations = operations();
    for contents in ["", "test"] {
        let fixture = TempDir::new();
        fs::create_dir_all(fixture.path().join("source/nested")).unwrap();
        fs::create_dir(fixture.path().join("destination")).unwrap();
        for index in 0..128 {
            fs::write(
                fixture.path().join(format!("source/nested/{index}")),
                contents,
            )
            .unwrap();
        }
        let tree = request(Filetree::open(fixture.path().to_path_buf()));
        let operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
        let observer = observe(&tree, operation, false);
        let results = done(&observer.job);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].status, ItemStatus::Success);
        let status = observer.job.status();
        assert_eq!(status.phase, JobPhase::Complete);
        assert_eq!(status.processed, 130);
        assert_eq!(status.bytes, 128 * contents.len() as u64);
        let statuses = observer.statuses.lock().unwrap();
        assert!(
            statuses
                .iter()
                .any(|status| { !status.terminal && status.processed > 0 && status.results == 0 })
        );
        assert!(statuses.windows(2).all(|pair| {
            pair[0].processed <= pair[1].processed && pair[0].bytes <= pair[1].bytes
        }));
        for index in 0..128 {
            assert_eq!(
                fs::read(
                    fixture
                        .path()
                        .join(format!("destination/source/nested/{index}"))
                )
                .unwrap(),
                contents.as_bytes()
            );
        }
    }
}

#[test]
fn t_empty_file_progress_can_cancel_before_directory_completion() {
    let _operations = operations();
    let fixture = TempDir::new();
    fs::create_dir(fixture.path().join("source")).unwrap();
    fs::create_dir(fixture.path().join("destination")).unwrap();
    for index in 0..64 {
        fs::write(fixture.path().join(format!("source/{index}")), "").unwrap();
    }
    let tree = request(Filetree::open(fixture.path().to_path_buf()));
    let operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let observer = observe(&tree, operation, true);
    eventually(|| observer.job.status().terminal);
    let status = observer.job.status();
    let results = observer.job.results(0, status.results).unwrap();
    assert!(status.cancelled);
    assert_eq!(status.phase, JobPhase::Complete);
    assert_eq!(status.bytes, 0);
    assert!(status.processed > 0 && status.processed < 65);
    let completed = results
        .iter()
        .filter(|item| item.status == ItemStatus::Success)
        .count();
    assert!(completed > 0 && completed < 64);
    assert_eq!(
        fs::read_dir(fixture.path().join("source")).unwrap().count(),
        64
    );
    assert_eq!(
        fs::read_dir(fixture.path().join("destination/source"))
            .unwrap()
            .count(),
        completed
    );
}

#[test]
fn t_job_notifications_coalesce_bytes_and_publish_confirmation_and_cancellation() {
    let data = DataHandle::new(Limits::default()).unwrap();
    let job = Job(Arc::new(Shared {
        _source: data.source(),
        _state: None,
        data: data.downgrade(),
        id: 1,
        cancel: AtomicBool::new(false),
        bytes: AtomicU64::new(0),
        processed: AtomicUsize::new(0),
        revision: AtomicU64::new(1),
        progress: Mutex::new(None),
        state: Mutex::new(Status {
            phase: JobPhase::Preparing,
            terminal: false,
            cancelled: false,
            confirmation: None,
            answer: None,
            results: Vec::new(),
            published: 0,
            error: None,
            cleanup: None,
        }),
        changed: Condvar::new(),
        task_memory: Memory::new(data.memory()),
        _memory: Charge::new(1024),
    }));
    let observer = Observer::new(&data, job.clone(), false);
    job.set_phase(JobPhase::Reading);
    assert_eq!(
        observer.statuses.lock().unwrap().last().unwrap().phase,
        JobPhase::Reading
    );
    job.set_phase(JobPhase::Working);
    job.copied(100);
    assert_eq!(observer.statuses.lock().unwrap().last().unwrap().bytes, 100);
    let count = observer.statuses.lock().unwrap().len();
    let revision = job.status().revision;
    /* Keep scheduler pauses from advancing the progress window in this test. */
    *job.0.progress.lock().unwrap() = Some(Instant::now() + Duration::from_secs(60));
    job.copied(200);
    assert_eq!(observer.statuses.lock().unwrap().len(), count);
    assert_eq!(job.status().bytes, 300);
    assert!(job.status_since(Some(revision)).is_none());
    job.processed();
    assert_eq!(observer.statuses.lock().unwrap().len(), count + 1);
    assert_eq!(
        observer.statuses.lock().unwrap().last().unwrap().processed,
        1
    );
    *job.0.progress.lock().unwrap() = Some(Instant::now() + Duration::from_secs(60));
    job.processed();
    assert_eq!(observer.statuses.lock().unwrap().len(), count + 1);
    assert_eq!(job.status().processed, 2);
    let count = observer.statuses.lock().unwrap().len();
    job.0.state.lock().unwrap().confirmation = Some(Confirmation {
        token: 1,
        item: ItemId(1),
        node: Some(NodeId(1)),
        source: PathBuf::from("source"),
        target: PathBuf::from("target"),
        prepare_move: false,
    });
    job.confirm(1, false).unwrap();
    assert_eq!(observer.statuses.lock().unwrap().len(), count + 1);
    assert_eq!(job.status_since(Some(revision)).unwrap().bytes, 300);
    job.cancel();
    assert!(observer.statuses.lock().unwrap().last().unwrap().cancelling);
    assert_eq!(observer.statuses.lock().unwrap().len(), count + 2);
    let weak = data.downgrade();
    drop(data);
    assert!(
        weak.upgrade().is_none(),
        "a Job notification must not retain its data owner"
    );
    job.notify();
}
