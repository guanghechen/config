use super::*;

#[test]
fn t_relative_cases() {
    let cases = [
        ("file:///foo/bar", "file:///foo/baz", Some("../baz")),
        ("file:///foo/bar", "file:///foo/bar", Some(".")),
        ("file:///foo/bar", "file:///bar/baz", Some("../../bar/baz")),
        ("file:///foo", "https:///foo", None),
        ("/foo/bar", "file:///foo/baz", None),
    ];

    for (from, to, expected) in cases {
        let result = relative(from, to);
        assert_eq!(result.as_deref(), expected, "from: {}, to: {}", from, to);
    }
}
