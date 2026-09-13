use super::split::normalize_drive_segment;

pub fn extname(filepath: &str) -> String {
    if filepath.is_empty() {
        return String::new();
    }

    let mut path = filepath;
    if path.ends_with(['/', '\\']) {
        path = path.trim_end_matches(['/', '\\']);
        if path.is_empty() {
            return String::new();
        }
    }

    let mut skip = 0usize;

    for segment in path.rsplit(['/', '\\']) {
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

        if normalize_drive_segment(segment).is_some() {
            return String::new();
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
    use super::extname;

    #[test]
    fn t_extname_cases() {
        let cases = [
            ("", ""),
            (".", ""),
            ("..", ""),
            ("/", ""),
            ("foo", ""),
            ("foo.txt", ".txt"),
            ("foo.", "."),
            ("foo..", "."),
            ("foo..bar", ".bar"),
            ("/path/to/archive.tar.gz", ".gz"),
            ("//server/share/.foo", ""),
            ("//server/share/file.txt", ".txt"),
            ("foo/.hidden", ""),
            ("foo/.hidden.ext", ".ext"),
            ("foo/bar/..", ""),
            ("foo/bar/../baz.txt", ".txt"),
            ("foo/bar/.", ""),
            ("foo/bar/", ""),
            ("C:/tools/rust-compiler.exe", ".exe"),
            ("C:\\", ""),
            ("C:", ""),
            ("家/项目/说明.md", ".md"),
        ];

        for (input, expected) in cases {
            assert_eq!(extname(input), expected, "input: {}", input);
        }
    }
}
