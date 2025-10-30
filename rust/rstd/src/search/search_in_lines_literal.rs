use crate::algorithm::kmp::{calc_fails, find_all_matched_points};
use crate::types::{ISearchInLinesLiteralLineMatch, ISearchInLinesLiteralMatchPoint};

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

/// Search for literal text matches (non-regex) using KMP algorithm
pub fn search_in_lines_literal(
    pattern: &str,
    lines_vec: &[String],
    flag_fuzzy: bool,
    flag_case_sensitive: bool,
) -> Vec<ISearchInLinesLiteralLineMatch> {
    let score_exact: u32 = 100;
    let score_scalar: u32 = 30;
    let score_exact_bonus: f64 = 30.0;
    let score_scalar_bonus: f64 = 30.0;
    let mut matches: Vec<ISearchInLinesLiteralLineMatch> = vec![];

    let pattern_str = if flag_case_sensitive {
        pattern.to_string()
    } else {
        pattern.to_lowercase()
    };
    let pattern_bytes = pattern_str.as_bytes();
    let pattern_chars = pattern_str.chars().collect::<Vec<char>>();
    let n_pattern_bytes: usize = pattern_bytes.len();
    let n_pattern_chars: usize = pattern_chars.len();
    let mut fails: Vec<usize> = vec![0; n_pattern_bytes + 1];
    calc_fails(pattern_bytes, &mut fails);

    // Smart pattern detection: check if pattern contains newlines
    let is_multiline_pattern = pattern.contains('\n');

    if is_multiline_pattern {
        // For multiline patterns, use full text approach with optimized line lookup
        let full_text = lines_vec.join("\n");
        let full_text_str = if flag_case_sensitive {
            full_text
        } else {
            full_text.to_lowercase()
        };
        let full_text_bytes = full_text_str.as_bytes();
        let line_offsets = build_line_offsets(lines_vec);

        let points = find_all_matched_points(full_text_bytes, pattern_bytes, Some(&fails));
        for start_pos in points {
            let end_pos = start_pos + n_pattern_bytes;

            // Use binary search to find line number - O(log n) instead of O(n)
            let (line_num, line_start_pos) = find_line_for_position(&line_offsets, start_pos);

            let relative_start = start_pos - line_start_pos;
            let relative_end = end_pos - line_start_pos;

            matches.push(ISearchInLinesLiteralLineMatch {
                lnum: line_num,
                score: score_exact,
                matches: vec![ISearchInLinesLiteralMatchPoint {
                    start: relative_start,
                    end: relative_end,
                }],
            });
        }
    } else {
        // For single-line patterns, search line by line for better efficiency and memory usage
        for (line_idx, line) in lines_vec.iter().enumerate() {
            let line_str = if flag_case_sensitive {
                line.as_str() // Use string slice instead of allocation
            } else {
                // Only allocate when we need case conversion
                &line.to_lowercase()
            };
            let line_bytes = line_str.as_bytes();

            let points = find_all_matched_points(line_bytes, pattern_bytes, Some(&fails));
            for start_pos in points {
                let end_pos = start_pos + n_pattern_bytes;

                matches.push(ISearchInLinesLiteralLineMatch {
                    lnum: line_idx + 1,
                    score: score_exact,
                    matches: vec![ISearchInLinesLiteralMatchPoint {
                        start: start_pos,
                        end: end_pos,
                    }],
                });
            }
        }
    }

    // Add fallback fuzzy search if no exact matches found and fuzzy is enabled
    if flag_fuzzy && matches.is_empty() {
        for (i, line) in lines_vec.iter().enumerate() {
            if line.is_empty() {
                continue;
            }

            let line_str = if flag_case_sensitive {
                line.as_str() // Use string slice instead of allocation
            } else {
                // Only allocate when we need case conversion
                &line.to_lowercase()
            };
            let line_bytes = line_str.as_bytes();
            let base: f64 = line.len() as f64;
            let points = find_all_matched_points(line_bytes, pattern_bytes, Some(&fails));
            if !points.is_empty() {
                let mut pieces: Vec<ISearchInLinesLiteralMatchPoint> = vec![];
                let mut score: u32 = 0;
                for l in points {
                    let r: usize = l + n_pattern_bytes;
                    let delta: f64 = r as f64;
                    let bonus: u32 = ((delta / base) * score_exact_bonus) as u32;
                    score += score_exact + bonus;
                    pieces.push(ISearchInLinesLiteralMatchPoint { start: l, end: r });
                }
                matches.push(ISearchInLinesLiteralLineMatch {
                    lnum: i + 1,
                    score,
                    matches: pieces,
                });
                continue;
            }

            if !flag_fuzzy {
                continue;
            }

            // Use string slices and avoid unnecessary allocations in fuzzy matching
            let line_chars = line_str.chars().collect::<Vec<char>>();
            let n_line_chars: usize = line_chars.len();
            let mut score = 0;
            let mut all_pattern_matches: Vec<ISearchInLinesLiteralMatchPoint> = vec![];
            let mut last_ti: usize = 0;
            let mut len: usize = 0;
            let mut pi: usize = 0;
            for ti in 0..n_line_chars {
                let c: char = line_chars[ti];
                if c != pattern_chars[pi] {
                    continue;
                }

                pi += 1;
                if pi == n_pattern_chars {
                    pi = 0;
                    let mut pattern_matches: Vec<ISearchInLinesLiteralMatchPoint> = {
                        let mut i: usize = ti;
                        let mut last_piece: ISearchInLinesLiteralMatchPoint =
                            ISearchInLinesLiteralMatchPoint {
                                start: ti,
                                end: ti + 1,
                            };
                        let mut pieces: Vec<ISearchInLinesLiteralMatchPoint> = vec![];
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
                    for piece in &mut pattern_matches {
                        let weight: usize = piece.end - piece.start;
                        max_weight = max_weight.max(weight);

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

                    let bonus: u32 = (max_weight as f64 / n_pattern_chars as f64
                        * score_scalar_bonus)
                        .round() as u32;
                    score += score_scalar + bonus;
                }
            }

            if score > 0 {
                matches.push(ISearchInLinesLiteralLineMatch {
                    lnum: i + 1,
                    score,
                    matches: all_pattern_matches,
                });
            }
        }
    }

    matches
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_literal_case_sensitive() {
        let lines = vec![
            "Hello World".to_string(),
            "hello world".to_string(),
            "HELLO WORLD".to_string(),
        ];
        let result = search_in_lines_literal("Hello", &lines, false, true);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[0].matches[0].start, 0);
        assert_eq!(result[0].matches[0].end, 5);
    }

    #[test]
    fn test_search_literal_case_insensitive() {
        let lines = vec![
            "Hello World".to_string(),
            "hello world".to_string(),
            "HELLO WORLD".to_string(),
        ];
        let result = search_in_lines_literal("hello", &lines, false, false);
        assert_eq!(result.len(), 3);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 2);
        assert_eq!(result[2].lnum, 3);
    }

    #[test]
    fn test_search_multiline_literal() {
        let lines = vec![
            "line1".to_string(),
            "line2".to_string(),
            "line3".to_string(),
        ];
        let result = search_in_lines_literal("line1\nline2", &lines, false, true);
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn test_search_fuzzy_match() {
        let lines = vec!["hello world".to_string()];
        let result = search_in_lines_literal("hw", &lines, true, false);
        assert!(!result.is_empty());
    }

    #[test]
    fn test_search_multiple_matches_same_line() {
        let lines = vec!["foo bar foo baz foo".to_string()];
        let result = search_in_lines_literal("foo", &lines, false, true);
        assert_eq!(result.len(), 3);
        assert_eq!(result[0].lnum, 1);
        assert_eq!(result[1].lnum, 1);
        assert_eq!(result[2].lnum, 1);
    }
}
