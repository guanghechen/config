use super::super::SEP;
use super::dirname;

#[test]
fn t_dirname_cases() {
    fn adapt_expected(template: &str, sep: char) -> String {
        if template.contains('/') || template.contains('\\') {
            let sep_str = sep.to_string();
            template.replace(['\\', '/'], &sep_str)
        } else {
            template.to_string()
        }
    }

    #[rustfmt::skip]
        let cases: &[(&str, &str, &str)] = &[
            (""                     , ".."         , "../"),
            ("."                    , ".."         , "../"),
            (".."                   , ".."         , "../"),
            ("/"                    , "/"          , "/"),
            ("//"                   , "/"          , "/"),
            ("///"                  , "/"          , "/"),
            ("/foo"                 , "/"          , "/"),
            ("/foo/bar"             , "/foo"       , "/foo/"),
            ("/foo/bar/"            , "/foo"       , "/foo/"),
            ("foo"                  , ".."         , "../"),
            ("foo/bar"              , "foo"        , "foo/"),
            ("foo/bar/"             , "foo"        , "foo/"),
            ("foo//bar"             , "foo"        , "foo/"),
            ("../foo"               , ".."         , "../"),
            ("../foo/bar"           , "../foo"     , "../foo/"),
            ("../foo//bar/"         , "../foo"     , "../foo/"),
            ("C:"                   , "C:"         , "C:/"),
            (r"C:\"                 , "C:"         , "C:/"),
            (r"C:\foo"              , "C:"         , "C:/"),
            (r"C:\foo\bar"          , "C:/foo"     , "C:/foo/"),
            ("C:/foo/bar"           , "C:/foo"     , "C:/foo/"),
            (r"foo\bar\baz"         , "foo/bar"    , "foo/bar/"),
            ("//server/share"       , "/server"    , "/server/"),
            ("//server/share/foo"   , "/server/share", "/server/share/"),
        ];

    for &(input, expected_strip, expected_keep) in cases {
        let actual_strip = dirname(input, false, SEP);
        let actual_keep = dirname(input, true, SEP);
        let expected_strip = adapt_expected(expected_strip, SEP);
        let expected_keep = adapt_expected(expected_keep, SEP);

        assert_eq!(
            actual_strip, expected_strip,
            "strip trailing slash, input: {input}",
        );
        assert_eq!(
            actual_keep, expected_keep,
            "keep trailing slash, input: {input}",
        );
    }
}
