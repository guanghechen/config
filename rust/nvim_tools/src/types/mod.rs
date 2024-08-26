use serde::{Deserialize, Serialize};

pub mod file;
pub mod r#match;
pub mod replace;
pub mod third_party;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CmdResult<T> {
    pub cmd: String,
    pub error: Option<String>,
    pub data: Option<T>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FunResult<T> {
    pub error: Option<String>,
    pub data: Option<T>,
}
