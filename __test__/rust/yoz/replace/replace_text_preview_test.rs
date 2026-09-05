use super::*;

#[test]
fn t_replace_literal() {
    let text = "hello world, hello rust";
    let result = replace_text_preview(text, "hello", "hi", false, false, true).unwrap();
    assert_eq!(result, "hi world, hi rust");
}

#[test]
fn t_replace_literal_keep_search() {
    let text = "hello world";
    let result = replace_text_preview(text, "hello", " hi", true, false, true).unwrap();
    assert_eq!(result, "hello hi world");
}

#[test]
fn t_replace_regex_valid() {
    let text = "foo123 bar456";
    let result = replace_text_preview(text, r"\d+", "XXX", false, true, true).unwrap();
    assert_eq!(result, "fooXXX barXXX");
}

#[test]
fn t_replace_regex_with_capture_groups() {
    let text = r#"require("foo")"#;
    let result = replace_text_preview(
        text,
        r#"require\("(.+?)"\)"#,
        "import $1",
        false,
        true,
        true,
    )
    .unwrap();
    assert_eq!(result, "import foo");
}

#[test]
fn t_replace_regex_invalid_pattern() {
    let text = "test";
    let result = replace_text_preview(text, r"(unclosed", "replacement", false, true, true);
    // Invalid regex should return original text, not error
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "test");
}

#[test]
fn t_replace_case_insensitive() {
    let text = "Hello HELLO hello";
    let result = replace_text_preview(text, "hello", "hi", false, false, false).unwrap();
    assert_eq!(result, "hi hi hi");
}

#[test]
fn t_replace_case_sensitive() {
    let text = "Hello hello HELLO";
    let result = replace_text_preview(text, "hello", "hi", false, false, true).unwrap();
    assert_eq!(result, "Hello hi HELLO");
}

#[test]
fn t_replace_no_match() {
    let text = "foo bar";
    let result = replace_text_preview(text, "baz", "qux", false, false, true).unwrap();
    assert_eq!(result, "foo bar");
}

#[test]
fn t_replace_empty_pattern() {
    let text = "test";
    let result = replace_text_preview(text, "", "X", false, false, true).unwrap();
    // Empty pattern should not match anything
    assert_eq!(result, "test");
}

#[test]
fn t_replace_regex_multiple_groups() {
    let text = "2024-01-15";
    let result = replace_text_preview(
        text,
        r"(\d{4})-(\d{2})-(\d{2})",
        "$2/$3/$1",
        false,
        true,
        true,
    )
    .unwrap();
    assert_eq!(result, "01/15/2024");
}
