use std::path::Path;

pub fn is_exist(path: &str) -> bool {
    if path.is_empty() {
        return false;
    }
    Path::new(path).exists()
}

pub fn is_exist_directory(path: &str) -> bool {
    if path.is_empty() {
        return false;
    }
    Path::new(path).is_dir()
}

pub fn is_exist_file(path: &str) -> bool {
    if path.is_empty() {
        return false;
    }
    Path::new(path).is_file()
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/is_exist_test.rs"
    ));
}
