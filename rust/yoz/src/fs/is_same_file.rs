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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/fs/is_same_file_test.rs"
    ));
}
