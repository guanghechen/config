use super::SEP;
use super::split::split;

pub fn normalize(filepath: &str, keep_tailing_slash: bool) -> String {
    if filepath.is_empty() {
        return ".".to_string();
    }

    let pieces = split(filepath, keep_tailing_slash);
    normalize_splits(&pieces)
}

pub(crate) fn normalize_splits(pieces: &[String]) -> String {
    if pieces.is_empty() {
        return ".".to_string();
    }

    if pieces.len() == 1 && pieces[0].is_empty() {
        return SEP.to_string();
    }
    pieces.join(&SEP.to_string())
}

#[cfg(test)]
mod tests {
    use super::normalize;

    #[test]
    fn t_normalize_cases() {
        #[rustfmt::skip]
        let cases: &[(&str, &str, &str)] = &[
            (""                     , "."               , "."),
            ("."                    , "."               , "."),
            ("./"                   , "./"              , "."),
            (".."                   , ".."              , ".."),
            ("../"                  , "../"             , ".."),
            ("/../b/c//.././/d/./e" , "/b/d/e"          , "/b/d/e"),
            ("../bar/.baz/./df/f"   , "../bar/.baz/df/f", "../bar/.baz/df/f"),
            ("../../bar/baz"        , "../../bar/baz"   , "../../bar/baz"),
            ("/"                    , "/"               , "/"),
            ("//"                   , "/"               , "/"),
            ("//alice"              , "/alice"          , "/alice"),
            ("//alice/bob/.."       , "/alice"          , "/alice"),
            ("//alice/bob/../"      , "/alice/"         , "/alice"),
            ("/bar///baz//foo"      , "/bar/baz/foo"    , "/bar/baz/foo"),
            ("b/c"                  , "b/c"             , "b/c"),
            ("b/c/"                 , "b/c/"            , "b/c"),
            ("b/c/."                , "b/c"             , "b/c"),
            ("/foo/./bar/../baz"    , "/foo/baz"        , "/foo/baz"),
            ("/foo/./bar/../baz/"   , "/foo/baz/"       , "/foo/baz"),
            ("c:"                   , "C:"              , "C:"),
            ("C:\\"                 , "C:"              , "C:"),
            ("C:/"                  , "C:"              , "C:"),
            ("C:\\bar"              , "C:/bar"          , "C:/bar"),
            ("C:\\..\\xx"           , "C:/xx"           , "C:/xx"),
            ("foo/bar/baz"          , "foo/bar/baz"     , "foo/bar/baz"),
            ("foo\\bar\\baz\\"      , "foo/bar/baz/"    , "foo/bar/baz"),
            ("foo/bar/"             , "foo/bar/"        , "foo/bar"),
            ("/家/文件/项目"        , "/家/文件/项目"  , "/家/文件/项目"),
            ("项目/计划/"           , "项目/计划/"     , "项目/计划"),
        ];

        for &(input, expected_keep, expected_strip) in cases {
            let actual_keep = normalize(input, true);
            let actual_strip = normalize(input, false);
            assert_eq!(
                actual_keep, expected_keep,
                "keep trailing slash, input: {input}"
            );
            assert_eq!(
                actual_strip, expected_strip,
                "strip trailing slash, input: {input}"
            );
        }
    }

    #[test]
    fn t_uses_canonical_separator() {
        assert_eq!(normalize("\\foo/bar", false), "/foo/bar");
        assert_eq!(normalize("foo\\bar", false), "foo/bar");
    }
}
