use std::fs;
use std::path::Path;

use crate::types::dto::FileMoveFailedResult;
use crate::types::dto::FileMoveSucceedResult;

pub fn move_file<P: AsRef<Path>, Q: AsRef<Path>>(
    old_path: P,
    new_path: Q,
    force: bool,
) -> Result<FileMoveSucceedResult, FileMoveFailedResult> {
    let old_path = old_path.as_ref();
    let new_path = new_path.as_ref();

    // Check if the source path exists
    if !old_path.exists() {
        return Err(FileMoveFailedResult {
            error: format!(
                "[rename] Source path does not exist: {}",
                old_path.display()
            ),
        });
    }

    // Check if the destination path already exists
    if new_path.exists() {
        if force {
            // If force is true, remove the destination first
            if new_path.is_dir() {
                if let Err(e) = fs::remove_dir_all(new_path) {
                    return Err(FileMoveFailedResult {
                        error: format!("[rename] Failed to remove existing directory: {}", e),
                    });
                }
            } else if let Err(e) = fs::remove_file(new_path) {
                return Err(FileMoveFailedResult {
                    error: format!("[rename] Failed to remove existing file: {}", e),
                });
            }
        } else {
            // If force is false, return an error
            return Err(FileMoveFailedResult {
                error: format!(
                    "[rename] Destination path already exists: {}",
                    new_path.display()
                ),
            });
        }
    }

    // Perform the rename operation
    if let Err(e) = fs::rename(old_path, new_path) {
        return Err(FileMoveFailedResult {
            error: format!("[rename] Failed to rename file: {}", e),
        });
    }

    Ok(FileMoveSucceedResult { ok: true })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::io::Write;

    fn create_test_file(path: &str, content: &str) -> std::io::Result<()> {
        let mut file = File::create(path)?;
        file.write_all(content.as_bytes())?;
        Ok(())
    }

    #[test]
    fn test_rename_file() {
        let old_path = "test_old_file.txt";
        let new_path = "test_new_file.txt";

        // Create test file
        create_test_file(old_path, "test content").unwrap();

        // Rename the file
        assert!(move_file(old_path, new_path, false).is_ok());

        // Check that old file doesn't exist and new file exists
        assert!(!Path::new(old_path).exists());
        assert!(Path::new(new_path).exists());

        // Clean up
        fs::remove_file(new_path).unwrap();
    }

    #[test]
    fn test_rename_directory() {
        let old_path = "test_old_dir";
        let new_path = "test_new_dir";

        // Create test directory
        fs::create_dir(old_path).unwrap();

        // Rename the directory
        assert!(move_file(old_path, new_path, false).is_ok());

        // Check that old directory doesn't exist and new directory exists
        assert!(!Path::new(old_path).exists());
        assert!(Path::new(new_path).exists());

        // Clean up
        fs::remove_dir(new_path).unwrap();
    }

    #[test]
    fn test_rename_nonexistent_source() {
        let old_path = "nonexistent_file.txt";
        let new_path = "new_file.txt";

        // Try to rename a nonexistent file
        let result = move_file(old_path, new_path, false);
        assert!(result.is_err());
        let error = result.unwrap_err();
        assert!(error.error.contains("[rename] Source path does not exist"));
    }

    #[test]
    fn test_rename_existing_destination() {
        let old_path = "test_old_file2.txt";
        let new_path = "test_new_file2.txt";

        // Create both files
        create_test_file(old_path, "old content").unwrap();
        create_test_file(new_path, "new content").unwrap();

        // Try to rename to existing destination
        let result = move_file(old_path, new_path, false);
        assert!(result.is_err());
        let error = result.unwrap_err();
        assert!(error
            .error
            .contains("[rename] Destination path already exists"));

        // Clean up
        fs::remove_file(old_path).unwrap();
        fs::remove_file(new_path).unwrap();
    }

    #[test]
    fn test_rename_overwrite() {
        let old_path = "test_old_file3.txt";
        let new_path = "test_new_file3.txt";

        // Create both files
        create_test_file(old_path, "old content").unwrap();
        create_test_file(new_path, "new content").unwrap();

        // Rename with overwrite (force = true)
        assert!(move_file(old_path, new_path, true).is_ok());

        // Check that only new file exists
        assert!(!Path::new(old_path).exists());
        assert!(Path::new(new_path).exists());

        // Clean up
        fs::remove_file(new_path).unwrap();
    }
}
