pub fn is_absolute(filepath: &str) -> bool {
    let bytes = filepath.as_bytes();
    if bytes.is_empty() {
        return false;
    }

    if matches!(bytes.get(0..2), Some([b'/', b'/']) | Some([b'\\', b'\\'])) {
        return true;
    }

    if matches!(bytes.first(), Some(b'/') | Some(b'\\')) {
        return true;
    }

    if bytes.len() >= 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
        return bytes.len() == 2 || matches!(bytes.get(2), Some(b'/') | Some(b'\\'));
    }

    false
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/is_absolute_test.rs"
    ));
}
