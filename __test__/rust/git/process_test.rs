use super::*;
use crate::test_support::Fixture;

#[test]
fn t_precancelled_query_spawns_nothing() {
    assert_eq!(
        run(Path::new("/missing"), &[], &[], &AtomicBool::new(true)).unwrap_err(),
        CANCELLED
    );
}

#[test]
fn t_git_failure_retains_stderr() {
    let fixture = Fixture::new();
    let error = run(
        &fixture.0,
        &fixture.options().environment,
        &[
            "rev-parse".into(),
            "--verify".into(),
            "does-not-exist".into(),
        ],
        &AtomicBool::new(false),
    )
    .unwrap_err();
    assert!(error.contains("exit 128"));
    assert!(error.contains("fatal:"));
}

#[test]
fn t_large_stdin_is_fully_written_and_closed() {
    let fixture = Fixture::new();
    let input = vec![b'x'; 2 * 1024 * 1024];
    let expected = fixture.git(&["hash-object", "--stdin"], Some(&input));
    let result = output(
        &fixture.0,
        &fixture.options().environment,
        &["hash-object".into(), "--stdin".into()],
        Some(input),
        &AtomicBool::new(false),
    )
    .unwrap();
    assert!(result.status.success());
    assert_eq!(result.stdout, expected);
}

#[test]
#[cfg(unix)]
fn t_cancel_interrupts_a_blocked_stdin_writer() {
    let fixture = Fixture::new();
    let cancelled = AtomicBool::new(false);
    let started = Instant::now();
    thread::scope(|scope| {
        scope.spawn(|| {
            thread::sleep(Duration::from_millis(100));
            cancelled.store(true, Ordering::Release);
        });
        let result = output(
            &fixture.0,
            &fixture.options().environment,
            &["-c".into(), "alias.slow=!sleep 30".into(), "slow".into()],
            Some(vec![b'x'; 1024 * 1024]),
            &cancelled,
        );
        assert_eq!(result.unwrap_err(), CANCELLED);
    });
    assert!(started.elapsed() < Duration::from_secs(2));
}

#[test]
#[cfg(unix)]
fn t_nonzero_exit_preserves_stdout_after_early_stdin_close() {
    let fixture = Fixture::new();
    let result = output(
        &fixture.0,
        &fixture.options().environment,
        &[
            "-c".into(),
            "alias.partial=!printf 'match\\0'; exit 7".into(),
            "partial".into(),
        ],
        Some(vec![b'x'; 1024 * 1024]),
        &AtomicBool::new(false),
    )
    .unwrap();
    assert_eq!(result.status.code(), Some(7));
    assert_eq!(result.stdout, b"match\0");
}

#[test]
#[cfg(unix)]
fn t_cancel_interrupts_owned_git_process_and_its_pipes() {
    let fixture = Fixture::new();
    let cancelled = AtomicBool::new(false);
    let started = Instant::now();
    thread::scope(|scope| {
        scope.spawn(|| {
            thread::sleep(Duration::from_millis(100));
            cancelled.store(true, Ordering::Release);
        });
        let result = run(
            &fixture.0,
            &fixture.options().environment,
            &["-c".into(), "alias.slow=!sleep 30".into(), "slow".into()],
            &cancelled,
        );
        assert_eq!(result.unwrap_err(), CANCELLED);
    });
    assert!(started.elapsed() < Duration::from_secs(2));
}
