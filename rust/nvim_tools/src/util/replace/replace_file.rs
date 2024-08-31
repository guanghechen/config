use crate::algorithm::kmp::find_all_matched_points;
use crate::types::r#match::MatchLocation;
use crate::util::regex::get_static_regex;
use crate::util::string::get_locations;
use regex::Captures;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs::File;
use std::io::{Read, Write};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileAdvanceByMatchesSucceedResult {
    pub locations: Vec<MatchLocation>,
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
) -> Result<bool, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let len_of_search: usize = search_pattern.len();
    let mut next_text: String = text.to_string();
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
        let mut pieces: Vec<&str> = vec![];
        let mut i: usize = 0;
        for m in match_points {
            let j: usize = m + len_of_search;
            if match_offsets.contains(&m) {
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

pub fn replace_file_advance_by_matches(
    filepath: &str,
    search_pattern: &String,
    replace_pattern: &str,
    flag_regex: bool,
    match_offsets: &[usize],
    remain_offsets: &[usize],
) -> Result<ReplaceFileAdvanceByMatchesSucceedResult, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let len_of_search: usize = search_pattern.len();
    let mut next_text: String = text.to_string();
    let mut offset_delta: i64 = 0;
    let mut next_offsets: Vec<usize> = vec![];
    if flag_regex {
        if let Ok(r) = get_static_regex(search_pattern) {
            let regex = r.lock().unwrap();
            next_text = regex
                .replace_all(&text, |caps: &Captures| {
                    let m = caps.get(0).unwrap();
                    let offset: usize = m.start();
                    let should_replace: bool = match_offsets.contains(&offset);
                    if should_replace {
                        let mut replacement: String = replace_pattern.to_string();
                        for i in 1..caps.len() {
                            if let Some(cap) = caps.get(i) {
                                let placeholder = format!("${}", i);
                                replacement = replacement.replace(&placeholder, cap.as_str());
                            }
                        }

                        let mut i = next_offsets.len();
                        while i < remain_offsets.len() {
                            let remain_offset: usize = remain_offsets[i];
                            if remain_offset > offset {
                                break;
                            }

                            next_offsets.push((remain_offset as i64 + offset_delta) as usize);
                            i += 1;
                        }
                        offset_delta +=
                            (replacement.len() as i64) - (m.end() as i64 - m.start() as i64);

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
        let delta: i64 = (len_of_replace as i64) - (len_of_search as i64);
        let mut pieces: Vec<&str> = vec![];
        let mut i: usize = 0;
        for m in match_points {
            let j: usize = m + len_of_search;
            let offset: usize = m;
            let should_replace: bool = match_offsets.contains(&offset);
            if should_replace {
                pieces.push(&text[i..m]);
                pieces.push(replace_pattern);

                let mut i = next_offsets.len();
                while i < remain_offsets.len() {
                    let remain_offset: usize = remain_offsets[i];
                    if remain_offset > offset {
                        break;
                    }

                    next_offsets.push((remain_offset as i64 + offset_delta) as usize);
                    i += 1;
                }
                offset_delta += delta
            } else {
                pieces.push(&text[i..j]);
            }
            i = j;
        }
        pieces.push(&text[i..]);
        next_text = pieces.join("");
    }

    let mut i: usize = next_offsets.len();
    while i < remain_offsets.len() {
        let remain_offset: usize = remain_offsets[i];
        next_offsets.push((remain_offset as i64 + offset_delta) as usize);
        i += 1
    }

    if text != next_text {
        let mut new_file = File::create(filepath).unwrap();
        new_file.write_all(next_text.as_bytes()).unwrap();
    }

    let locations: Vec<MatchLocation> = get_locations(&next_text, &next_offsets);
    Ok(ReplaceFileAdvanceByMatchesSucceedResult { locations })
}
