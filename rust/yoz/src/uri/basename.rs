pub fn basename(uri: &str) -> Option<String> {
    use super::parse::parse;
    parse(uri).map(|parts| basename_path(parts.path))
}

fn basename_path(path: &str) -> String {
    if path.is_empty() {
        return String::new();
    }

    if path == "." {
        return String::new();
    }

    let mut p = path;
    if p.ends_with('/') {
        p = p.trim_end_matches('/');
        if p.is_empty() {
            return String::new();
        }
    }

    let has_prefix_sep = p.starts_with('/');
    let mut skip = 0usize;

    for segment in p.rsplit('/') {
        if segment.is_empty() || segment == "." {
            continue;
        }

        if segment == ".." {
            skip = skip.saturating_add(1);
            continue;
        }

        if skip > 0 {
            skip -= 1;
            continue;
        }

        return segment.to_string();
    }

    if skip > 0 {
        return if has_prefix_sep {
            String::new()
        } else {
            "..".to_string()
        };
    }

    String::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_basename_cases() {
        let cases = [
            ("file:///usr/bin/nvim", Some("nvim")),
            ("file:///foo/bar/../baz", Some("baz")),
            ("https://example.com/path/file.txt#section", Some("file.txt")),
            ("/usr/bin", None),
        ];

        for (input, expected) in cases {
            let result = basename(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }
}
