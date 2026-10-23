use crate::search::matcher;
use crate::string::get_locations;
use crate::types::IMatchLocation;
use crate::types::replace::IReplaceFileResult;
use regex::Captures;
use std::collections::HashSet;
use std::fs::File;
use std::io::Read;
use std::io::Write;

pub fn replace_file_by_matches_advance(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
    remain_offsets: &[usize],
) -> Result<IReplaceFileResult, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();

    let mut offset_delta: i64 = 0;
    let mut next_offsets: Vec<usize> = vec![];
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let next_text: String = regex
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
                offset_delta += (replacement.len() as i64) - (m.end() as i64 - m.start() as i64);

                replacement
            } else {
                m.as_str().to_string()
            }
        })
        .to_string();

    let mut i: usize = next_offsets.len();
    while i < remain_offsets.len() {
        let remain_offset: usize = remain_offsets[i];
        next_offsets.push((remain_offset as i64 + offset_delta) as usize);
        i += 1
    }

    if text != next_text {
        let mut new_file = File::create(filepath).map_err(|e| e.to_string())?;
        new_file
            .write_all(next_text.as_bytes())
            .map_err(|e| e.to_string())?;
    }

    let locations: Vec<IMatchLocation> = get_locations(&next_text, &next_offsets);
    Ok(IReplaceFileResult { locations })
}
