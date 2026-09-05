pub fn split(path: &str) -> Vec<String> {
    if path.is_empty() || path == "." {
        return vec![".".to_string()];
    }

    let has_prefix_sep = path.starts_with('/');
    let has_suffix_sep = path.len() > 1 && path.ends_with('/');

    let mut pieces: Vec<String> = Vec::new();
    if has_prefix_sep {
        pieces.push(String::new());
    }

    for piece in path.split('/') {
        if piece.is_empty() || piece == "." {
            continue;
        }

        if piece == ".." {
            if let Some(last) = pieces.last() {
                if last.is_empty() {
                    continue;
                }
                if last != ".." {
                    pieces.pop();
                    continue;
                }
            }
            pieces.push("..".to_string());
        } else {
            pieces.push(piece.to_string());
        }
    }

    if pieces.is_empty() {
        pieces.push(".".to_string());
    }

    let root_like = pieces.len() == 1 && pieces[0].is_empty();
    let last_segment_is_non_empty = pieces.last().map(|p| !p.is_empty()).unwrap_or(false);

    if !root_like && last_segment_is_non_empty && has_suffix_sep {
        pieces.push(String::new());
    }

    pieces
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/split_test.rs"
    ));
}
