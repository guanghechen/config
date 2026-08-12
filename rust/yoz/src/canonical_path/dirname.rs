use super::SEP;
use super::normalize::normalize_splits;
use super::split::split;

pub fn dirname(filepath: &str, keep_tailing_slash: bool) -> String {
    if filepath.is_empty() {
        if keep_tailing_slash {
            return format!("..{}", SEP);
        }
        return "..".to_string();
    }

    let pieces = split(filepath, false);
    if pieces.len() <= 1 {
        if pieces[0].is_empty() {
            return SEP.to_string();
        }

        if pieces[0].len() == 2 {
            let bytes = pieces[0].as_bytes();
            if bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
                if keep_tailing_slash {
                    return format!("{}{}", pieces[0], SEP);
                }
                return pieces[0].to_string();
            }
        }

        if keep_tailing_slash {
            return format!("..{}", SEP);
        }
        return "..".to_string();
    }

    let n = pieces.len() - 1;
    let result = normalize_splits(&pieces[0..n]);
    if keep_tailing_slash && !pieces[n - 1].is_empty() {
        return format!("{}{}", result, SEP);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::dirname;

    #[test]
    fn t_dirname_cases() {
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
            let actual_strip = dirname(input, false);
            let actual_keep = dirname(input, true);

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
}
