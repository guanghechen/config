use super::normalize::normalize_splits;
use super::split::split;

pub fn parent(uri: &str) -> Option<String> {
    use super::parse::{build, parse};
    let parts = parse(uri)?;
    let dir = parent_path(parts.path);
    Some(build(parts.protocol, &dir, None))
}

fn parent_path(path: &str) -> String {
    if path.is_empty() {
        return "../".to_string();
    }

    let pieces = split(path);
    let pieces_without_trailing = if !pieces.is_empty() && pieces.last().is_some_and(|s| s.is_empty()) {
        &pieces[..pieces.len() - 1]
    } else {
        &pieces[..]
    };

    if pieces_without_trailing.len() <= 1 {
        if pieces_without_trailing.is_empty() || pieces_without_trailing[0].is_empty() {
            return "/".to_string();
        }
        return "../".to_string();
    }

    let n = pieces_without_trailing.len() - 1;
    let result = normalize_splits(&pieces_without_trailing[0..n]);
    if !pieces_without_trailing[n - 1].is_empty() {
        return format!("{}/", result);
    }
    result
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/parent_test.rs"
    ));
}
