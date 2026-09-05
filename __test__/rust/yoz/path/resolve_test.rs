use super::resolve;

#[test]
fn t_resolve_prefers_absolute_target() {
    let actual_strip = resolve("foo/bar", "/baz/qux", false, '/');
    assert_eq!(actual_strip, "/baz/qux");
    let actual_keep = resolve("foo/bar", "/baz/qux", true, '/');
    assert_eq!(actual_keep, "/baz/qux");
}

#[test]
fn t_resolve_combines_relative_paths() {
    let actual_strip = resolve("/foo", "bar/baz", false, '/');
    assert_eq!(actual_strip, "/foo/bar/baz");
    let actual_keep = resolve("/foo", "bar/baz", true, '/');
    assert_eq!(actual_keep, "/foo/bar/baz");
}

#[test]
fn t_resolve_handles_parent_segments() {
    let actual_strip = resolve("/foo/baz", "../bar", false, '/');
    assert_eq!(actual_strip, "/foo/bar");
    let actual_keep = resolve("/foo/baz", "../bar", true, '/');
    assert_eq!(actual_keep, "/foo/bar");
}

#[test]
fn t_resolve_representative_cases() {
    #[rustfmt::skip]
        let cases: &[(&str, &str, char, &str, &str)] = &[
            ("", "", '/', "/", "/"),
            ("", ".", '/', "/", "/"),
            ("", "./", '/', "/", "/"),
            ("", "..", '/', "/", "/"),
            ("", "../", '/', "/", "/"),
            ("", "/../b/c//.././/d/./e", '/', "/b/d/e", "/b/d/e"),
            ("", "../bar/.baz/./df/f", '/', "/bar/.baz/df/f", "/bar/.baz/df/f"),
            ("", "../../bar/baz", '/', "/bar/baz", "/bar/baz"),
            ("", "/", '/', "/", "/"),
            ("", "//", '/', "/", "/"),
            ("", "//alice", '/', "/alice", "/alice"),
            ("", "//alice/bob/..", '/', "/alice", "/alice"),
            ("", "//alice/bob/../", '/', "/alice/", "/alice"),
            ("", "/bar///baz//foo", '/', "/bar/baz/foo", "/bar/baz/foo"),
            ("", "b/c", '/', "/b/c", "/b/c"),
            ("", "b/c/", '/', "/b/c/", "/b/c"),
            ("", "b/c/.", '/', "/b/c", "/b/c"),
            ("", "/foo/./bar/../baz", '/', "/foo/baz", "/foo/baz"),
            ("", "/foo/./bar/../baz/", '/', "/foo/baz/", "/foo/baz"),
            ("", "c:", '/', "C:", "C:"),
            ("", "C:\\", '/', "C:", "C:"),
            ("", "C:/", '/', "C:", "C:"),
            ("", "C:\\bar", '/', "C:/bar", "C:/bar"),
            ("", "C:\\..\\xx", '/', "C:/xx", "C:/xx"),
            ("", "foo/bar/baz", '/', "/foo/bar/baz", "/foo/bar/baz"),
            ("", "foo\\bar\\baz\\", '/', "/foo/bar/baz/", "/foo/bar/baz"),
            ("", "foo/bar/", '/', "/foo/bar/", "/foo/bar"),
            ("", "/家/文件/项目", '/', "/家/文件/项目", "/家/文件/项目"),
            ("", "项目/计划/", '/', "/项目/计划/", "/项目/计划"),
            (".", "", '/', "./", "."),
            (".", ".", '/', ".", "."),
            (".", "./", '/', "./", "."),
        ];

    for &(from, to, sep, expected_keep, expected_strip) in cases {
        let actual_keep = resolve(from, to, true, sep);
        let actual_strip = resolve(from, to, false, sep);
        assert_eq!(
            actual_keep, expected_keep,
            "keep trailing slash, from: {from}, to: {to}, sep: {sep}"
        );
        assert_eq!(
            actual_strip, expected_strip,
            "strip trailing slash, from: {from}, to: {to}, sep: {sep}"
        );
    }
}
