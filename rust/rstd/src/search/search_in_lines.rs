use super::ISearchBuffer;
use super::search_in_lines_literal::search_in_lines_literal;
use super::search_in_lines_regex::search_in_lines_regex;
use super::text_utils::build_preview_string;
use super::text_utils::locate_line;
use crate::types::ISearchInLinesLineMatch;
use crate::types::ISearchInLinesMatchPoint;
use crate::types::ISearchTextResult;
use crate::types::ITextMatch;
use std::time::Instant;

/// Unified search function that combines literal and regex search
/// Converts from specific types to unified ISearchInLines types
pub fn search_in_lines(
    pattern: &str,
    lines: &[String],
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<ISearchTextResult, String> {
    let buffer = ISearchBuffer::from_lines(lines);
    search_in_lines_buffer(
        pattern,
        &buffer,
        flag_fuzzy,
        flag_regex,
        flag_case_sensitive,
    )
}

pub(crate) fn search_in_lines_buffer(
    pattern: &str,
    buffer: &ISearchBuffer,
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<ISearchTextResult, String> {
    let start = Instant::now();

    if pattern.is_empty() {
        return Ok(ISearchTextResult {
            elapsed_time: 0,
            matches: Vec::new(),
            lines: Vec::new(),
        });
    }

    let raw_line_matches = if flag_regex {
        search_in_lines_regex(pattern, buffer, flag_case_sensitive)?
    } else {
        search_in_lines_literal(pattern, buffer, flag_fuzzy, flag_case_sensitive)
    };

    let line_matches: Vec<ISearchInLinesLineMatch> = raw_line_matches
        .into_iter()
        .map(|matched_line| ISearchInLinesLineMatch {
            lnum: matched_line.lnum,
            score: matched_line.score,
            matches: matched_line
                .matches
                .into_iter()
                .map(|point| ISearchInLinesMatchPoint {
                    start: point.start,
                    end: point.end,
                })
                .collect(),
        })
        .collect();

    let matches = convert_line_matches(buffer, &line_matches);

    Ok(ISearchTextResult {
        elapsed_time: start.elapsed().as_millis() as u64,
        matches,
        lines: line_matches,
    })
}

fn convert_line_matches(
    buffer: &ISearchBuffer,
    line_matches: &[ISearchInLinesLineMatch],
) -> Vec<ITextMatch> {
    if buffer.line_count() == 0 || line_matches.is_empty() {
        return Vec::new();
    }

    let line_offsets = buffer.line_offsets();
    if line_offsets.len() < 2 {
        return Vec::new();
    }
    let bytes = buffer.as_bytes();
    let mut matches = Vec::new();

    for line_match in line_matches {
        let line_number = line_match.lnum;
        if line_number == 0 || (line_number as usize) > buffer.line_count() {
            continue;
        }
        let line_start_abs = line_offsets[line_number - 1];

        for point in &line_match.matches {
            let start_abs = line_start_abs.saturating_add(point.start);
            let end_abs_exclusive = line_start_abs.saturating_add(point.end);
            if start_abs >= end_abs_exclusive || start_abs >= bytes.len() {
                continue;
            }
            let end_abs_exclusive = std::cmp::min(end_abs_exclusive, bytes.len());
            if end_abs_exclusive == 0 || end_abs_exclusive <= start_abs {
                continue;
            }
            let end_abs_inclusive = end_abs_exclusive - 1;

            let start_line = locate_line(&line_offsets, start_abs);
            let end_line = locate_line(&line_offsets, end_abs_inclusive);

            let line_start = line_offsets[start_line - 1];
            let line_end_exclusive = line_offsets[end_line];

            let same_line = start_line == end_line;
            let line_content_end = if same_line {
                buffer.line_content_end(start_line)
            } else {
                line_end_exclusive
            };

            let preview_start_abs = std::cmp::max(line_start, start_abs.saturating_sub(64));
            let preview_line_limit = if same_line && end_abs_exclusive <= line_content_end {
                line_content_end
            } else {
                line_end_exclusive
            };
            let preview_end_abs_exclusive =
                std::cmp::min(preview_line_limit, end_abs_exclusive.saturating_add(64));

            if preview_end_abs_exclusive <= preview_start_abs
                || preview_end_abs_exclusive > bytes.len()
            {
                continue;
            }

            let preview_bytes = &bytes[preview_start_abs..preview_end_abs_exclusive];
            let start_rel = start_abs - preview_start_abs;
            let end_rel = end_abs_inclusive - preview_start_abs;

            let (preview_string, sx, sy) = build_preview_string(preview_bytes, start_rel, end_rel);

            let lx = u32::try_from(start_line).unwrap_or(u32::MAX);
            let ly = u32::try_from(end_line).unwrap_or(u32::MAX);

            let cx = u32::try_from(start_abs - line_offsets[start_line - 1]).unwrap_or(u32::MAX);
            let cy =
                u32::try_from(end_abs_inclusive - line_offsets[end_line - 1]).unwrap_or(u32::MAX);

            matches.push(ITextMatch {
                lx,
                ly,
                cx,
                cy,
                ox: start_abs,
                oy: end_abs_inclusive,
                s: preview_string,
                sx,
                sy,
            });
        }
    }

    matches
}

#[cfg(test)]
mod tests {
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
}
