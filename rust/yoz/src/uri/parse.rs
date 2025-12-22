pub struct UriParts<'a> {
    pub protocol: &'a str,
    pub path: &'a str,
    pub hash: Option<&'a str>,
}

pub fn parse(uri: &str) -> Option<UriParts<'_>> {
    let protocol_end = uri.find("://")?;
    let protocol = &uri[..protocol_end];
    if protocol.is_empty() {
        return None;
    }

    let rest = &uri[protocol_end + 3..];
    let (path, hash) = match rest.find('#') {
        Some(hash_pos) => (&rest[..hash_pos], Some(&rest[hash_pos + 1..])),
        None => (rest, None),
    };

    Some(UriParts {
        protocol,
        path,
        hash,
    })
}

pub fn build(protocol: &str, path: &str, hash: Option<&str>) -> String {
    let mut result = String::with_capacity(protocol.len() + 3 + path.len() + hash.map_or(0, |h| h.len() + 1));
    result.push_str(protocol);
    result.push_str("://");
    result.push_str(path);
    if let Some(h) = hash {
        result.push('#');
        result.push_str(h);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_parse_valid_uri() {
        let cases = [
            ("file:///bin/sh", "file", "/bin/sh", None),
            ("file:///home/user/file.txt", "file", "/home/user/file.txt", None),
            ("http://example.com/path", "http", "example.com/path", None),
            ("https://example.com/path#section", "https", "example.com/path", Some("section")),
            ("file:///path/to/file#line=10", "file", "/path/to/file", Some("line=10")),
            ("custom://some/path#hash", "custom", "some/path", Some("hash")),
        ];

        for (input, expected_protocol, expected_path, expected_hash) in cases {
            let parts = parse(input).unwrap_or_else(|| panic!("failed to parse: {}", input));
            assert_eq!(parts.protocol, expected_protocol, "protocol mismatch for: {}", input);
            assert_eq!(parts.path, expected_path, "path mismatch for: {}", input);
            assert_eq!(parts.hash, expected_hash, "hash mismatch for: {}", input);
        }
    }

    #[test]
    fn t_parse_invalid_uri() {
        let cases = [
            "",
            "/bin/sh",
            "file:/bin/sh",
            "://path",
            "file//path",
        ];

        for input in cases {
            assert!(parse(input).is_none(), "should not parse: {}", input);
        }
    }

    #[test]
    fn t_build_uri() {
        let cases = [
            ("file", "/bin/sh", None, "file:///bin/sh"),
            ("https", "example.com/path", Some("section"), "https://example.com/path#section"),
            ("file", "/path/to/file", Some("line=10"), "file:///path/to/file#line=10"),
        ];

        for (protocol, path, hash, expected) in cases {
            let result = build(protocol, path, hash);
            assert_eq!(result, expected);
        }
    }
}
