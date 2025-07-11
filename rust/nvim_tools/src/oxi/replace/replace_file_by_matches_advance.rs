use crate::types::dto::ReplaceFileResult;
use crate::types::dto::{FunResult, ReplaceFileByMatchesAdvanceParams};
use crate::util;

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
