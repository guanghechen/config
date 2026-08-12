use super::is_absolute::is_absolute;
use super::normalize::normalize;

pub fn resolve(from: &str, to: &str, keep_tailing_slash: bool) -> String {
    if is_absolute(to) {
        return normalize(to, keep_tailing_slash);
    }

    let mut combined = String::with_capacity(from.len() + 1 + to.len());
    combined.push_str(from);
    combined.push('/');
    combined.push_str(to);
    normalize(&combined, keep_tailing_slash)
}

#[cfg(test)]
mod tests {
    use super::resolve;

    #[test]
    fn t_resolve_prefers_absolute_target() {
        let actual_strip = resolve("foo/bar", "/baz/qux", false);
        assert_eq!(actual_strip, "/baz/qux");
        let actual_keep = resolve("foo/bar", "/baz/qux", true);
        assert_eq!(actual_keep, "/baz/qux");
    }

    #[test]
    fn t_resolve_combines_relative_paths() {
        let actual_strip = resolve("/foo", "bar/baz", false);
        assert_eq!(actual_strip, "/foo/bar/baz");
        let actual_keep = resolve("/foo", "bar/baz", true);
        assert_eq!(actual_keep, "/foo/bar/baz");
    }

    #[test]
    fn t_resolve_handles_parent_segments() {
        let actual_strip = resolve("/foo/baz", "../bar", false);
        assert_eq!(actual_strip, "/foo/bar");
        let actual_keep = resolve("/foo/baz", "../bar", true);
        assert_eq!(actual_keep, "/foo/bar");
    }

    #[test]
    fn t_resolve_representative_cases() {
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
            ("", "c:", "C:", "C:"),
            ("", "C:\\", "C:", "C:"),
            ("", "C:/", "C:", "C:"),
            ("", "C:\\bar", "C:/bar", "C:/bar"),
            ("", "C:\\..\\xx", "C:/xx", "C:/xx"),
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
            let actual_keep = resolve(from, to, true);
            let actual_strip = resolve(from, to, false);
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
}
