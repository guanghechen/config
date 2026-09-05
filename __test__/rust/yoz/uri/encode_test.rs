use super::*;

#[test]
fn t_encode_cases() {
    let cases = [
        ("hello world", "hello%20world"),
        ("foo/bar", "foo%2Fbar"),
        ("中文", "%E4%B8%AD%E6%96%87"),
        ("100%", "100%25"),
        ("", ""),
        ("plain", "plain"),
        ("a-b_c.d~e", "a-b_c.d~e"),
    ];

    for (input, expected) in cases {
        assert_eq!(encode(input), expected, "input: {}", input);
    }
}
