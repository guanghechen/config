use super::*;

#[test]
fn t_basename_cases() {
    let cases = [
        ("file:///usr/bin/nvim", Some("nvim")),
        ("file:///foo/bar/../baz", Some("baz")),
        (
            "https://example.com/path/file.txt#section",
            Some("file.txt"),
        ),
        ("/usr/bin", None),
    ];

    for (input, expected) in cases {
        let result = basename(input);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}
