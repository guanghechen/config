use crate::Options;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};

pub struct Fixture(pub PathBuf);
static NEXT: AtomicUsize = AtomicUsize::new(0);

impl Fixture {
    pub fn new() -> Self {
        let fixture = loop {
            let path = std::env::temp_dir().join(format!(
                "yoz-git-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            match std::fs::create_dir(&path) {
                Ok(()) => break Self(path),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => panic!("temporary directory: {error}"),
            }
        };
        fixture.git(&["init", "-q"], None);
        fixture
    }

    pub fn git(&self, args: &[&str], input: Option<&[u8]>) -> Vec<u8> {
        let mut command = Command::new("git");
        command
            .current_dir(&self.0)
            .args([
                "-c",
                "user.name=Test",
                "-c",
                "user.email=test@example.com",
                "-c",
                "commit.gpgSign=false",
                "-c",
                "core.autocrlf=false",
            ])
            .arg("-c")
            .arg(format!(
                "core.hooksPath={}",
                self.0.join("no-hooks").display()
            ))
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(if input.is_some() {
                Stdio::piped()
            } else {
                Stdio::null()
            });
        let mut child = command.spawn().unwrap();
        if let Some(input) = input {
            child.stdin.take().unwrap().write_all(input).unwrap();
        }
        let output = child.wait_with_output().unwrap();
        assert!(
            output.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        output.stdout
    }

    pub fn write(&self, path: &str, text: &str) {
        let path = self.0.join(path);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, text).unwrap();
    }

    pub fn commit(&self) {
        self.git(&["add", "."], None);
        self.git(&["commit", "-qm", "fixture"], None);
    }

    pub fn options(&self) -> Options {
        let root = self.0.to_str().unwrap().replace('\\', "/").into_bytes();
        Options {
            cwd: self.0.clone(),
            root,
            environment: std::env::vars_os().collect(),
            base: None,
            include_numstat: false,
            include_untracked: true,
        }
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
