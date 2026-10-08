use super::io::{Signature, cancelled};
use std::io::{self, Read};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::atomic::AtomicBool;

fn execute(command: &mut Command, validate: &impl Fn() -> io::Result<()>) -> io::Result<()> {
    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped());
    validate()?;
    let mut child = command.spawn()?;
    let mut stderr = child.stderr.take().expect("piped trash stderr");
    let (status, message) = std::thread::scope(|scope| {
        let output = scope.spawn(move || {
            let mut message = Vec::new();
            let mut block = [0u8; 4096];
            while let Ok(count) = stderr.read(&mut block) {
                if count == 0 {
                    break;
                }
                message.extend_from_slice(&block[..count.min(4096 - message.len())]);
            }
            message
        });
        (child.wait(), output.join().unwrap_or_default())
    });
    let status = status?;
    if status.success() {
        Ok(())
    } else {
        let mut message = format!(
            "trash command failed ({status}): {}",
            String::from_utf8_lossy(&message).trim()
        );
        if message.len() > 2048 {
            let mut end = 2048;
            while !message.is_char_boundary(end) {
                end -= 1;
            }
            message.truncate(end);
        }
        Err(io::Error::other(message))
    }
}

#[cfg(any(windows, target_os = "linux"))]
fn recycle_windows(
    path: &str,
    directory: bool,
    wsl: bool,
    validate: &impl Fn() -> io::Result<()>,
) -> io::Result<()> {
    let operation = if directory {
        "DeleteDirectory"
    } else {
        "DeleteFile"
    };
    let script = format!(
        "$ErrorActionPreference='Stop'; Add-Type -AssemblyName Microsoft.VisualBasic; \
         [Microsoft.VisualBasic.FileIO.FileSystem]::{operation}('{}', 'OnlyErrorDialogs', 'SendToRecycleBin')",
        path.replace('\'', "''")
    );
    execute(
        Command::new(if wsl { "powershell.exe" } else { "powershell" }).args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            &script,
        ]),
        validate,
    )
}

/** Reuse the configured platform trash tool. Never fall back to permanent deletion. */
pub(super) fn recycle(path: &Path, expected: &Signature, cancel: &AtomicBool) -> io::Result<()> {
    let validate = || {
        cancelled(cancel)?;
        expected.verify(path, false)
    };
    validate()?;
    #[cfg(target_os = "macos")]
    execute(Command::new("trash").arg(path), &validate)?;
    #[cfg(target_os = "linux")]
    {
        if std::env::var_os("WSL_DISTRO_NAME").is_some() {
            let mut command = Command::new("wslpath");
            command
                .arg("-w")
                .arg(path)
                .stdin(Stdio::null())
                .stdout(Stdio::piped())
                .stderr(Stdio::piped());
            let converted = command.spawn()?.wait_with_output()?;
            if !converted.status.success() {
                return Err(io::Error::other(
                    "could not convert the trash path with wslpath",
                ));
            }
            let converted = std::str::from_utf8(&converted.stdout).map_err(|_| {
                io::Error::new(io::ErrorKind::InvalidData, "trash path is not UTF-8")
            })?;
            let directory = std::fs::metadata(path).is_ok_and(|metadata| metadata.is_dir());
            recycle_windows(
                converted.trim_end_matches(['\r', '\n']),
                directory,
                true,
                &validate,
            )?;
        } else {
            execute(
                Command::new("gio").args(["trash", "--"]).arg(path),
                &validate,
            )?;
        }
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::FileTypeExt;
        let kind = std::fs::symlink_metadata(path)?.file_type();
        let path = path.to_str().ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::Unsupported,
                "trash tool requires a Unicode path",
            )
        })?;
        recycle_windows(
            path,
            kind.is_dir() || kind.is_symlink_dir(),
            false,
            &validate,
        )?;
    }
    match std::fs::symlink_metadata(path) {
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error),
        Ok(_) => Err(io::Error::other(
            "trash tool returned without removing the source path",
        )),
    }
}
