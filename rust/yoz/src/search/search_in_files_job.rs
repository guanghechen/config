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
                let result = result.into_lua(lua)?;
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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/search/search_in_files_job_test.rs"
    ));
}
