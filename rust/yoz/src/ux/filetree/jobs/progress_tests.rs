use super::*;
use crate::ux::filetree::jobs_tests::{done, plan};
use crate::ux::filetree::tests::{Directory, request};
use std::fs;

struct Observer {
    job: Job,
    statuses: Mutex<Vec<JobStatus>>,
    cancel_on_item: bool,
    cancelled: AtomicBool,
}

impl Listener for Observer {
    fn wake(&self) {
        let mut statuses = self.statuses.lock().unwrap();
        let status = self.job.status();
        let cancel = self.cancel_on_item && status.processed > 0 && !status.terminal;
        statuses.push(status);
        drop(statuses);
        if cancel && !self.cancelled.swap(true, Ordering::AcqRel) {
            self.job.cancel();
        }
    }
    fn close(&self) {}
    fn is_closed(&self) -> bool {
        false
    }
}

fn observe(tree: &Filetree, operation: OperationPlan, cancel_on_item: bool) -> Arc<Observer> {
    let execution = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
    let job = tree.start_operation(operation).unwrap();
    let observer = Arc::new(Observer {
        job,
        statuses: Mutex::new(Vec::new()),
        cancel_on_item,
        cancelled: AtomicBool::new(false),
    });
    let listener: Arc<dyn Listener> = observer.clone();
    tree.data().listen(&listener).unwrap();
    drop(execution);
    observer
}

#[test]
fn t_job_processed_counts_survive_subtree_compaction_including_empty_files() {
    for contents in ["", "test"] {
        let fixture = Directory::new();
        fs::create_dir_all(fixture.0.join("source/nested")).unwrap();
        fs::create_dir(fixture.0.join("destination")).unwrap();
        for index in 0..128 {
            fs::write(fixture.0.join(format!("source/nested/{index}")), contents).unwrap();
        }
        let tree = request(Filetree::open(fixture.0.clone()));
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
                fs::read(fixture.0.join(format!("destination/source/nested/{index}"))).unwrap(),
                contents.as_bytes()
            );
        }
    }
}

#[test]
fn t_empty_file_progress_can_cancel_before_directory_completion() {
    let fixture = Directory::new();
    fs::create_dir(fixture.0.join("source")).unwrap();
    fs::create_dir(fixture.0.join("destination")).unwrap();
    for index in 0..64 {
        fs::write(fixture.0.join(format!("source/{index}")), "").unwrap();
    }
    let tree = request(Filetree::open(fixture.0.clone()));
    let operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
    let observer = observe(&tree, operation, true);
    let deadline = Instant::now() + Duration::from_secs(10);
    while !observer.job.status().terminal {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(1));
    }
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
    assert_eq!(fs::read_dir(fixture.0.join("source")).unwrap().count(), 64);
    assert_eq!(
        fs::read_dir(fixture.0.join("destination/source"))
            .unwrap()
            .count(),
        completed
    );
}

#[test]
fn t_create_progress_counts_only_created_components() {
    let fixture = Directory::new();
    fs::create_dir(fixture.0.join("existing")).unwrap();
    let tree = request(Filetree::open(fixture.0.clone()));
    let target = request(tree.resolve(fixture.0.clone()));
    let job = tree
        .start_create(CreatePlan {
            target,
            path: "existing/new/empty".into(),
            directory: false,
        })
        .unwrap();
    let results = done(&job);
    let status = job.status();
    assert_eq!(status.processed, 2);
    assert_eq!(results.len(), 2);
    assert_eq!(status.bytes, 0);
    assert_eq!(status.phase, JobPhase::Complete);
}
