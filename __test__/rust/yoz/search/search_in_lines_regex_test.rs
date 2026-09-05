use super::*;

fn buffer(lines: &[&str]) -> ISearchBuffer<'static> {
    let owned: Vec<String> = lines.iter().map(|line| (*line).to_string()).collect();
    ISearchBuffer::from_lines(&owned)
}

#[test]
fn t_search_regex_valid() {
    let buf = buffer(&["foo123", "bar456", "foo789"]);
    let result = search_in_lines_regex(r"foo\d+", &buf, true).unwrap();
    assert_eq!(result.len(), 2);
    assert_eq!(result[0].lnum, 1);
    assert_eq!(result[1].lnum, 3);
}

#[test]
fn t_search_regex_invalid_pattern() {
    let buf = buffer(&["foo123", "bar456"]);
    let result = search_in_lines_regex(r"foo(bar", &buf, true);
    assert!(result.is_err());
}

#[test]
fn t_search_regex_unclosed_bracket() {
    let buf = buffer(&["test"]);
    let result = search_in_lines_regex(r"[abc", &buf, true);
    assert!(result.is_err());
}

#[test]
fn t_search_multiline_regex() {
    let buf = buffer(&["foo", "bar", "baz"]);
    let result = search_in_lines_regex("foo\nbar", &buf, true).unwrap();
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].lnum, 1);
}

#[test]
fn t_search_regex_with_groups() {
    let buf = buffer(&["require('foo')", "import 'bar'"]);
    let pattern = "require\\(['\"](.+?)['\"]\\)";
    let result = search_in_lines_regex(pattern, &buf, true).unwrap();
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].lnum, 1);
}

#[test]
fn t_search_regex_case_insensitive() {
    let buf = buffer(&["Hello World", "hello world", "HELLO WORLD"]);
    let result = search_in_lines_regex("hello", &buf, false).unwrap();
    assert_eq!(result.len(), 3);
}
