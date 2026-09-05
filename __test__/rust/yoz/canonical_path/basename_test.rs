use super::basename;

#[test]
fn t_basename_cases() {
    let cases = [
        ("", ""),
        (".", ""),
        ("..", ".."),
        ("/", ""),
        ("/..", ""),
        ("//server/share", "share"),
        ("C:/tools/rustc", "rustc"),
        ("\\", ""),
        ("c:", "C:"),
        ("/foo/bar/../baz", "baz"),
        ("/usr/bin/nvim", "nvim"),
        ("/家/文件/项目", "项目"),
        ("foo//bar", "bar"),
        ("foo/..", ""),
        ("foo/bar/..", "foo"),
        ("foo/bar/.", "bar"),
        ("foo/bar.txt", "bar.txt"),
        ("foo/", "foo"),
        ("foo\\", "foo"),
        ("foo\\bar\\baz", "baz"),
    ];

    for (input, expected) in cases {
        assert_eq!(basename(input), expected, "input: {}", input);
    }
}
