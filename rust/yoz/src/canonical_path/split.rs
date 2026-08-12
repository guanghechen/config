pub fn split(filepath: &str, keep_tailing_slash: bool) -> Vec<String> {
    if filepath.is_empty() || filepath == "." {
        return vec![".".to_string()];
    }

    let has_prefix_sep = filepath.starts_with(['/', '\\']);
    let has_suffix_sep = filepath.len() > 1 && filepath.ends_with(['/', '\\']);

    let mut pieces: Vec<String> = Vec::new();
    if has_prefix_sep {
        pieces.push(String::new());
    }

    for piece in filepath.split(['/', '\\']) {
        if piece.is_empty() || piece == "." {
            continue;
        }

        if piece == ".." {
            if let Some(last) = pieces.last() {
                if last.is_empty() {
                    continue;
                }
                if last.len() == 2 && last.as_bytes()[1] == b':' {
                    continue;
                }
                if last != ".." {
                    pieces.pop();
                    continue;
                }
            }
            pieces.push("..".to_string());
        } else if let Some(norm) = normalize_drive_segment(piece) {
            pieces.push(norm);
        } else {
            pieces.push(piece.to_string());
        }
    }

    if pieces.is_empty() {
        pieces.push(".".to_string());
    }

    let drive_root = pieces.len() == 1 && pieces[0].len() == 2 && pieces[0].as_bytes()[1] == b':';
    let root_like = pieces.len() == 1 && pieces[0].is_empty();

    let last_segment_is_non_empty = pieces
        .last()
        .map(|piece| !piece.is_empty())
        .unwrap_or(false);
    if keep_tailing_slash
        && !drive_root
        && !root_like
        && last_segment_is_non_empty
        && has_suffix_sep
    {
        pieces.push(String::new());
    }

    pieces
}

pub(crate) fn normalize_drive_segment(segment: &str) -> Option<String> {
    let mut chars = segment.chars();
    match (chars.next(), chars.next(), chars.next()) {
        (Some(letter), Some(':'), None) if letter.is_ascii_alphabetic() => {
            let mut drive = String::with_capacity(2);
            drive.push(letter.to_ascii_uppercase());
            drive.push(':');
            Some(drive)
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
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
            let expected_keep_vec: Vec<String> =
                expected_keep.iter().map(|s| s.to_string()).collect();
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
}
