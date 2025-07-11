use crate::types::FunResult;
use crate::util;
use crate::util::replace::ReplacePreviewResult;

pub fn replace_text_preview_advance(
    (text, search_pattern, replace_pattern, keep_search_pieces, flag_regex, flag_case_sensitive): (
        String,
        String,
        String,
        bool,
        bool,
        bool,
    ),
) -> String {
    let result: FunResult<ReplacePreviewResult> = match util::replace::replace_text_preview_advance(
        &text,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
        flag_case_sensitive,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}

