//! Matching one text at a time, for filters that walk a tree rather than a corpus: Treeview labels in
//! the Explorer. Semantics follow the corpus: fzf's syntax, smart case and alignment.

use super::algo::{Scratch, Text};
use super::class::{Scheme, classes};
use super::matcher::{self, Options};
use super::pattern::{self, CaseMode, Pattern};
use std::cell::RefCell;

thread_local! {
    static SCRATCH: RefCell<(Scratch, Vec<char>)> = RefCell::new((Scratch::default(), Vec::new()));
}

/// Byte ranges of character `positions` in `text`, merged into runs.
pub(crate) fn byte_ranges(text: &str, mut positions: Vec<usize>) -> Vec<(usize, usize)> {
    positions.sort_unstable();
    positions.dedup();
    let offsets: Vec<usize> = if text.is_ascii() {
        Vec::new()
    } else {
        text.char_indices()
            .map(|(offset, _)| offset)
            .chain(std::iter::once(text.len()))
            .collect()
    };
    let byte = |at: usize| if offsets.is_empty() { at } else { offsets[at] };
    let mut ranges: Vec<(usize, usize)> = Vec::new();
    for at in positions {
        let (start, end) = (byte(at), byte(at + 1));
        match ranges.last_mut() {
            Some(last) if last.1 == start => last.1 = end,
            _ => ranges.push((start, end)),
        }
    }
    ranges
}

#[derive(Clone, Debug)]
pub(crate) struct TextMatcher {
    pattern: Pattern,
    scheme: Scheme,
}

impl TextMatcher {
    pub(crate) fn new(query: &str, fuzzy: bool, case: CaseMode, scheme: Scheme) -> Self {
        Self {
            pattern: pattern::parse(query, fuzzy, case),
            scheme,
        }
    }

    fn with_text<R>(text: &str, run: impl FnOnce(Text, &mut Scratch) -> R) -> R {
        SCRATCH.with(|scratch| {
            let (scratch, chars) = &mut *scratch.borrow_mut();
            if text.is_ascii() {
                return run(Text::Bytes(text.as_bytes()), scratch);
            }
            chars.clear();
            chars.extend(text.chars());
            run(Text::Chars(chars), scratch)
        })
    }

    fn options(&self, with_pos: bool) -> Options {
        Options {
            forward: self.scheme != Scheme::Path,
            with_pos,
            fallback: true,
        }
    }

    pub(crate) fn is_match(&self, text: &str) -> bool {
        let options = self.options(false);
        Self::with_text(text, |text, scratch| {
            matcher::is_match(classes(self.scheme), &self.pattern, text, &options, scratch)
        })
    }

    /// Matched byte ranges, merged into runs; empty when the text does not match.
    pub(crate) fn ranges(&self, text: &str) -> Vec<(usize, usize)> {
        let options = self.options(true);
        let mut positions = Vec::new();
        let matched = Self::with_text(text, |chars, scratch| {
            matcher::match_item(
                classes(self.scheme),
                &self.pattern,
                chars,
                &options,
                scratch,
                Some(&mut positions),
            )
            .is_some()
        });
        if matched {
            byte_ranges(text, positions)
        } else {
            Vec::new()
        }
    }
}
