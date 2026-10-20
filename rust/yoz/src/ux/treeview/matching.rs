use super::model::{DisplayOptions, Error, Result};
use crate::fuzzy::{CaseMode, Scheme, TextMatcher};
use regex::{Regex, RegexBuilder};

/// Label filters: regex patterns, or the fzf syntax, smart case and alignment that pickers use.
#[derive(Clone)]
pub(crate) enum Matcher {
    Regex(Regex),
    Fuzzy(TextMatcher),
}

impl Matcher {
    pub(crate) fn new(display: &DisplayOptions) -> Result<Self> {
        if display.regex {
            return RegexBuilder::new(&display.pattern)
                .case_insensitive(!display.case_sensitive)
                .build()
                .map(Self::Regex)
                .map_err(|error| Error::invalid(error.to_string()));
        }
        let case = if display.case_sensitive {
            CaseMode::Respect
        } else {
            CaseMode::Smart
        };
        Ok(Self::Fuzzy(TextMatcher::new(
            &display.pattern,
            display.fuzzy,
            case,
            Scheme::Path,
        )))
    }

    pub(crate) fn is_match(&self, label: &str) -> bool {
        match self {
            Self::Regex(regex) => regex.is_match(label),
            Self::Fuzzy(matcher) => matcher.is_match(label),
        }
    }

    pub(crate) fn ranges(&self, label: &str, limit: usize) -> Vec<(usize, usize)> {
        match self {
            Self::Regex(regex) => regex
                .find_iter(label)
                .take(limit)
                .map(|range| (range.start(), range.end()))
                .collect(),
            Self::Fuzzy(matcher) => {
                let mut ranges = matcher.ranges(label);
                ranges.truncate(limit);
                ranges
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fuzzy_highlights_original_utf8_bytes_of_the_best_alignment() {
        let matcher = Matcher::new(&DisplayOptions {
            pattern: "a中".into(),
            fuzzy: true,
            ..DisplayOptions::default()
        })
        .unwrap();
        assert_eq!(matcher.ranges("Ab中", 10), vec![(0, 1), (2, 5)]);
        // The occurrence at the start of the label scores higher than the one after a letter.
        assert_eq!(matcher.ranges("a中a中", 10), vec![(0, 4)]);
        assert!(!matcher.is_match("中a"));
        assert_eq!(matcher.ranges("中a", 10), Vec::<(usize, usize)>::new());
    }

    #[test]
    fn labels_follow_the_picker_syntax_and_smart_case() {
        let matcher = |pattern: &str, fuzzy: bool, case_sensitive: bool| {
            Matcher::new(&DisplayOptions {
                pattern: pattern.into(),
                fuzzy,
                case_sensitive,
                ..DisplayOptions::default()
            })
            .unwrap()
        };
        assert!(matcher("RDm", true, false).is_match("README.md"));
        assert!(!matcher("RDm", true, false).is_match("readme.md"));
        assert!(matcher("rdm", true, false).is_match("README.md"));
        assert!(!matcher("rdm", true, true).is_match("README.md"));
        assert!(!matcher("rdm", false, false).is_match("readme.md"));
        assert!(matcher("me.m", false, false).is_match("README.md"));
        assert!(matcher("^read .md$ !test", true, false).is_match("readme.md"));
        assert!(!matcher("^read .md$ !test", true, false).is_match("readme_test.md"));
        assert!(matcher("lua$ | md$", true, false).is_match("init.lua"));
        assert_eq!(
            matcher("rdm", true, false).ranges("README.md", 1),
            vec![(0, 1)]
        );
    }

    #[test]
    fn regex_takes_precedence_and_invalid_patterns_are_rejected() {
        let matcher = Matcher::new(&DisplayOptions {
            pattern: "^A[0-9]+$".into(),
            regex: true,
            fuzzy: true,
            ..DisplayOptions::default()
        })
        .unwrap();
        assert_eq!(matcher.ranges("a12", 10), vec![(0, 3)]);
        assert!(!matcher.is_match("ba12"));
        assert!(
            Matcher::new(&DisplayOptions {
                pattern: "[".into(),
                regex: true,
                ..DisplayOptions::default()
            })
            .is_err()
        );
    }
}
