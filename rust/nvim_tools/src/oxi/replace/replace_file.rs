use crate::types::FunResult;
use crate::util;

pub fn replace_file(
    (filepath, search_pattern, replace_pattern, flag_regex, flag_case_sensitive): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<bool> = match util::replace::replace_file(
        &filepath,
        &search_pattern,
        &replace_pattern,
        flag_regex,
        flag_case_sensitive,
    ) {
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

