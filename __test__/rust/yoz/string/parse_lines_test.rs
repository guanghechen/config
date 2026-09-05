use super::parse_lines;

#[test]
fn t_parse_lines_with_widths() {
    let text = "foo\nbar\nbaz";
    let lines = parse_lines(text, Some(&[3, 3, 3]));
    assert_eq!(lines, vec!["foo", "bar", "baz"]);
}

#[test]
fn t_parse_lines_without_widths() {
    let text = "foo\nbar\nbaz";
    let lines = parse_lines(text, None);
    assert_eq!(lines, vec!["foo", "bar", "baz"]);
}

#[test]
fn t_parse_lines_with_widths_without_newlines() {
    let text = "abcdef";
    let lines = parse_lines(text, Some(&[2, 2, 2]));
    assert_eq!(lines, vec!["ab", "cd", "ef"]);
}

#[test]
fn t_parse_lines_with_crlf_widths() {
    let text = "foo\r\nbar";
    let lines = parse_lines(text, Some(&[3, 3]));
    assert_eq!(lines, vec!["foo", "bar"]);
}
