use crate::algorithm::kmp::find_all_matched_points;
use crate::util::regex::get_static_regex;
use regex::Captures;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs::File;
use std::io::{Read, Write};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileByMatchesSucceedResult {
    pub offset_deltas: Vec<i32>,
}

/// Peform replacement on the entire file.
pub fn replace_file(
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
            find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
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

pub fn replace_file_by_matches(
    filepath: &str,
    search_pattern: &String,
    replace_pattern: &str,
    flag_regex: bool,
    match_offsets: &[usize],
) -> Result<ReplaceFileByMatchesSucceedResult, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let len_of_search: usize = search_pattern.len();
    let mut next_text: String = text.to_string();
    let mut offset_deltas: Vec<i32> = vec![];
    if flag_regex {
        if let Ok(r) = get_static_regex(search_pattern) {
            let regex = r.lock().unwrap();
            next_text = regex
                .replace_all(&text, |caps: &Captures| {
                    let m = caps.get(0).unwrap();
                    let should_replace: bool = match_offsets.contains(&m.start());
                    if should_replace {
                        let mut replacement: String = replace_pattern.to_string();
                        for i in 1..caps.len() {
                            if let Some(cap) = caps.get(i) {
                                let placeholder = format!("${}", i);
                                replacement = replacement.replace(&placeholder, cap.as_str());
                            }
                        }
                        let offset_delta: i32 =
                            (replacement.len() as i32) - (m.end() as i32 - m.start() as i32);
                        offset_deltas.push(offset_delta);
                        replacement
                    } else {
                        m.as_str().to_string()
                    }
                })
                .to_string();
        }
    } else {
        let match_points: Vec<usize> =
            find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
        let len_of_replace: usize = replace_pattern.len();
        let offset_delta: i32 = (len_of_replace as i32) - (len_of_search as i32);
        let mut pieces: Vec<&str> = vec![];
        let mut i: usize = 0;
        for m in match_points {
            let j: usize = m + len_of_search;
            if match_offsets.contains(&m) {
                pieces.push(&text[i..m]);
                pieces.push(replace_pattern);
                offset_deltas.push(offset_delta);
            } else {
                pieces.push(&text[i..j]);
            }
            i = j;
        }
        pieces.push(&text[i..]);
        next_text = pieces.join("");
    }

    if text != next_text {
        let mut new_file = File::create(filepath).unwrap();
        new_file.write_all(next_text.as_bytes()).unwrap();
    }
    Ok(ReplaceFileByMatchesSucceedResult { offset_deltas })
}
