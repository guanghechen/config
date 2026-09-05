use super::*;

#[test]
fn t_validate_cases() {
    let cases = [
        ("file:///bin/sh", true),
        ("file:///home/user/file.txt", true),
        ("https://example.com/path#section", true),
        ("file://", true),
        ("/bin/sh", false),
        ("", false),
        ("foo/bar", false),
    ];

    for (input, expected) in cases {
        assert_eq!(validate(input), expected, "input: {}", input);
    }
}
