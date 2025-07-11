use crate::types::FunResult;
use crate::util;
use crate::util::replace::ReplacePreviewResult;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFilePreviewAdvanceByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

pub fn replace_file_preview_advance_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFilePreviewAdvanceByMatchesParams>(&params).unwrap();
    let result: FunResult<ReplacePreviewResult> =
        match util::replace::replace_file_preview_advance_by_matches(
            &params.filepath,
            &params.search_pattern,
            &params.replace_pattern,
            params.keep_search_pieces,
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

