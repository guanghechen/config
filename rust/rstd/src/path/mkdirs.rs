use super::get_cwd;
use super::is_absolute;
use std::borrow::Cow;
use std::fs;
use std::path::Path;

pub fn mkdirs(dirpath: &str) -> Result<(), String> {
    if dirpath.is_empty() {
        return Ok(());
    }

    let cwd_guard = get_cwd();
    let cwd: &str = &cwd_guard;

    let absolute = if is_absolute(dirpath) {
        Cow::Borrowed(dirpath)
    } else {
        Cow::Owned(format!("{cwd}{dirpath}"))
    };

    let path = Path::new(absolute.as_ref());

    fs::create_dir_all(path)
        .map_err(|error| format!("Failed to create directory {}: {error}", path.display()))
}
