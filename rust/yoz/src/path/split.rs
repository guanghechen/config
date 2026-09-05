pub fn split(filepath: &str, keep_tailing_slash: bool) -> Vec<String> {
    if filepath.is_empty() || filepath == "." {
        return vec![".".to_string()];
    }

    let has_prefix_sep = filepath.starts_with(['/', '\\']);
    let has_suffix_sep = filepath.len() > 1 && filepath.ends_with(['/', '\\']);

    let mut pieces: Vec<String> = Vec::new();
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
    let mut chars = segment.chars();
    match (chars.next(), chars.next(), chars.next()) {
        (Some(letter), Some(':'), None) if letter.is_ascii_alphabetic() => {
            let mut drive = String::with_capacity(2);
            drive.push(letter.to_ascii_uppercase());
            drive.push(':');
            Some(drive)
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/split_test.rs"
    ));
}
