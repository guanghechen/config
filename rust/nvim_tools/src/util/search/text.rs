use crate::types::dto::LineMatch;
use crate::types::dto::MatchPoint;
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
) -> Result<Vec<LineMatch>, String> {
    let score_exact: u32 = 100;
    let mut matches: Vec<LineMatch> = vec![];

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

                    matches.push(LineMatch {
                        lnum: line_num,
                        score: score_exact,
                        matches: vec![MatchPoint {
                            start: relative_start,
                            end: relative_end,
                        }],
                    });
                }
            } else {
                // For single-line patterns, search line by line for better efficiency
                for (line_idx, line) in lines_vec.iter().enumerate() {
                    for mat in regex.find_iter(line) {
                        matches.push(LineMatch {
                            lnum: line_idx + 1,
                            score: score_exact,
                            matches: vec![MatchPoint {
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
    if pattern.is_empty() {
        return Ok(vec![]);
    }

    // Convert lines to vector to enable reuse and efficient indexing
    let lines_vec: Vec<String> = lines.into_iter().map(|s| s.as_ref().to_string()).collect();

    if flag_regex {
        search_in_lines_regex(pattern, &lines_vec, flag_case_sensitive)
    } else {
        // Use rstd's search_in_lines_literal and convert types
        let rstd_results = rstd::search::search_in_lines_literal(
            pattern,
            &lines_vec,
            flag_fuzzy,
            flag_case_sensitive,
        );

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
