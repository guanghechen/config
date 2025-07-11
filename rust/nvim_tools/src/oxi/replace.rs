use crate::types::dto::FunResult;
use crate::types::dto::ReplaceFileByMatchesAdvanceParams;
use crate::types::dto::ReplaceFileByMatchesParams;
use crate::types::dto::ReplaceFileParams;
use crate::types::dto::ReplaceFilePreviewAdvanceParams;
use crate::types::dto::ReplaceFilePreviewByMatchesAdvanceParams;
use crate::types::dto::ReplaceFilePreviewParams;
use crate::types::dto::ReplaceFileResult;
use crate::types::dto::ReplacePreviewResult;
use crate::types::dto::ReplaceTextPreviewAdvanceParams;
use crate::types::dto::ReplaceTextPreviewByMatchesAdvanceParams;
use crate::types::dto::ReplaceTextPreviewByMatchesParams;
use crate::types::dto::ReplaceTextPreviewParams;
use crate::util;

pub fn replace_file(params: ReplaceFileParams) -> FunResult<bool> {
    match util::replace::replace_file(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(succeed) => FunResult {
            error: None,
            data: Some(succeed),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_file_by_matches(params: ReplaceFileByMatchesParams) -> FunResult<bool> {
    match util::replace::replace_file_by_matches(
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
    }
}

pub fn replace_file_by_matches_advance(
    params: ReplaceFileByMatchesAdvanceParams,
) -> FunResult<ReplaceFileResult> {
    match util::replace::replace_file_by_matches_advance(
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
    }
}

pub fn replace_file_preview(params: ReplaceFilePreviewParams) -> FunResult<String> {
    match util::replace::replace_file_preview(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(next_text) => FunResult {
            error: None,
            data: Some(next_text),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_file_preview_advance(
    params: ReplaceFilePreviewAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_file_preview_advance(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_file_preview_by_matches_advance(
    params: ReplaceFilePreviewByMatchesAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_file_preview_by_matches_advance(
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
    }
}

pub fn replace_text_preview(params: ReplaceTextPreviewParams) -> FunResult<String> {
    match util::replace::replace_text_preview(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(next_text) => FunResult {
            error: None,
            data: Some(next_text),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_text_preview_advance(
    params: ReplaceTextPreviewAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_text_preview_advance(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_text_preview_by_matches(
    params: ReplaceTextPreviewByMatchesParams,
) -> FunResult<String> {
    match util::replace::replace_text_preview_by_matches(
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
    }
}

pub fn replace_text_preview_by_matches_advance(
    params: ReplaceTextPreviewByMatchesAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_text_preview_by_matches_advance(
        &params.text,
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
    }
}
