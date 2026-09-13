mod basename;
mod cwd;
mod dirname;
mod extname;
mod from_os_path;
mod is_absolute;
mod is_descendant;
mod is_dirpath;
mod join;
mod normalize;
mod relative;
mod resolve;
mod sep;
mod split;
mod to_os_path;

pub use basename::*;
pub use cwd::*;
pub use dirname::*;
pub use extname::*;
pub use from_os_path::*;
pub use is_absolute::*;
pub use is_descendant::*;
pub use is_dirpath::*;
pub use join::*;
pub use normalize::*;
pub use relative::*;
pub use resolve::*;
pub use sep::*;
pub use split::*;
pub use to_os_path::*;

#[cfg(test)]
mod differential_tests {
    use super as canonical;
    use crate::path;

    const PATHS: &[&str] = &[
        "",
        ".",
        "./",
        "..",
        "../",
        "/",
        "//",
        "///",
        "/foo",
        "/foo/",
        "/foo//bar",
        "/foo/./bar",
        "/foo/bar/..",
        "/foo/bar/../baz/",
        r"\foo\bar",
        r"foo\bar\..\baz\",
        "C:",
        "c:",
        "C:/",
        r"C:\",
        "C:/foo/../bar",
        "1:/foo/..",
        "1:/",
        "/家/文件/../项目/",
        "项目/计划",
    ];

    #[test]
    fn t_matches_path_unary_operations() {
        for &filepath in PATHS {
            assert_eq!(canonical::basename(filepath), path::basename(filepath));
            assert_eq!(
                canonical::dirname(filepath, false),
                path::dirname(filepath, false, '/')
            );
            assert_eq!(
                canonical::dirname(filepath, true),
                path::dirname(filepath, true, '/')
            );
            assert_eq!(canonical::extname(filepath), path::extname(filepath));
            assert_eq!(
                canonical::is_absolute(filepath),
                path::is_absolute(filepath)
            );
            assert_eq!(canonical::is_dirpath(filepath), path::is_dirpath(filepath));
            assert_eq!(
                canonical::normalize(filepath, false),
                path::normalize(filepath, false, '/')
            );
            assert_eq!(
                canonical::normalize(filepath, true),
                path::normalize(filepath, true, '/')
            );
            assert_eq!(
                canonical::split(filepath, false),
                path::split(filepath, false)
            );
            assert_eq!(
                canonical::split(filepath, true),
                path::split(filepath, true)
            );
        }
    }

    #[test]
    fn t_matches_path_binary_operations() {
        for &from in PATHS {
            for &to in PATHS {
                for keep_tailing_slash in [false, true] {
                    assert_eq!(
                        canonical::join(from, to, keep_tailing_slash),
                        path::join(from, to, keep_tailing_slash, '/'),
                        "join from={from:?}, to={to:?}"
                    );
                    assert_eq!(
                        canonical::resolve(from, to, keep_tailing_slash),
                        path::resolve(from, to, keep_tailing_slash, '/'),
                        "resolve from={from:?}, to={to:?}"
                    );
                }

                if canonical::is_absolute(from) && canonical::is_absolute(to) {
                    for keep_tailing_slash in [false, true] {
                        assert_eq!(
                            canonical::relative(from, to, keep_tailing_slash),
                            path::relative(from, to, keep_tailing_slash, '/'),
                            "relative from={from:?}, to={to:?}"
                        );
                    }
                    assert_eq!(
                        canonical::is_descendant(from, to),
                        path::is_descendant(from, to),
                        "is_descendant from={from:?}, to={to:?}"
                    );
                }
            }
        }
    }
}
