use crate::search::matcher;
use regex::Captures;
use std::collections::HashSet;

pub fn replace_text_preview_by_matches(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<String, String> {
    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
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
                    format!("{}{}", m.as_str(), replacement)
                } else {
                    replacement
                }
            } else {
                m.as_str().to_string()
            }
        })
        .to_string();
    Ok(next_text)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::search::search_in_text;

    #[test]
    fn t_replace_by_matches_replaces_the_match_search_reported() {
        let text = "İab a";
        let offsets: Vec<usize> = search_in_text("a", text, false, false, false)
            .unwrap()
            .matches
            .iter()
            .map(|found| found.ox)
            .collect();
        assert_eq!(offsets, [2, 5]);
        let result =
            replace_text_preview_by_matches(text, "a", "X", false, false, false, &offsets[..1]);
        assert_eq!(result.unwrap(), "İXb a");
    }
}
