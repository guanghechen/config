use crate::types::FunResult;
use crate::util;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceTextPreviewByMatchesParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

pub fn replace_text_preview_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceTextPreviewByMatchesParams>(&params).unwrap();
    let result: FunResult<String> = match util::replace::replace_text_preview_by_matches(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
    ) {
        Ok(next_text) => FunResult {
            error: None,
            data: Some(next_text),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}

