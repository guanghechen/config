use serde::{Deserialize, Serialize};

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
