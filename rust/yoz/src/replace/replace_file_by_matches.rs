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
    let next_text: String = super::replace_all(&regex, &text, |caps: &Captures| {
        let m = caps.get(0).unwrap();
        let offset: usize = m.start();
        if match_offsets.contains(&offset) {
            super::expand(caps, replace_pattern)
        } else {
            m.as_str().to_string()
        }
    });

    if text != next_text {
        let mut new_file = File::create(filepath).map_err(|e| e.to_string())?;
        new_file
            .write_all(next_text.as_bytes())
            .map_err(|e| e.to_string())?;
    }

    Ok(true)
}
