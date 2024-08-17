use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct MatchPoint {
    #[serde(rename = "l")]
    pub start: usize, // related to the parent.lines
    #[serde(rename = "r")]
    pub end: usize, // related to the parent.lines
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LineMatchPiece {
    pub l: usize,
    pub r: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LineMatch {
    pub idx: usize,
    pub score: usize,
    pub pieces: Vec<LineMatchPiece>,
}
