use super::*;

#[test]
fn t_search_empty_pattern() {
    let lines = vec!["some text".to_string()];
    let result = search_in_lines("", &lines, false, false, true).unwrap();
    assert!(result.matches.is_empty());
}

#[test]
fn t_search_literal_mode() {
    let lines = vec![
        "Hello World".to_string(),
        "hello world".to_string(),
        "HELLO WORLD".to_string(),
    ];
    let result = search_in_lines("Hello", &lines, false, false, true).unwrap();
    assert_eq!(result.matches.len(), 1);
    assert_eq!(result.matches[0].lx, 1);
}

#[test]
fn t_search_regex_mode() {
    let lines = vec![
        "foo123".to_string(),
        "bar456".to_string(),
        "foo789".to_string(),
    ];
    let result = search_in_lines(r"foo\d+", &lines, false, true, true).unwrap();
    assert_eq!(result.matches.len(), 2);
    assert_eq!(result.matches[0].lx, 1);
    assert_eq!(result.matches[1].lx, 3);
}

#[test]
fn t_search_fuzzy_mode() {
    let lines = vec!["hello world".to_string()];
    let result = search_in_lines("hw", &lines, true, false, false).unwrap();
    assert!(!result.matches.is_empty());
}

#[test]
fn t_search_case_insensitive() {
    let lines = vec![
        "Hello World".to_string(),
        "hello world".to_string(),
        "HELLO WORLD".to_string(),
    ];
    let result = search_in_lines("hello", &lines, false, false, false).unwrap();
    assert_eq!(result.matches.len(), 3);
}

#[test]
fn t_search_multiline_preview_metadata() {
    let lines = vec!["foo bar baz".to_string(), "qux quux".to_string()];

    let result =
        search_in_lines("bar baz\nqux", &lines, false, false, true).expect("search succeeds");
    assert_eq!(result.matches.len(), 1);

    let m = &result.matches[0];
    assert_eq!(m.lx, 1, "left line should equal first line");
    assert_eq!(m.ly, 2, "right line should equal second line");
    assert_eq!(m.cx, 4, "start column should align with 'bar'");
    assert_eq!(m.cy, 2, "end column should align with 'x'");
    assert_eq!(m.ox, 4, "absolute start offset should match sliced text");
    assert_eq!(m.oy, 14, "absolute end offset should match sliced text");
    assert_eq!(
        m.s, "foo bar baz↲qux quux",
        "preview should span both lines"
    );
    assert_eq!(m.sx, 4, "preview offset should reflect first match column");
    assert_eq!(m.sy, 16, "preview offset should reflect last match column");
}

#[test]
fn t_search_preview_single_line_trims_newlines() {
    let lines = vec!["alpha beta".to_string()];
    let result = search_in_lines("alpha", &lines, false, false, true).expect("search succeeds");
    assert_eq!(result.matches.len(), 1);
    let m = &result.matches[0];
    assert_eq!(m.s, "alpha beta");
}
