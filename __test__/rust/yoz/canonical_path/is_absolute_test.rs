use super::is_absolute;

#[test]
fn t_is_absolute_cases() {
    let cases = [
        ("", false),
        (".", false),
        ("foo/bar", false),
        ("C", false),
        ("../foo", false),
        ("C:foo", false),
        ("/", true),
        ("/usr/bin", true),
        ("/home/user/../", true),
        ("//server/share", true),
        ("\\", true),
        ("\\server\\share", true),
        ("C:", true),
        ("C:/", true),
        ("C:\\", true),
        ("C:/foo", true),
        ("C:\\foo", true),
    ];

    for (input, expected) in cases {
        assert_eq!(is_absolute(input), expected, "input: {}", input);
    }
}
