use crate::types::{replace::ReplacePreview, FunResult};
use crate::util;
use crate::util::replace::ReplaceFileAdvanceByMatchesSucceedResult;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub match_offsets: Vec<usize>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileAdvanceByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub match_offsets: Vec<usize>,
    pub remain_offsets: Vec<usize>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFilePreviewByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub match_offsets: Vec<usize>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFilePreviewAdvanceByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub match_offsets: Vec<usize>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceTextPreviewByMatchesParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub match_offsets: Vec<usize>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceTextPreviewAdvanceByMatchesParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub match_offsets: Vec<usize>,
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

pub fn replace_file_advance_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFileAdvanceByMatchesParams>(&params).unwrap();
    let result: FunResult<ReplaceFileAdvanceByMatchesSucceedResult> =
        match util::replace::replace_file_advance_by_matches(
            &params.filepath,
            &params.search_pattern,
            &params.replace_pattern,
            params.flag_regex,
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

pub fn replace_file_preview_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFilePreviewByMatchesParams>(&params).unwrap();
    let result: FunResult<String> = match util::replace::replace_file_preview_by_matches(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
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

pub fn replace_file_preview_advance(
    (filepath, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<ReplacePreview> = match util::replace::replace_file_preview_advance(
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

pub fn replace_file_preview_advance_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceFilePreviewAdvanceByMatchesParams>(&params).unwrap();
    let result: FunResult<ReplacePreview> =
        match util::replace::replace_file_preview_advance_by_matches(
            &params.filepath,
            &params.search_pattern,
            &params.replace_pattern,
            params.keep_search_pieces,
            params.flag_regex,
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

pub fn replace_text_preview_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceTextPreviewByMatchesParams>(&params).unwrap();
    let result: FunResult<String> = match util::replace::replace_text_preview_by_matches(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
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

pub fn replace_text_preview_advance(
    (text, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<ReplacePreview> = match util::replace::replace_text_preview_advance(
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

pub fn replace_text_preview_advance_by_matches(params: String) -> String {
    let params = serde_json::from_str::<ReplaceTextPreviewByMatchesParams>(&params).unwrap();
    let result: FunResult<ReplacePreview> =
        match util::replace::replace_text_preview_advance_by_matches(
            &params.text,
            &params.search_pattern,
            &params.replace_pattern,
            params.keep_search_pieces,
            params.flag_regex,
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
