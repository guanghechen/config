use crate::types::dto::FunResult;
use crate::types::dto::ReplaceFileByMatchesAdvanceParams;
use crate::types::dto::ReplaceFileByMatchesParams;
use crate::types::dto::ReplaceFileParams;
use crate::types::dto::ReplaceFilePreviewAdvanceParams;
use crate::types::dto::ReplaceFilePreviewByMatchesAdvanceParams;
use crate::types::dto::ReplaceFilePreviewParams;
use crate::types::dto::ReplaceFileResult;
use crate::types::dto::ReplacePreviewResult;
use crate::types::dto::ReplaceTextPreviewAdvanceParams;
use crate::types::dto::ReplaceTextPreviewByMatchesAdvanceParams;
use crate::types::dto::ReplaceTextPreviewByMatchesParams;
use crate::types::dto::ReplaceTextPreviewParams;
use crate::types::dto::ReplaceCurrentMatchInBufferParams;
use crate::types::dto::ReplaceCurrentMatchInBufferResult;
use crate::types::dto::ReplaceAllMatchesInBufferParams;
use crate::types::dto::ReplaceAllMatchesInBufferResult;
use crate::util;
use nvim_oxi::api::Buffer;

pub fn replace_file(params: ReplaceFileParams) -> FunResult<bool> {
    match util::replace::replace_file(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(succeed) => FunResult {
            error: None,
            data: Some(succeed),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_file_by_matches(params: ReplaceFileByMatchesParams) -> FunResult<bool> {
    match util::replace::replace_file_by_matches(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_file_by_matches_advance(
    params: ReplaceFileByMatchesAdvanceParams,
) -> FunResult<ReplaceFileResult> {
    match util::replace::replace_file_by_matches_advance(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
        &params.remain_offsets,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

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

pub fn replace_file_preview_advance(
    params: ReplaceFilePreviewAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_file_preview_advance(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_file_preview_by_matches_advance(
    params: ReplaceFilePreviewByMatchesAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_file_preview_by_matches_advance(
        &params.filepath,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_text_preview(params: ReplaceTextPreviewParams) -> FunResult<String> {
    match util::replace::replace_text_preview(
        &params.text,
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

pub fn replace_text_preview_advance(
    params: ReplaceTextPreviewAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_text_preview_advance(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
            data: None,
        },
    }
}

pub fn replace_text_preview_by_matches(
    params: ReplaceTextPreviewByMatchesParams,
) -> FunResult<String> {
    match util::replace::replace_text_preview_by_matches(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
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

pub fn replace_text_preview_by_matches_advance(
    params: ReplaceTextPreviewByMatchesAdvanceParams,
) -> FunResult<ReplacePreviewResult> {
    match util::replace::replace_text_preview_by_matches_advance(
        &params.text,
        &params.search_pattern,
        &params.replace_pattern,
        params.keep_search_pieces,
        params.flag_regex,
        params.flag_case_sensitive,
        &params.match_offsets,
    ) {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(error) => FunResult {
            error: Some(error),
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
    match util::replace::replace_text_preview_by_matches(
        &text,
        &params.search_pattern,
        &params.replace_pattern,
        false, // keep_search_pieces
        params.flag_regex,
        params.flag_case_sensitive,
        &[match_offset],
    ) {
        Ok(new_text) => {
            // Update buffer with new content
            let new_lines: Vec<String> = new_text.split('\n').map(|s| s.to_string()).collect();

            match buffer.set_lines(.., false, new_lines) {
                Ok(_) => {
                    FunResult {
                        error: None,
                        data: Some(ReplaceCurrentMatchInBufferResult {
                            success: true,
                        }),
                    }
                }
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
    match util::replace::replace_text_preview(
        &text,
        &params.search_pattern,
        &params.replace_pattern,
        false, // keep_search_pieces
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
