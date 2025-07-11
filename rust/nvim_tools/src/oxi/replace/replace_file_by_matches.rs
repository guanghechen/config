use crate::types::dto::{FunResult, ReplaceFileByMatchesParams};
use crate::util;

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
