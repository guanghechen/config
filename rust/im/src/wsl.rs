//! WSL backend using the yoz-owned Windows bridge.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use super::CaptureAndSelectError;

const HELPER_PROCESS_TIMEOUT: Duration = Duration::from_secs(1);
const HELPER_PROCESS_POLL_INTERVAL: Duration = Duration::from_millis(2);

fn release_is_wsl(release: &str) -> bool {
    let release = release.to_ascii_lowercase();
    release.contains("microsoft") || release.contains("wsl")
}

pub fn is_available() -> bool {
    env::var_os("WSL_INTEROP").is_some()
        || env::var_os("WSL_DISTRO_NAME").is_some()
        || fs::read_to_string("/proc/sys/kernel/osrelease")
            .is_ok_and(|release| release_is_wsl(&release))
}

fn parse_source_id(source_id: &str, subject: &str) -> Result<u64, String> {
    let input_locale = source_id.parse::<u64>().map_err(|error| {
        format!("[{subject}] Invalid WSL input source ID {source_id:?}: {error}")
    })?;
    if input_locale == 0 {
        return Err(format!("[{subject}] Input source ID must not be zero"));
    }
    Ok(input_locale)
}

fn output_detail(output: &Output) -> String {
    let stderr = String::from_utf8_lossy(&output.stderr);
    let stderr = stderr.trim();
    if !stderr.is_empty() {
        return stderr.to_owned();
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stdout = stdout.trim();
    if !stdout.is_empty() {
        return stdout.to_owned();
    }
    "no process output".to_owned()
}

fn status_error(output: &Output, subject: &str) -> String {
    let status = output
        .status
        .code()
        .map_or_else(|| output.status.to_string(), |code| code.to_string());
    format!(
        "[{subject}] IM process exited with {status}: {}",
        output_detail(output)
    )
}

struct ProcessError {
    output: Option<Output>,
    message: String,
}

#[derive(Default)]
pub struct Backend {
    executable: Option<PathBuf>,
}

impl Backend {
    pub fn setup(&mut self, executable: &str) -> Result<(), String> {
        if executable.is_empty() {
            return Err("[im.setup] Executable path must not be empty".to_owned());
        }
        let executable = PathBuf::from(executable);
        if !executable.is_file() {
            return Err(format!(
                "[im.setup] IM executable is unavailable: {}",
                executable.display()
            ));
        }
        self.executable = Some(executable);
        Ok(())
    }

    fn executable(&self, subject: &str) -> Result<&Path, String> {
        self.executable
            .as_deref()
            .ok_or_else(|| format!("[{subject}] WSL IM executable has not been configured"))
    }

    fn run(&self, args: &[&str], subject: &str) -> Result<Output, ProcessError> {
        let executable = self.executable(subject).map_err(|message| ProcessError {
            output: None,
            message,
        })?;
        let mut command = Command::new(executable);
        command
            .args(args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let mut child = command.spawn().map_err(|error| ProcessError {
            output: None,
            message: format!(
                "[{subject}] Failed to start {}: {error}",
                executable.display()
            ),
        })?;
        let deadline = Instant::now() + HELPER_PROCESS_TIMEOUT;
        loop {
            match child.try_wait() {
                Ok(Some(_)) => break,
                Ok(None) if Instant::now() < deadline => {
                    let remaining = deadline.saturating_duration_since(Instant::now());
                    thread::sleep(remaining.min(HELPER_PROCESS_POLL_INTERVAL));
                }
                Ok(None) => {
                    let _ = child.kill();
                    let output = child.wait_with_output().ok();
                    return Err(ProcessError {
                        output,
                        message: format!(
                            "[{subject}] IM process timed out after {}ms: {}",
                            HELPER_PROCESS_TIMEOUT.as_millis(),
                            executable.display()
                        ),
                    });
                }
                Err(error) => {
                    let _ = child.kill();
                    let output = child.wait_with_output().ok();
                    return Err(ProcessError {
                        output,
                        message: format!(
                            "[{subject}] Failed to wait for {}: {error}",
                            executable.display()
                        ),
                    });
                }
            }
        }
        child.wait_with_output().map_err(|error| ProcessError {
            output: None,
            message: format!(
                "[{subject}] Failed to collect output from {}: {error}",
                executable.display()
            ),
        })
    }

    fn source_id_from_output(output: &Output, subject: &str) -> Result<u64, String> {
        let source_id = std::str::from_utf8(&output.stdout)
            .map_err(|error| format!("[{subject}] Input source ID is not valid UTF-8: {error}"))?;
        let source_id = source_id.trim();
        if source_id.is_empty() {
            return Err(format!("[{subject}] IM query returned an empty source ID"));
        }
        parse_source_id(source_id, subject)
    }

    pub fn capture(&mut self) -> Result<String, String> {
        let subject = "im.capture";
        let output = self.run(&[], subject).map_err(|error| error.message)?;
        if !output.status.success() {
            return Err(status_error(&output, subject));
        }
        Self::source_id_from_output(&output, subject).map(|source_id| source_id.to_string())
    }

    pub fn capture_and_select_english(&mut self) -> Result<String, CaptureAndSelectError> {
        let subject = "im.capture_and_select_english";
        let output = match self.run(&["--english"], subject) {
            Ok(output) => output,
            Err(error) => {
                if let Some(output) = error.output
                    && let Ok(snapshot) = Self::source_id_from_output(&output, subject)
                {
                    return Err(CaptureAndSelectError::Select {
                        snapshot: snapshot.to_string(),
                        error: error.message,
                    });
                }
                return Err(CaptureAndSelectError::Capture(error.message));
            }
        };
        if !output.status.success() {
            let error = status_error(&output, subject);
            return match Self::source_id_from_output(&output, subject) {
                Ok(snapshot) => Err(CaptureAndSelectError::Select {
                    snapshot: snapshot.to_string(),
                    error,
                }),
                Err(_) => Err(CaptureAndSelectError::Capture(error)),
            };
        }
        Self::source_id_from_output(&output, subject)
            .map_err(CaptureAndSelectError::Capture)
            .map(|snapshot| snapshot.to_string())
    }

    pub fn restore(&mut self, source_id: &str) -> Result<(), String> {
        let subject = "im.restore";
        let requested = parse_source_id(source_id, subject)?;
        let requested_source_id = requested.to_string();
        let output = self
            .run(&[&requested_source_id], subject)
            .map_err(|error| error.message)?;
        if !output.status.success() {
            return Err(status_error(&output, subject));
        }
        if !output.stdout.is_empty() {
            return Err(format!(
                "[{subject}] IM restore returned unexpected output: {}",
                String::from_utf8_lossy(&output.stdout).trim()
            ));
        }
        Ok(())
    }

    pub fn is_english(&mut self, source_id: &str) -> bool {
        super::win::is_english(source_id)
    }
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/im/wsl_test.rs"
    ));
}
