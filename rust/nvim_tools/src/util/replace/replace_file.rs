use crate::algorithm::kmp::find_all_matched_points;
use crate::types::replace::ReplacePreview;
use crate::util::regex::get_static_regex;
use regex::Captures;
use std::collections::HashSet;
use std::fs::File;
use std::io::{Read, Write};

use super::{replace_text_preview, replace_text_preview_with_matches};

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
    match_idxs: &[usize],
) -> Result<bool, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let match_idxs: HashSet<usize> = match_idxs.iter().cloned().collect();
    let mut next_text: String = text.to_string();
    if flag_regex {
        if let Ok(r) = get_static_regex(search_pattern) {
            let regex = r.lock().unwrap();
            let mut match_idx: usize = 0;
            next_text = regex
                .replace_all(&text, |caps: &Captures| {
                    let should_replace: bool = match_idxs.contains(&match_idx);
                    match_idx += 1;
                    if should_replace {
                        let mut replacement: String = replace_pattern.to_string();
                        for i in 1..caps.len() {
                            if let Some(cap) = caps.get(i) {
                                let placeholder = format!("${}", i);
                                replacement = replacement.replace(&placeholder, cap.as_str());
                            }
                        }
                        replacement
                    } else {
                        search_pattern.to_string()
                    }
                })
                .to_string();
        }
    } else {
        let match_points: Vec<usize> =
            find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
        let len_of_search: usize = search_pattern.len();
        let mut pieces: Vec<&str> = vec![];
        let mut i: usize = 0;
        for (match_idx, m) in match_points.into_iter().enumerate() {
            let j: usize = m + len_of_search;
            if match_idxs.contains(&match_idx) {
                pieces.push(&text[i..m]);
                pieces.push(replace_pattern);
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
    Ok(true)
}

pub fn replace_file_preview(
    filepath: &str,
    search_pattern: &String,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
) -> Result<String, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;
    replace_text_preview(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
    )
}

pub fn replace_file_preview_with_matches(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
) -> Result<ReplacePreview, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;
    replace_text_preview_with_matches(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
    )
}
