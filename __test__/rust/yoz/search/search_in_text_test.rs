use super::*;

#[test]
fn t_search_literal_case_sensitive() {
    let text = "Hello World\nhello world\nHELLO WORLD";
    let result = search_in_text("Hello", text, false, false, true).unwrap();
    assert_eq!(result.matches.len(), 1);
    assert_eq!(result.matches[0].lx, 1);
    assert_eq!(result.matches[0].cx, 0);
    assert_eq!(result.matches[0].cy, 4);
}

#[test]
fn t_search_literal_case_insensitive() {
    let text = "Hello World\nhello world\nHELLO WORLD";
    let result = search_in_text("hello", text, false, false, false).unwrap();
    assert_eq!(result.matches.len(), 3);
    assert_eq!(result.matches[0].lx, 1);
    assert_eq!(result.matches[1].lx, 2);
    assert_eq!(result.matches[2].lx, 3);
}

#[test]
fn t_search_regex_valid() {
    let text = "foo123\nbar456\nfoo789";
    let result = search_in_text(r"foo\d+", text, false, true, true).unwrap();
    assert_eq!(result.matches.len(), 2);
    assert_eq!(result.matches[0].lx, 1);
    assert_eq!(result.matches[1].lx, 3);
}

#[test]
fn t_search_regex_invalid_pattern() {
    let text = "foo123\nbar456";
    let result = search_in_text(r"foo(bar", text, false, true, true);
    assert!(result.is_err());
}

#[test]
fn t_search_regex_unclosed_bracket() {
    let text = "test";
    let result = search_in_text(r"[abc", text, false, true, true);
    assert!(result.is_err());
}

#[test]
fn t_search_empty_pattern() {
    let text = "some text";
    let result = search_in_text("", text, false, false, true).unwrap();
    assert!(result.matches.is_empty());
}

#[test]
fn t_search_multiline_literal() {
    let text = "line1\nline2\nline3";
    let result = search_in_text("line1\nline2", text, false, false, true).unwrap();
    assert_eq!(result.matches.len(), 1);
}

#[test]
fn t_search_multiline_regex() {
    let text = "foo\nbar\nbaz";
    let result = search_in_text("foo\nbar", text, false, true, true).unwrap();
    assert_eq!(result.matches.len(), 1);
    assert_eq!(result.matches[0].lx, 1);
}

#[test]
fn t_search_fuzzy_match() {
    let text = "hello world";
    let result = search_in_text("hw", text, true, false, false).unwrap();
    assert!(!result.matches.is_empty());
}

#[test]
fn t_search_multiple_matches_same_line() {
    let text = "foo bar foo baz foo";
    let result = search_in_text("foo", text, false, false, true).unwrap();
    assert_eq!(result.matches.len(), 3);
    assert_eq!(result.matches[0].lx, 1);
    assert_eq!(result.matches[1].lx, 1);
    assert_eq!(result.matches[2].lx, 1);
}

#[test]
fn t_search_regex_with_groups() {
    let text = "require('foo')\nimport 'bar'";
    let pattern = "require\\(['\"](.+?)['\"]\\)";
    let result = search_in_text(pattern, text, false, true, true).unwrap();
    assert_eq!(result.matches.len(), 1);
    assert_eq!(result.matches[0].lx, 1);
}

#[test]
fn t_search_preview_metadata() {
    let text = "foo bar baz\nqux quux";
    let result = search_in_text("bar baz\nqux", text, false, false, true).unwrap();

    assert_eq!(result.matches.len(), 1);
    let m = &result.matches[0];
    assert_eq!(m.lx, 1);
    assert_eq!(m.ly, 2);
    assert_eq!(m.cx, 4);
    assert_eq!(m.cy, 2);
    assert_eq!(m.ox, 4);
    assert_eq!(m.oy, 14);
    assert_eq!(m.s, "foo bar baz↲qux quux");
    assert_eq!(m.sx, 4);
    assert_eq!(m.sy, 16);
}
