use super::decode::decode;
use super::parse::parse;

#[cfg(windows)]
pub const SEP: char = '\\';

#[cfg(not(windows))]
pub const SEP: char = '/';

pub fn to_filepath(uri: &str) -> Option<String> {
    let parts = parse(uri)?;

    if parts.protocol != "file" {
        return None;
    }

    let path = parts.path;
    if path.is_empty() {
        return None;
    }

    let decoded = decode(path);

    #[cfg(windows)]
    {
        // On Windows, file URI path starts with "/" followed by drive letter
        // e.g., "/C:/Users/..." -> "C:/Users/..."
        // Then normalize to use backslashes
        let trimmed = decoded.strip_prefix('/').unwrap_or(&decoded);
        let normalized = trimmed.replace('/', &SEP.to_string());
        Some(normalized)
    }

    #[cfg(not(windows))]
    {
        // On Unix, the path is already in the correct format
        // e.g., "/home/user/..." -> "/home/user/..."
        Some(decoded)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[cfg(not(windows))]
    fn t_to_filepath_unix() {
        let cases = [
            ("file:///home/user/file.txt", Some("/home/user/file.txt")),
            ("file:///bin/sh", Some("/bin/sh")),
            ("file:///path/to/dir/", Some("/path/to/dir/")),
            ("file:///path%20with%20spaces/file.txt", Some("/path with spaces/file.txt")),
            ("http://example.com/path", None),
            ("", None),
            ("/bin/sh", None),
        ];

        for (input, expected) in cases {
            let result = to_filepath(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }

    #[test]
    #[cfg(windows)]
    fn t_to_filepath_windows() {
        let cases = [
            ("file:///C:/Users/user/file.txt", Some("C:\\Users\\user\\file.txt")),
            ("file:///D:/path/to/dir/", Some("D:\\path\\to\\dir\\")),
            ("file:///C:/path%20with%20spaces/file.txt", Some("C:\\path with spaces\\file.txt")),
            ("http://example.com/path", None),
            ("", None),
        ];

        for (input, expected) in cases {
            let result = to_filepath(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }

    #[test]
    fn t_non_file_protocol() {
        let cases = ["http://example.com", "https://example.com", "ftp://server/path"];

        for input in cases {
            assert!(to_filepath(input).is_none(), "should return None for: {}", input);
        }
    }
}
