use crate::types::fs::IFsMoveError;
use crate::types::fs::IFsMoveParams;
use std::fs;
use std::path::Path;

pub fn r#move(params: &IFsMoveParams) -> Result<bool, IFsMoveError> {
    let old_path = Path::new(&params.old_path);
    let new_path = Path::new(&params.new_path);

    if !old_path.exists() {
        return Err(IFsMoveError {
            error: format!(
                "[rename] Source path does not exist: {}",
                old_path.display()
            ),
        });
    }

    if new_path.exists() {
        if params.force {
            if new_path.is_dir() {
                if let Err(e) = fs::remove_dir_all(new_path) {
                    return Err(IFsMoveError {
                        error: format!("[rename] Failed to remove existing directory: {}", e),
                    });
                }
            } else if let Err(e) = fs::remove_file(new_path) {
                return Err(IFsMoveError {
                    error: format!("[rename] Failed to remove existing file: {}", e),
                });
            }
        } else {
            return Err(IFsMoveError {
                error: format!(
                    "[rename] Destination path already exists: {}",
                    new_path.display()
                ),
            });
        }
    }

    if let Err(e) = fs::rename(old_path, new_path) {
        return Err(IFsMoveError {
            error: format!("[rename] Failed to rename file: {}", e),
        });
    }

    Ok(true)
}
