use super::encode::encode;

#[cfg(windows)]
pub const SEP: char = '\\';

#[cfg(not(windows))]
pub const SEP: char = '/';

pub fn from_filepath(filepath: &str) -> String {
    if filepath.is_empty() {
        return String::new();
    }

    #[cfg(windows)]
    {
        // On Windows, convert backslashes to forward slashes and prepend /
        // e.g., "C:\Users\user\file.txt" -> "file:///C:/Users/user/file.txt"
        let normalized = filepath.replace('\\', "/");
        let encoded = encode_filepath_component(&normalized);
        format!("file:///{}", encoded)
    }

    #[cfg(not(windows))]
    {
        // On Unix, the path should already start with /
        // e.g., "/home/user/file.txt" -> "file:///home/user/file.txt"
        let encoded = encode_filepath_component(filepath);
        format!("file://{}", encoded)
    }
}

fn encode_filepath_component(path: &str) -> String {
    path.chars()
        .map(|c| {
            if c == '/' || c == ':' {
                c.to_string()
            } else if needs_encoding(c) {
                encode(&c.to_string())
            } else {
                c.to_string()
            }
        })
        .collect()
}

fn needs_encoding(c: char) -> bool {
    !matches!(c,
        'A'..='Z' | 'a'..='z' | '0'..='9' |
        '-' | '_' | '.' | '~' |
        '!' | '$' | '&' | '\'' | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '@'
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[cfg(not(windows))]
    fn t_from_filepath_unix() {
        let cases = [
            ("/home/user/file.txt", "file:///home/user/file.txt"),
            ("/bin/sh", "file:///bin/sh"),
            ("/path/to/dir/", "file:///path/to/dir/"),
            ("/path with spaces/file.txt", "file:///path%20with%20spaces/file.txt"),
            ("", ""),
        ];

        for (input, expected) in cases {
            let result = from_filepath(input);
            assert_eq!(result, expected, "input: {}", input);
        }
    }

    #[test]
    #[cfg(windows)]
    fn t_from_filepath_windows() {
        let cases = [
            ("C:\\Users\\user\\file.txt", "file:///C:/Users/user/file.txt"),
            ("D:\\path\\to\\dir\\", "file:///D:/path/to/dir/"),
            ("C:\\path with spaces\\file.txt", "file:///C:/path%20with%20spaces/file.txt"),
            ("C:/Users/user/file.txt", "file:///C:/Users/user/file.txt"),
            ("", ""),
        ];

        for (input, expected) in cases {
            let result = from_filepath(input);
            assert_eq!(result, expected, "input: {}", input);
        }
    }
}
