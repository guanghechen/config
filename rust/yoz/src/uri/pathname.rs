use super::parse::parse;

pub fn pathname(uri: &str) -> Option<String> {
    parse(uri).map(|parts| parts.path.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_pathname_cases() {
        let cases = [
            ("file:///bin/sh", Some("/bin/sh")),
            ("file:///home/user/file.txt", Some("/home/user/file.txt")),
            ("http://example.com/path", Some("example.com/path")),
            ("https://example.com/path#section", Some("example.com/path")),
            ("file:///path/to/file#line=10", Some("/path/to/file")),
            ("/bin/sh", None),
            ("", None),
        ];

        for (input, expected) in cases {
            let result = pathname(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }
}
