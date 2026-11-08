use crate::types::replace::IReplacePreviewResult;

use super::replace_text_preview_by_matches_advance::replace_text_preview_by_matches_advance;

pub fn replace_file_preview_by_matches_advance(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<IReplacePreviewResult, String> {
    let (_, text) = super::read_text(filepath)?;
    replace_text_preview_by_matches_advance(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
        flag_case_sensitive,
        match_offsets,
    )
}
