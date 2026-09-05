use super::*;

#[test]
fn t_normalize_cases() {
    let cases = [
        ("file:///foo/./bar/../baz", Some("file:///foo/baz")),
        ("file:///foo/./bar/../baz/", Some("file:///foo/baz/")),
        ("file:///foo//bar///baz", Some("file:///foo/bar/baz")),
        (
            "https://example.com/foo/../bar#section",
            Some("https://example.com/bar#section"),
        ),
        ("/foo/bar", None),
        ("", None),
    ];

    for (input, expected) in cases {
        let result = normalize(input);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}
