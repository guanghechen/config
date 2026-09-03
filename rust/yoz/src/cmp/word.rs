use regex::Regex;
use std::collections::HashSet;
use std::sync::OnceLock;

fn regex() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| Regex::new(r"[\p{L}\p{N}_][\p{L}\p{M}\p{N}_\-]{1,}").unwrap())
}

fn collect_ascii(text: &str, limit: usize) -> Vec<String> {
    let bytes = text.as_bytes();
    let mut seen = HashSet::new();
    let mut words = Vec::new();
    let mut index = 0;
    while index < bytes.len() {
        while index < bytes.len() && !bytes[index].is_ascii_alphanumeric() && bytes[index] != b'_' {
            index += 1;
        }
        let start = index;
        while index < bytes.len()
            && (bytes[index].is_ascii_alphanumeric()
                || bytes[index] == b'_'
                || bytes[index] == b'-')
        {
            index += 1;
        }
        let word = &text[start..index];
        if word.len() >= 2 && word.len() < 512 && seen.insert(word) {
            words.push(word.to_owned());
            if words.len() >= limit {
                break;
            }
        }
    }
    words
}

pub fn collect(text: &str, limit: usize) -> Vec<String> {
    if text.is_ascii() {
        return collect_ascii(text, limit);
    }

    let mut seen = HashSet::new();
    let mut words = Vec::new();
    for matched in regex().find_iter(text) {
        let word = matched.as_str();
        if word.len() >= 512 || !seen.insert(word) {
            continue;
        }
        words.push(word.to_owned());
        if words.len() >= limit {
            break;
        }
    }
    words
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_collects_unicode_words_in_source_order() {
        assert_eq!(
            collect("hello 你好世界 hello completion_item", 10),
            vec!["hello", "你好世界", "completion_item"]
        );
    }

    #[test]
    fn t_observes_the_limit() {
        assert_eq!(collect("one two three", 2), vec!["one", "two"]);
    }

    #[test]
    fn t_keeps_combining_marks_inside_words() {
        assert_eq!(collect("cafe\u{301}Value", 10), vec!["cafe\u{301}Value"]);
    }

    #[test]
    fn t_ascii_fast_path_matches_word_contract() {
        assert_eq!(
            collect("a alpha-beta _id -ignored 42 alpha-beta", 10),
            vec!["alpha-beta", "_id", "ignored", "42"]
        );
    }
}
