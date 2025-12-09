use super::get_cwd;
use super::is_absolute;
use super::normalize_splits;
use super::split;
use std::borrow::Cow;

pub fn relative(from: &str, to: &str, keep_tailing_slash: bool, sep: char) -> String {
    let cwd_guard = get_cwd();
    let cwd: &str = &cwd_guard;

    let abs_from = if is_absolute(from) {
        Cow::Borrowed(from)
    } else {
        Cow::Owned(format!("{}/{}", cwd, from))
    };

    let abs_to = if is_absolute(to) {
        Cow::Borrowed(to)
    } else {
        Cow::Owned(format!("{}/{}", cwd, to))
    };

    let from_pieces = split(abs_from.as_ref(), false);
    let mut to_pieces = split(abs_to.as_ref(), false);

    let to_has_suffix_sep = keep_tailing_slash && to.len() > 1 && to.ends_with(['/', '\\']);
    let should_append_slash =
        to_has_suffix_sep && to_pieces.len() > 1 && !to_pieces.last().is_some_and(|s| s.is_empty());

    let n1 = from_pieces.len();
    let n2 = to_pieces.len();
    let n = n1.min(n2);
    if n < 1 || from_pieces[0] != to_pieces[0] {
        if should_append_slash {
            to_pieces.push(String::new());
        };
        return normalize_splits(&to_pieces, sep);
    }

    let mut m = n;
    for i in 1..n {
        if from_pieces[i] != to_pieces[i] {
            m = i;
            break;
        }
    }

    if m == n {
        if n1 == n2 {
            if should_append_slash {
                return "./".to_string();
            }
            return ".".to_string();
        }

        if n1 < n2 {
            if to_has_suffix_sep
                && to_pieces.len() > 1
                && !to_pieces.last().is_some_and(|s| s.is_empty())
            {
                to_pieces.push(String::new());
            };
            return normalize_splits(&to_pieces[m..], sep);
        }
    }

    let d = n1 - m;
    if n2 == m {
        if should_append_slash {
            let mut result = String::with_capacity(d * 3);
            for _ in 0..d {
                result.push_str("..");
                result.push(sep);
            }
            return result;
        }

        let mut result = String::with_capacity(d * 3 - 1);
        for i in 0..d {
            if i > 0 {
                result.push(sep);
            }
            result.push_str("..");
        }
        return result;
    }

    let mut prefix = String::with_capacity(d * 3);
    for _ in 0..d {
        prefix.push_str("..");
        prefix.push(sep);
    }
    if should_append_slash {
        to_pieces.push(String::new());
    };
    prefix + normalize_splits(&to_pieces[m..], sep).as_str()
}

#[cfg(test)]
mod tests {
    use super::super::get_cwd;
    use super::super::set_cwd;
    use super::relative;

    #[test]
    fn t_relative_cases() {
        let original = get_cwd().to_string();
        #[cfg(windows)]
        set_cwd("C:\\workspace");
        #[cfg(not(windows))]
        set_cwd("/workspace");
        #[rustfmt::skip]
        let cases: &[(&str, &str, &str, &str)] = &[
            (""              , ""                   , "."        , "."),
            (""              , "foo"                , "foo"      , "foo"),
            (""              , "foo/"               , "foo/"     , "foo"),
            ("."             , "."                  , "."        , "."),
            ("."             , "foo"                , "foo"      , "foo"),
            ("."             , "foo/"               , "foo/"     , "foo"),
            ("foo"           , "."                  , ".."       , ".."),
            ("foo"           , "bar"                , "../bar"   , "../bar"),
            ("foo"           , "foo/bar"            , "bar"      , "bar"),
            ("foo"           , "foo/bar/"           , "bar/"     , "bar"),
            ("foo/bar"       , "foo/bar"            , "."        , "."),
            ("foo/bar"       , "foo/bar/"           , "./"       , "."),
            ("foo/bar"       , "foo/baz"            , "../baz"   , "../baz"),
            ("foo/bar"       , "../baz"             , "../../../baz", "../../../baz"),
            ("foo/bar"       , "../../baz"          , "../../../baz", "../../../baz"),
            ("/foo/bar"      , "/foo/bar"           , "."        , "."),
            ("/foo/bar"      , "/foo/bar/"          , "./"       , "."),
            ("/foo/bar"      , "/foo/baz"           , "../baz"   , "../baz"),
            ("/foo/bar"      , "/bar/baz"           , "../../bar/baz", "../../bar/baz"),
            ("../foo"        , "../foo/bar"         , "bar"      , "bar"),
            ("../foo"        , "../foo/bar/"        , "bar/"     , "bar"),
            ("../foo"        , "../../foo/bar"      , "bar"      , "bar"),
            ("../foo"        , "../../foo/bar/"     , "bar/"     , "bar"),
            ("C:\\foo"       , "C:\\foo"            , "."        , "."),
            ("C:\\foo"       , "C:\\foo\\bar"       , "bar"      , "bar"),
            ("C:\\foo"       , "C:\\foo\\bar\\"     , "bar/"     , "bar"),
            ("C:\\foo\\bar"  , "C:\\foo"            , ".."       , ".."),
            ("C:\\foo"       , "D:\\\\bar"          , "D:/bar"   , "D:/bar"),
            ("//server/share", "//server/share/foo" , "foo"      , "foo"),
            ("//server/share", "//server/share/foo/", "foo/"     , "foo"),
        ];

        for &(from, to, expected_keep, expected_strip) in cases {
            let actual_keep = relative(from, to, true, '/');
            let actual_strip = relative(from, to, false, '/');
            assert_eq!(
                actual_keep, expected_keep,
                "keep trailing slash, from: {from}, to: {to}"
            );
            assert_eq!(
                actual_strip, expected_strip,
                "strip trailing slash, from: {from}, to: {to}"
            );
        }

        set_cwd(&original);
    }
}
