use crate::search::matcher;
use crate::types::replace::IExpandedMatch;
use std::collections::HashMap;

/// The extent and replacement of each match file search lists at `match_offsets` in `text`, or `None` where no match
/// of the pattern starts. Matching follows file search and replacement, on the whole text.
pub fn expand_text_by_matches(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<Vec<Option<IExpandedMatch>>, String> {
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let wanted: HashMap<usize, usize> = match_offsets
        .iter()
        .enumerate()
        .map(|(index, &offset)| (offset, index))
        .collect();
    let mut expanded = vec![None; match_offsets.len()];
    for caps in regex.captures_iter(text) {
        let found = caps.get(0).expect("group 0 is the match");
        if found.is_empty() {
            continue;
        }
        if let Some(&index) = wanted.get(&found.start()) {
            expanded[index] = Some(IExpandedMatch {
                oy: found.end() - 1,
                replacement: super::expand(&caps, replace_pattern),
            });
        }
    }
    Ok(expanded)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn expanded(
        text: &str,
        pattern: &str,
        replacement: &str,
        offsets: &[usize],
    ) -> Vec<Option<(usize, String)>> {
        expand_text_by_matches(text, pattern, replacement, true, true, offsets)
            .unwrap()
            .into_iter()
            .map(|found| found.map(|found| (found.oy, found.replacement)))
            .collect()
    }

    #[test]
    fn t_each_offset_takes_the_match_that_starts_there() {
        assert_eq!(
            expanded("a=1 b=2", r"(\w)=(\d)", "$2=$1", &[4, 0, 2]),
            [
                Some((6, "2=b".to_string())),
                Some((2, "1=a".to_string())),
                None
            ]
        );
    }

    #[test]
    fn t_matching_takes_the_whole_text_as_file_search_does() {
        /* `.` and `\s` cross line breaks, and `$` holds before "\r\n". */
        assert_eq!(
            expanded("foo\r\nbar\nbaz", r"o\s+b(.)", "<$1>", &[2]),
            [Some((6, "<a>".to_string()))]
        );
        assert_eq!(
            expanded("a;\r\nb;", ";$", "", &[1, 5]),
            [Some((1, String::new())), Some((5, String::new()))]
        );
    }
}
