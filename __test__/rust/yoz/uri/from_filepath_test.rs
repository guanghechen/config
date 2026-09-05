use super::*;

#[test]
#[cfg(not(windows))]
fn t_from_filepath_unix() {
    let cases = [
        ("/home/user/file.txt", "file:///home/user/file.txt"),
        ("/bin/sh", "file:///bin/sh"),
        ("/path/to/dir/", "file:///path/to/dir/"),
        (
            "/path with spaces/file.txt",
            "file:///path%20with%20spaces/file.txt",
        ),
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
        (
            "C:\\Users\\user\\file.txt",
            "file:///C:/Users/user/file.txt",
        ),
        ("D:\\path\\to\\dir\\", "file:///D:/path/to/dir/"),
        (
            "C:\\path with spaces\\file.txt",
            "file:///C:/path%20with%20spaces/file.txt",
        ),
        ("C:/Users/user/file.txt", "file:///C:/Users/user/file.txt"),
        ("", ""),
    ];

    for (input, expected) in cases {
        let result = from_filepath(input);
        assert_eq!(result, expected, "input: {}", input);
    }
}
