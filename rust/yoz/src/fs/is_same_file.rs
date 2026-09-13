use super::identity::FileIdentity;
use std::path::Path;

/// Checks whether two native absolute paths identify the same filesystem object.
pub fn is_same_file(left: &str, right: &str) -> Result<bool, String> {
    let left = Path::new(left);
    let right = Path::new(right);
    if !left.is_absolute() {
        return Err(format!(
            "[is_same_file] Left path must be absolute: {}",
            left.display()
        ));
    }
    if !right.is_absolute() {
        return Err(format!(
            "[is_same_file] Right path must be absolute: {}",
            right.display()
        ));
    }

    let left_identity = FileIdentity::from_path(left).map_err(|error| {
        format!(
            "[is_same_file] Failed to identify left path {}: {error}",
            left.display()
        )
    })?;
    left_identity.matches_path(right).map_err(|error| {
        format!(
            "[is_same_file] Failed to identify right path {}: {error}",
            right.display()
        )
    })
}

#[cfg(test)]
mod tests {
    use super::is_same_file;
    use std::fs;
    use std::io;
    use std::path::{Path, PathBuf};
    use std::time::{SystemTime, UNIX_EPOCH};

    struct TempDir(PathBuf);

    impl TempDir {
        fn new(name: &str) -> Self {
            let path = std::env::temp_dir().join(format!(
                "yoz_is_same_file_{name}_{}_{}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map(|duration| duration.as_nanos())
                    .unwrap_or(0)
            ));
            fs::create_dir_all(&path).expect("create temporary directory");
            Self(path)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).ok();
        }
    }

    fn path_string(path: &Path) -> String {
        path.to_str().expect("test path must be UTF-8").to_owned()
    }

    #[cfg(unix)]
    fn symlink_file(source: &Path, target: &Path) -> io::Result<()> {
        std::os::unix::fs::symlink(source, target)
    }

    #[cfg(windows)]
    fn symlink_file(source: &Path, target: &Path) -> io::Result<()> {
        std::os::windows::fs::symlink_file(source, target)
    }

    #[test]
    fn t_accepts_the_same_path() {
        let root = TempDir::new("same_path");
        let filepath = root.path().join("file");
        fs::write(&filepath, "sentinel").expect("create file");

        assert_eq!(
            is_same_file(&path_string(&filepath), &path_string(&filepath)),
            Ok(true)
        );
    }

    #[test]
    fn t_rejects_distinct_files() {
        let root = TempDir::new("distinct");
        let left = root.path().join("left");
        let right = root.path().join("right");
        fs::write(&left, "left").expect("create left file");
        fs::write(&right, "right").expect("create right file");

        assert_eq!(
            is_same_file(&path_string(&left), &path_string(&right)),
            Ok(false)
        );
    }

    #[test]
    fn t_detects_hard_link_aliases() {
        let root = TempDir::new("hard_link");
        let source = root.path().join("source");
        let alias = root.path().join("alias");
        fs::write(&source, "sentinel").expect("create source file");
        fs::hard_link(&source, &alias).expect("create hard link alias");

        assert_eq!(
            is_same_file(&path_string(&source), &path_string(&alias)),
            Ok(true)
        );
    }

    #[test]
    fn t_detects_symbolic_link_aliases() {
        let root = TempDir::new("symbolic_link");
        let source = root.path().join("source");
        let alias = root.path().join("alias");
        fs::write(&source, "sentinel").expect("create source file");

        if let Err(error) = symlink_file(&source, &alias) {
            #[cfg(windows)]
            if error.kind() == io::ErrorKind::PermissionDenied {
                return;
            }
            panic!("create symbolic link alias: {error}");
        }

        assert_eq!(
            is_same_file(&path_string(&source), &path_string(&alias)),
            Ok(true)
        );
    }

    #[test]
    fn t_reports_missing_and_relative_paths() {
        let root = TempDir::new("invalid");
        let source = root.path().join("source");
        let missing = root.path().join("missing");
        fs::write(&source, "sentinel").expect("create source file");

        assert!(is_same_file(&path_string(&source), &path_string(&missing)).is_err());
        assert!(is_same_file("source", &path_string(&source)).is_err());
        assert!(is_same_file(&path_string(&source), "target").is_err());
    }
}
