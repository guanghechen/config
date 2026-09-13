use std::borrow::Cow;

#[inline]
pub fn to_os_path(filepath: &str) -> Cow<'_, str> {
    to_separator(filepath, std::path::MAIN_SEPARATOR)
}

#[inline]
fn to_separator(filepath: &str, separator: char) -> Cow<'_, str> {
    if separator == '/' || !filepath.as_bytes().contains(&b'/') {
        return Cow::Borrowed(filepath);
    }

    let mut buffer = [0; 4];
    Cow::Owned(filepath.replace('/', separator.encode_utf8(&mut buffer)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_to_separator() {
        assert_eq!(
            to_separator("C:/workspace/file.lua", '\\'),
            r"C:\workspace\file.lua"
        );
        assert_eq!(to_separator("C:/", '\\'), r"C:\");
        assert_eq!(
            to_separator("//server/share/repo", '\\'),
            r"\\server\share\repo"
        );
        assert_eq!(
            to_separator("/workspace/file.lua", '/'),
            "/workspace/file.lua"
        );
    }

    #[test]
    fn t_noop_borrows_input() {
        assert!(matches!(
            to_separator("/workspace/file.lua", '/'),
            Cow::Borrowed(_)
        ));
        assert!(matches!(
            to_separator(r"C:\workspace", '\\'),
            Cow::Borrowed(_)
        ));
    }

    #[test]
    fn t_uses_platform_separator() {
        let actual = to_os_path("C:/workspace/file.lua");
        let expected = if cfg!(windows) {
            r"C:\workspace\file.lua"
        } else {
            "C:/workspace/file.lua"
        };
        assert_eq!(actual, expected);
    }
}
