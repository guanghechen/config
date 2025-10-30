use crate::types::dto::LineMatch;
use crate::types::dto::MatchPoint;

pub fn search_in_lines<I, S>(
    pattern: &str,
    lines: I,
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<Vec<LineMatch>, String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<str>,
{
    // Convert lines to vector
    let lines_vec: Vec<String> = lines.into_iter().map(|s| s.as_ref().to_string()).collect();

    // Use rstd's search_in_lines and convert types
    let rstd_results = rstd::search::search_in_lines(
        pattern,
        &lines_vec,
        flag_fuzzy,
        flag_regex,
        flag_case_sensitive,
    )?;

    Ok(rstd_results
        .into_iter()
        .map(|rstd_match| LineMatch {
            lnum: rstd_match.lnum,
            score: rstd_match.score,
            matches: rstd_match
                .matches
                .into_iter()
                .map(|rstd_point| MatchPoint {
                    start: rstd_point.start,
                    end: rstd_point.end,
                })
                .collect(),
        })
        .collect())
}

pub fn search_in_text(
    pattern: &str,
    text: &str,
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<Vec<LineMatch>, String> {
    search_in_lines(
        pattern,
        text.lines(),
        flag_fuzzy,
        flag_regex,
        flag_case_sensitive,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_literal_case_sensitive() {
        let text = "Hello World\nhello world\nHELLO WORLD";
        let result = search_in_text("Hello", text, false, false, true).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[0].matches[0].start, 0);
        assert_eq!(result[0].matches[0].end, 5);
    }

    #[test]
    fn test_search_literal_case_insensitive() {
        let text = "Hello World\nhello world\nHELLO WORLD";
        let result = search_in_text("hello", text, false, false, false).unwrap();
        assert_eq!(result.len(), 3);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 2);
        assert_eq!(result[2].lnum, 3);
    }

    #[test]
    fn test_search_regex_valid() {
        let text = "foo123\nbar456\nfoo789";
        let result = search_in_text(r"foo\d+", text, false, true, true).unwrap();
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 3);
    }

    #[test]
    fn test_search_regex_invalid_pattern() {
        let text = "foo123\nbar456";
        let result = search_in_text(r"foo(bar", text, false, true, true);
        // Invalid regex should return error
        assert!(result.is_err());
    }

    #[test]
    fn test_search_regex_unclosed_bracket() {
        let text = "test";
        let result = search_in_text(r"[abc", text, false, true, true);
        // Invalid regex should return error
        assert!(result.is_err());
    }

    #[test]
    fn test_search_empty_pattern() {
        let text = "some text";
        let result = search_in_text("", text, false, false, true).unwrap();
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn test_search_multiline_literal() {
        let text = "line1\nline2\nline3";
        let result = search_in_text("line1\nline2", text, false, false, true).unwrap();
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn test_search_multiline_regex() {
        let text = "foo\nbar\nbaz";
        // Use actual newline in pattern, not regex escape sequence
        let result = search_in_text("foo\nbar", text, false, true, true).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
    }

    #[test]
    fn test_search_fuzzy_match() {
        let text = "hello world";
        let result = search_in_text("hw", text, true, false, false).unwrap();
        assert!(result.len() > 0);
    }

    #[test]
    fn test_search_multiple_matches_same_line() {
        let text = "foo bar foo baz foo";
        let result = search_in_text("foo", text, false, false, true).unwrap();
        assert_eq!(result.len(), 3);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 1);
        assert_eq!(result[2].lnum, 1);
    }

    #[test]
    fn test_search_regex_with_groups() {
        let text = "require('foo')\nimport 'bar'";
        let pattern = "require\\(['\"](.+?)['\"]\\)";
        let result = search_in_text(pattern, text, false, true, true).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
    }
}
