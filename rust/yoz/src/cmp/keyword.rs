use regex::Regex;
use std::sync::OnceLock;

fn mark_regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| Regex::new(r"^\p{M}$").unwrap())
}

fn is_keyword(character: char) -> bool {
    if character.is_alphanumeric() || character == '_' || character == '-' {
        return true;
    }
    let mut buffer = [0; 4];
    mark_regex().is_match(character.encode_utf8(&mut buffer))
}

fn clamp_boundary(value: &str, mut byte_index: usize) -> usize {
    byte_index = byte_index.min(value.len());
    while byte_index > 0 && !value.is_char_boundary(byte_index) {
        byte_index -= 1;
    }
    byte_index
}

pub fn range(line: &str, cursor_col: usize, include_suffix: bool) -> (usize, usize) {
    let cursor_col = clamp_boundary(line, cursor_col);
    let mut start = cursor_col;
    for (index, character) in line[..cursor_col].char_indices().rev() {
        if !is_keyword(character) {
            break;
        }
        start = index;
    }

    let mut end = cursor_col;
    if include_suffix {
        for (index, character) in line[cursor_col..].char_indices() {
            if !is_keyword(character) {
                break;
            }
            end = cursor_col + index + character.len_utf8();
        }
    }

    (start, end)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/cmp/keyword_test.rs"
    ));
}
