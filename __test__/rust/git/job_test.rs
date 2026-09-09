use super::*;
use crate::test_support::Fixture;
use std::time::{Duration, Instant};

#[test]
fn t_completed_result_is_repeatable_and_disposal_is_idempotent() {
    let fixture = Fixture::new();
    fixture.write("new", "content");
    let mut job = start_status(fixture.options()).unwrap();
    let started = Instant::now();
    while job.poll().unwrap().is_none() {
        assert!(started.elapsed() < Duration::from_secs(5));
        thread::sleep(Duration::from_millis(1));
    }
    let Some(Outcome::Completed(first)) = job.poll().unwrap().cloned() else {
        panic!("completed")
    };
    let Some(Outcome::Completed(second)) = job.poll().unwrap() else {
        panic!("completed")
    };
    assert!(Arc::ptr_eq(&first, second));
    job.dispose();
    job.dispose();
    assert!(job.poll().is_err());
    assert!(job.cancel().is_err());
    assert_eq!(first.entries.len(), 1);
}

#[test]
fn t_disconnected_worker_has_a_terminal_failure() {
    let (sender, receiver) = mpsc::channel();
    drop(sender);
    let mut job = StatusJob {
        cancelled: Arc::new(AtomicBool::new(false)),
        receiver: Some(receiver),
        terminal: None,
        disposed: false,
    };
    assert!(matches!(job.poll().unwrap(), Some(Outcome::Failed(_))));
}

#[test]
fn t_relative_cwd_is_rejected_before_worker_creation() {
    let fixture = Fixture::new();
    let mut options = fixture.options();
    options.cwd = "relative".into();
    assert!(start_status(options).is_err());
}
