//! WSL backend using the yoz-owned Windows bridge.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Output, Stdio};
use std::thread;
use std::time::{Duration, Instant};

#[cfg(target_os = "linux")]
pub(super) use super::win::{input_method, source_id_for};

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

fn parse_source_id(source_id: &str, subject: &str) -> Result<u16, String> {
    let input_locale = source_id.parse::<u16>().map_err(|error| {
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

fn kill_and_reap(child: &mut Child) {
    let _ = child.kill();
    let _ = child.wait();
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

    fn run(&self, args: &[&str], subject: &str) -> Result<Output, String> {
        let executable = self.executable(subject)?;
        let mut command = Command::new(executable);
        command
            .args(args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let mut child = command.spawn().map_err(|error| {
            format!(
                "[{subject}] Failed to start {}: {error}",
                executable.display()
            )
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
                    kill_and_reap(&mut child);
                    return Err(format!(
                        "[{subject}] IM process timed out after {}ms: {}",
                        HELPER_PROCESS_TIMEOUT.as_millis(),
                        executable.display()
                    ));
                }
                Err(error) => {
                    kill_and_reap(&mut child);
                    return Err(format!(
                        "[{subject}] Failed to wait for {}: {error}",
                        executable.display()
                    ));
                }
            }
        }
        let output = child.wait_with_output().map_err(|error| {
            format!(
                "[{subject}] Failed to collect output from {}: {error}",
                executable.display()
            )
        })?;
        if !output.status.success() {
            let status = output
                .status
                .code()
                .map_or_else(|| output.status.to_string(), |code| code.to_string());
            return Err(format!(
                "[{subject}] IM process exited with {status}: {}",
                output_detail(&output)
            ));
        }
        Ok(output)
    }

    fn current_source_id(&self, subject: &str) -> Result<u16, String> {
        let output = self.run(&[], subject)?;
        let source_id = String::from_utf8(output.stdout)
            .map_err(|error| format!("[{subject}] Input source ID is not valid UTF-8: {error}"))?;
        let source_id = source_id.trim();
        if source_id.is_empty() {
            return Err(format!("[{subject}] IM query returned an empty source ID"));
        }
        parse_source_id(source_id, subject)
    }

    pub fn current(&mut self) -> Result<String, String> {
        self.current_source_id("im.current")
            .map(|source_id| source_id.to_string())
    }

    pub fn select(&mut self, source_id: &str) -> Result<(), String> {
        let requested = parse_source_id(source_id, "im.select")?;
        let requested_source_id = requested.to_string();
        let output = self.run(&[&requested_source_id], "im.select")?;
        if !output.stdout.is_empty() {
            return Err(format!(
                "[im.select] IM selection returned unexpected output: {}",
                String::from_utf8_lossy(&output.stdout).trim()
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{Backend, is_available, parse_source_id, release_is_wsl};

    #[cfg(unix)]
    static PROCESS_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    #[cfg(unix)]
    fn lock_process_test() -> std::sync::MutexGuard<'static, ()> {
        PROCESS_TEST_LOCK
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    #[test]
    fn t_detects_wsl_kernel_releases() {
        let _ = is_available();
        assert!(release_is_wsl("5.15.153.1-microsoft-standard-WSL2"));
        assert!(release_is_wsl("4.4.0-19041-Microsoft"));
        assert!(!release_is_wsl("6.12.10-generic"));
    }

    #[test]
    fn t_validates_helper_source_ids() {
        assert_eq!(parse_source_id("1033", "test"), Ok(1033));
        assert_eq!(parse_source_id("2052", "test"), Ok(2052));
        assert!(parse_source_id("67699721", "test").is_err());
        assert!(parse_source_id("", "test").is_err());
        assert!(parse_source_id("0", "test").is_err());
        assert!(parse_source_id("Chinese", "test").is_err());
    }

    #[test]
    fn t_requires_setup_and_contextualizes_spawn_failures() {
        let mut im = Backend::default();
        assert!(
            im.current()
                .expect_err("unconfigured backend must fail")
                .contains("has not been configured")
        );
        assert!(im.setup("").is_err());
        assert!(
            im.setup("/dev/yoz-im-does-not-exist")
                .expect_err("missing executable must fail")
                .contains("executable is unavailable")
        );
    }

    #[cfg(unix)]
    #[test]
    fn t_times_out_and_reaps_a_hung_helper() {
        use std::os::unix::fs::PermissionsExt;
        use std::time::{Instant, SystemTime, UNIX_EPOCH};

        let _guard = lock_process_test();
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time")
            .as_nanos();
        let executable =
            std::env::temp_dir().join(format!("yoz-wsl-im-hung-{}-{nonce}.sh", std::process::id()));
        std::fs::write(&executable, "#!/bin/sh\nexec sleep 5\n").expect("write helper");
        let mut permissions = std::fs::metadata(&executable)
            .expect("helper metadata")
            .permissions();
        permissions.set_mode(0o700);
        std::fs::set_permissions(&executable, permissions).expect("make helper executable");

        let mut im = Backend::default();
        im.setup(executable.to_str().expect("UTF-8 helper path"))
            .expect("configure helper");
        let started_at = Instant::now();
        assert!(
            im.current()
                .expect_err("hung helper must time out")
                .contains("timed out after 1000ms")
        );
        assert!(started_at.elapsed() < std::time::Duration::from_secs(2));

        std::fs::remove_file(executable).expect("remove helper");
    }

    #[cfg(unix)]
    #[test]
    fn t_invokes_the_configured_helper_with_argv() {
        use std::os::unix::fs::PermissionsExt;
        use std::time::{SystemTime, UNIX_EPOCH};

        let _guard = lock_process_test();
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time")
            .as_nanos();
        let executable =
            std::env::temp_dir().join(format!("yoz-wsl-im-{}-{nonce}.sh", std::process::id()));
        let state =
            std::env::temp_dir().join(format!("yoz-wsl-im-state-{}-{nonce}", std::process::id()));
        std::fs::write(&state, "1033\n").expect("write helper state");
        std::fs::write(
            &executable,
            format!(
                "#!/bin/sh\nstate='{}'\nif [ \"$#\" -eq 0 ]; then cat \"$state\"; exit 0; fi\ncase \"$1\" in\n  1033|2052) printf '%s\\n' \"$1\" > \"$state\" ;;\n  *) exit 1 ;;\nesac\n",
                state.display()
            ),
        )
        .expect("write helper");
        let mut permissions = std::fs::metadata(&executable)
            .expect("helper metadata")
            .permissions();
        permissions.set_mode(0o700);
        std::fs::set_permissions(&executable, permissions).expect("make helper executable");

        let mut im = Backend::default();
        im.setup(executable.to_str().expect("UTF-8 helper path"))
            .expect("configure helper");
        assert_eq!(im.current(), Ok("1033".to_owned()));
        assert!(im.select("2052").is_ok());
        assert_eq!(im.current(), Ok("2052".to_owned()));
        assert!(im.select("1033").is_ok());

        std::fs::remove_file(executable).expect("remove helper");
        std::fs::remove_file(state).expect("remove helper state");
    }

    #[cfg(unix)]
    #[test]
    fn t_rejects_unexpected_selection_output() {
        use std::os::unix::fs::PermissionsExt;
        use std::time::{SystemTime, UNIX_EPOCH};

        let _guard = lock_process_test();
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time")
            .as_nanos();
        let executable = std::env::temp_dir().join(format!(
            "yoz-wsl-im-output-{}-{nonce}.sh",
            std::process::id()
        ));
        std::fs::write(
            &executable,
            "#!/bin/sh\nif [ \"$#\" -eq 0 ]; then printf '1033\\n'; else printf 'unexpected\\n'; fi\n",
        )
        .expect("write helper");
        let mut permissions = std::fs::metadata(&executable)
            .expect("helper metadata")
            .permissions();
        permissions.set_mode(0o700);
        std::fs::set_permissions(&executable, permissions).expect("make helper executable");

        let mut im = Backend::default();
        im.setup(executable.to_str().expect("UTF-8 helper path"))
            .expect("configure helper");
        assert!(
            im.select("2052")
                .expect_err("selection output must fail")
                .contains("unexpected output")
        );

        std::fs::remove_file(executable).expect("remove helper");
    }
}
