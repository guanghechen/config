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
use std::fs;
use std::fs::File;
use std::io::Write;

/** A UTF-8 byte order mark. */
const BOM: &str = "\u{feff}";

/** Reads a file's text as file search does: a leading UTF-8 byte order mark is left out, so the match offsets of a
search index the text, as Neovim's buffer lines do. Also returns whether the file starts with one. */
fn read_text(filepath: &str) -> Result<(bool, String), String> {
    let mut text = fs::read_to_string(filepath).map_err(|e| e.to_string())?;
    let bom = text.starts_with(BOM);
    if bom {
        text.drain(..BOM.len());
    }
    Ok((bom, text))
}

/** Writes `text` over a file, after the byte order mark `read_text` left out of it. */
fn write_text(filepath: &str, bom: bool, text: &str) -> Result<(), String> {
    let mut file = File::create(filepath).map_err(|e| e.to_string())?;
    if bom {
        file.write_all(BOM.as_bytes()).map_err(|e| e.to_string())?;
    }
    file.write_all(text.as_bytes()).map_err(|e| e.to_string())
}

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
    use crate::search::search_in_files;
    use crate::test_support::TempDir;
    use crate::types::ISearchInFilesOptions;

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

    /** The match offsets file search reports for `pattern` in the only file under `dir`. */
    fn search_offsets(dir: &TempDir, pattern: &str, regex: bool) -> Vec<usize> {
        let options = ISearchInFilesOptions {
            cwd: Some(dir.path().to_str().unwrap().to_string()),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: regex,
            max_filesize: None,
            max_matches: None,
            search_pattern: pattern.to_string(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
            specified_filepath: None,
        };
        let result = search_in_files(&options).unwrap();
        result
            .items
            .first()
            .map_or_else(Vec::new, |item| item.matches.iter().map(|m| m.ox).collect())
    }

    #[test]
    fn t_a_byte_order_mark_stays_out_of_the_text_search_offsets_index_and_in_the_file() {
        let dir = TempDir::new();
        let path = dir.path().join("text");
        fs::write(&path, "\u{feff}abcabcabc\nabc\n").unwrap();
        let file = path.to_str().unwrap();

        /* The second match, not the first one three bytes after the mark. */
        let offsets = search_offsets(&dir, "abc", false);
        assert_eq!(offsets, vec![0, 3, 6, 10]);
        let preview =
            replace_file_preview_by_matches_advance(file, "abc", "X", false, false, true, &[3])
                .unwrap();
        assert_eq!(preview.text, "abcXabc\nabc\n");
        let result =
            replace_file_by_matches_advance(file, "abc", "X", false, true, &[3], &[6, 10]).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "\u{feff}abcXabc\nabc\n");
        let remaining: Vec<usize> = result.locations.iter().map(|l| l.offset).collect();
        assert_eq!(remaining, search_offsets(&dir, "abc", false)[1..]);

        /* The first line starts after the mark, as in search. */
        assert_eq!(search_offsets(&dir, "^abc", true), vec![0, 8]);
        replace_file_by_matches(file, "^abc", "Y", true, true, &[0]).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "\u{feff}YXabc\nabc\n");
        replace_file(file, "^abc", "Y", true, true).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "\u{feff}YXabc\nY\n");

        /* Previews show the text search lists, without the mark. */
        assert_eq!(
            replace_file_preview(file, "X", "Z", false, false, true).unwrap(),
            "YZabc\nY\n"
        );
        let preview = replace_file_preview_advance(file, "Y", "W", false, true, true).unwrap();
        assert_eq!(preview.text, "WXabc\nW\n");
        let ranges: Vec<_> = preview.matches.iter().map(|m| (m.start, m.end)).collect();
        assert_eq!(ranges, vec![(0, 1), (6, 7)]);

        /* A file that is only the mark has no text to change. */
        fs::write(&path, "\u{feff}").unwrap();
        replace_file(file, "^", "X", true, true).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "\u{feff}");
    }

    /** A linear congruential generator, so the cases are the same on every run. */
    struct Cases(u64);

    impl Cases {
        fn below(&mut self, bound: usize) -> usize {
            self.0 = self
                .0
                .wrapping_mul(6364136223846793005)
                .wrapping_add(1442695040888963407);
            ((self.0 >> 33) as usize) % bound
        }
    }

    #[test]
    fn t_every_search_offset_names_the_match_its_replacement_changes() {
        let dir = TempDir::new();
        let path = dir.path().join("text");
        let file = path.to_str().unwrap();
        let pieces = ["ab", "a", "b", "\n", "\r\n", "\u{feff}", "é"];
        let patterns = [
            ("ab", false),
            ("é", false),
            ("b\\r?\\na", true),
            ("^a", true),
            ("b$", true),
        ];
        let mut cases = Cases(62);
        let mut replaced = 0;
        for case in 0..200 {
            let mut content = String::from(if case % 2 == 0 { BOM } else { "" });
            for _ in 0..=cases.below(12) {
                content.push_str(pieces[cases.below(pieces.len())]);
            }
            let (pattern, regex) = patterns[cases.below(patterns.len())];
            /* Search and replacement both leave out one leading mark, whichever piece put it there. */
            let (mark, text) = match content.strip_prefix(BOM) {
                Some(text) => (BOM, text),
                None => ("", content.as_str()),
            };
            fs::write(&path, &content).unwrap();
            for offset in search_offsets(&dir, pattern, regex) {
                let found = crate::search::matcher(pattern, regex, true)
                    .unwrap()
                    .find_iter(text)
                    .find(|m| m.start() == offset);
                let Some(found) = found else {
                    panic!("{content:?} /{pattern}/: no match at offset {offset}");
                };
                fs::write(&path, &content).unwrap();
                replace_file_by_matches(file, pattern, "X", regex, true, &[offset]).unwrap();
                let expected = format!("{mark}{}X{}", &text[..found.start()], &text[found.end()..]);
                assert_eq!(
                    fs::read_to_string(&path).unwrap(),
                    expected,
                    "{content:?} /{pattern}/ at {offset}"
                );
                replaced += 1;
            }
        }
        assert!(replaced > 100, "only {replaced} replacements");
    }
}
