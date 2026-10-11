use super::model::{DisplayOptions, Error, Result};
use regex::{Regex, RegexBuilder};

#[derive(Clone)]
pub(crate) struct Matcher {
    exact: Regex,
    fuzzy: Option<Regex>,
}

impl Matcher {
    pub(crate) fn new(display: &DisplayOptions) -> Result<Self> {
        let compile = |pattern: &str| {
            RegexBuilder::new(pattern)
                .case_insensitive(!display.case_sensitive)
                .build()
                .map_err(|error| Error::invalid(error.to_string()))
        };
        let exact = compile(&if display.regex {
            display.pattern.to_string()
        } else {
            regex::escape(&display.pattern)
        })?;
        let fuzzy = if display.fuzzy && !display.regex {
            let pattern = display
                .pattern
                .chars()
                .map(|ch| format!("({})", regex::escape(&ch.to_string())))
                .collect::<Vec<_>>()
                .join(".*?");
            Some(compile(&pattern)?)
        } else {
            None
        };
        Ok(Self { exact, fuzzy })
    }

    pub(crate) fn is_match(&self, label: &str) -> bool {
        self.exact.is_match(label)
            || self
                .fuzzy
                .as_ref()
                .is_some_and(|fuzzy| fuzzy.is_match(label))
    }

    pub(crate) fn ranges(&self, label: &str, limit: usize) -> Vec<(usize, usize)> {
        let exact: Vec<_> = self
            .exact
            .find_iter(label)
            .take(limit)
            .map(|range| (range.start(), range.end()))
            .collect();
        if !exact.is_empty() {
            return exact;
        }
        self.fuzzy
            .as_ref()
            .and_then(|fuzzy| fuzzy.captures(label))
            .map(|captures| {
                captures
                    .iter()
                    .skip(1)
                    .flatten()
                    .take(limit)
                    .map(|range| (range.start(), range.end()))
                    .collect()
            })
            .unwrap_or_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fuzzy_highlights_original_utf8_bytes_and_prefers_literal_matches() {
        let matcher = Matcher::new(&DisplayOptions {
            pattern: "a中".into(),
            fuzzy: true,
            ..DisplayOptions::default()
        })
        .unwrap();
        assert_eq!(matcher.ranges("Ab中", 10), vec![(0, 1), (2, 5)]);
        assert_eq!(matcher.ranges("a中a中", 10), vec![(0, 4), (4, 8)]);
        assert!(!matcher.is_match("中a"));
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
