use crate::types::{replace::ReplacePreview, FunResult};
use crate::util;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub match_idxs: Vec<usize>,
}

pub fn replace_file(
    (filepath, search_pattern, replace_pattern, flag_regex): (String, String, String, bool),
) -> String {
    let result: FunResult<bool> =
        match util::replace::replace_file(&filepath, &search_pattern, &replace_pattern, flag_regex)
        {
            Ok(succeed) => FunResult {
                error: None,
                data: Some(succeed),
            },
            Err(error) => FunResult {
                error: Some(error),
                data: None,
            },
        };
    serde_json::to_string(&result).unwrap()
}

pub fn replace_file_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFileByMatchesParams>(&params).unwrap();
    let result: FunResult<bool> = match util::replace::replace_file_by_matches(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        &params.match_idxs,
    ) {
        Ok(succeed) => FunResult {
            error: None,
            data: Some(succeed),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}

pub fn replace_file_preview(
    (filepath, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<String> = match util::replace::replace_file_preview(
        &filepath,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
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

pub fn replace_file_preview_with_matches(
    (filepath, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<ReplacePreview> = match util::replace::replace_file_preview_with_matches(
        &filepath,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
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

pub fn replace_text_preview(
    (text, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<String> = match util::replace::replace_text_preview(
        &text,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
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

pub fn replace_text_preview_with_matches(
    (text, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<ReplacePreview> = match util::replace::replace_text_preview_with_matches(
        &text,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
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
