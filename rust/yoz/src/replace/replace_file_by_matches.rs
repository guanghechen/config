use crate::search::matcher;
use regex::Captures;
use std::collections::HashSet;

pub fn replace_file_by_matches(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<bool, String> {
    let (bom, text) = super::read_text(filepath)?;

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
        super::write_text(filepath, bom, &next_text)?;
    }

    Ok(true)
}
