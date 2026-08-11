use super::search_in_files::SearchInFilesOutcome;
use super::search_in_files::resolve_base_dir;
use super::search_in_files::search_in_files_cancellable;
use crate::types::ISearchFailedResult;
use crate::types::ISearchInFilesOptions;
use mlua::IntoLua;
use mlua::MultiValue as LuaMultiValue;
use mlua::Value as LuaValue;
use mlua::prelude::*;
use std::any::Any;
use std::panic::AssertUnwindSafe;
use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::sync::mpsc;
use std::sync::mpsc::Receiver;
use std::time::Instant;

pub struct SearchInFilesJob {
    cancelled: Arc<AtomicBool>,
    receiver: Option<Receiver<SearchInFilesOutcome>>,
    terminal: Option<SearchInFilesOutcome>,
    started_at: Instant,
    disposed: bool,
}

impl SearchInFilesJob {
    fn ensure_live(&self) -> LuaResult<()> {
        if self.disposed {
            return Err(LuaError::RuntimeError(
                "search-in-files job has been disposed".to_string(),
            ));
        }
        Ok(())
    }

    fn update_terminal(&mut self) -> LuaResult<()> {
        self.ensure_live()?;
        if self.terminal.is_some() {
            return Ok(());
        }

        let receiver = self.receiver.as_ref().ok_or_else(|| {
            LuaError::RuntimeError("search-in-files job has no result receiver".to_string())
        })?;

        match receiver.try_recv() {
            Ok(outcome) => {
                self.terminal = Some(outcome);
                self.receiver = None;
            }
            Err(mpsc::TryRecvError::Empty) => {}
            Err(mpsc::TryRecvError::Disconnected) => {
                self.terminal = Some(SearchInFilesOutcome::Failed(ISearchFailedResult {
                    elapsed_time: self.started_at.elapsed().as_millis() as u64,
                    error: "Search worker disconnected before publishing an outcome".to_string(),
                }));
                self.receiver = None;
            }
        }
        Ok(())
    }

    fn poll(&mut self, lua: &Lua) -> LuaResult<LuaMultiValue> {
        self.update_terminal()?;

        let Some(outcome) = self.terminal.as_ref() else {
            return poll_values(lua, "running", LuaValue::Nil, LuaValue::Nil);
        };

        match outcome {
            SearchInFilesOutcome::Completed(result) => {
                let result = result.clone().into_lua(lua)?;
                poll_values(lua, "completed", result, LuaValue::Nil)
            }
            SearchInFilesOutcome::Cancelled => {
                poll_values(lua, "cancelled", LuaValue::Nil, LuaValue::Nil)
            }
            SearchInFilesOutcome::Failed(error) => {
                let error = error.clone().into_lua(lua)?;
                poll_values(lua, "failed", LuaValue::Nil, error)
            }
        }
    }

    fn cancel(&mut self) -> LuaResult<()> {
        self.ensure_live()?;
        if self.terminal.is_none() {
            self.cancelled.store(true, Ordering::Release);
        }
        Ok(())
    }

    fn dispose(&mut self) {
        if self.disposed {
            return;
        }

        self.disposed = true;
        self.cancelled.store(true, Ordering::Release);
        self.receiver = None;
    }
}

impl Drop for SearchInFilesJob {
    fn drop(&mut self) {
        self.cancelled.store(true, Ordering::Release);
    }
}

impl LuaUserData for SearchInFilesJob {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("poll", |lua, job, ()| job.poll(lua));
        methods.add_method_mut("cancel", |_, job, ()| job.cancel());
        methods.add_method_mut("dispose", |_, job, ()| {
            job.dispose();
            Ok(())
        });
    }
}

pub fn start_search_in_files(options: ISearchInFilesOptions) -> Result<SearchInFilesJob, String> {
    start_search_in_files_with(options, search_in_files_cancellable)
}

fn start_search_in_files_with<F>(
    options: ISearchInFilesOptions,
    run_search: F,
) -> Result<SearchInFilesJob, String>
where
    F: FnOnce(&ISearchInFilesOptions, std::path::PathBuf, &AtomicBool) -> SearchInFilesOutcome
        + Send
        + 'static,
{
    let base_dir = resolve_base_dir(&options)?;
    let cancelled = Arc::new(AtomicBool::new(false));
    let worker_cancelled = Arc::clone(&cancelled);
    let (sender, receiver) = mpsc::channel();
    let started_at = Instant::now();
    let worker_started_at = started_at;

    std::thread::Builder::new()
        .name("yoz-search-in-files".to_string())
        .spawn(move || {
            let outcome = match std::panic::catch_unwind(AssertUnwindSafe(|| {
                run_search(&options, base_dir, &worker_cancelled)
            })) {
                Ok(_) if worker_cancelled.load(Ordering::Acquire) => {
                    SearchInFilesOutcome::Cancelled
                }
                Ok(outcome) => outcome,
                Err(panic) => SearchInFilesOutcome::Failed(ISearchFailedResult {
                    elapsed_time: worker_started_at.elapsed().as_millis() as u64,
                    error: format!("Search worker panicked: {}", panic_message(panic)),
                }),
            };
            let _ = sender.send(outcome);
        })
        .map_err(|error| format!("Failed to spawn search worker: {}", error))?;

    Ok(SearchInFilesJob {
        cancelled,
        receiver: Some(receiver),
        terminal: None,
        started_at,
        disposed: false,
    })
}

fn panic_message(panic: Box<dyn Any + Send>) -> String {
    if let Some(message) = panic.downcast_ref::<&str>() {
        return (*message).to_string();
    }
    if let Some(message) = panic.downcast_ref::<String>() {
        return message.clone();
    }
    "unknown panic payload".to_string()
}

fn poll_values(
    lua: &Lua,
    status: &str,
    result: LuaValue,
    error: LuaValue,
) -> LuaResult<LuaMultiValue> {
    Ok(LuaMultiValue::from_vec(vec![
        LuaValue::String(lua.create_string(status)?),
        result,
        error,
    ]))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::search::search_in_files;
    use std::sync::Barrier;
    use std::thread;
    use std::time::Duration;

    fn fixture_options() -> ISearchInFilesOptions {
        let cwd = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures")
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
}
