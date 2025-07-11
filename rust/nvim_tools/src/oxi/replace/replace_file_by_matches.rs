use crate::types::FunResult;
use crate::util;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

pub fn replace_file_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFileByMatchesParams>(&params).unwrap();
    let result: FunResult<bool> = match util::replace::replace_file_by_matches(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}

