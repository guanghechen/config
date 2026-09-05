use super::*;

#[test]
fn t_extname_cases() {
    let cases = [
        ("file:///path/to/file.txt", Some(".txt")),
        ("file:///path/to/archive.tar.gz#line=10", Some(".gz")),
        ("https://example.com/.hidden", Some("")),
        ("/path/to/file.txt", None),
    ];

    for (input, expected) in cases {
        let result = extname(input);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}
