use crate::types::dto::{FunResult, ReplaceTextPreviewAdvanceParams};
use crate::util;
use crate::types::dto::ReplacePreviewResult;

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
