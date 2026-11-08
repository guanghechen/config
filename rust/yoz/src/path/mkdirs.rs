use std::fs;
use std::path::Path;

/// Makes a directory and its missing parents, taking one that another process makes meanwhile as made. A relative path
/// starts from the process's directory, which `:cd` moves along with Neovim's.
pub fn mkdirs(dirpath: &str) -> Result<(), String> {
    if dirpath.is_empty() {
        return Ok(());
    }

    let path = Path::new(dirpath);
    fs::create_dir_all(path)
        .map_err(|error| format!("Failed to create directory {}: {error}", path.display()))
}
