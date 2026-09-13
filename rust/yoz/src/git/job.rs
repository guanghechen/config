use super::{Options, Snapshot, collect};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::thread;

#[derive(Clone, Debug)]
pub enum Outcome<T = Arc<Snapshot>> {
    Completed(T),
    Cancelled,
    Failed(String),
}

pub struct QueryJob<T> {
    cancelled: Arc<AtomicBool>,
    receiver: Option<Receiver<Outcome<T>>>,
    terminal: Option<Outcome<T>>,
    disposed: bool,
}

pub type StatusJob = QueryJob<Arc<Snapshot>>;

impl<T> QueryJob<T> {
    pub fn poll(&mut self) -> Result<Option<&Outcome<T>>, String> {
        if self.disposed {
            return Err("Git query job has been disposed".into());
        }
        if self.terminal.is_none() {
            match self
                .receiver
                .as_ref()
                .ok_or("Git query receiver missing")?
                .try_recv()
            {
                Ok(outcome) => self.terminal = Some(outcome),
                Err(TryRecvError::Disconnected) => {
                    self.terminal = Some(Outcome::Failed("Git query worker disconnected".into()))
                }
                Err(TryRecvError::Empty) => {}
            }
            if self.terminal.is_some() {
                self.receiver = None;
            }
        }
        Ok(self.terminal.as_ref())
    }

    pub fn cancel(&mut self) -> Result<(), String> {
        if self.disposed {
            return Err("Git query job has been disposed".into());
        }
        self.cancelled.store(true, Ordering::Release);
        Ok(())
    }

    pub fn dispose(&mut self) {
        self.cancelled.store(true, Ordering::Release);
        self.receiver = None;
        self.terminal = None;
        self.disposed = true;
    }
}

impl<T> Drop for QueryJob<T> {
    fn drop(&mut self) {
        self.dispose();
    }
}

pub fn start_status(options: Options) -> Result<StatusJob, String> {
    if !options.cwd.is_absolute() {
        return Err("Git status cwd must be absolute".into());
    }
    spawn("yoz-git-status", move |cancelled| {
        collect(&options, cancelled).map(Arc::new)
    })
}

pub(crate) fn spawn<T: Send + 'static>(
    name: &'static str,
    work: impl FnOnce(&AtomicBool) -> Result<T, String> + Send + 'static,
) -> Result<QueryJob<T>, String> {
    let cancelled = Arc::new(AtomicBool::new(false));
    let worker_cancelled = Arc::clone(&cancelled);
    let (sender, receiver) = mpsc::channel();
    thread::Builder::new()
        .name(name.into())
        .spawn(move || {
            let outcome = match catch_unwind(AssertUnwindSafe(|| work(&worker_cancelled))) {
                Ok(_) if worker_cancelled.load(Ordering::Acquire) => Outcome::Cancelled,
                Ok(Ok(result)) => Outcome::Completed(result),
                Ok(Err(error)) => Outcome::Failed(error),
                Err(_) => Outcome::Failed(format!("{name} worker panicked")),
            };
            let _ = sender.send(outcome);
        })
        .map_err(|error| format!("Failed to start {name} worker: {error}"))?;
    Ok(QueryJob {
        cancelled,
        receiver: Some(receiver),
        terminal: None,
        disposed: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::git::test_support::Fixture;
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
}
