use super::*;

#[test]
fn t_split_cases() {
    #[rustfmt::skip]
        let cases: &[(&str, &[&str])] = &[
            (""                     , &["."]),
            ("."                    , &["."]),
            ("./"                   , &[".", ""]),
            (".."                   , &[".."]),
            ("../"                  , &["..", ""]),
            ("/../b/c//.././/d/./e" , &["", "b", "d", "e"]),
            ("../bar/.baz/./df/f"   , &["..", "bar", ".baz", "df", "f"]),
            ("../../bar/baz"        , &["..", "..", "bar", "baz"]),
            ("/"                    , &[""]),
            ("//"                   , &[""]),
            ("//alice"              , &["", "alice"]),
            ("//alice/bob/.."       , &["", "alice"]),
            ("//alice/bob/../"      , &["", "alice", ""]),
            ("/bar///baz//foo"      , &["", "bar", "baz", "foo"]),
            ("b/c"                  , &["b", "c"]),
            ("b/c/"                 , &["b", "c", ""]),
            ("b/c/."                , &["b", "c"]),
            ("/foo/./bar/../baz"    , &["", "foo", "baz"]),
            ("/foo/./bar/../baz/"   , &["", "foo", "baz", ""]),
            ("foo/bar/baz"          , &["foo", "bar", "baz"]),
            ("foo/bar/"             , &["foo", "bar", ""]),
            ("/家/文件/项目"        , &["", "家", "文件", "项目"]),
            ("项目/计划/"           , &["项目", "计划", ""]),
        ];

    for &(input, expected) in cases {
        let expected_vec: Vec<String> = expected.iter().map(|s| s.to_string()).collect();
        let actual = split(input);
        assert_eq!(actual, expected_vec, "input: {input}");
    }
}
