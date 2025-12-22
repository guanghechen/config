use super::ISearchBuffer;
use super::text_utils::locate_line;
use crate::algorithm::kmp::calc_fails;
use crate::algorithm::kmp::find_all_matched_points;
use crate::types::ISearchInLinesLiteralLineMatch;
use crate::types::ISearchInLinesLiteralMatchPoint;
use std::borrow::Cow;

pub fn search_in_lines_literal(
    pattern: &str,
    buffer: &ISearchBuffer,
    flag_fuzzy: bool,
    flag_case_sensitive: bool,
) -> Vec<ISearchInLinesLiteralLineMatch> {
    let score_exact: u32 = 100;
    let score_scalar: u32 = 30;
    let score_exact_bonus: f64 = 30.0;
    let score_scalar_bonus: f64 = 30.0;

    let pattern_str = if flag_case_sensitive {
        pattern.to_string()
    } else {
        pattern.to_lowercase()
    };
    let pattern_bytes = pattern_str.as_bytes();
    let pattern_chars = pattern_str.chars().collect::<Vec<char>>();
    let n_pattern_bytes: usize = pattern_bytes.len();
    let n_pattern_chars: usize = pattern_chars.len();
    if n_pattern_bytes == 0 {
        return Vec::new();
    }

    let mut fails: Vec<usize> = vec![0; n_pattern_bytes + 1];
    calc_fails(pattern_bytes, &mut fails);

    let is_multiline_pattern = pattern.contains('\n');

    if is_multiline_pattern {
        return search_multiline(
            buffer,
            pattern_bytes,
            n_pattern_bytes,
            &fails,
            score_exact,
            flag_case_sensitive,
        );
    }

    search_single_line(
        buffer,
        pattern_bytes,
        &pattern_chars,
        n_pattern_bytes,
        n_pattern_chars,
        &fails,
        score_exact,
        score_scalar,
        score_exact_bonus,
        score_scalar_bonus,
        flag_fuzzy,
        flag_case_sensitive,
    )
}

fn search_multiline(
    buffer: &ISearchBuffer,
    pattern_bytes: &[u8],
    n_pattern_bytes: usize,
    fails: &Vec<usize>,
    score_exact: u32,
    flag_case_sensitive: bool,
) -> Vec<ISearchInLinesLiteralLineMatch> {
    let line_offsets = buffer.line_offsets();
    if line_offsets.len() < 2 {
        return Vec::new();
    }

    let search_text: Cow<'_, str> = if flag_case_sensitive {
        Cow::Borrowed(buffer.as_str())
    } else {
        Cow::Owned(buffer.as_str().to_lowercase())
    };

    let mut matches: Vec<ISearchInLinesLiteralLineMatch> = Vec::new();
    let points = find_all_matched_points(search_text.as_bytes(), pattern_bytes, Some(fails));
    for start_pos in points {
        let end_pos = start_pos + n_pattern_bytes;
        let line_num = locate_line(line_offsets, start_pos);
        if line_num == 0 || line_num > buffer.line_count() {
            continue;
        }

        let line_index = line_num - 1;
        let line_start_pos = line_offsets[line_index];
        let relative_start = start_pos.saturating_sub(line_start_pos);
        let relative_end = end_pos.saturating_sub(line_start_pos);

        matches.push(ISearchInLinesLiteralLineMatch {
            lnum: line_num,
            score: score_exact,
            matches: vec![ISearchInLinesLiteralMatchPoint {
                start: relative_start,
                end: relative_end,
            }],
        });
    }

    matches
}

#[allow(clippy::too_many_arguments)]
fn search_single_line(
    buffer: &ISearchBuffer,
    pattern_bytes: &[u8],
    pattern_chars: &[char],
    n_pattern_bytes: usize,
    n_pattern_chars: usize,
    fails: &Vec<usize>,
    score_exact: u32,
    score_scalar: u32,
    score_exact_bonus: f64,
    score_scalar_bonus: f64,
    flag_fuzzy: bool,
    flag_case_sensitive: bool,
) -> Vec<ISearchInLinesLiteralLineMatch> {
    let mut matches: Vec<ISearchInLinesLiteralLineMatch> = Vec::new();

    for (line_idx, line) in buffer.iter_lines().enumerate() {
        let line_view: Cow<'_, str> = if flag_case_sensitive {
            Cow::Borrowed(line)
        } else {
            Cow::Owned(line.to_lowercase())
        };
        let line_bytes = line_view.as_bytes();
        let base: f64 = line.len() as f64;

        let points = find_all_matched_points(line_bytes, pattern_bytes, Some(fails));
        if !points.is_empty() {
            for start_pos in points {
                let end_pos = start_pos + n_pattern_bytes;
                let delta: f64 = end_pos as f64;
                let bonus: u32 = if base <= f64::EPSILON {
                    0
                } else {
                    ((delta / base) * score_exact_bonus).round() as u32
                };
                let score = score_exact + bonus;

                matches.push(ISearchInLinesLiteralLineMatch {
                    lnum: line_idx + 1,
                    score,
                    matches: vec![ISearchInLinesLiteralMatchPoint {
                        start: start_pos,
                        end: end_pos,
                    }],
                });
            }
            continue;
        }

        if !flag_fuzzy {
            continue;
        }

        if let Some(fuzzy_match) = fuzzy_match_line(
            &line_view,
            pattern_chars,
            n_pattern_chars,
            score_scalar,
            score_scalar_bonus,
            flag_case_sensitive,
        ) {
            matches.push(ISearchInLinesLiteralLineMatch {
                lnum: line_idx + 1,
                score: fuzzy_match.0,
                matches: fuzzy_match.1,
            });
        }
    }

    matches
}

