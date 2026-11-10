//! Work on a named worker thread that Lua polls, cancels and disposes; Lua owns the scheduling.

use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::thread;

#[derive(Clone, Debug)]
pub enum Outcome<T> {
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

impl<T> QueryJob<T> {
    pub fn poll(&mut self) -> Result<Option<&Outcome<T>>, String> {
        if self.disposed {
            return Err("Query job has been disposed".into());
        }
        if self.terminal.is_none() {
            match self
                .receiver
                .as_ref()
                .ok_or("Query job receiver missing")?
                .try_recv()
            {
                Ok(outcome) => self.terminal = Some(outcome),
                Err(TryRecvError::Disconnected) => {
                    self.terminal = Some(Outcome::Failed("Query worker disconnected".into()))
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
            return Err("Query job has been disposed".into());
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

    #[test]
    fn t_disconnected_worker_has_a_terminal_failure() {
        let (sender, receiver) = mpsc::channel::<Outcome<()>>();
        drop(sender);
        let mut job = QueryJob {
            cancelled: Arc::new(AtomicBool::new(false)),
            receiver: Some(receiver),
            terminal: None,
            disposed: false,
        };
        assert!(matches!(job.poll().unwrap(), Some(Outcome::Failed(_))));
    }
}
