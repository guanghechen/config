use super::identity::FileIdentity;
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

    let source_identity = FileIdentity::from_path(&source_canonical).map_err(|error| {
        format!(
            "[is_descendant] Failed to identify source {}: {error}",
            source_canonical.display()
        )
    })?;

    for ancestor in target_canonical.ancestors() {
        let matches = source_identity.matches_path(ancestor).map_err(|error| {
            format!(
                "[is_descendant] Failed to identify target ancestor {}: {error}",
                ancestor.display()
            )
        })?;
        if matches {
            return Ok(true);
        }
    }

    Ok(false)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/fs/is_descendant_test.rs"
    ));
}
