use super::*;

#[test]
fn t_join_cases() {
    let cases = [
        ("file:///foo/bar", "baz", Some("file:///foo/bar/baz")),
        ("file:///foo/bar", "../baz", Some("file:///foo/baz")),
        ("file:///foo#section", "bar", Some("file:///foo/bar")),
        ("/foo/bar", "baz", None),
    ];

    for (from, to, expected) in cases {
        let result = join(from, to);
        assert_eq!(result.as_deref(), expected, "from: {}, to: {}", from, to);
    }
}
