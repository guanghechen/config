use super::*;
use crate::search::search_in_files;
use std::sync::Barrier;
use std::thread;
use std::time::Duration;

fn fixture_options() -> ISearchInFilesOptions {
    let cwd = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../__test__/fixtures/yoz")
        .to_string_lossy()
        .to_string();
    ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: false,
        max_filesize: Some("1M".to_string()),
        max_matches: Some(100),
        search_pattern: "Hello".to_string(),
        search_paths: ".".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    }
}

#[test]
fn t_disconnected_worker_becomes_failed_terminal_outcome() {
    let cancelled = Arc::new(AtomicBool::new(false));
    let (sender, receiver) = mpsc::channel();
    drop(sender);
    let mut job = SearchInFilesJob {
        cancelled,
        receiver: Some(receiver),
        terminal: None,
        started_at: Instant::now(),
        disposed: false,
    };

    job.update_terminal().expect("poll should not fail");
    assert!(matches!(
        job.terminal,
        Some(SearchInFilesOutcome::Failed(_))
    ));
}

#[test]
fn t_dispose_is_idempotent_and_other_operations_reject_misuse() {
    let cancelled = Arc::new(AtomicBool::new(false));
    let (_sender, receiver) = mpsc::channel();
    let mut job = SearchInFilesJob {
        cancelled: Arc::clone(&cancelled),
        receiver: Some(receiver),
        terminal: None,
        started_at: Instant::now(),
        disposed: false,
    };

    job.dispose();
    job.dispose();

    assert!(cancelled.load(Ordering::Acquire));
    assert!(job.receiver.is_none());
    assert!(job.update_terminal().is_err());
    assert!(job.cancel().is_err());
}

#[test]
fn t_real_worker_cancel_stays_running_until_acknowledged() {
    let entered = Arc::new(Barrier::new(2));
    let release = Arc::new(Barrier::new(2));
    let worker_entered = Arc::clone(&entered);
    let worker_release = Arc::clone(&release);
    let mut job =
        start_search_in_files_with(fixture_options(), move |options, base_dir, cancelled| {
            worker_entered.wait();
            worker_release.wait();
            search_in_files_cancellable(options, base_dir, cancelled)
        })
        .expect("worker should start");

    entered.wait();
    job.cancel().expect("cancel request should succeed");
    job.update_terminal().expect("poll should succeed");
    assert!(job.terminal.is_none(), "cancel request is not terminal");

    release.wait();
    for _ in 0..5_000 {
        job.update_terminal().expect("poll should succeed");
        if job.terminal.is_some() {
            break;
        }
        thread::sleep(Duration::from_millis(1));
    }
    assert!(matches!(
        job.terminal,
        Some(SearchInFilesOutcome::Cancelled)
    ));
}

#[test]
fn t_worker_panic_remains_failed_when_cancelled_concurrently() {
    let entered = Arc::new(Barrier::new(2));
    let release = Arc::new(Barrier::new(2));
    let worker_entered = Arc::clone(&entered);
    let worker_release = Arc::clone(&release);
    let mut job = start_search_in_files_with(fixture_options(), move |_, _, _| {
        worker_entered.wait();
        worker_release.wait();
        panic!("worker exploded");
    })
    .expect("worker should start");

    entered.wait();
    job.cancel().expect("cancel request should succeed");
    release.wait();

    for _ in 0..5_000 {
        job.update_terminal().expect("poll should succeed");
        if job.terminal.is_some() {
            break;
        }
        thread::sleep(Duration::from_millis(1));
    }

    let Some(SearchInFilesOutcome::Failed(error)) = job.terminal.as_ref() else {
        panic!("worker panic must remain a failed terminal outcome");
    };
    assert!(error.error.contains("worker exploded"));
}

#[test]
fn t_async_job_preserves_synchronous_ordered_items() {
    let options = fixture_options();
    let expected = search_in_files(&options).expect("synchronous search should succeed");
    let mut job = start_search_in_files(options).expect("worker should start");

    for _ in 0..5_000 {
        job.update_terminal().expect("poll should succeed");
        if job.terminal.is_some() {
            break;
        }
        thread::sleep(Duration::from_millis(1));
    }

    let terminal = job
        .terminal
        .clone()
        .expect("worker should finish within the test timeout");
    let SearchInFilesOutcome::Completed(actual) = terminal else {
        panic!("expected completed async search, got {terminal:?}");
    };
    assert_eq!(expected.items, actual.items);

    job.update_terminal()
        .expect("terminal poll should be repeatable");
    assert!(matches!(
        job.terminal,
        Some(SearchInFilesOutcome::Completed(_))
    ));
}
