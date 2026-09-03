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
    use super::*;

    #[test]
    fn t_resolves_prefix_and_full_ranges() {
        assert_eq!(range("hello-world", 8, false), (0, 8));
        assert_eq!(range("hello-world", 8, true), (0, 11));
    }

    #[test]
    fn t_keeps_unicode_boundaries() {
        let line = "你好-world";
        assert_eq!(range(line, "你好-w".len(), false), (0, "你好-w".len()));
    }

    #[test]
    fn t_keeps_combining_marks_inside_words() {
        let word = "cafe\u{301}";
        let line = format!("{word}' ./child");
        assert_eq!(range(&line, word.len(), false), (0, word.len()));
    }
}
