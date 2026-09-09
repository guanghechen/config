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
