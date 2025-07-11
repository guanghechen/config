use crate::types::dto::{FunResult, ReplaceFileParams};
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