fn fuzzy_match_line(
    line_view: &str,
    pattern_chars: &[char],
    n_pattern_chars: usize,
    score_scalar: u32,
    score_scalar_bonus: f64,
    case_sensitive: bool,
) -> Option<(u32, Vec<ISearchInLinesLiteralMatchPoint>)> {
    if line_view.is_empty() || n_pattern_chars == 0 {
        return None;
    }

    let line_chars = line_view.chars().collect::<Vec<char>>();
    let n_line_chars = line_chars.len();
    if n_line_chars < n_pattern_chars {
        return None;
    }

    let mut score: u32 = 0;
    let mut all_pattern_matches: Vec<ISearchInLinesLiteralMatchPoint> = Vec::new();
    let mut last_ti: usize = 0;
    let mut len: usize = 0;
    let mut pi: usize = 0;

    for ti in 0..n_line_chars {
        let c: char = line_chars[ti];
        if c != pattern_chars[pi] {
            continue;
        }

        pi += 1;
        if pi != n_pattern_chars {
            continue;
        }

        pi = 0;
        let mut pattern_matches: Vec<ISearchInLinesLiteralMatchPoint> = {
            let mut i: usize = ti;
            let mut last_piece = ISearchInLinesLiteralMatchPoint {
                start: ti,
                end: ti + 1,
            };
            let mut pieces: Vec<ISearchInLinesLiteralMatchPoint> = Vec::new();
            for j in (0..n_pattern_chars).rev() {
                while i > 0 && line_chars[i] != pattern_chars[j] {
                    i -= 1;
                }

                if i + 1 == last_piece.start {
                    last_piece.start = i;
                } else {
                    pieces.push(last_piece);
                    last_piece = ISearchInLinesLiteralMatchPoint {
                        start: i,
                        end: i + 1,
                    };
                }

                if i == 0 {
                    break;
                }
                i -= 1;
            }
            pieces.push(last_piece);
            pieces.reverse();
            pieces
        };

        let mut i: usize = last_ti;
        last_ti = ti;
        let mut max_weight: usize = 0;
        let mut heuristic_bonus: i32 = 0;
        let mut prev_end: Option<usize> = None;

        for piece in &mut pattern_matches {
            let length = piece.end - piece.start;
            max_weight = max_weight.max(length);

            if length > 1 {
                heuristic_bonus += 50 * (length as i32);
            }

            let start_char_index = piece.start;
            if start_char_index == 0 {
                heuristic_bonus += 120;
            } else if is_boundary(
                line_chars[start_char_index - 1],
                line_chars[start_char_index],
                case_sensitive,
            ) {
                heuristic_bonus += 90;
            }

            if let Some(prev) = prev_end {
                let gap = piece.start.saturating_sub(prev);
                if gap > 1 {
                    heuristic_bonus -= (gap as i32) * 15;
                }
            }
            prev_end = Some(piece.end);

            while i < piece.start {
                len += line_chars[i].len_utf8();
                i += 1;
            }
            piece.start = len;

            while i < piece.end {
                len += line_chars[i].len_utf8();
                i += 1;
            }
            piece.end = len;
        }

        all_pattern_matches.extend(pattern_matches);

        let bonus: u32 =
            (max_weight as f64 / n_pattern_chars as f64 * score_scalar_bonus).round() as u32;
        let adjusted = heuristic_bonus.max(0) as u32;
        score = score.saturating_add(score_scalar + bonus + adjusted);
    }

    if score == 0 {
        return None;
    }

    Some((score, all_pattern_matches))
}

fn is_boundary(prev: char, current: char, case_sensitive: bool) -> bool {
    if !prev.is_alphanumeric() && current.is_alphanumeric() {
        return true;
    }
    if case_sensitive {
        prev.is_lowercase() && current.is_uppercase()
    } else {
        prev == '_' || prev == '-' || prev == ' '
    }
}

#[cfg(test)]
mod tests {
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
}
