use crate::algorithm::kmp::find_all_matched_points;
use crate::types::r#match::MatchPoint;
use crate::types::replace::ReplacePreview;
use crate::util::regex::get_static_regex;
use regex::Captures;
use std::collections::HashSet;
use std::fs::File;
use std::io::Read;

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

pub fn replace_file_preview_by_matches(
    filepath: &str,
    search_pattern: &String,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    match_offsets: &[usize],
) -> Result<String, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;
    replace_text_preview_by_matches(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
        match_offsets,
    )
}

pub fn replace_file_preview_advance(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
) -> Result<ReplacePreview, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;
    replace_text_preview_advance(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
    )
}

pub fn replace_file_preview_advance_by_matches(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    match_offsets: &[usize],
) -> Result<ReplacePreview, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;
    replace_text_preview_advance_by_matches(
        &text,
        search_pattern,
        replace_pattern,
        keep_search_pieces,
        flag_regex,
        match_offsets,
    )
}

pub fn replace_text_preview(
    text: &str,
    search_pattern: &String,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
) -> Result<String, String> {
    if flag_regex {
        let result: Result<String, String> = match get_static_regex(search_pattern) {
            Ok(r) => {
                let regex = r.lock().unwrap();
                let next_text: String = regex
                    .replace_all(text, |caps: &Captures| {
                        let mut replacement = replace_pattern.to_string();
                        for i in 1..caps.len() {
                            if let Some(cap) = caps.get(i) {
                                let placeholder = format!("${}", i);
                                replacement = replacement.replace(&placeholder, cap.as_str());
                            }
                        }

                        if keep_search_pieces {
                            format!("{}{}", search_pattern, replacement)
                        } else {
                            replacement
                        }
                    })
                    .to_string();
                return Ok(next_text);
            }
            Err(error) => Err(error),
        };
        return result;
    }

    let match_points: Vec<usize> =
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
    let len_of_search: usize = search_pattern.len();
    let mut pieces: Vec<&str> = vec![];
    let mut i: usize = 0;
    for m in match_points {
        let j: usize = m + len_of_search;
        if keep_search_pieces {
            pieces.push(&text[i..j]);
            pieces.push(replace_pattern);
        } else {
            pieces.push(&text[i..m]);
            pieces.push(replace_pattern);
        }
        i = j;
    }
    pieces.push(&text[i..]);
    Ok(pieces.join(""))
}

pub fn replace_text_preview_by_matches(
    text: &str,
    search_pattern: &String,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    match_offsets: &[usize],
) -> Result<String, String> {
    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    if flag_regex {
        let result: Result<String, String> = match get_static_regex(search_pattern) {
            Ok(r) => {
                let regex = r.lock().unwrap();
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
                                format!("{}{}", search_pattern, replacement)
                            } else {
                                replacement
                            }
                        } else {
                            search_pattern.to_string()
                        }
                    })
                    .to_string();
                return Ok(next_text);
            }
            Err(error) => Err(error),
        };
        return result;
    }

    let match_points: Vec<usize> =
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
    let len_of_search: usize = search_pattern.len();
    let mut pieces: Vec<&str> = vec![];
    let mut i: usize = 0;
    for m in match_points {
        let j: usize = m + len_of_search;
        if match_offsets.contains(&m) {
            if keep_search_pieces {
                pieces.push(&text[i..j]);
                pieces.push(replace_pattern);
            } else {
                pieces.push(&text[i..m]);
                pieces.push(replace_pattern);
            }
        } else {
            pieces.push(&text[i..j]);
        }
        i = j;
    }
    pieces.push(&text[i..]);
    Ok(pieces.join(""))
}

pub fn replace_text_preview_advance(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
) -> Result<ReplacePreview, String> {
    let mut matches: Vec<MatchPoint> = vec![];
    if flag_regex {
        let result: Result<ReplacePreview, String> = match get_static_regex(search_pattern) {
            Ok(r) => {
                let regex = r.lock().unwrap();
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
                            format!("{}{}", search_pattern, replacement)
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
                    })
                    .to_string();
                Ok(ReplacePreview {
                    text: next_text,
                    matches,
                })
            }
            Err(error) => Err(error),
        };
        return result;
    }

    let match_points: Vec<usize> =
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
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
    let next_text: String = pieces.join("");
    Ok(ReplacePreview {
        text: next_text,
        matches,
    })
}

pub fn replace_text_preview_advance_by_matches(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    match_offsets: &[usize],
) -> Result<ReplacePreview, String> {
    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let mut matches: Vec<MatchPoint> = vec![];
    if flag_regex {
        let result: Result<ReplacePreview, String> = match get_static_regex(search_pattern) {
            Ok(r) => {
                let regex = r.lock().unwrap();
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
                                format!("{}{}", search_pattern, replacement)
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
                            search_pattern.to_string()
                        }
                    })
                    .to_string();
                Ok(ReplacePreview {
                    text: next_text,
                    matches,
                })
            }
            Err(error) => Err(error),
        };
        return result;
    }

    let match_points: Vec<usize> =
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None);
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
    Ok(ReplacePreview {
        text: next_text,
        matches,
    })
}
