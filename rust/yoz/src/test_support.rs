//! Support shared by unit tests across the crate.

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

/** How long [`eventually`] polls before failing the test. */
const TIMEOUT: Duration = Duration::from_secs(15);

/** Set in the child process that [`isolated`] starts. */
#[cfg(any(target_os = "macos", target_os = "linux"))]
const ISOLATED: &str = "YOZ_TEST_ISOLATED";

/// A fresh directory, removed with its contents on drop.
pub(crate) struct TempDir(PathBuf);

impl TempDir {
    pub(crate) fn new() -> Self {
        Self::new_in(&std::env::temp_dir())
    }

    pub(crate) fn new_in(parent: &Path) -> Self {
        let path = parent.join(format!("yoz-test-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }

    pub(crate) fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// What an [`eventually`] poll returns: `true`, or `Some` value, once the awaited condition holds.
pub(crate) trait Ready {
    type Output;
    fn ready(self) -> Option<Self::Output>;
}

impl Ready for bool {
    type Output = ();
    fn ready(self) -> Option<()> {
        self.then_some(())
    }
}

impl<T> Ready for Option<T> {
    type Output = T;
    fn ready(self) -> Option<T> {
        self
    }
}

/// Polls `poll` every millisecond until it is ready; fails the test after [`TIMEOUT`].
#[track_caller]
pub(crate) fn eventually<R: Ready>(mut poll: impl FnMut() -> R) -> R::Output {
    let started = Instant::now();
    loop {
        if let Some(value) = poll().ready() {
            return value;
        }
        assert!(
            started.elapsed() < TIMEOUT,
            "condition not reached in {TIMEOUT:?}"
        );
        std::thread::sleep(Duration::from_millis(1));
    }
}

/// The nearest-rank percentile of ascending samples: the smallest sample with at least `fraction` of
/// the samples at or below it.
pub(crate) fn percentile<T: Copy>(sorted: &[T], fraction: f64) -> T {
    sorted[((sorted.len() as f64 * fraction).ceil() as usize).clamp(1, sorted.len()) - 1]
}

/// Lets a test exhaust process-wide resources, such as descriptors or the shared IO pool, without
/// disturbing tests running beside it. In the test process it reruns `test` alone in a child process,
/// asserts that it passed and returns false; in that child it returns true and the test runs its body.
/// `test` is the test's path, `concat!(module_path!(), "::<name>")`.
#[cfg(any(target_os = "macos", target_os = "linux"))]
pub(crate) fn isolated(test: &str) -> bool {
    if std::env::var_os(ISOLATED).is_some() {
        return true;
    }
    let test = test
        .strip_prefix(concat!(env!("CARGO_CRATE_NAME"), "::"))
        .unwrap_or(test);
    let output = std::process::Command::new(std::env::current_exe().unwrap())
        .args(["--exact", test, "--nocapture"])
        .env(ISOLATED, "1")
        .output()
        .unwrap();
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        output.status.success() && stdout.contains("1 passed"),
        "{stdout}\n{}",
        String::from_utf8_lossy(&output.stderr)
    );
    false
}
