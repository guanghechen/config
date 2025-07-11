use crate::types::FunResult;
use crate::util;

pub fn replace_file_preview(
    (
        filepath,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
        flag_case_sensitive,
    ): (String, String, String, bool, bool, bool),
) -> String {
    let result: FunResult<String> = match util::replace::replace_file_preview(
        &filepath,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
        flag_case_sensitive,
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

