use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct LineMatch {
    pub lnum: usize,
    pub score: u32,
    pub matches: Vec<MatchPoint>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct MatchLocation {
    pub offset: usize,
    pub lnum: usize,
    pub col: usize,
    pub line: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct MatchPoint {
    #[serde(rename = "l")]
    pub start: usize, // related to the parent.lines
    #[serde(rename = "r")]
    pub end: usize, // related to the parent.lines
}
