use crate::search::ISearchInLinesMatchPoint;
use crate::search::matcher;
use crate::types::replace::IReplacePreviewResult;
use regex::Captures;
use std::collections::HashSet;

pub fn replace_text_preview_by_matches_advance(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<IReplacePreviewResult, String> {
    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();
    let mut matches: Vec<ISearchInLinesMatchPoint> = vec![];
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let mut total_search_len: usize = 0;
    let mut total_replace_len: usize = 0;
    let next_text: String = super::replace_all(&regex, text, |caps: &Captures| {
        let replacement = super::expand(caps, replace_pattern);

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
                matches.push(ISearchInLinesMatchPoint {
                    start: search_start,
                    end: search_end,
                });
                matches.push(ISearchInLinesMatchPoint {
                    start: replace_start,
                    end: replace_end,
                });
                format!("{}{}", m.as_str(), replacement)
            } else {
                let replace_start: usize = m.start() + total_replace_len - total_search_len;
                let replace_end: usize = replace_start + replacement.len();
                total_search_len += m.len();
                total_replace_len += replacement.len();
                matches.push(ISearchInLinesMatchPoint {
                    start: replace_start,
                    end: replace_end,
                });
                replacement
            }
        } else {
            m.as_str().to_string()
        }
    });
    Ok(IReplacePreviewResult {
        text: next_text,
        matches,
    })
}
