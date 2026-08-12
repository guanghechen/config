use super::SEP;
use super::normalize;

pub fn dirname(filepath: &str, keep_tailing_slash: bool) -> String {
    if filepath.is_empty() {
        if keep_tailing_slash {
            return format!("..{}", SEP);
        }
        return "..".to_string();
    }

    let mut result = normalize(filepath, false);
    let bytes = result.as_bytes();
    if bytes.len() == 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
        if keep_tailing_slash {
            result.push(SEP);
        }
        return result;
    }

    let Some(index) = result.rfind(SEP) else {
        return parent(keep_tailing_slash);
    };
    if index == 0 {
        result.truncate(1);
        return result;
    }

    result.truncate(index);
    if keep_tailing_slash {
        result.push(SEP);
    }
    result
}

fn parent(keep_tailing_slash: bool) -> String {
    if keep_tailing_slash {
        "../".to_string()
    } else {
        "..".to_string()
    }
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
