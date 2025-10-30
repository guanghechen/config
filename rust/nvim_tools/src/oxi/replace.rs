use crate::types::dto::FunResult;
use crate::types::dto::ReplaceAllMatchesInBufferParams;
use crate::types::dto::ReplaceAllMatchesInBufferResult;
use crate::types::dto::ReplaceCurrentMatchInBufferParams;
use crate::types::dto::ReplaceCurrentMatchInBufferResult;
use crate::types::dto::ShowReplacePreviewInBufferParams;
use crate::types::dto::ShowReplacePreviewInBufferResult;
use crate::util;
use nvim_oxi::api::Buffer;

pub fn show_replace_preview_in_buffer(
    params: ShowReplacePreviewInBufferParams,
) -> FunResult<ShowReplacePreviewInBufferResult> {
    let buffer = Buffer::from(params.bufnr);

    let config = util::replace::ReplacePreviewConfig {
        search_pattern: params.search_pattern,
        replace_pattern: params.replace_pattern,
        flag_fuzzy: params.flag_fuzzy,
        flag_regex: params.flag_regex,
        flag_case_sensitive: params.flag_case_sensitive,
    };

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

pub fn replace_current_match_in_buffer(
    params: ReplaceCurrentMatchInBufferParams,
) -> FunResult<ReplaceCurrentMatchInBufferResult> {
    let mut buffer = Buffer::from(params.bufnr);

    if !buffer.is_valid() {
        return FunResult {
            error: Some(format!("Invalid buffer number: {}", params.bufnr)),
            data: None,
        };
    }

    // Validate current match index
    if params.current_match_index == 0 || params.current_match_index > params.matches.len() {
        return FunResult {
            error: Some("Invalid current match index".to_string()),
            data: None,
        };
    }

    // Get current buffer content
    let lines: Vec<String> = {
        let lines_result = buffer.get_lines(.., false);
        match lines_result {
            Ok(lines_iter) => lines_iter.map(|s| s.to_string()).collect(),
            Err(err) => {
                return FunResult {
                    error: Some(format!("Failed to read buffer {}: {}", params.bufnr, err)),
                    data: None,
                };
            }
        }
    };

    let text = lines.join("\n");

    // Get the current match
    let current_match = &params.matches[params.current_match_index - 1];
    if current_match.matches.is_empty() {
        return FunResult {
            error: Some("Current match has no match points".to_string()),
            data: None,
        };
    }

    // Calculate the match offset for the current match
    let line_index = current_match.lnum - 1;
    let mut line_start_offset = 0;
    for i in 0..line_index {
        if i < lines.len() {
            line_start_offset += lines[i].len() + 1; // +1 for newline
        }
    }
    let match_offset = line_start_offset + current_match.matches[0].start;

    // Use existing replace function to perform the replacement
    match rstd::replace::replace_text_preview_by_matches(
        &text,
        &params.search_pattern,
        &params.replace_pattern,
        false,
        params.flag_regex,
        params.flag_case_sensitive,
        &[match_offset],
    ) {
        Ok(new_text) => {
            // Update buffer with new content
            let new_lines: Vec<String> = new_text.split('\n').map(|s| s.to_string()).collect();

            match buffer.set_lines(.., false, new_lines) {
                Ok(_) => FunResult {
                    error: None,
                    data: Some(ReplaceCurrentMatchInBufferResult { success: true }),
                },
                Err(err) => FunResult {
                    error: Some(format!("Failed to update buffer: {}", err)),
                    data: None,
                },
            }
        }
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_all_matches_in_buffer(
    params: ReplaceAllMatchesInBufferParams,
) -> FunResult<ReplaceAllMatchesInBufferResult> {
    let mut buffer = Buffer::from(params.bufnr);

    if !buffer.is_valid() {
        return FunResult {
            error: Some(format!("Invalid buffer number: {}", params.bufnr)),
            data: None,
        };
    }

    // Get current buffer content
    let lines: Vec<String> = {
        let lines_result = buffer.get_lines(.., false);
        match lines_result {
            Ok(lines_iter) => lines_iter.map(|s| s.to_string()).collect(),
            Err(err) => {
                return FunResult {
                    error: Some(format!("Failed to read buffer {}: {}", params.bufnr, err)),
                    data: None,
                };
            }
        }
    };

    let text = lines.join("\n");
    let match_count = params.matches.len();

    // Use existing replace function to replace all matches
    match rstd::replace::replace_text_preview(
        &text,
        &params.search_pattern,
        &params.replace_pattern,
        false,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(new_text) => {
            // Update buffer with new content
            let new_lines: Vec<String> = new_text.split('\n').map(|s| s.to_string()).collect();

            match buffer.set_lines(.., false, new_lines) {
                Ok(_) => FunResult {
                    error: None,
                    data: Some(ReplaceAllMatchesInBufferResult {
                        success: true,
                        replaced_count: match_count,
                    }),
                },
                Err(err) => FunResult {
                    error: Some(format!("Failed to update buffer: {}", err)),
                    data: None,
                },
            }
        }
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}
