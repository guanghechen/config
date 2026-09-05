use super::split;

#[test]
fn t_split_cases() {
    #[rustfmt::skip]
        let cases: &[(&str, &[&str], &[&str])] = &[
            (""                     , &["."]                            , &["."]),
            ("."                    , &["."]                            , &["."]),
            ("./"                   , &[".", ""]                        , &["."]),
            (".."                   , &[".."]                           , &[".."]),
            ("../"                  , &["..", ""]                       , &[".."]),
            ("/../b/c//.././/d/./e" , &["", "b", "d", "e"]              , &["", "b", "d", "e"]),
            ("../bar/.baz/./df/f"   , &["..", "bar", ".baz", "df", "f"] , &["..", "bar", ".baz", "df", "f"]),
            ("../../bar/baz"        , &["..", "..", "bar", "baz"]       , &["..", "..", "bar", "baz"]),
            ("/"                    , &[""]                             , &[""]),
            ("//"                   , &[""]                             , &[""]),
            ("//alice"              , &["", "alice"]                    , &["", "alice"]),
            ("//alice/bob/.."       , &["", "alice"]                    , &["", "alice"]),
            ("//alice/bob/../"      , &["", "alice", ""]                , &["", "alice"]),
            ("/bar///baz//foo"      , &["", "bar", "baz", "foo"]        , &["", "bar", "baz", "foo"]),
            ("b/c"                  , &["b", "c"]                       , &["b", "c"]),
            ("b/c/"                 , &["b", "c", ""]                   , &["b", "c"]),
            ("b/c/."                , &["b", "c"]                       , &["b", "c"]),
            ("/foo/./bar/../baz"    , &["", "foo", "baz"]               , &["", "foo", "baz"]),
            ("/foo/./bar/../baz/"   , &["", "foo", "baz", ""]           , &["", "foo", "baz"]),
            ("c:"                   , &["C:"]                           , &["C:"]),
            ("C:\\"                 , &["C:"]                           , &["C:"]),
            ("C:/"                  , &["C:"]                           , &["C:"]),
            ("C:\\bar"              , &["C:", "bar"]                    , &["C:", "bar"]),
            ("C:\\..\\xx"           , &["C:", "xx"]                     , &["C:", "xx"]),
            ("foo/bar/baz"          , &["foo", "bar", "baz"]            , &["foo", "bar", "baz"]),
            ("foo\\bar\\baz\\"      , &["foo", "bar", "baz", ""]        , &["foo", "bar", "baz"]),
            ("foo/bar/"             , &["foo", "bar", ""]               , &["foo", "bar"]),
            ("/家/文件/项目"        , &["", "家", "文件", "项目"]       , &["", "家", "文件", "项目"]),
            ("项目/计划/"           , &["项目", "计划", ""]             , &["项目", "计划"]),
        ];

    for &(input, expected_keep, expected_strip) in cases {
        let expected_keep_vec: Vec<String> = expected_keep.iter().map(|s| s.to_string()).collect();
        let expected_strip_vec: Vec<String> =
            expected_strip.iter().map(|s| s.to_string()).collect();
        let actual_keep = split(input, true);
        let actual_strip = split(input, false);
        assert_eq!(
            actual_keep, expected_keep_vec,
            "keep trailing slash, input: {input}"
        );
        assert_eq!(
            actual_strip, expected_strip_vec,
            "strip trailing slash, input: {input}"
        );
    }
}
