use crate::types::dto::FunResult;
use crate::types::dto::LineMatch;
use crate::types::dto::SearchInBufferParams;
use crate::types::dto::ShowReplacePreviewInBufferParams;
use crate::types::dto::ShowReplacePreviewInBufferResult;
use crate::util;
use nvim_oxi::api::Buffer;

pub fn search_in_buffer(params: SearchInBufferParams) -> FunResult<Vec<LineMatch>> {
    let buffer = Buffer::from(params.bufnr);

    if !buffer.is_valid() {
        return FunResult {
            error: Some(format!("Invalid buffer number: {}", params.bufnr)),
            data: None,
        };
    }

    let lines_result = buffer.get_lines(.., false);

    match lines_result {
        Ok(lines_iter) => {
            let lines: Vec<String> = lines_iter.map(|s| s.to_string()).collect();
            match rstd::search::search_in_lines(
                &params.search_pattern,
                &lines,
                params.flag_fuzzy,
                params.flag_regex,
                params.flag_case_sensitive,
            ) {
                Ok(matches) => FunResult {
                    error: None,
                    data: Some(matches.into_iter().map(LineMatch::from).collect()),
                },
                Err(error) => FunResult {
                    error: Some(error),
                    data: None,
                },
            }
        }
        Err(err) => FunResult {
            error: Some(format!("Failed to read buffer {}: {}", params.bufnr, err)),
            data: None,
        },
    }
}

pub fn show_replace_preview_in_buffer(
    params: ShowReplacePreviewInBufferParams,
) -> FunResult<ShowReplacePreviewInBufferResult> {
    let buffer = Buffer::from(params.bufnr);

    // Create configuration from parameters
    let config = util::replace::ReplacePreviewConfig {
        search_pattern: params.search_pattern,
        replace_pattern: params.replace_pattern,
        flag_fuzzy: params.flag_fuzzy,
        flag_regex: params.flag_regex,
        flag_case_sensitive: params.flag_case_sensitive,
    };

    // Perform the replace preview operation using the extracted utility functions
    match util::replace::perform_buffer_replace_preview(&buffer, &config) {
        Ok(preview_result) => FunResult {
            error: None,
            data: Some(ShowReplacePreviewInBufferResult {
                bufnr: params.bufnr,
                error: None,
                preview_applied: true,
                matches_count: preview_result.matches_count,
                search_matches: preview_result.search_matches,
                replacement_lines: preview_result.replacement_lines,
                replacement_matches: preview_result.replacement_matches,
            }),
        },
        Err(error_message) => FunResult {
            error: Some(error_message),
            data: None,
        },
    }
}
