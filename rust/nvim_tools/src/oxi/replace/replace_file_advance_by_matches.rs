use crate::types::FunResult;
use crate::util;
use crate::util::replace::ReplaceFileResult;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileAdvanceByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
    pub remain_offsets: Vec<usize>,
}

pub fn replace_file_advance_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFileAdvanceByMatchesParams>(&params).unwrap();
    let result: FunResult<ReplaceFileResult> = match util::replace::replace_file_advance_by_matches(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
        &params.remain_offsets,
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

