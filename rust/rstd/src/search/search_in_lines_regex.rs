use super::ISearchBuffer;
use super::text_utils::locate_line;
use crate::types::ISearchInLinesRegexLineMatch;
use crate::types::ISearchInLinesRegexMatchPoint;
use regex::Regex;

pub fn search_in_lines_regex(
    pattern: &str,
    buffer: &ISearchBuffer,
    flag_case_sensitive: bool,
) -> Result<Vec<ISearchInLinesRegexLineMatch>, String> {
    let score_exact: u32 = 100;
    let mut matches: Vec<ISearchInLinesRegexLineMatch> = Vec::new();

    let regex_pattern = if flag_case_sensitive {
        format!("(?-i)(?s){}", pattern)
    } else {
        format!("(?i)(?s){}", pattern)
    };

    let regex =
        Regex::new(&regex_pattern).map_err(|error| format!("Invalid regex pattern: {}", error))?;
    let is_multiline_pattern = pattern.contains('\n');

    if is_multiline_pattern {
        let line_offsets = buffer.line_offsets();
        if line_offsets.len() < 2 {
            return Ok(matches);
        }

        for mat in regex.find_iter(buffer.as_str()) {
            let start_pos = mat.start();
            let end_pos = mat.end();
            let line_num = locate_line(line_offsets, start_pos);
            if line_num == 0 || (line_num as usize) > buffer.line_count() {
                continue;
            }

            let line_index = (line_num - 1) as usize;
            let line_start_pos = line_offsets[line_index];
            let relative_start = start_pos.saturating_sub(line_start_pos);
            let relative_end = end_pos.saturating_sub(line_start_pos);

            matches.push(ISearchInLinesRegexLineMatch {
                lnum: line_num,
                score: score_exact,
                matches: vec![ISearchInLinesRegexMatchPoint {
                    start: relative_start,
                    end: relative_end,
                }],
            });
        }

        return Ok(matches);
    }

    for (line_idx, line) in buffer.iter_lines().enumerate() {
        let mut line_matches: Vec<ISearchInLinesRegexMatchPoint> = Vec::new();
        for mat in regex.find_iter(line) {
            line_matches.push(ISearchInLinesRegexMatchPoint {
                start: mat.start(),
                end: mat.end(),
            });
        }

        if line_matches.is_empty() {
            continue;
        }

        matches.push(ISearchInLinesRegexLineMatch {
            lnum: line_idx + 1,
            score: score_exact,
            matches: line_matches,
        });
    }

    Ok(matches)
}

#[cfg(test)]
mod tests {
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
}
