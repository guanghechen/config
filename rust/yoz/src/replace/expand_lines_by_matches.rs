use crate::search::ISearchBuffer;
use crate::search::matcher;
use regex::Captures;
use std::collections::HashMap;

/// The replacement of each match buffer search lists at `match_offsets`, or `None` where no match of the pattern
/// starts, as at a fuzzy piece. Matching follows buffer search, each line on its own unless the pattern holds a line
/// break, and the groups are those of the match in its line; the offsets index the lines joined with "\n".
pub fn expand_lines_by_matches(
    lines: &[String],
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
) -> Result<Vec<Option<String>>, String> {
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let buffer = ISearchBuffer::from_lines(lines);
    let wanted: HashMap<usize, usize> = match_offsets
        .iter()
        .enumerate()
        .map(|(index, &offset)| (offset, index))
        .collect();
    let mut expanded = vec![None; match_offsets.len()];
    let mut expand_at = |offset: usize, caps: &Captures| {
        if let Some(&index) = wanted.get(&offset) {
            expanded[index] = Some(super::expand(caps, replace_pattern));
        }
    };

    if search_pattern.contains('\n') {
        for caps in regex.captures_iter(buffer.as_str()) {
            let found = caps.get(0).expect("group 0 is the match");
            if !found.is_empty() {
                expand_at(found.start(), &caps);
            }
        }
    } else {
        let line_offsets = buffer.line_offsets();
        for (index, line) in buffer.iter_lines().enumerate() {
            for caps in regex.captures_iter(line) {
                let found = caps.get(0).expect("group 0 is the match");
                if !found.is_empty() {
                    expand_at(line_offsets[index] + found.start(), &caps);
                }
            }
        }
    }

    Ok(expanded)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::search::search_in_lines;

    fn lines(text: &[&str]) -> Vec<String> {
        text.iter().map(|line| line.to_string()).collect()
    }

    /// The replacement of every match buffer search lists.
    fn expand_listed(
        text: &[&str],
        pattern: &str,
        replacement: &str,
        flag_fuzzy: bool,
        flag_regex: bool,
    ) -> Vec<Option<String>> {
        let lines = lines(text);
        let listed = search_in_lines(pattern, &lines, flag_fuzzy, flag_regex, true).unwrap();
        let offsets: Vec<usize> = listed.matches.iter().map(|m| m.ox).collect();
        expand_lines_by_matches(&lines, pattern, replacement, flag_regex, true, &offsets).unwrap()
    }

    #[test]
    fn t_each_line_is_matched_on_its_own_as_search_lists_it() {
        /* On the joined text `.` and `\s` would cross the line breaks. */
        assert_eq!(
            expand_listed(&["ab 1", "x", "ab 2"], "a.*b", "#", false, true),
            [Some("#".to_string()), Some("#".to_string())]
        );
        assert_eq!(
            expand_listed(&["foo bar", "baz qux"], r"\s+", "_", false, true),
            [Some("_".to_string()), Some("_".to_string())]
        );
    }

    #[test]
    fn t_groups_are_those_of_the_match_in_its_line() {
        assert_eq!(
            expand_listed(&["a=1 b=2", "c=3"], r"(\w)=(\d)", "$2=$1", false, true),
            [
                Some("1=a".to_string()),
                Some("2=b".to_string()),
                Some("3=c".to_string())
            ]
        );
        /* `\B` needs the letter before the match, which the matched text alone lacks. */
        assert_eq!(
            expand_listed(&["xfoo"], r"\Bfoo", "bar", false, true),
            [Some("bar".to_string())]
        );
    }

    #[test]
    fn t_a_pattern_with_a_line_break_matches_the_joined_lines() {
        assert_eq!(
            expand_listed(
                &["foo", "bar", "foo", "baz"],
                "foo\nba(.)",
                "<$1>",
                false,
                true
            ),
            [Some("<r>".to_string()), Some("<z>".to_string())]
        );
        assert_eq!(
            expand_listed(&["a.", "b"], ".\nb", "!", false, false),
            [Some("!".to_string())]
        );
    }

    #[test]
    fn t_an_offset_no_match_starts_at_takes_no_replacement() {
        /* The second line has no exact match, so fuzzy search lists its pieces. */
        let expanded = expand_listed(&["foo", "f_o_o"], "foo", "bar", true, false);
        assert_eq!(expanded[0], Some("bar".to_string()));
        assert!(expanded.len() > 1, "{expanded:?}");
        assert!(expanded[1..].iter().all(Option::is_none), "{expanded:?}");

        let lines = lines(&["foo foo"]);
        assert_eq!(
            expand_lines_by_matches(&lines, "foo", "bar", false, true, &[4, 1]).unwrap(),
            [Some("bar".to_string()), None]
        );
    }
}
