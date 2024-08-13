use serde::{Deserialize, Serialize};

pub mod r#match;
pub mod replace;
pub mod ripgrep_result;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CmdResult<T> {
    pub cmd: String,
    pub error: Option<String>,
    pub data: Option<T>,
}
