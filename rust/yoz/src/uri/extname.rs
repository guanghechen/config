pub fn extname(uri: &str) -> Option<String> {
    use super::parse::parse;
    parse(uri).map(|parts| extname_path(parts.path))
}

fn extname_path(path: &str) -> String {
    if path.is_empty() {
        return String::new();
    }

    let mut p = path;
    if p.ends_with('/') {
        p = p.trim_end_matches('/');
        if p.is_empty() {
            return String::new();
        }
    }

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

        return extension_from_segment(segment);
    }

    String::new()
}

fn extension_from_segment(segment: &str) -> String {
    if segment.is_empty() || segment == "." || segment == ".." {
        return String::new();
    }

    let mut start_dot = None;

    for (index, byte) in segment.as_bytes().iter().enumerate().rev() {
        if *byte == b'.' {
            start_dot = Some(index);
            break;
        }
    }

    match start_dot {
        Some(0) => String::new(),
        Some(index) => segment[index..].to_string(),
        None => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_extname_cases() {
        let cases = [
            ("file:///path/to/file.txt", Some(".txt")),
            ("file:///path/to/archive.tar.gz#line=10", Some(".gz")),
            ("https://example.com/.hidden", Some("")),
            ("/path/to/file.txt", None),
        ];

        for (input, expected) in cases {
            let result = extname(input);
            assert_eq!(result.as_deref(), expected, "input: {}", input);
        }
    }
}
