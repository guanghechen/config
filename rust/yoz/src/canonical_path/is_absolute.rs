pub fn is_absolute(filepath: &str) -> bool {
    let bytes = filepath.as_bytes();
    if bytes.is_empty() {
        return false;
    }

    if matches!(bytes.get(0..2), Some([b'/', b'/']) | Some([b'\\', b'\\'])) {
        return true;
    }

    if matches!(bytes.first(), Some(b'/') | Some(b'\\')) {
        return true;
    }

    if bytes.len() >= 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
        return bytes.len() == 2 || matches!(bytes.get(2), Some(b'/') | Some(b'\\'));
    }

    false
}

#[cfg(test)]
mod tests {
    use super::is_absolute;

    #[test]
    fn t_is_absolute_cases() {
        let cases = [
            ("", false),
            (".", false),
            ("foo/bar", false),
            ("C", false),
            ("../foo", false),
            ("C:foo", false),
            ("/", true),
            ("/usr/bin", true),
            ("/home/user/../", true),
            ("//server/share", true),
            ("\\", true),
            ("\\server\\share", true),
            ("C:", true),
            ("C:/", true),
            ("C:\\", true),
            ("C:/foo", true),
            ("C:\\foo", true),
        ];

        for (input, expected) in cases {
            assert_eq!(is_absolute(input), expected, "input: {}", input);
        }
    }
}
