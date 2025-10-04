use crate::types::dto::LineMatch;
use crate::types::dto::ReplacementPoint;
use crate::util;
use nvim_oxi::api::Buffer;

/// Represents the result of a replace preview operation
#[derive(Debug, Clone)]
pub struct ReplacePreviewResult {
    pub search_matches: Vec<LineMatch>,
    pub replacement_lines: Vec<String>,
    pub replacement_matches: Vec<ReplacementPoint>,
    pub matches_count: usize,
}

/// Common configuration for replace preview operations
#[derive(Debug, Clone)]
pub struct ReplacePreviewConfig {
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_fuzzy: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

/// Reads lines from a buffer and returns them as a vector of strings
pub fn read_buffer_lines(buffer: &Buffer) -> Result<Vec<String>, String> {
    if !buffer.is_valid() {
        return Err("Invalid buffer".to_string());
    }

    let lines_result = buffer.get_lines(.., false);
    match lines_result {
        Ok(lines_iter) => {
            let lines: Vec<String> = lines_iter.map(|s| s.to_string()).collect();
            Ok(lines)
        }
        Err(err) => Err(format!("Failed to read buffer: {}", err)),
    }
}

/// Performs search operation on the given lines using the provided configuration
pub fn perform_search(
    lines: &[String],
    config: &ReplacePreviewConfig,
) -> Result<Vec<LineMatch>, String> {
    util::search::search_in_lines(
        &config.search_pattern,
        lines,
        config.flag_fuzzy,
        config.flag_regex,
        config.flag_case_sensitive,
    )
}

/// Calculates replacement text for a specific match, handling regex capture groups
pub fn calculate_replacement_text(
    matched_text: &str,
    config: &ReplacePreviewConfig,
) -> String {
    if config.flag_regex {
        // For regex replacements, handle capture groups
        match util::regex::compile_regex(&config.search_pattern) {
            Ok(regex) => {
                if let Some(captures) = regex.captures(matched_text) {
                    let mut replacement = config.replace_pattern.clone();
                    for i in 1..captures.len() {
                        if let Some(cap) = captures.get(i) {
                            let placeholder = format!("${}", i);
                            replacement = replacement.replace(&placeholder, cap.as_str());
                        }
                    }
                    replacement
                } else {
                    config.replace_pattern.clone()
                }
            }
            Err(_) => config.replace_pattern.clone(),
        }
    } else {
        config.replace_pattern.clone()
    }
}

/// Converts line matches to character positions and generates replacement points
pub fn generate_replacement_points(
    search_matches: &[LineMatch],
    lines: &[String],
    full_text: &str,
    config: &ReplacePreviewConfig,
) -> Vec<ReplacementPoint> {
    let mut replacement_matches = Vec::new();

    // Convert line matches to character positions in the full text
    for line_match in search_matches {
        let line_index = line_match.lnum - 1; // Convert to 0-based

        // Calculate character offset to start of this line
        let mut line_start_offset = 0;
        for i in 0..line_index {
            if i < lines.len() {
                line_start_offset += lines[i].len() + 1; // +1 for newline
            }
        }

        // Process each match point on this line
        for match_point in &line_match.matches {
            let search_start = line_start_offset + match_point.start;
            let search_end = line_start_offset + match_point.end;

            // Calculate replacement text for this specific match
            let matched_text = if search_end <= full_text.len() {
                &full_text[search_start..search_end]
            } else {
                continue; // Skip invalid ranges
            };

            let replacement_text = calculate_replacement_text(matched_text, config);

            // Add replacement match with the replacement text content
            replacement_matches.push(ReplacementPoint {
                start: search_start,
                end: search_end,
                replacement_text,
            });
        }
    }

    replacement_matches
}

/// Generates preview text with replacements applied
pub fn generate_replacement_lines(
    full_text: &str,
    config: &ReplacePreviewConfig,
) -> Result<Vec<String>, String> {
    match util::replace::replace_text_preview_advance(
        full_text,
        &config.search_pattern,
        &config.replace_pattern,
        false,
        config.flag_regex,
        config.flag_case_sensitive,
    ) {
        Ok(replace_result) => {
            let replacement_lines = replace_result
                .text
                .split('\n')
                .map(|s| s.to_string())
                .collect();
            Ok(replacement_lines)
        }
        Err(_) => {
            // If replacement fails, return original lines
            let lines = full_text.split('\n').map(|s| s.to_string()).collect();
            Ok(lines)
        }
    }
}

/// Performs a complete replace preview operation on the given lines
pub fn perform_replace_preview(
    lines: &[String],
    config: &ReplacePreviewConfig,
) -> Result<ReplacePreviewResult, String> {
    // First, find all the search matches in the original text
    let search_matches = perform_search(lines, config)?;
    let matches_count = search_matches.len();

    let full_text = lines.join("\n");

    // Generate replacement matches with actual replacement text
    let replacement_matches = generate_replacement_points(&search_matches, lines, &full_text, config);

    // Create replacement text by applying all replacements
    let replacement_lines = generate_replacement_lines(&full_text, config)?;

    Ok(ReplacePreviewResult {
        search_matches,
        replacement_lines,
        replacement_matches,
        matches_count,
    })
}

/// Performs a complete replace preview operation on a buffer
pub fn perform_buffer_replace_preview(
    buffer: &Buffer,
    config: &ReplacePreviewConfig,
) -> Result<ReplacePreviewResult, String> {
    let lines = read_buffer_lines(buffer)?;
    perform_replace_preview(&lines, config)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_replacement_text_with_regex() {
        let config = ReplacePreviewConfig {
            search_pattern: r#"require\(([\w\W]+?)\)"#.to_string(),
            replace_pattern: r#"import $1"#.to_string(),
            flag_fuzzy: false,
            flag_regex: true,
            flag_case_sensitive: true,
        };

        let matched_text = r#"require("node.path")"#;
        let result = calculate_replacement_text(matched_text, &config);
        assert_eq!(result, r#"import "node.path""#);
    }

    #[test]
    fn test_calculate_replacement_text_without_regex() {
        let config = ReplacePreviewConfig {
            search_pattern: "old_text".to_string(),
            replace_pattern: "new_text".to_string(),
            flag_fuzzy: false,
            flag_regex: false,
            flag_case_sensitive: true,
        };

        let matched_text = "old_text";
        let result = calculate_replacement_text(matched_text, &config);
        assert_eq!(result, "new_text");
    }

    #[test]
    fn test_perform_replace_preview() {
        let lines = vec![
            "let x = old_text;".to_string(),
            "let y = old_text;".to_string(),
        ];

        let config = ReplacePreviewConfig {
            search_pattern: "old_text".to_string(),
            replace_pattern: "new_text".to_string(),
            flag_fuzzy: false,
            flag_regex: false,
            flag_case_sensitive: true,
        };

        let result = perform_replace_preview(&lines, &config);
        assert!(result.is_ok());

        let preview_result = result.unwrap();
        assert_eq!(preview_result.matches_count, 2);
        assert_eq!(preview_result.replacement_matches.len(), 2);
    }
}