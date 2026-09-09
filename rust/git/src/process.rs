use std::ffi::OsString;
use std::io::{self, Read, Write};
use std::path::Path;
use std::process::{Child, Command, Output, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

pub const CANCELLED: &str = "Operation cancelled";
const TIMEOUT: Duration = Duration::from_secs(30);

struct OwnedChild(Child);

impl OwnedChild {
    fn terminate(&mut self) {
        #[cfg(unix)]
        unsafe {
            // The child is spawned in its own process group; descendants share ownership.
            libc::kill(-(self.0.id() as libc::pid_t), libc::SIGKILL);
        }
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

impl Drop for OwnedChild {
    fn drop(&mut self) {
        if !matches!(self.0.try_wait(), Ok(Some(_))) {
            self.terminate();
        }
    }
}

pub fn run(
    cwd: &Path,
    environment: &[(OsString, OsString)],
    args: &[OsString],
    cancelled: &AtomicBool,
) -> Result<Vec<u8>, String> {
    let output = output(cwd, environment, args, None, cancelled)?;
    if !output.status.success() {
        let reason = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        return Err(format!(
            "Git query failed (exit {}): {reason}",
            output
                .status
                .code()
                .map(|code| code.to_string())
                .unwrap_or_else(|| "signal".into())
        ));
    }
    Ok(output.stdout)
}

enum Pipe {
    Read(bool, io::Result<Vec<u8>>),
    Written(io::Result<()>),
}

fn read_pipe(
    mut pipe: impl Read + Send + 'static,
    stderr: bool,
    sender: mpsc::Sender<Pipe>,
) -> Result<(), String> {
    thread::Builder::new()
        .name(if stderr { "git-stderr" } else { "git-stdout" }.into())
        .spawn(move || {
            let mut bytes = Vec::new();
            let result = pipe.read_to_end(&mut bytes).map(|_| bytes);
            let _ = sender.send(Pipe::Read(stderr, result));
        })
        .map_err(|error| format!("Failed to start Git output reader: {error}"))?;
    Ok(())
}

/// Collect all streams without blocking cancellation on a full stdin pipe.
/// Nonzero exit statuses retain stdout for commands with meaningful partial results.
pub fn output(
    cwd: &Path,
    environment: &[(OsString, OsString)],
    args: &[OsString],
    input: Option<Vec<u8>>,
    cancelled: &AtomicBool,
) -> Result<Output, String> {
    if cancelled.load(Ordering::Acquire) {
        return Err(CANCELLED.into());
    }
    let mut command = Command::new("git");
    command
        .env_clear()
        .envs(environment.iter().map(|(key, value)| (key, value)));
    command
        .arg("--no-pager")
        .arg("--no-optional-locks")
        .args(args)
        .current_dir(cwd)
        .stdin(if input.is_some() {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        command.process_group(0);
    }
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000); // CREATE_NO_WINDOW
    }
    let mut child = OwnedChild(
        command
            .spawn()
            .map_err(|error| format!("Failed to spawn Git: {error}"))?,
    );
    let stdout = child.0.stdout.take().ok_or("Git stdout pipe missing")?;
    let stderr = child.0.stderr.take().ok_or("Git stderr pipe missing")?;
    let (sender, receiver) = mpsc::channel();
    read_pipe(stdout, false, sender.clone())?;
    read_pipe(stderr, true, sender.clone())?;
    let mut written = Some(Ok(()));
    if let Some(input) = input {
        written = None;
        let mut stdin = child.0.stdin.take().ok_or("Git stdin pipe missing")?;
        let sender = sender.clone();
        thread::Builder::new()
            .name("git-stdin".into())
            .spawn(move || {
                let result = stdin.write_all(&input);
                drop(stdin);
                let _ = sender.send(Pipe::Written(result));
            })
            .map_err(|error| format!("Failed to start Git input writer: {error}"))?;
    }
    drop(sender);

    let started = Instant::now();
    let (mut out, mut err, mut status) = (None, None, None);
    loop {
        if cancelled.load(Ordering::Acquire) || started.elapsed() >= TIMEOUT {
            child.terminate();
            return Err(if cancelled.load(Ordering::Acquire) {
                CANCELLED.into()
            } else {
                "Git query timed out after 30000ms".into()
            });
        }
        // Reap only once pipes close, retaining process-group identity during cancellation.
        if status.is_none() && out.is_some() && err.is_some() && written.is_some() {
            status = child
                .0
                .try_wait()
                .map_err(|error| format!("Failed waiting for Git: {error}"))?;
        }
        if status.is_some() {
            break;
        }
        match receiver.recv_timeout(Duration::from_millis(2)) {
            Ok(Pipe::Read(is_stderr, result)) => {
                let bytes =
                    result.map_err(|error| format!("Failed reading Git output: {error}"))?;
                if is_stderr {
                    err = Some(bytes);
                } else {
                    out = Some(bytes);
                }
            }
            Ok(Pipe::Written(result)) => written = Some(result),
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                if out.is_none() || err.is_none() || written.is_none() {
                    return Err("Git output reader disconnected".into());
                }
                thread::sleep(Duration::from_millis(1));
            }
        }
    }
    let status = status.expect("finished process");
    if status.success() {
        written
            .expect("finished input writer")
            .map_err(|error| format!("Failed writing Git input: {error}"))?;
    }
    Ok(Output {
        status,
        stdout: out.unwrap_or_default(),
        stderr: err.unwrap_or_default(),
    })
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/process_test.rs"
    ));
}
