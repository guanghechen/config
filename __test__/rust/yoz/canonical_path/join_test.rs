use super::join;

#[test]
fn t_join_normalizes_segments() {
    let actual = join("/foo//", "./bar", false);
    assert_eq!(actual, "/foo/bar");
}

#[test]
fn t_join_representative_cases() {
    #[rustfmt::skip]
        let cases: &[(&str, &str, &str, &str)] = &[
            ("", "", "/", "/"),
            ("", ".", "/", "/"),
            ("", "./", "/", "/"),
            ("", "..", "/", "/"),
            ("", "../", "/", "/"),
            ("", "/../b/c//.././/d/./e", "/b/d/e", "/b/d/e"),
            ("", "../bar/.baz/./df/f", "/bar/.baz/df/f", "/bar/.baz/df/f"),
            ("", "../../bar/baz", "/bar/baz", "/bar/baz"),
            ("", "/", "/", "/"),
            ("", "//", "/", "/"),
            ("", "//alice", "/alice", "/alice"),
            ("", "//alice/bob/..", "/alice", "/alice"),
            ("", "//alice/bob/../", "/alice/", "/alice"),
            ("", "/bar///baz//foo", "/bar/baz/foo", "/bar/baz/foo"),
            ("", "b/c", "/b/c", "/b/c"),
            ("", "b/c/", "/b/c/", "/b/c"),
            ("", "b/c/.", "/b/c", "/b/c"),
            ("", "/foo/./bar/../baz", "/foo/baz", "/foo/baz"),
            ("", "/foo/./bar/../baz/", "/foo/baz/", "/foo/baz"),
            ("", "c:", "/C:", "/C:"),
            ("", "C:\\", "/C:/", "/C:"),
            ("", "C:/", "/C:/", "/C:"),
            ("", "C:\\bar", "/C:/bar", "/C:/bar"),
            ("", "C:\\..\\xx", "/C:/xx", "/C:/xx"),
            ("", "foo/bar/baz", "/foo/bar/baz", "/foo/bar/baz"),
            ("", "foo\\bar\\baz\\", "/foo/bar/baz/", "/foo/bar/baz"),
            ("", "foo/bar/", "/foo/bar/", "/foo/bar"),
            ("", "/家/文件/项目", "/家/文件/项目", "/家/文件/项目"),
            ("", "项目/计划/", "/项目/计划/", "/项目/计划"),
            (".", "", "./", "."),
            (".", ".", ".", "."),
            (".", "./", "./", "."),
        ];

    for &(from, to, expected_keep, expected_strip) in cases {
        let actual_keep = join(from, to, true);
        let actual_strip = join(from, to, false);
        assert_eq!(
            actual_keep, expected_keep,
            "keep trailing slash, from: {from}, to: {to}"
        );
        assert_eq!(
            actual_strip, expected_strip,
            "strip trailing slash, from: {from}, to: {to}"
        );
    }
}
