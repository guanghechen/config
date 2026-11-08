use super::replace_text_preview::replace_text_preview;

pub fn replace_file_preview(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<String, String> {
    let (_, text) = super::read_text(filepath)?;
    replace_text_preview(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
        flag_case_sensitive,
    )
}
