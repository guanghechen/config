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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/extname_test.rs"
    ));
}
