use super::normalize::normalize_splits;
use super::split::split;

pub fn dirname(filepath: &str, keep_tailing_slash: bool, sep: char) -> String {
    if filepath.is_empty() {
        if keep_tailing_slash {
            return format!("..{}", sep);
        }
        return "..".to_string();
    }

    let pieces = split(filepath, false);
    if pieces.len() <= 1 {
        if pieces[0].is_empty() {
            return sep.to_string();
        }

        if pieces[0].len() == 2 {
            let bytes = pieces[0].as_bytes();
            if bytes[0].is_ascii_alphabetic() && bytes[1] == b':' {
                if keep_tailing_slash {
                    return format!("{}{}", pieces[0], sep);
                }
                return pieces[0].to_string();
            }
        }

        if keep_tailing_slash {
            return format!("..{}", sep);
        }
        return "..".to_string();
    }

    let n = pieces.len() - 1;
    let result = normalize_splits(&pieces[0..n], sep);
    if keep_tailing_slash && !pieces[n - 1].is_empty() {
        return format!("{}{}", result, sep);
    }
    result
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/dirname_test.rs"
    ));
}
