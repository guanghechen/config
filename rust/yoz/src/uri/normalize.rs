use super::split::split;

pub(crate) fn normalize_path(path: &str) -> String {
    if path.is_empty() {
        return ".".to_string();
    }

    let pieces = split(path);
    normalize_splits(&pieces)
}

pub(crate) fn normalize_splits(pieces: &[String]) -> String {
    if pieces.is_empty() {
        return ".".to_string();
    }

    if pieces.len() == 1 && pieces[0].is_empty() {
        return "/".to_string();
    }

    pieces.join("/")
}

pub fn normalize(uri: &str) -> Option<String> {
    use super::parse::{build, parse};
    let parts = parse(uri)?;
    let normalized_path = normalize_path(parts.path);
    Some(build(parts.protocol, &normalized_path, parts.hash))
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/normalize_test.rs"
    ));
}
