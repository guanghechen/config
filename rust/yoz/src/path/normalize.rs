use super::split::split;

pub fn normalize(filepath: &str, keep_tailing_slash: bool, sep: char) -> String {
    if filepath.is_empty() {
        return ".".to_string();
    }

    let pieces = split(filepath, keep_tailing_slash);
    normalize_splits(&pieces, sep)
}

pub(crate) fn normalize_splits(pieces: &[String], sep: char) -> String {
    if pieces.is_empty() {
        return ".".to_string();
    }

    if pieces.len() == 1 && pieces[0].is_empty() {
        return sep.to_string();
    }
    pieces.join(&sep.to_string())
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/normalize_test.rs"
    ));
}
