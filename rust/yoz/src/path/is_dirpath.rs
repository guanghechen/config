pub fn is_dirpath(filepath: &str) -> bool {
    if filepath.is_empty() || filepath == "." || filepath == ".." {
        return true;
    }

    let last = filepath.as_bytes()[filepath.len() - 1];
    last == b'/' || last == b'\\'
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/is_dirpath_test.rs"
    ));
}
