use std::fs;
use std::path::Path;

use crate::types::dto::ReadAllFilesFailedResult; // Import for Windows-specific metadata extensions
use crate::types::dto::ReadAllFilesSucceedResult; // Import for Windows-specific metadata extensions

/// Read files from a directory, optionally recursively, returning a list of absolute file paths
pub fn collect_files<P: AsRef<Path>>(
    dirpath: P,
    recursive: bool,
) -> Result<ReadAllFilesSucceedResult, ReadAllFilesFailedResult> {
    let dirpath = dirpath.as_ref();

    if !dirpath.exists() {
        return Err(ReadAllFilesFailedResult {
            error: format!("Directory does not exist: {}", dirpath.display()),
        });
    }

    if !dirpath.is_dir() {
        return Err(ReadAllFilesFailedResult {
            error: format!("Path is not a directory: {}", dirpath.display()),
        });
    }

    let mut files = Vec::new();

    if let Err(e) = collect_files_recursive(dirpath, &mut files, recursive) {
        return Err(ReadAllFilesFailedResult {
            error: format!("Failed to read directory contents: {}", e),
        });
    }

    // Sort the files for consistent results
    files.sort();

    Ok(ReadAllFilesSucceedResult { files })
}

// Helper function to recursively collect all file paths
fn collect_files_recursive<P: AsRef<Path>>(
    dir_path: P,
    files: &mut Vec<String>,
    recursive: bool,
) -> std::io::Result<()> {
    let dir_path = dir_path.as_ref();

    if !dir_path.is_dir() {
        return Ok(());
    }

    for entry in fs::read_dir(dir_path)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() {
            if recursive {
                collect_files_recursive(&path, files, recursive)?;
            }
        } else if path.is_file() {
            if let Some(path_str) = path.to_str() {
                files.push(path_str.to_string());
            }
        }
    }

    Ok(())
}
