use crate::types::dto::{FunResult, ReplaceFilePreviewAdvanceByMatchesParams};
use crate::util;
use crate::types::dto::ReplacePreviewResult;

pub fn replace_file_preview_advance_by_matches(
    params: ReplaceFilePreviewAdvanceByMatchesParams,
) -> FunResult<ReplacePreviewResult> {
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
    }
}
