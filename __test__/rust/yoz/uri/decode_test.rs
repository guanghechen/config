use super::*;

#[test]
fn t_decode_cases() {
    let cases = [
        ("hello%20world", "hello world"),
        ("foo%2Fbar", "foo/bar"),
        ("%E4%B8%AD%E6%96%87", "中文"),
        ("no%encoding", "no%encoding"),
        ("100%25", "100%"),
        ("", ""),
        ("plain", "plain"),
        ("%2f%2F", "//"),
        ("a%20b%20c", "a b c"),
    ];

    for (input, expected) in cases {
        assert_eq!(decode(input), expected, "input: {}", input);
    }
}
