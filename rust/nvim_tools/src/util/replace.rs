use crate::algorithm::kmp::find_all_matched_points;

use super::r#match::{find_matches_per_line, LineMatch, MatchPoint};
use regex::{Captures, Regex};
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::{Read, Write};
use std::sync::Mutex;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplacePreview {
    pub text: String,
    pub lines: Vec<LineMatch>,
}

// https://docs.rs/regex/latest/regex/index.html
// I follow the example of the docs to reuse regex when running it multiple times
lazy_static! {
    static ref CACHE_PATTERN: Mutex<String> = Mutex::new(String::new());
    static ref CACHE_REGEX: Mutex<Regex> = Mutex::new(Regex::new(r"").unwrap());
}

fn get_static_regex(pattern: &String) -> Result<&'static Mutex<Regex>, String> {
    if *pattern != *CACHE_PATTERN.lock().unwrap() {
        CACHE_PATTERN.lock().unwrap().clone_from(pattern);
        let regex = Regex::new(pattern);
        return if let Ok(r) = regex {
            *CACHE_REGEX.lock().unwrap() = r;
            Ok(&CACHE_REGEX)
        } else {
            Err("Invalid regex".to_string())
        };
    }
    Ok(&CACHE_REGEX)
}

pub fn replace_text_preview(
    text: &str,
    search_pattern: &String,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
) -> ReplacePreview {
    let mut next_text: String = text.to_string();
    let mut matches: Vec<MatchPoint> = vec![];

    if flag_regex {
        if let Ok(r) = get_static_regex(search_pattern) {
            let regex = r.lock().unwrap();
            let mut total_search_len: usize = 0;
            let mut total_replace_len: usize = 0;

            next_text = regex
                .replace_all(text, |caps: &Captures| {
                    let mut replacement = replace_pattern.to_string();
                    for i in 1..caps.len() {
                        if let Some(cap) = caps.get(i) {
                            let placeholder = format!("${}", i);
                            replacement = replacement.replace(&placeholder, cap.as_str());
                        }
                    }

                    let mat = caps.get(0).unwrap();
                    if keep_search_pieces {
                        let search_start: usize = mat.start() + total_replace_len;
                        let search_end: usize = search_start + mat.len();
                        let replace_start: usize = search_end;
                        let replace_end: usize = replace_start + replacement.len();
                        total_search_len += mat.len();
                        total_replace_len += replacement.len();
                        matches.push(MatchPoint {
                            start: search_start,
                            end: search_end,
                        });
                        matches.push(MatchPoint {
                            start: replace_start,
                            end: replace_end,
                        });
                        format!("{}{}", mat.as_str(), replacement)
                    } else {
                        let replace_start: usize =
                            mat.start() + total_replace_len - total_search_len;
                        let replace_end: usize = replace_start + replacement.len();
                        total_search_len += mat.len();
                        total_replace_len += replacement.len();
                        matches.push(MatchPoint {
                            start: replace_start,
                            end: replace_end,
                        });
                        replacement
                    }
                })
                .to_string();
        }
    } else {
        let match_points: Vec<usize> =
            find_all_matched_points(text.as_bytes(), search_pattern.as_bytes());
        let len_of_search: usize = search_pattern.len();
        let len_of_replace: usize = replace_pattern.len();
        let mut total_search_len: usize = 0;
        let mut total_replace_len: usize = 0;
        let mut pieces: Vec<&str> = vec![];
        let mut i: usize = 0;
        for m in match_points {
            let j: usize = m + len_of_search;
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
            i = j;
        }
        pieces.push(&text[i..]);
        next_text = pieces.join("");
    }

    let lines: Vec<LineMatch> = find_matches_per_line(&next_text, &matches);
    ReplacePreview {
        text: next_text,
        lines,
    }
}

/// Peform replacement on the entire file.
pub fn replace_entire_file(
    filepath: &str,
    search_pattern: &String,
    replace_pattern: &str,
    flag_regex: bool,
) -> Result<bool, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let mut next_text: String = text.to_string();
    if flag_regex {
        if let Ok(r) = get_static_regex(search_pattern) {
            let regex = r.lock().unwrap();
            next_text = regex
                .replace_all(&text, |caps: &Captures| {
                    let mut replacement = replace_pattern.to_string();
                    for i in 1..caps.len() {
                        if let Some(cap) = caps.get(i) {
                            let placeholder = format!("${}", i);
                            replacement = replacement.replace(&placeholder, cap.as_str());
                        }
                    }
                    replacement
                })
                .to_string();
        }
    } else {
        let match_points: Vec<usize> =
            find_all_matched_points(text.as_bytes(), search_pattern.as_bytes());
        let len_of_search: usize = search_pattern.len();
        let mut pieces: Vec<&str> = vec![];
        let mut i: usize = 0;
        for m in match_points {
            let j: usize = m + len_of_search;
            pieces.push(&text[i..m]);
            pieces.push(replace_pattern);
            i = j;
        }
        pieces.push(&text[i..]);
        next_text = pieces.join("");
    }

    if text != next_text {
        let mut new_file = File::create(filepath).unwrap();
        new_file.write_all(next_text.as_bytes()).unwrap();
    }
    Ok(true)
}
