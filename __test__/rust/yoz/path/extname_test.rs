use super::extname;

#[test]
fn t_extname_cases() {
    let cases = [
        ("", ""),
        (".", ""),
        ("..", ""),
        ("/", ""),
        ("foo", ""),
        ("foo.txt", ".txt"),
        ("foo.", "."),
        ("foo..", "."),
        ("foo..bar", ".bar"),
        ("/path/to/archive.tar.gz", ".gz"),
        ("//server/share/.foo", ""),
        ("//server/share/file.txt", ".txt"),
        ("foo/.hidden", ""),
        ("foo/.hidden.ext", ".ext"),
        ("foo/bar/..", ""),
        ("foo/bar/../baz.txt", ".txt"),
        ("foo/bar/.", ""),
        ("foo/bar/", ""),
        ("C:/tools/rust-compiler.exe", ".exe"),
        ("C:\\", ""),
        ("C:", ""),
        ("家/项目/说明.md", ".md"),
    ];

    for (input, expected) in cases {
        assert_eq!(extname(input), expected, "input: {}", input);
    }
}
