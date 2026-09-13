pub fn decode(src: &str) -> String {
    let mut result = Vec::with_capacity(src.len());
    let bytes = src.as_bytes();
    let len = bytes.len();
    let mut i = 0;

    while i < len {
        if bytes[i] == b'%' && i + 2 < len {
            let hex1 = bytes[i + 1];
            let hex2 = bytes[i + 2];
            if let (Some(d1), Some(d2)) = (hex_digit(hex1), hex_digit(hex2)) {
                result.push(d1 << 4 | d2);
                i += 3;
                continue;
            }
        }
        result.push(bytes[i]);
        i += 1;
    }

    String::from_utf8(result).unwrap_or_else(|e| String::from_utf8_lossy(e.as_bytes()).into_owned())
}

fn hex_digit(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_decode_cases() {
        let cases = [
            ("hello%20world", "hello world"),
            ("foo%2Fbar", "foo/bar"),
            ("%E4%B8%AD%E6%96%87", "中文"),
            ("no%encoding", "no%encoding"),
            ("100%25", "100%"),
            ("", ""),
            ("plain", "plain"),
            ("%2f%2F", "//"),
            ("a%20b%20c", "a b c"),
        ];

        for (input, expected) in cases {
            assert_eq!(decode(input), expected, "input: {}", input);
        }
    }
}
