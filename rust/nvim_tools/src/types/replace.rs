use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct ReplaceEntireFileResult {
    pub success: bool,
    pub error: Option<String>,
}
