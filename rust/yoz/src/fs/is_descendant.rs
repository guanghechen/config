use std::fs;
use std::io;
use std::path::{Component, Path, PathBuf};

fn canonicalize_nearest_existing(filepath: &Path) -> io::Result<PathBuf> {
    let mut current = filepath.to_path_buf();

    loop {
        match fs::canonicalize(&current) {
            Ok(canonical) => return Ok(canonical),
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                let Some(parent) = current.parent() else {
                    return Err(error);
                };
                if parent == current {
                    return Err(error);
                }
                current = parent.to_path_buf();
            }
            Err(error) => return Err(error),
        }
    }
}

/// Checks filesystem ancestry after resolving symlinks and platform aliases.
///
/// Both arguments must be native absolute local paths. `source` must exist;
/// `target` may not, but it must not contain `..` components. A missing
/// target's nearest existing ancestor is canonicalized, which is sufficient
/// to determine whether creating it would place it at or below `source`.
pub fn is_descendant(source: &str, target: &str) -> Result<bool, String> {
    let source = Path::new(source);
    let target = Path::new(target);
    if !source.is_absolute() {
        return Err(format!(
            "[is_descendant] Source path must be absolute: {}",
            source.display()
        ));
    }
    if !target.is_absolute() {
        return Err(format!(
            "[is_descendant] Target path must be absolute: {}",
            target.display()
        ));
    }
    if target
        .components()
        .any(|component| component == Component::ParentDir)
    {
        return Err(format!(
            "[is_descendant] Target path must not contain parent components: {}",
            target.display()
        ));
    }

    let source_canonical = fs::canonicalize(source).map_err(|error| {
        format!(
            "[is_descendant] Failed to canonicalize source {}: {error}",
            source.display()
        )
    })?;
    let target_canonical = canonicalize_nearest_existing(target).map_err(|error| {
        format!(
            "[is_descendant] Failed to canonicalize target {}: {error}",
            target.display()
        )
    })?;

    if target_canonical.starts_with(&source_canonical) {
        return Ok(true);
    }

    let source_handle = same_file::Handle::from_path(&source_canonical).map_err(|error| {
        format!(
            "[is_descendant] Failed to identify source {}: {error}",
            source_canonical.display()
        )
    })?;

    for ancestor in target_canonical.ancestors() {
        let ancestor_handle = same_file::Handle::from_path(ancestor).map_err(|error| {
            format!(
                "[is_descendant] Failed to identify target ancestor {}: {error}",
                ancestor.display()
            )
        })?;
        if ancestor_handle == source_handle {
            return Ok(true);
        }
    }

    Ok(false)
}

#[cfg(test)]
mod tests {
    use super::is_descendant;
    use std::fs;
    use std::io;
    use std::path::{Path, PathBuf};
    use std::time::{SystemTime, UNIX_EPOCH};

    struct TempDir(PathBuf);

    impl TempDir {
        fn new(name: &str) -> Self {
            let path = std::env::temp_dir().join(format!(
                "yoz_is_descendant_{name}_{}_{}",
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
    fn symlink_dir(source: &Path, target: &Path) -> io::Result<()> {
        std::os::unix::fs::symlink(source, target)
    }

    #[cfg(windows)]
    fn symlink_dir(source: &Path, target: &Path) -> io::Result<()> {
        std::os::windows::fs::symlink_dir(source, target)
    }

    #[test]
    fn detects_missing_target_below_source() {
        let root = TempDir::new("missing_target");
        let source = root.path().join("source");
        fs::create_dir_all(&source).expect("create source");
        let target = source.join("missing/nested/copy");

        let result = is_descendant(&path_string(&source), &path_string(&target));

        assert_eq!(result, Ok(true));
    }

    #[test]
    fn rejects_missing_target_below_sibling() {
        let root = TempDir::new("sibling");
        let source = root.path().join("source");
        fs::create_dir_all(&source).expect("create source");
        let target = root.path().join("sibling/missing/copy");

        let result = is_descendant(&path_string(&source), &path_string(&target));

        assert_eq!(result, Ok(false));
    }

    #[test]
    fn detects_target_reached_through_symlink_alias() {
        let root = TempDir::new("symlink");
        let source = root.path().join("source");
        let alias = root.path().join("alias");
        fs::create_dir_all(&source).expect("create source");

        if let Err(error) = symlink_dir(&source, &alias) {
            #[cfg(windows)]
            if error.kind() == io::ErrorKind::PermissionDenied {
                return;
            }
            panic!("create directory symlink: {error}");
        }

        let target = alias.join("missing/copy");
        let result = is_descendant(&path_string(&source), &path_string(&target));

        assert_eq!(result, Ok(true));
    }

    #[test]
    fn detects_target_with_same_filesystem_identity() {
        let root = TempDir::new("filesystem_identity");
        let source = root.path().join("source");
        let alias = root.path().join("alias");
        fs::write(&source, "sentinel").expect("create source");
        fs::hard_link(&source, &alias).expect("create hard link alias");

        let result = is_descendant(&path_string(&source), &path_string(&alias));

        assert_eq!(result, Ok(true));
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn detects_missing_target_through_firmlink_alias() {
        let source = Path::new("/Users");
        let alias = Path::new("/System/Volumes/Data/Users");
        let Ok(source_handle) = same_file::Handle::from_path(source) else {
            return;
        };
        let Ok(alias_handle) = same_file::Handle::from_path(alias) else {
            return;
        };
        if source_handle != alias_handle {
            return;
        }

        let target = alias.join(format!("yoz-is-descendant-missing-{}", std::process::id()));
        let result = is_descendant(&path_string(source), &path_string(&target));

        assert_eq!(result, Ok(true));
    }

    #[test]
    fn detects_casing_alias_on_case_insensitive_filesystem() {
        let root = TempDir::new("casing");
        let source = root.path().join("CaseSource");
        let alias = root.path().join("casesource");
        fs::create_dir_all(&source).expect("create source");

        match fs::canonicalize(&alias) {
            Ok(_) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => return,
            Err(error) => panic!("canonicalize casing alias: {error}"),
        }

        let target = alias.join("missing/copy");
        let result = is_descendant(&path_string(&source), &path_string(&target));

        assert_eq!(result, Ok(true));
    }

    #[test]
    fn reports_missing_source() {
        let root = TempDir::new("missing_source");
        let source = root.path().join("missing-source");
        let target = root.path().join("target");

        let result = is_descendant(&path_string(&source), &path_string(&target));

        assert!(result.is_err());
    }

    #[test]
    fn rejects_relative_paths() {
        let root = TempDir::new("relative");
        let source = root.path().join("source");
        fs::create_dir_all(&source).expect("create source");

        assert!(is_descendant("source", &path_string(root.path())).is_err());
        assert!(is_descendant(&path_string(&source), "target").is_err());
    }

    #[test]
    fn rejects_parent_components_in_target() {
        let root = TempDir::new("parent_component");
        let source = root.path().join("source");
        fs::create_dir_all(&source).expect("create source");
        let target = root
            .path()
            .join("missing")
            .join("..")
            .join("source")
            .join("copy");

        let result = is_descendant(&path_string(&source), &path_string(&target));

        assert!(
            result
                .expect_err("target with parent component must be rejected")
                .contains("must not contain parent components")
        );
    }
}
