use nvim_oxi::conversion::Error as ConversionError;
use nvim_oxi::conversion::FromObject;
use nvim_oxi::conversion::ToObject;
use nvim_oxi::lua;
use nvim_oxi::serde::Deserializer;
use nvim_oxi::serde::Serializer;
use nvim_oxi::Object;
use serde::Deserialize;
use serde::Serialize;
use std::fs;
use std::path::Path;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RenameSucceedResult {
    pub old_path: String,
    pub new_path: String,
    pub message: String,
}

impl FromObject for RenameSucceedResult {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for RenameSucceedResult {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for RenameSucceedResult {
    unsafe fn pop(lstate: *mut lua::ffi::lua_State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for RenameSucceedResult {
    unsafe fn push(self, lstate: *mut lua::ffi::lua_State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RenameFailedResult {
    pub error: String,
}

pub fn rename_path<P: AsRef<Path>, Q: AsRef<Path>>(
    old_path: P,
    new_path: Q,
    force: bool,
) -> Result<RenameSucceedResult, RenameFailedResult> {
    let old_path = old_path.as_ref();
    let new_path = new_path.as_ref();

    // Check if the source path exists
    if !old_path.exists() {
        return Err(RenameFailedResult {
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
                    return Err(RenameFailedResult {
                        error: format!("[rename] Failed to remove existing directory: {}", e),
                    });
                }
            } else if let Err(e) = fs::remove_file(new_path) {
                return Err(RenameFailedResult {
                    error: format!("[rename] Failed to remove existing file: {}", e),
                });
            }
        } else {
            // If force is false, return an error
            return Err(RenameFailedResult {
                error: format!(
                    "[rename] Destination path already exists: {}",
                    new_path.display()
                ),
            });
        }
    }

    // Perform the rename operation
    if let Err(e) = fs::rename(old_path, new_path) {
        return Err(RenameFailedResult {
            error: format!("[rename] Failed to rename file: {}", e),
        });
    }

    Ok(RenameSucceedResult {
        old_path: old_path.display().to_string(),
        new_path: new_path.display().to_string(),
        message: format!(
            "Successfully renamed '{}' to '{}'",
            old_path.display(),
            new_path.display()
        ),
    })
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
        assert!(rename_path(old_path, new_path, false).is_ok());

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
        assert!(rename_path(old_path, new_path, false).is_ok());

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
        let result = rename_path(old_path, new_path, false);
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
        let result = rename_path(old_path, new_path, false);
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
        assert!(rename_path(old_path, new_path, true).is_ok());

        // Check that only new file exists
        assert!(!Path::new(old_path).exists());
        assert!(Path::new(new_path).exists());

        // Clean up
        fs::remove_file(new_path).unwrap();
    }
}
