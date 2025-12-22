pub fn split(path: &str) -> Vec<String> {
    if path.is_empty() || path == "." {
        return vec![".".to_string()];
    }

    let has_prefix_sep = path.starts_with('/');
    let has_suffix_sep = path.len() > 1 && path.ends_with('/');

    let mut pieces: Vec<String> = Vec::new();
    if has_prefix_sep {
        pieces.push(String::new());
    }

    for piece in path.split('/') {
        if piece.is_empty() || piece == "." {
            continue;
        }

        if piece == ".." {
            if let Some(last) = pieces.last() {
                if last.is_empty() {
                    continue;
                }
                if last != ".." {
                    pieces.pop();
                    continue;
                }
            }
            pieces.push("..".to_string());
        } else {
            pieces.push(piece.to_string());
        }
    }

    if pieces.is_empty() {
        pieces.push(".".to_string());
    }

    let root_like = pieces.len() == 1 && pieces[0].is_empty();
    let last_segment_is_non_empty = pieces.last().map(|p| !p.is_empty()).unwrap_or(false);

    if !root_like && last_segment_is_non_empty && has_suffix_sep {
        pieces.push(String::new());
    }

    pieces
}

#[cfg(test)]
mod tests {
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
}
