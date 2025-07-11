use crate::types::dto::{FunResult, ReplaceTextPreviewByMatchesParams};
use crate::util;

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
