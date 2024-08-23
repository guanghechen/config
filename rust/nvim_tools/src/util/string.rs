use crate::algorithm::kmp::{calc_fails, find_all_matched_points};
use crate::types::r#match::{LineMatch, MatchPoint};

pub fn parse_comma_list(input: &str) -> Vec<String> {
    let parts: Vec<String> = input
        //-
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect();
    parts
}

pub fn normalize_comma_list(input: &str) -> String {
    let parts: Vec<String> = parse_comma_list(input);
    parts.join(", ")
}

pub fn get_line_widths(text: &str) -> Vec<u32> {
    let mut lwidths: Vec<u32> = vec![];
    for line in text.lines() {
        lwidths.push(line.len() as u32);
    }
    lwidths
}

pub fn find_match_points<S: AsRef<str>>(
    pattern: &str,
    lines: &[S],
    flag_fuzzy: bool,
) -> Vec<LineMatch> {
    if pattern.is_empty() {
        return vec![];
    }

    let pattern_bytes = pattern.as_bytes();
    let pattern_chars = pattern.chars().collect::<Vec<char>>();
    let n_pattern_bytes: usize = pattern_bytes.len();
    let n_pattern_chars: usize = pattern_chars.len();

    let score_exact: usize = 100;
    let score_scalar: usize = 30;
    let score_exact_bonus: f64 = 30.0;
    let score_scalar_bonus: f64 = 30.0;

    let mut fails: Vec<usize> = vec![0; n_pattern_bytes + 1];
    let mut matches: Vec<LineMatch> = vec![];
    calc_fails(pattern_bytes, &mut fails);

    for (idx, line) in lines.iter().enumerate() {
        let line = line.as_ref();
        if line.is_empty() {
            continue;
        }

        let line_bytes = line.as_bytes();
        let base: f64 = line.len() as f64;
        let points = find_all_matched_points(line_bytes, pattern_bytes, Some(&fails));
        if !points.is_empty() {
            let mut pieces: Vec<MatchPoint> = vec![];
            let mut score = 0;
            for l in points {
                let r: usize = l + n_pattern_bytes;
                let delta: f64 = r as f64;
                let bonus: usize = ((delta / base) * score_exact_bonus) as usize;
                score += score_exact + bonus;
                pieces.push(MatchPoint { start: l, end: r });
            }
            matches.push(LineMatch {
                idx,
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

                let bonus: usize = (max_weight as f64 / n_pattern_chars as f64 * score_scalar_bonus)
                    .round() as usize;
                score += score_scalar + bonus;
            }
        }

        if score > 0 {
            matches.push(LineMatch {
                idx,
                score,
                matches: all_pattern_matches,
            });
        }
    }

    matches
}

pub struct NewlineIndices<'a> {
    text: &'a str,
    next_index: usize,
}

impl<'a> NewlineIndices<'a> {
    pub fn new(text: &'a str) -> Self {
        NewlineIndices {
            text,
            next_index: 0,
        }
    }
}

impl<'a> Iterator for NewlineIndices<'a> {
    type Item = usize;

    fn next(&mut self) -> Option<usize> {
        if self.next_index < self.text.len() {
            match self.text[self.next_index..].find('\n') {
                Some(index) => {
                    let newline_index = self.next_index + index;
                    self.next_index = newline_index + 1;
                    return Some(newline_index);
                }
                None => {
                    self.next_index = self.text.len();
                    return Some(self.text.len());
                }
            }
        }
        None
    }
}
