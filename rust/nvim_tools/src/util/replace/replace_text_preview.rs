use crate::algorithm::kmp::find_all_matched_points;
use crate::util::regex::get_static_regex;
use regex::Captures;

pub fn replace_text_preview(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
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

                        let m = caps.get(0).unwrap();
                        if keep_search_pieces {
                            format!("{}{}", m.as_str(), replacement)
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

    let match_points: Vec<usize> = if flag_case_sensitive {
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None)
    } else {
        let text_lower = text.to_lowercase();
        let pattern_lower = search_pattern.to_lowercase();
        find_all_matched_points(text_lower.as_bytes(), pattern_lower.as_bytes(), None)
    };
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

