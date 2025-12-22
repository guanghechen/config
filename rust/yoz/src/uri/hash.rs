use super::parse::parse;

pub fn hash(uri: &str) -> Option<String> {
    parse(uri).and_then(|parts| parts.hash.map(|h| h.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_hash_cases() {
        let cases = [
            ("file:///bin/sh", None),
            ("file:///path/to/file#line=10", Some("line=10")),
            ("https://example.com/path#section", Some("section")),
            ("custom://some/path#hash", Some("hash")),
            ("file:///path#", Some("")),
            ("/bin/sh", None),
            ("", None),
        ];

        for (input, expected) in cases {
            let result = hash(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }
}
