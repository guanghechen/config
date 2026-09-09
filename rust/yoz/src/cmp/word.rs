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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/cmp/word_test.rs"
    ));
}
