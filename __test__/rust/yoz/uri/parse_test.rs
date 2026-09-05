use super::*;

#[test]
fn t_parse_valid_uri() {
    let cases = [
        ("file:///bin/sh", "file", "/bin/sh", None),
        (
            "file:///home/user/file.txt",
            "file",
            "/home/user/file.txt",
            None,
        ),
        ("http://example.com/path", "http", "example.com/path", None),
        (
            "https://example.com/path#section",
            "https",
            "example.com/path",
            Some("section"),
        ),
        (
            "file:///path/to/file#line=10",
            "file",
            "/path/to/file",
            Some("line=10"),
        ),
        (
            "custom://some/path#hash",
            "custom",
            "some/path",
            Some("hash"),
        ),
    ];

    for (input, expected_protocol, expected_path, expected_hash) in cases {
        let parts = parse(input).unwrap_or_else(|| panic!("failed to parse: {}", input));
        assert_eq!(
            parts.protocol, expected_protocol,
            "protocol mismatch for: {}",
            input
        );
        assert_eq!(parts.path, expected_path, "path mismatch for: {}", input);
        assert_eq!(parts.hash, expected_hash, "hash mismatch for: {}", input);
    }
}

#[test]
fn t_parse_invalid_uri() {
    let cases = ["", "/bin/sh", "file:/bin/sh", "://path", "file//path"];

    for input in cases {
        assert!(parse(input).is_none(), "should not parse: {}", input);
    }
}

#[test]
fn t_build_uri() {
    let cases = [
        ("file", "/bin/sh", None, "file:///bin/sh"),
        (
            "https",
            "example.com/path",
            Some("section"),
            "https://example.com/path#section",
        ),
        (
            "file",
            "/path/to/file",
            Some("line=10"),
            "file:///path/to/file#line=10",
        ),
    ];

    for (protocol, path, hash, expected) in cases {
        let result = build(protocol, path, hash);
        assert_eq!(result, expected);
    }
}
