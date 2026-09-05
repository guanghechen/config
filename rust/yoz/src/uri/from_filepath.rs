use super::encode::encode;

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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/from_filepath_test.rs"
    ));
}
