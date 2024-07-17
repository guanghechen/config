use crate::types::replace::ReplaceEntireFileResult;
use crate::util;

pub fn replace_text_preview(
    (text, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
        String,
        String,
        String,
        bool,
        bool,
    ),
) -> String {
    let result = util::replace::replace_text_preview(
        &text,
        &search_pattern,
        &replace_pattern,
        keep_search_pieces,
        flag_regex,
    );
    serde_json::to_string(&result).unwrap()
}

pub fn replace_entire_file(
    (file_path, search_pattern, replace_pattern, flag_regex): (String, String, String, bool),
) -> String {
    let result = match util::replace::replace_entire_file(
        &file_path,
        &search_pattern,
        &replace_pattern,
        flag_regex,
    ) {
        Ok(success) => ReplaceEntireFileResult {
            success,
            error: None,
        },
        Err(error) => ReplaceEntireFileResult {
            success: false,
            error: Some(error),
        },
    };
    serde_json::to_string(&result).unwrap()
}
