use crate::types::{ISearchInLinesRegexLineMatch, ISearchInLinesRegexMatchPoint};
use regex::Regex;

/// Find the line number for a given byte position using binary search
/// Returns (line_number, line_start_position)
fn find_line_for_position(line_offsets: &[usize], position: usize) -> (usize, usize) {
    match line_offsets.binary_search(&position) {
        Ok(idx) => (idx + 1, line_offsets[idx]),
        Err(idx) => {
            if idx == 0 {
                (1, 0)
            } else {
                (idx, line_offsets[idx - 1])
            }
        }
    }
}

/// Build line offset table for efficient line number lookups
fn build_line_offsets(lines: &[impl AsRef<str>]) -> Vec<usize> {
    let mut offsets = Vec::with_capacity(lines.len() + 1);
    offsets.push(0); // First line always starts at position 0

    let mut current_pos = 0;
    for line in lines {
        current_pos += line.as_ref().len() + 1; // +1 for newline
        offsets.push(current_pos);
    }

    offsets
}

/// Search for regex pattern matches
pub fn search_in_lines_regex(
    pattern: &str,
    lines_vec: &[String],
    flag_case_sensitive: bool,
) -> Result<Vec<ISearchInLinesRegexLineMatch>, String> {
    let score_exact: u32 = 100;
    let mut matches: Vec<ISearchInLinesRegexLineMatch> = vec![];

    let regex_pattern = if flag_case_sensitive {
        format!("(?-i)(?s){}", pattern)
    } else {
        format!("(?i)(?s){}", pattern)
    };
    let regex = Regex::new(&regex_pattern);
    match regex {
        Ok(regex) => {
            // Smart pattern detection: check if pattern contains newlines
            let is_multiline_pattern = pattern.contains('\n');

            if is_multiline_pattern {
                // For multiline patterns, use full text approach with optimized line lookup
                let full_text = lines_vec.join("\n");
                let line_offsets = build_line_offsets(lines_vec);

                for mat in regex.find_iter(&full_text) {
                    let start_pos = mat.start();
                    let end_pos = mat.end();

                    // Use binary search to find line number - O(log n) instead of O(n)
                    let (line_num, line_start_pos) =
                        find_line_for_position(&line_offsets, start_pos);

                    let relative_start = start_pos - line_start_pos;
                    let relative_end = end_pos - line_start_pos;

                    matches.push(ISearchInLinesRegexLineMatch {
                        lnum: line_num,
                        score: score_exact,
                        matches: vec![ISearchInLinesRegexMatchPoint {
                            start: relative_start,
                            end: relative_end,
                        }],
                    });
                }
            } else {
                // For single-line patterns, search line by line for better efficiency
                for (line_idx, line) in lines_vec.iter().enumerate() {
                    for mat in regex.find_iter(line) {
                        matches.push(ISearchInLinesRegexLineMatch {
                            lnum: line_idx + 1,
                            score: score_exact,
                            matches: vec![ISearchInLinesRegexMatchPoint {
                                start: mat.start(),
                                end: mat.end(),
                            }],
                        });
                    }
                }
            }
        }
        Err(e) => return Err(format!("Invalid regex pattern: {}", e)),
    };

    Ok(matches)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_regex_valid() {
        let lines = vec![
            "foo123".to_string(),
            "bar456".to_string(),
            "foo789".to_string(),
        ];
        let result = search_in_lines_regex(r"foo\d+", &lines, true).unwrap();
        assert_eq!(result.len(), 2);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 3);
    }

    #[test]
    fn test_search_regex_invalid_pattern() {
        let lines = vec!["foo123".to_string(), "bar456".to_string()];
        let result = search_in_lines_regex(r"foo(bar", &lines, true);
        // Invalid regex should return error
        assert!(result.is_err());
    }

    #[test]
    fn test_search_regex_unclosed_bracket() {
        let lines = vec!["test".to_string()];
        let result = search_in_lines_regex(r"[abc", &lines, true);
        // Invalid regex should return error
        assert!(result.is_err());
    }

    #[test]
    fn test_search_multiline_regex() {
        let lines = vec!["foo".to_string(), "bar".to_string(), "baz".to_string()];
        // Use actual newline in pattern
        let result = search_in_lines_regex("foo\nbar", &lines, true).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
    }

    #[test]
    fn test_search_regex_with_groups() {
        let lines = vec![
            "require('foo')".to_string(),
            "import 'bar'".to_string(),
        ];
        let pattern = "require\\(['\"](.+?)['\"]\\)";
        let result = search_in_lines_regex(pattern, &lines, true).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
    }

    #[test]
    fn test_search_regex_case_insensitive() {
        let lines = vec![
            "Hello World".to_string(),
            "hello world".to_string(),
            "HELLO WORLD".to_string(),
        ];
        let result = search_in_lines_regex("hello", &lines, false).unwrap();
        assert_eq!(result.len(), 3);
    }
}
