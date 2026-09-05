use super::*;

#[test]
#[cfg(not(windows))]
fn t_to_filepath_unix_keep_trailing() {
    let cases = [
        ("file:///home/user/file.txt", Some("/home/user/file.txt")),
        ("file:///bin/sh", Some("/bin/sh")),
        ("file:///path/to/dir/", Some("/path/to/dir/")),
        (
            "file:///path%20with%20spaces/file.txt",
            Some("/path with spaces/file.txt"),
        ),
        ("http://example.com/path", None),
        ("", None),
        ("/bin/sh", None),
    ];

    for (input, expected) in cases {
        let result = to_filepath(input, true);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}

#[test]
#[cfg(not(windows))]
fn t_to_filepath_unix_strip_trailing() {
    let cases = [
        ("file:///home/user/file.txt", Some("/home/user/file.txt")),
        ("file:///bin/sh", Some("/bin/sh")),
        ("file:///path/to/dir/", Some("/path/to/dir")),
        ("file:///", Some("/")),
    ];

    for (input, expected) in cases {
        let result = to_filepath(input, false);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}

#[test]
#[cfg(windows)]
fn t_to_filepath_windows_keep_trailing() {
    let cases = [
        (
            "file:///C:/Users/user/file.txt",
            Some("C:\\Users\\user\\file.txt"),
        ),
        ("file:///D:/path/to/dir/", Some("D:\\path\\to\\dir\\")),
        (
            "file:///C:/path%20with%20spaces/file.txt",
            Some("C:\\path with spaces\\file.txt"),
        ),
        ("http://example.com/path", None),
        ("", None),
    ];

    for (input, expected) in cases {
        let result = to_filepath(input, true);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}

#[test]
#[cfg(windows)]
fn t_to_filepath_windows_strip_trailing() {
    let cases = [
        (
            "file:///C:/Users/user/file.txt",
            Some("C:\\Users\\user\\file.txt"),
        ),
        ("file:///D:/path/to/dir/", Some("D:\\path\\to\\dir")),
        ("file:///C:/", Some("C:\\")),
    ];

    for (input, expected) in cases {
        let result = to_filepath(input, false);
        assert_eq!(result.as_deref(), expected, "input: {}", input);
    }
}

#[test]
fn t_non_file_protocol() {
    let cases = [
        "http://example.com",
        "https://example.com",
        "ftp://server/path",
    ];

    for input in cases {
        assert!(
            to_filepath(input, true).is_none(),
            "should return None for: {}",
            input
        );
    }
}
