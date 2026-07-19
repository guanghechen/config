use std::ffi::OsStr;
use std::io::{self, Read};
use std::process::{Command, Output, Stdio};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::time::{Duration, Instant};

use crate::error::{AppError, AppResult};

pub struct OperationDeadline {
    label: String,
    started_at: Instant,
    budget: Duration,
}

impl OperationDeadline {
    pub fn new(label: impl Into<String>, budget: Duration) -> Self {
        Self {
            label: label.into(),
            started_at: Instant::now(),
            budget,
        }
    }

    pub fn check(&self, phase: &str) -> AppResult<()> {
        if self.started_at.elapsed() < self.budget {
            return Ok(());
        }

        Err(AppError::CommandTimeout {
            command: format!("{} {phase}", self.label),
            timeout_ms: self.budget.as_millis(),
        })
    }
}

/// Runs a bounded child process without a shell. Timeout aborts and reaps the
/// child; all other IO failures propagate to the caller's boundary policy.
pub fn output_with_timeout<I, S>(program: &str, args: I, timeout: Duration) -> AppResult<Output>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let args = args
        .into_iter()
        .map(|arg| arg.as_ref().to_os_string())
        .collect::<Vec<_>>();
    let command = std::iter::once(program.to_string())
        .chain(args.iter().map(|arg| arg.to_string_lossy().into_owned()))
        .collect::<Vec<_>>()
        .join(" ");
    let mut command_builder = Command::new(program);
    command_builder
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    configure_process_group(&mut command_builder);
    let mut child = command_builder.spawn()?;
    let process_group_id = child.id();
    let stdout_reader = child.stdout.take().map(spawn_reader);
    let stderr_reader = child.stderr.take().map(spawn_reader);
    let start = Instant::now();
    let deadline = start + timeout;

    let status = loop {
        match child.try_wait() {
            Ok(Some(status)) => break status,
            Ok(None) if Instant::now() < deadline => {
                std::thread::sleep(Duration::from_millis(1));
            }
            Ok(None) => {
                terminate_process_group(&mut child, process_group_id);
                return Err(AppError::CommandTimeout {
                    command,
                    timeout_ms: timeout.as_millis(),
                });
            }
            Err(error) => {
                terminate_process_group(&mut child, process_group_id);
                return Err(error.into());
            }
        }
    };

    let stdout = match receive_reader(stdout_reader, deadline) {
        Ok(stdout) => stdout,
        Err(ReaderReceiveError::Timeout) => {
            terminate_process_group(&mut child, process_group_id);
            return Err(AppError::CommandTimeout {
                command,
                timeout_ms: timeout.as_millis(),
            });
        }
        Err(ReaderReceiveError::Io(error)) => {
            terminate_process_group(&mut child, process_group_id);
            return Err(error.into());
        }
    };
    let stderr = match receive_reader(stderr_reader, deadline) {
        Ok(stderr) => stderr,
        Err(ReaderReceiveError::Timeout) => {
            terminate_process_group(&mut child, process_group_id);
            return Err(AppError::CommandTimeout {
                command,
                timeout_ms: timeout.as_millis(),
            });
        }
        Err(ReaderReceiveError::Io(error)) => {
            terminate_process_group(&mut child, process_group_id);
            return Err(error.into());
        }
    };
    Ok(Output {
        status,
        stdout,
        stderr,
    })
}

fn spawn_reader<R>(mut pipe: R) -> Receiver<io::Result<Vec<u8>>>
where
    R: Read + Send + 'static,
{
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let mut output = Vec::new();
        let result = pipe.read_to_end(&mut output).map(|_| output);
        let _ = sender.send(result);
    });
    receiver
}

enum ReaderReceiveError {
    Timeout,
    Io(io::Error),
}

fn receive_reader(
    reader: Option<Receiver<io::Result<Vec<u8>>>>,
    deadline: Instant,
) -> Result<Vec<u8>, ReaderReceiveError> {
    let Some(reader) = reader else {
        return Ok(Vec::new());
    };
    let remaining = deadline.saturating_duration_since(Instant::now());
    match reader.recv_timeout(remaining) {
        Ok(result) => result.map_err(ReaderReceiveError::Io),
        Err(RecvTimeoutError::Timeout) => Err(ReaderReceiveError::Timeout),
        Err(RecvTimeoutError::Disconnected) => Err(ReaderReceiveError::Io(io::Error::other(
            "command output reader disconnected",
        ))),
    }
}

#[cfg(unix)]
fn configure_process_group(command: &mut Command) {
    use std::os::unix::process::CommandExt;

    command.process_group(0);
}

#[cfg(not(unix))]
fn configure_process_group(_command: &mut Command) {}

#[cfg(unix)]
fn terminate_process_group(child: &mut std::process::Child, process_group_id: u32) {
    const SIGKILL: i32 = 9;

    if let Ok(process_group_id) = i32::try_from(process_group_id) {
        // The child was spawned as its own process-group leader. A negative pid
        // targets the whole group, including descendants that still own pipes.
        unsafe {
            kill(-process_group_id, SIGKILL);
        }
    }
    let _ = child.kill();
    let _ = child.wait();
}

#[cfg(not(unix))]
fn terminate_process_group(child: &mut std::process::Child, _process_group_id: u32) {
    let _ = child.kill();
    let _ = child.wait();
}

#[cfg(unix)]
unsafe extern "C" {
    fn kill(pid: i32, signal: i32) -> i32;
}

#[cfg(all(test, unix))]
mod tests {
    use std::time::{Duration, Instant};

    use super::{OperationDeadline, output_with_timeout};
    use crate::error::AppError;

    #[test]
    fn captures_successful_output() {
        let output =
            output_with_timeout("/bin/sh", ["-c", "printf success"], Duration::from_secs(1))
                .unwrap();
        assert!(output.status.success());
        assert_eq!(output.stdout, b"success");
    }

    #[test]
    fn operation_deadline_reports_the_operation_and_phase() {
        let deadline = OperationDeadline::new("scheduler metrics", Duration::ZERO);
        let error = deadline.check("commit").unwrap_err();

        assert!(matches!(
            error,
            AppError::CommandTimeout { command, .. } if command == "scheduler metrics commit"
        ));
    }

    #[test]
    fn kills_and_reports_a_timed_out_child() {
        let error = output_with_timeout(
            "/bin/sh",
            ["-c", "while :; do :; done"],
            Duration::from_millis(20),
        )
        .unwrap_err();
        assert!(matches!(error, AppError::CommandTimeout { .. }));
    }

    #[test]
    fn drains_output_larger_than_a_pipe_buffer() {
        let output = output_with_timeout(
            "/bin/sh",
            [
                "-c",
                "i=0; while [ $i -lt 100000 ]; do printf x; i=$((i+1)); done",
            ],
            Duration::from_secs(2),
        )
        .unwrap();
        assert_eq!(output.stdout.len(), 100_000);
    }

    #[test]
    fn timeout_includes_descendants_holding_output_pipes() {
        let start = Instant::now();
        let error =
            output_with_timeout("/bin/sh", ["-c", "(sleep 5) &"], Duration::from_millis(30))
                .unwrap_err();

        assert!(matches!(error, AppError::CommandTimeout { .. }));
        assert!(
            start.elapsed() < Duration::from_secs(1),
            "timeout waited for a descendant-owned pipe"
        );
    }
}
