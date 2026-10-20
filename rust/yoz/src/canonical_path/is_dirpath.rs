pub fn is_dirpath(filepath: &str) -> bool {
    if filepath.is_empty() || filepath == "." || filepath == ".." {
        return true;
    }

    let last = filepath.as_bytes()[filepath.len() - 1];
    last == b'/' || last == b'\\'
}
