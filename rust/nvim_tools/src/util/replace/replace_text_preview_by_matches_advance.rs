use crate::algorithm::kmp::find_all_matched_points;
use crate::types::dto::MatchPoint;
use crate::util::regex::compile_regex;
use crate::types::dto::ReplacePreviewResult;
use regex::Captures;
use std::collections::HashSet;

pub fn replace_text_preview_by_matches_advance(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<ReplacePreviewResult, String> {
    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let mut matches: Vec<MatchPoint> = vec![];
    if flag_regex {
        let result: Result<ReplacePreviewResult, String> = match compile_regex(search_pattern) {
            Ok(r) => {
                let regex = r;
                let mut total_search_len: usize = 0;
                let mut total_replace_len: usize = 0;
                let next_text: String = regex
                    .replace_all(text, |caps: &Captures| {
                        let mut replacement = replace_pattern.to_string();
                        for i in 1..caps.len() {
                            if let Some(cap) = caps.get(i) {
                                let placeholder = format!("${}", i);
                                replacement = replacement.replace(&placeholder, cap.as_str());
                            }
                        }

                        let m = caps.get(0).unwrap();
                        let should_replace: bool = match_offsets.contains(&m.start());
                        if should_replace {
                            if keep_search_pieces {
                                let search_start: usize = m.start() + total_replace_len;
                                let search_end: usize = search_start + m.len();
                                let replace_start: usize = search_end;
                                let replace_end: usize = replace_start + replacement.len();
                                total_search_len += m.len();
                                total_replace_len += replacement.len();
                                matches.push(MatchPoint {
                                    start: search_start,
                                    end: search_end,
                                });
                                matches.push(MatchPoint {
                                    start: replace_start,
                                    end: replace_end,
                                });
                                format!("{}{}", m.as_str(), replacement)
                            } else {
                                let replace_start: usize =
                                    m.start() + total_replace_len - total_search_len;
                                let replace_end: usize = replace_start + replacement.len();
                                total_search_len += m.len();
                                total_replace_len += replacement.len();
                                matches.push(MatchPoint {
                                    start: replace_start,
                                    end: replace_end,
                                });
                                replacement
                            }
                        } else {
                            m.as_str().to_string()
                        }
                    })
                    .to_string();
                Ok(ReplacePreviewResult {
                    text: next_text,
                    matches,
                })
            }
            Err(error) => Err(error),
        };
        return result;
    }

    let match_points: Vec<usize> = if flag_case_sensitive {
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None)
    } else {
        let text_lower = text.to_lowercase();
        let pattern_lower = search_pattern.to_lowercase();
        find_all_matched_points(text_lower.as_bytes(), pattern_lower.as_bytes(), None)
    };
    let len_of_search: usize = search_pattern.len();
    let len_of_replace: usize = replace_pattern.len();
    let mut total_search_len: usize = 0;
    let mut total_replace_len: usize = 0;
    let mut pieces: Vec<&str> = vec![];
    let mut i: usize = 0;
    for m in match_points {
        let j: usize = m + len_of_search;
        if match_offsets.contains(&m) {
            if keep_search_pieces {
                let search_start: usize = m + total_replace_len;
                let search_end: usize = search_start + len_of_search;
                let replace_start: usize = search_end;
                let replace_end: usize = replace_start + len_of_replace;
                total_search_len += len_of_search;
                total_replace_len += len_of_replace;
                matches.push(MatchPoint {
                    start: search_start,
                    end: search_end,
                });
                matches.push(MatchPoint {
                    start: replace_start,
                    end: replace_end,
                });
                pieces.push(&text[i..j]);
                pieces.push(replace_pattern);
            } else {
                let replace_start: usize = m + total_replace_len - total_search_len;
                let replace_end: usize = replace_start + len_of_replace;
                total_search_len += len_of_search;
                total_replace_len += len_of_replace;
                matches.push(MatchPoint {
                    start: replace_start,
                    end: replace_end,
                });
                pieces.push(&text[i..m]);
                pieces.push(replace_pattern);
            }
        } else {
            pieces.push(&text[i..j]);
        }
        i = j;
    }
    pieces.push(&text[i..]);
    let next_text: String = pieces.join("");
    Ok(ReplacePreviewResult {
        text: next_text,
        matches,
    })
}
