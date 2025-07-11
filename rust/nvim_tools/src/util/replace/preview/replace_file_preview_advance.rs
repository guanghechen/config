use crate::types::dto::ReplacePreviewResult;
use std::fs::File;
use std::io::Read;

use super::replace_text_preview_advance::replace_text_preview_advance;

pub fn replace_file_preview_advance(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<ReplacePreviewResult, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;
    replace_text_preview_advance(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
        flag_case_sensitive,
    )
}
