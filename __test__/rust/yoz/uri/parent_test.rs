use super::*;

#[test]
fn t_parent_cases() {
    let cases = [
        ("file:///usr/bin/nvim", Some("file:///usr/bin/")),
        ("file:///foo/bar#section", Some("file:///foo/")),
        ("file:///foo", Some("file:///")),
        ("file:///", Some("file:///")),
        ("/usr/bin", None),
        ("", None),
    ];

    for (input, expected) in cases {
        let result = parent(input);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}
