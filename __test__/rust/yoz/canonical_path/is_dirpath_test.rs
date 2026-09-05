use super::is_dirpath;

#[test]
fn t_is_dirpath_cases() {
    let cases = [
        ("", true),
        (".", true),
        ("..", true),
        ("foo", false),
        ("foo/", true),
        ("foo\\", true),
        ("foo/bar", false),
        ("foo/bar/", true),
        ("foo\\bar\\", true),
        ("/", true),
        ("\\", true),
        ("C:/", true),
        ("C:\\", true),
        ("C:/foo", false),
        ("C:\\foo", false),
        ("C:/foo/", true),
        ("C:\\foo\\", true),
    ];

    for (input, expected) in cases {
        assert_eq!(is_dirpath(input), expected, "input: {}", input);
    }
}
