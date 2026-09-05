use super::ISearchBuffer;
use super::text_utils::locate_line;
use crate::types::ISearchInLinesRegexLineMatch;
use crate::types::ISearchInLinesRegexMatchPoint;
use regex::Regex;

pub fn search_in_lines_regex(
    pattern: &str,
    buffer: &ISearchBuffer,
    flag_case_sensitive: bool,
) -> Result<Vec<ISearchInLinesRegexLineMatch>, String> {
    let score_exact: u32 = 100;
    let mut matches: Vec<ISearchInLinesRegexLineMatch> = Vec::new();

    let regex_pattern = if flag_case_sensitive {
        format!("(?-i)(?s){}", pattern)
    } else {
        format!("(?i)(?s){}", pattern)
    };

    let regex =
        Regex::new(&regex_pattern).map_err(|error| format!("Invalid regex pattern: {}", error))?;
    let is_multiline_pattern = pattern.contains('\n');

    if is_multiline_pattern {
        let line_offsets = buffer.line_offsets();
        if line_offsets.len() < 2 {
            return Ok(matches);
        }

        for mat in regex.find_iter(buffer.as_str()) {
            let start_pos = mat.start();
            let end_pos = mat.end();
            let line_num = locate_line(line_offsets, start_pos);
            if line_num == 0 || line_num > buffer.line_count() {
                continue;
            }

            let line_index = line_num - 1;
            let line_start_pos = line_offsets[line_index];
            let relative_start = start_pos.saturating_sub(line_start_pos);
            let relative_end = end_pos.saturating_sub(line_start_pos);

            matches.push(ISearchInLinesRegexLineMatch {
                lnum: line_num,
                score: score_exact,
                matches: vec![ISearchInLinesRegexMatchPoint {
                    start: relative_start,
                    end: relative_end,
                }],
            });
        }

        return Ok(matches);
    }

    for (line_idx, line) in buffer.iter_lines().enumerate() {
        let mut line_matches: Vec<ISearchInLinesRegexMatchPoint> = Vec::new();
        for mat in regex.find_iter(line) {
            line_matches.push(ISearchInLinesRegexMatchPoint {
                start: mat.start(),
                end: mat.end(),
            });
        }

        if line_matches.is_empty() {
            continue;
        }

        matches.push(ISearchInLinesRegexLineMatch {
            lnum: line_idx + 1,
            score: score_exact,
            matches: line_matches,
        });
    }

    Ok(matches)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/search/search_in_lines_regex_test.rs"
    ));
}
