use crate::search::{search_in_lines_literal, search_in_lines_regex};
use crate::types::{ISearchInLinesLineMatch, ISearchInLinesMatchPoint};

/// Unified search function that combines literal and regex search
/// Converts from specific types to unified ISearchInLines types
pub fn search_in_lines(
    pattern: &str,
    lines: &[String],
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<Vec<ISearchInLinesLineMatch>, String> {
    if pattern.is_empty() {
        return Ok(vec![]);
    }

    if flag_regex {
        // Use regex search and convert types
        let regex_results = search_in_lines_regex(pattern, lines, flag_case_sensitive)?;

        Ok(regex_results
            .into_iter()
            .map(|regex_match| ISearchInLinesLineMatch {
                lnum: regex_match.lnum,
                score: regex_match.score,
                matches: regex_match
                    .matches
                    .into_iter()
                    .map(|regex_point| ISearchInLinesMatchPoint {
                        start: regex_point.start,
                        end: regex_point.end,
                    })
                    .collect(),
            })
            .collect())
    } else {
        // Use literal search and convert types
        let literal_results = search_in_lines_literal(pattern, lines, flag_fuzzy, flag_case_sensitive);

        Ok(literal_results
            .into_iter()
            .map(|literal_match| ISearchInLinesLineMatch {
                lnum: literal_match.lnum,
                score: literal_match.score,
                matches: literal_match
                    .matches
                    .into_iter()
                    .map(|literal_point| ISearchInLinesMatchPoint {
                        start: literal_point.start,
                        end: literal_point.end,
                    })
                    .collect(),
            })
            .collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_empty_pattern() {
        let lines = vec!["some text".to_string()];
        let result = search_in_lines("", &lines, false, false, true).unwrap();
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn test_search_literal_mode() {
        let lines = vec![
            "Hello World".to_string(),
            "hello world".to_string(),
            "HELLO WORLD".to_string(),
        ];
        let result = search_in_lines("Hello", &lines, false, false, true).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
    }

    #[test]
    fn test_search_regex_mode() {
        let lines = vec![
            "foo123".to_string(),
            "bar456".to_string(),
            "foo789".to_string(),
        ];
        let result = search_in_lines(r"foo\d+", &lines, false, true, true).unwrap();
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 3);
    }

    #[test]
    fn test_search_fuzzy_mode() {
        let lines = vec!["hello world".to_string()];
        let result = search_in_lines("hw", &lines, true, false, false).unwrap();
        assert!(result.len() > 0);
    }

    #[test]
    fn test_search_case_insensitive() {
        let lines = vec![
            "Hello World".to_string(),
            "hello world".to_string(),
            "HELLO WORLD".to_string(),
        ];
        let result = search_in_lines("hello", &lines, false, false, false).unwrap();
        assert_eq!(result.len(), 3);
    }
}
