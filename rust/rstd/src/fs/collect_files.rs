use crate::types::fs::{IFsCollectFilesError, IFsCollectFilesResult};
use std::fs;
use std::path::{Path, PathBuf};

pub fn collect_files(
    dirpath: &str,
    recursive: bool,
) -> Result<IFsCollectFilesResult, IFsCollectFilesError> {
    let dirpath = PathBuf::from(dirpath);

    if !dirpath.exists() {
        return Err(IFsCollectFilesError {
            error: format!("Directory does not exist: {}", dirpath.display()),
        });
    }

    if !dirpath.is_dir() {
        return Err(IFsCollectFilesError {
            error: format!("Path is not a directory: {}", dirpath.display()),
        });
    }

    let mut files = Vec::new();

    if let Err(e) = collect_files_recursive(&dirpath, &dirpath, &mut files, recursive) {
        return Err(IFsCollectFilesError {
            error: format!("Failed to read directory contents: {}", e),
        });
    }

    files.sort();

    Ok(IFsCollectFilesResult { files })
}

fn collect_files_recursive(
    dir_path: &Path,
    base_path: &Path,
    files: &mut Vec<String>,
    recursive: bool,
) -> std::io::Result<()> {
    if !dir_path.is_dir() {
        return Ok(());
    }

    for entry in fs::read_dir(dir_path)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() && recursive {
            collect_files_recursive(&path, base_path, files, recursive)?;
        } else if path.is_file()
            && let Ok(relative_path) = path.strip_prefix(base_path)
            && let Some(path_str) = relative_path.to_str()
        {
            files.push(path_str.to_string());
        }
    }

    Ok(())
}
