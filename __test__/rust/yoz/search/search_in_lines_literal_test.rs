use super::*;

fn buffer(lines: &[&str]) -> ISearchBuffer<'static> {
    let owned: Vec<String> = lines.iter().map(|line| (*line).to_string()).collect();
    ISearchBuffer::from_lines(&owned)
}

#[test]
fn t_search_literal_case_sensitive() {
    let buf = buffer(&["Hello World", "hello world", "HELLO WORLD"]);
    let result = search_in_lines_literal("Hello", &buf, false, true);
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].lnum, 1);
    assert_eq!(result[0].matches[0].start, 0);
    assert_eq!(result[0].matches[0].end, 5);
}

#[test]
fn t_search_literal_case_insensitive() {
    let buf = buffer(&["Hello World", "hello world", "HELLO WORLD"]);
    let result = search_in_lines_literal("hello", &buf, false, false);
    assert_eq!(result.len(), 3);
    assert_eq!(result[0].lnum, 1);
    assert_eq!(result[1].lnum, 2);
    assert_eq!(result[2].lnum, 3);
}

#[test]
fn t_search_multiline_literal() {
    let buf = buffer(&["line1", "line2", "line3"]);
    let result = search_in_lines_literal("line1\nline2", &buf, false, true);
    assert_eq!(result.len(), 1);
}

#[test]
fn t_search_fuzzy_match() {
    let buf = buffer(&["hello world"]);
    let result = search_in_lines_literal("hw", &buf, true, false);
    assert!(!result.is_empty());
}

#[test]
fn t_search_multiple_matches_same_line() {
    let buf = buffer(&["foo bar foo baz foo"]);
    let result = search_in_lines_literal("foo", &buf, false, true);
    assert_eq!(result.len(), 3);
    assert_eq!(result[0].lnum, 1);
    assert_eq!(result[1].lnum, 1);
    assert_eq!(result[2].lnum, 1);
}
