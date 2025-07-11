use crate::types::dto::{FunResult, ReplaceFilePreviewParams};
use crate::util;

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
