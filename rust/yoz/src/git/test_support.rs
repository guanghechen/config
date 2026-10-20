use crate::git::Options;
use crate::test_support::TempDir;
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

/// A Git repository in a temporary directory.
pub struct Fixture(TempDir);

impl Fixture {
    pub fn new() -> Self {
        let fixture = Self(TempDir::new());
        fixture.git(&["init", "-q"], None);
        fixture
    }

    pub fn path(&self) -> &Path {
        self.0.path()
    }

    pub fn git(&self, args: &[&str], input: Option<&[u8]>) -> Vec<u8> {
        let mut command = Command::new("git");
        command
            .current_dir(self.path())
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
                self.path().join("no-hooks").display()
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
        let path = self.path().join(path);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, text).unwrap();
    }

    pub fn commit(&self) {
        self.git(&["add", "."], None);
        self.git(&["commit", "-qm", "fixture"], None);
    }

    pub fn options(&self) -> Options {
        let root = self
            .path()
            .to_str()
            .unwrap()
            .replace('\\', "/")
            .into_bytes();
        Options {
            cwd: self.path().to_path_buf(),
            root,
            environment: std::env::vars_os().collect(),
            base: None,
            include_numstat: false,
            include_untracked: true,
        }
    }
}
