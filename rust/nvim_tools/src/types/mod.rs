use serde::{Deserialize, Serialize};

pub mod replace;
pub mod ripgrep_result;
pub mod string;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CmdResult<T> {
    pub cmd: String,
    pub error: Option<String>,
    pub data: Option<T>,
}
