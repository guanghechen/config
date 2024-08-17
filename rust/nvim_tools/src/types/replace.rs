use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct ReplaceFileResult {
    pub success: bool,
    pub error: Option<String>,
}
