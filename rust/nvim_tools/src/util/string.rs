use crate::{
    algorithm::kmp::{calc_fails, find_all_matched_points},
    types::string::{LineMatch, LineMatchPiece},
};

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

pub fn find_match_points<S: AsRef<str>>(pattern: &str, lines: &[S]) -> Vec<LineMatch> {
    let pattern_bytes = pattern.as_bytes();
    let pattern_chars = pattern.chars().collect::<Vec<char>>();
    let n_pattern_bytes: usize = pattern_bytes.len();

    let score_exact: usize = 10;
    let score_scalar: usize = 3;
    let score_exact_bonus: f64 = 3.0;
    let score_scalar_bonus: f64 = 3.0;

    let mut fails: Vec<usize> = vec![0; n_pattern_bytes + 1];
    let mut matches: Vec<LineMatch> = vec![];
    calc_fails(pattern_bytes, &mut fails);

    for (idx, line) in lines.iter().enumerate() {
        let line = line.as_ref();
        let line_bytes = line.as_bytes();
        let base: f64 = line.len() as f64;
        let points = find_all_matched_points(pattern_bytes, line_bytes, Some(&fails));
        if !points.is_empty() {
            let mut pieces: Vec<LineMatchPiece> = vec![];
            let mut score = 0;
            for l in points {
                let r: usize = l + n_pattern_bytes;
                let delta: f64 = r as f64;
                let bonus: usize = ((delta / base) * score_exact_bonus) as usize;
                score += score_exact + bonus;
                pieces.push(LineMatchPiece { l, r });
            }
            matches.push(LineMatch { idx, score, pieces });
            continue;
        }

        let mut pieces: Vec<LineMatchPiece> = vec![];
        let mut score = 0;
        let mut i: usize = 0;
        let mut t: usize = 0;
        let mut delta: f64 = 0.0;
        let mut continous: bool = false;
        let mut valid_piece_index: usize = 0;
        for c in line.chars() {
            let t2: usize = t + c.len_utf8();
            if c != pattern_chars[i] {
                t = t2;
                continous = false;
                continue;
            }

            if continous {
                if let Some(last) = pieces.last_mut() {
                    last.r = t2;
                }
            } else {
                let d: usize = if let Some(last) = pieces.last_mut() {
                    t - last.r
                } else {
                    t
                };
                delta += d as f64;

                continous = true;
                pieces.push(LineMatchPiece { l: t, r: t2 });
            }

            i += 1;
            t = t2;
            if i == pattern_chars.len() {
                let bonus: usize = ((1.0 - delta / base) * score_scalar_bonus) as usize;
                score += score_scalar + bonus;
                i = 0;
                delta = 0.0;
                continous = false;
                valid_piece_index = pieces.len();
            }
        }
        if score > 0 {
            pieces.truncate(valid_piece_index);
            matches.push(LineMatch { idx, score, pieces });
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
