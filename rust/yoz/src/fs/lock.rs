use std::fs::{self, File, OpenOptions, TryLockError};
use std::path::Path;
use std::thread;
use std::time::{Duration, Instant};

/// An exclusive OS lock on a file. It is released by `unlock`, on drop, and by the OS when the process ends, so a
/// crashed holder never leaves it behind.
pub struct FileLock(Option<File>);

impl FileLock {
    /// Locks `path`, creating it and its directory when missing, and retries every 10 ms until `timeout` passes.
    pub fn acquire(path: &Path, timeout: Duration) -> Result<Self, String> {
        if let Some(parent) = path.parent() {
            // Unlike `mkdir -p` in Vim, this tolerates another process creating the same directories at once.
            fs::create_dir_all(parent).map_err(|error| {
                format!("[lock] Failed to create {}: {error}", parent.display())
            })?;
        }
        let file = OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(path)
            .map_err(|error| format!("[lock] Failed to open {}: {error}", path.display()))?;
        let deadline = Instant::now() + timeout;
        loop {
            match file.try_lock() {
                Ok(()) => return Ok(Self(Some(file))),
                Err(TryLockError::WouldBlock) if Instant::now() < deadline => {
                    thread::sleep(Duration::from_millis(10));
                }
                Err(TryLockError::WouldBlock) => {
                    return Err(format!("[lock] Timed out waiting for {}", path.display()));
                }
                Err(TryLockError::Error(error)) => {
                    return Err(format!("[lock] Failed to lock {}: {error}", path.display()));
                }
            }
        }
    }

    /// Releases the lock; later calls do nothing.
    pub fn unlock(&mut self) {
        if let Some(file) = self.0.take() {
            // Closing the file releases the lock as well.
            let _ = file.unlock();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::FileLock;
    use crate::test_support::TempDir;
    use std::time::{Duration, Instant};

    #[test]
    fn t_lock_waits_for_its_holder_and_follows_each_release() {
        let dir = TempDir::new();
        let path = dir.path().join("state.lock");
        let mut held = FileLock::acquire(&path, Duration::ZERO).unwrap();

        let started = Instant::now();
        assert!(FileLock::acquire(&path, Duration::from_millis(50)).is_err());
        assert!(
            started.elapsed() >= Duration::from_millis(50),
            "waited for the holder"
        );

        held.unlock();
        held.unlock();
        drop(FileLock::acquire(&path, Duration::ZERO).unwrap());
        assert!(
            FileLock::acquire(&path, Duration::ZERO).is_ok(),
            "an unlocked or dropped lock is free again"
        );
    }

    #[test]
    fn t_locks_taken_at_once_create_their_directory_and_take_turns() {
        let dir = TempDir::new();
        let path = dir.path().join("a").join("b").join("state.lock");
        let holders = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let threads: Vec<_> = (0..8)
            .map(|_| {
                let (path, holders) = (path.clone(), holders.clone());
                std::thread::spawn(move || {
                    let mut lock = FileLock::acquire(&path, Duration::from_secs(5)).unwrap();
                    let order = std::sync::atomic::Ordering::SeqCst;
                    assert_eq!(0, holders.fetch_add(1, order), "one holder at a time");
                    std::thread::sleep(Duration::from_millis(5));
                    holders.fetch_sub(1, order);
                    lock.unlock();
                })
            })
            .collect();
        for thread in threads {
            thread.join().unwrap();
        }
    }
}
