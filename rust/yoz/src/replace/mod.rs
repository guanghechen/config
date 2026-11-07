mod replace_file;
mod replace_file_by_matches;
mod replace_file_by_matches_advance;
mod replace_file_preview;
mod replace_file_preview_advance;
mod replace_file_preview_by_matches_advance;
mod replace_text_preview;
mod replace_text_preview_advance;
mod replace_text_preview_by_matches;
mod replace_text_preview_by_matches_advance;
pub use replace_file::*;
pub use replace_file_by_matches::*;
pub use replace_file_by_matches_advance::*;
pub use replace_file_preview::*;
pub use replace_file_preview_advance::*;
pub use replace_file_preview_by_matches_advance::*;
pub use replace_text_preview::*;
pub use replace_text_preview_advance::*;
pub use replace_text_preview_by_matches::*;
pub use replace_text_preview_by_matches_advance::*;

use regex::Captures;
use regex::Regex;

/** Replaces the matches of `regex` in `text` with what `replace` returns for each. Search never lists an empty
match, so every empty match stays as it is. */
fn replace_all(regex: &Regex, text: &str, mut replace: impl FnMut(&Captures) -> String) -> String {
    regex
        .replace_all(text, |caps: &Captures| {
            if caps.get(0).is_some_and(|m| m.is_empty()) {
                String::new()
            } else {
                replace(caps)
            }
        })
        .into_owned()
}

/** Expands the replacement for one match as JavaScript does: `$$` is a dollar, and `$n` or `$nn` names a group,
taking two digits when that group exists. A group that took no part expands to nothing, a reference to a group the
pattern lacks stays literal, and captured text is never expanded again. */
fn expand(caps: &Captures, replacement: &str) -> String {
    let mut expanded = String::with_capacity(replacement.len());
    let mut rest = replacement;
    while let Some(at) = rest.find('$') {
        expanded.push_str(&rest[..at]);
        let tail = &rest[at + 1..];
        let digit = |index: usize| {
            tail.as_bytes()
                .get(index)
                .filter(|byte| byte.is_ascii_digit())
                .map(|byte| usize::from(byte - b'0'))
        };
        let reference = match (digit(0), digit(1)) {
            (Some(tens), Some(ones)) if (1..caps.len()).contains(&(tens * 10 + ones)) => {
                Some((tens * 10 + ones, 2))
            }
            (Some(group), _) if (1..caps.len()).contains(&group) => Some((group, 1)),
            _ => None,
        };
        rest = match reference {
            Some((group, len)) => {
                if let Some(cap) = caps.get(group) {
                    expanded.push_str(cap.as_str());
                }
                &tail[len..]
            }
            None if tail.starts_with('$') => {
                expanded.push('$');
                &tail[1..]
            }
            None => {
                expanded.push('$');
                tail
            }
        };
    }
    expanded.push_str(rest);
    expanded
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_replacements_leave_the_empty_matches_search_never_lists() {
        let replaced = |text: &str, pattern: &str, replacement: &str| {
            replace_text_preview(text, pattern, replacement, false, true, true).unwrap()
        };
        assert_eq!(replaced("a;\nb\nc;\n", ";?$", "!"), "a!\nb\nc!\n");
        assert_eq!(replaced("foo\n\nfoo\n\n", "^$|foo", "#"), "#\n\n#\n\n");
        /* Nor do they take part in the preview ranges. */
        let ranges = |keep_search_pieces: bool| {
            let preview = replace_text_preview_advance(
                "a;\nb\nc;\n",
                ";?$",
                "!",
                keep_search_pieces,
                true,
                true,
            )
            .unwrap();
            let ranges: Vec<_> = preview.matches.iter().map(|m| (m.start, m.end)).collect();
            (preview.text, ranges)
        };
        assert_eq!(
            ranges(false),
            ("a!\nb\nc!\n".to_string(), vec![(1, 2), (6, 7)])
        );
        assert_eq!(
            ranges(true),
            (
                "a;!\nb\nc;!\n".to_string(),
                vec![(1, 2), (2, 3), (7, 8), (8, 9)]
            )
        );
    }
}
