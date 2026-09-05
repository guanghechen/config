use super::*;

#[test]
fn t_is_data_uri_cases() {
    let cases = [
        ("data:text/plain;base64,SGVsbG8=", true),
        ("data:image/png;base64,abc123", true),
        ("data:", true),
        ("file:///foo/bar", false),
        ("https://example.com", false),
        ("", false),
        ("DATA:text/plain", false),
    ];

    for (input, expected) in cases {
        assert_eq!(is_data_uri(input), expected, "input: {}", input);
    }
}
