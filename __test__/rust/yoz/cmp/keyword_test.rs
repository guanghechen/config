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
