use crate::types::replace::ReplaceFileResult;
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
    (file_path, search_pattern, replace_pattern, flag_regex): (String, String, String, bool),
) -> String {
    let result = match util::replace::replace_file(
        &file_path,
        &search_pattern,
        &replace_pattern,
        flag_regex,
    ) {
        Ok(success) => ReplaceFileResult {
            success,
            error: None,
        },
        Err(error) => ReplaceFileResult {
            success: false,
            error: Some(error),
        },
    };
    serde_json::to_string(&result).unwrap()
}

pub fn replace_file_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFileByMatchesParams>(&params).unwrap();
    let result = match util::replace::replace_file_by_matches(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        &params.match_idxs,
    ) {
        Ok(success) => ReplaceFileResult {
            success,
            error: None,
        },
        Err(error) => ReplaceFileResult {
            success: false,
            error: Some(error),
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
    let result = util::replace::replace_file_preview(
        &filepath,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
    )
    .unwrap();
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
    let result = util::replace::replace_file_preview_with_matches(
        &filepath,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
    );
    match result {
        Ok(data) => serde_json::to_string(&data).unwrap(),
        Err(error) => {
            let data: util::replace::ReplacePreview = util::replace::ReplacePreview {
                text: error,
                matches: vec![],
            };
            serde_json::to_string(&data).unwrap()
        }
    }
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
    let result = util::replace::replace_text_preview(
        &text,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
    );
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
    let result = util::replace::replace_text_preview_with_matches(
        &text,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
    );
    serde_json::to_string(&result).unwrap()
}
