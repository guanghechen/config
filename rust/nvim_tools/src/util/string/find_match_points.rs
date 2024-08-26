use crate::algorithm::kmp::{calc_fails, find_all_matched_points};
use crate::types::r#match::{LineMatch, MatchPoint};
use regex::Regex;

pub fn find_match_points_line_by_line(
    pattern: &str,
    text: &str,
    flag_fuzzy: bool,
    flag_regex: bool,
) -> Result<Vec<LineMatch>, String> {
    if pattern.is_empty() {
        return Ok(vec![]);
    }

    let score_exact: u32 = 100;
    let score_scalar: u32 = 30;
    let score_exact_bonus: f64 = 30.0;
    let score_scalar_bonus: f64 = 30.0;
    let mut matches: Vec<LineMatch> = vec![];

    if flag_regex {
        let regex = Regex::new(pattern).unwrap();
        for (i, line) in text.lines().enumerate() {
            if line.is_empty() {
                continue;
            }

            let mut score: u32 = 0;
            let mut pieces: Vec<MatchPoint> = vec![];
            for mat in regex.find_iter(line) {
                score += score_exact;
                pieces.push(MatchPoint {
                    start: mat.start(),
                    end: mat.end(),
                })
            }

            if score > 0 {
                matches.push(LineMatch {
                    lnum: i + 1,
                    score,
                    matches: pieces,
                });
            }
        }
    } else {
        let pattern_bytes = pattern.as_bytes();
        let pattern_chars = pattern.chars().collect::<Vec<char>>();
        let n_pattern_bytes: usize = pattern_bytes.len();
        let n_pattern_chars: usize = pattern_chars.len();
        let mut fails: Vec<usize> = vec![0; n_pattern_bytes + 1];
        calc_fails(pattern_bytes, &mut fails);

        for (i, line) in text.lines().enumerate() {
            if line.is_empty() {
                continue;
            }

            let line_bytes = line.as_bytes();
            let base: f64 = line.len() as f64;
            let points = find_all_matched_points(line_bytes, pattern_bytes, Some(&fails));
            if !points.is_empty() {
                let mut pieces: Vec<MatchPoint> = vec![];
                let mut score: u32 = 0;
                for l in points {
                    let r: usize = l + n_pattern_bytes;
                    let delta: f64 = r as f64;
                    let bonus: u32 = ((delta / base) * score_exact_bonus) as u32;
                    score += score_exact + bonus;
                    pieces.push(MatchPoint { start: l, end: r });
                }
                matches.push(LineMatch {
                    lnum: i + 1,
                    score,
                    matches: pieces,
                });
                continue;
            }

            if !flag_fuzzy {
                continue;
            }

            let line_chars = line.chars().collect::<Vec<char>>();
            let n_line_chars: usize = line_chars.len();
            let mut score = 0;
            let mut all_pattern_matches: Vec<MatchPoint> = vec![];
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
                    let mut pattern_matches: Vec<MatchPoint> = {
                        let mut i: usize = ti;
                        let mut last_piece: MatchPoint = MatchPoint {
                            start: ti,
                            end: ti + 1,
                        };
                        let mut pieces: Vec<MatchPoint> = vec![];
                        for j in (0..n_pattern_chars).rev() {
                            while i > 0 && line_chars[i] != pattern_chars[j] {
                                i -= 1;
                            }

                            if i + 1 == last_piece.start {
                                last_piece.start = i;
                            } else {
                                pieces.push(last_piece);
                                last_piece = MatchPoint {
                                    start: i,
                                    end: i + 1,
                                };
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
                matches.push(LineMatch {
                    lnum: i + 1,
                    score,
                    matches: all_pattern_matches,
                });
            }
        }
    }

    Ok(matches)
}
