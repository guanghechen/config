use super::split::normalize_drive_segment;

pub fn basename(filepath: &str) -> String {
    if filepath.is_empty() {
        return String::new();
    }

    if filepath == "." {
        return String::new();
    }

    let mut path = filepath;
    if path.ends_with(['/', '\\']) {
        path = path.trim_end_matches(['/', '\\']);
        if path.is_empty() {
            return String::new();
        }
    }

    let has_prefix_sep = path.starts_with(['/', '\\']);
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

        if let Some(norm) = normalize_drive_segment(segment) {
            return norm;
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

    normalize_drive_segment(path).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/basename_test.rs"
    ));
}
