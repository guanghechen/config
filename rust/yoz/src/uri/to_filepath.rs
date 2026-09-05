use super::decode::decode;
use super::parse::parse;

pub fn to_filepath(uri: &str, keep_trailing_slash: bool) -> Option<String> {
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
    let mut result = {
        // On Windows, file URI path starts with "/" followed by drive letter
        // e.g., "/C:/Users/..." -> "C:/Users/..."
        // Then normalize to use backslashes
        let trimmed = decoded.strip_prefix('/').unwrap_or(&decoded);
        trimmed.replace('/', "\\")
    };

    #[cfg(not(windows))]
    let mut result = decoded;

    if !keep_trailing_slash && result.len() > 1 {
        let last_char = result.chars().last().unwrap_or('\0');
        if last_char == '/' || last_char == '\\' {
            // On Windows, preserve trailing slash for root paths like "C:\"
            // "C:" means current directory on C drive, "C:\" means root of C drive
            #[cfg(windows)]
            let is_windows_root = result.len() == 3
                && result.chars().nth(1) == Some(':')
                && result.chars().next().map_or(false, |c| c.is_ascii_alphabetic());

            #[cfg(not(windows))]
            let is_windows_root = false;

            if !is_windows_root {
                result.pop();
            }
        }
    }

    Some(result)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/to_filepath_test.rs"
    ));
}
