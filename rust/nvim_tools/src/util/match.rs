use super::string::NewlineIndices;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MatchPoint {
    #[serde(rename = "l")]
    pub start: usize, // related to the parent.lines
    #[serde(rename = "r")]
    pub end: usize, // related to the parent.lines
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LineMatchPiece {
    #[serde(rename = "i")]
    pub match_idx: usize, // index of the block match points.
    #[serde(rename = "l")]
    pub start: usize, // the character index of the line start
    #[serde(rename = "r")]
    pub end: usize, // the character index of the line end
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LineMatch {
    #[serde(rename = "l")]
    pub start: usize, // the character index of the line start
    #[serde(rename = "r")]
    pub end: usize, // the character index of the line end
    #[serde(rename = "p")]
    pub pieces: Vec<LineMatchPiece>,
}

pub fn find_matches_per_line(text: &str, matches: &[MatchPoint]) -> Vec<LineMatch> {
    let mut lines: Vec<LineMatch> = vec![];
    let mut line_start_idx: usize = 0;
    let mut match_idx: usize = 0;
    for line_end_idx in NewlineIndices::new(text) {
        let mut pieces: Vec<LineMatchPiece> = vec![];
        while match_idx < matches.len() {
            let m = &matches[match_idx];
            if m.end < line_start_idx {
                match_idx += 1;
                continue;
            }
            if m.start >= line_end_idx {
                break;
            }

            let start: usize = m.start.max(line_start_idx);
            let end: usize = m.end.min(line_end_idx);
            if start < end {
                pieces.push(LineMatchPiece {
                    match_idx,
                    start: start - line_start_idx,
                    end: end - line_start_idx,
                });
            }

            if m.end > line_end_idx {
                break;
            }

            match_idx += 1;
        }

        let line: LineMatch = LineMatch {
            start: line_start_idx,
            end: line_end_idx,
            pieces,
        };
        lines.push(line);
        line_start_idx = line_end_idx + 1;
    }
    lines
}
