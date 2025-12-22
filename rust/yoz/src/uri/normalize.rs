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
    use super::*;

    #[test]
    fn t_normalize_cases() {
        let cases = [
            ("file:///foo/./bar/../baz", Some("file:///foo/baz")),
            ("file:///foo/./bar/../baz/", Some("file:///foo/baz/")),
            ("file:///foo//bar///baz", Some("file:///foo/bar/baz")),
            ("https://example.com/foo/../bar#section", Some("https://example.com/bar#section")),
            ("/foo/bar", None),
            ("", None),
        ];

        for (input, expected) in cases {
            let result = normalize(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }
}
