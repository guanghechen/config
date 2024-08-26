use crate::types::r#match::MatchPoint;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplacePreview {
    pub text: String,
    pub matches: Vec<MatchPoint>,
}
