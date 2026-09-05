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
        let actual_keep = relative(from, to, true);
        let actual_strip = relative(from, to, false);
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
