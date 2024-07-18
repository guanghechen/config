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
    let n_pattern: usize = pattern.len();
    let mut fails: Vec<usize> = vec![0; n_pattern + 1];
    calc_fails(pattern.as_bytes(), &mut fails);

    let mut matches: Vec<LineMatch> = vec![];
    for (idx, line) in lines.iter().enumerate() {
        let line = line.as_ref();
        let line_bytes = line.as_bytes();
        let points = find_all_matched_points(pattern.as_bytes(), line_bytes, Some(&fails));
        if !points.is_empty() {
            let mut pieces: Vec<LineMatchPiece> = vec![];
            let mut score = 0;
            for p in points {
                pieces.push(LineMatchPiece {
                    l: p,
                    r: p + n_pattern,
                });
                score += 10;
            }
            let m: LineMatch = LineMatch { idx, score, pieces };
            matches.push(m);
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
