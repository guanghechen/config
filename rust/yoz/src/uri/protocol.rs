use super::parse::parse;

pub fn protocol(uri: &str) -> Option<String> {
    parse(uri).map(|parts| parts.protocol.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_protocol_cases() {
        let cases = [
            ("file:///bin/sh", Some("file")),
            ("http://example.com/path", Some("http")),
            ("https://example.com/path#section", Some("https")),
            ("custom://some/path", Some("custom")),
            ("/bin/sh", None),
            ("", None),
        ];

        for (input, expected) in cases {
            let result = protocol(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }
}
