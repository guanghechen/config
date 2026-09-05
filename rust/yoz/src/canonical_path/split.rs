pub fn split(filepath: &str, keep_tailing_slash: bool) -> Vec<String> {
    if filepath.is_empty() || filepath == "." {
        return vec![".".to_string()];
    }

    let bytes = filepath.as_bytes();
    let has_prefix_sep = matches!(bytes.first(), Some(b'/') | Some(b'\\'));
    let has_suffix_sep = bytes.len() > 1 && matches!(bytes.last(), Some(b'/') | Some(b'\\'));

    let capacity = bytes
        .iter()
        .filter(|&&byte| byte == b'/' || byte == b'\\')
        .count()
        + 1;
    let mut pieces: Vec<String> = Vec::with_capacity(capacity);
    if has_prefix_sep {
        pieces.push(String::new());
    }

    for piece in filepath.split(['/', '\\']) {
        if piece.is_empty() || piece == "." {
            continue;
        }

        if piece == ".." {
            if let Some(last) = pieces.last() {
                if last.is_empty() {
                    continue;
                }
                if last.len() == 2 && last.as_bytes()[1] == b':' {
                    continue;
                }
                if last != ".." {
                    pieces.pop();
                    continue;
                }
            }
            pieces.push("..".to_string());
        } else if let Some(norm) = normalize_drive_segment(piece) {
            pieces.push(norm);
        } else {
            pieces.push(piece.to_string());
        }
    }

    if pieces.is_empty() {
        pieces.push(".".to_string());
    }

    let drive_root = pieces.len() == 1 && pieces[0].len() == 2 && pieces[0].as_bytes()[1] == b':';
    let root_like = pieces.len() == 1 && pieces[0].is_empty();

    let last_segment_is_non_empty = pieces
        .last()
        .map(|piece| !piece.is_empty())
        .unwrap_or(false);
    if keep_tailing_slash
        && !drive_root
        && !root_like
        && last_segment_is_non_empty
        && has_suffix_sep
    {
        pieces.push(String::new());
    }

    pieces
}

pub(crate) fn normalize_drive_segment(segment: &str) -> Option<String> {
    let bytes = segment.as_bytes();
    if bytes.len() == 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
        let mut drive = String::with_capacity(2);
        drive.push(bytes[0].to_ascii_uppercase() as char);
        drive.push(':');
        Some(drive)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/split_test.rs"
    ));
}
