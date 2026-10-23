use crate::search::matcher;
use regex::Captures;
use std::collections::HashSet;
use std::fs::File;
use std::io::Read;
use std::io::Write;

pub fn replace_file_by_matches(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<bool, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let next_text: String = regex
        .replace_all(&text, |caps: &Captures| {
            let m = caps.get(0).unwrap();
            let offset: usize = m.start();
            if match_offsets.contains(&offset) {
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

    if text != next_text {
        let mut new_file = File::create(filepath).map_err(|e| e.to_string())?;
        new_file
            .write_all(next_text.as_bytes())
            .map_err(|e| e.to_string())?;
    }

    Ok(true)
}
