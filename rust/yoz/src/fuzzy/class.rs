//! Character classes, scoring constants and per-scheme bonus tables, after fzf's `algo.go` (MIT).

use std::sync::OnceLock;

pub(crate) const SCORE_MATCH: i16 = 16;
pub(crate) const SCORE_GAP_START: i16 = -3;
pub(crate) const SCORE_GAP_EXTENSION: i16 = -1;
/** Bonus at the start of a word; cancelled once the gap between acronym letters grows past eight. */
pub(crate) const BONUS_BOUNDARY: i16 = SCORE_MATCH / 2;
pub(crate) const BONUS_NON_WORD: i16 = SCORE_MATCH / 2;
pub(crate) const BONUS_CAMEL123: i16 = BONUS_BOUNDARY + SCORE_GAP_EXTENSION;
/** Minimum bonus for characters inside a consecutive chunk. */
pub(crate) const BONUS_CONSECUTIVE: i16 = -(SCORE_GAP_START + SCORE_GAP_EXTENSION);
pub(crate) const BONUS_FIRST_CHAR_MULTIPLIER: i16 = 2;

/// Ordered as in fzf: comparisons such as `class >= NonWord` and `class <= Delimiter` rely on it.
#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
#[repr(u8)]
pub(crate) enum CharClass {
    White = 0,
    NonWord = 1,
    Delimiter = 2,
    Lower = 3,
    Upper = 4,
    Letter = 5,
    Number = 6,
}

const CLASSES: usize = 7;

/// fzf's `--scheme`: `path` favours matches after `/` and ranks by the matched part of the basename.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Scheme {
    Default,
    Path,
}

pub(crate) struct Classes {
    /** Every byte, so lookups need no bounds check; bytes past ASCII never reach it. */
    ascii: [CharClass; 256],
    matrix: [[i16; CLASSES]; CLASSES],
    /** Bonus after whitespace and at the start of the string. */
    pub(crate) boundary_white: i16,
    pub(crate) initial: CharClass,
    delimiters: &'static [char],
}

const WHITE: &[char] = &[
    ' ', '\t', '\n', '\u{0b}', '\u{0c}', '\r', '\u{85}', '\u{a0}',
];

impl Classes {
    fn new(scheme: Scheme) -> Self {
        let (boundary_white, boundary_delimiter, delimiters, initial): (
            i16,
            i16,
            &'static [char],
            CharClass,
        ) = match scheme {
            Scheme::Default => (
                BONUS_BOUNDARY + 2,
                BONUS_BOUNDARY + 1,
                &['/', ',', ':', ';', '|'],
                CharClass::White,
            ),
            Scheme::Path => (
                BONUS_BOUNDARY,
                BONUS_BOUNDARY + 1,
                &['/'],
                CharClass::Delimiter,
            ),
        };
        let mut ascii = [CharClass::NonWord; 256];
        for (byte, class) in ascii.iter_mut().enumerate().take(128) {
            let char = byte as u8 as char;
            *class = match char {
                'a'..='z' => CharClass::Lower,
                'A'..='Z' => CharClass::Upper,
                '0'..='9' => CharClass::Number,
                char if WHITE.contains(&char) => CharClass::White,
                char if delimiters.contains(&char) => CharClass::Delimiter,
                _ => CharClass::NonWord,
            };
        }
        let mut classes = Self {
            ascii,
            matrix: [[0; CLASSES]; CLASSES],
            boundary_white,
            initial,
            delimiters,
        };
        let all = [
            CharClass::White,
            CharClass::NonWord,
            CharClass::Delimiter,
            CharClass::Lower,
            CharClass::Upper,
            CharClass::Letter,
            CharClass::Number,
        ];
        for previous in all {
            for class in all {
                classes.matrix[previous as usize][class as usize] =
                    bonus_for(previous, class, boundary_white, boundary_delimiter);
            }
        }
        classes
    }

    #[inline]
    pub(crate) fn of_byte(&self, byte: u8) -> CharClass {
        self.ascii[byte as usize]
    }

    /// Rust's Unicode properties stand in for Go's categories: `is_lowercase` and `is_alphabetic` are
    /// slightly broader than `Ll` and `L`, which only affects non-ASCII text.
    #[inline]
    pub(crate) fn of(&self, char: char) -> CharClass {
        if char.is_ascii() {
            return self.ascii[char as usize];
        }
        if char.is_lowercase() {
            CharClass::Lower
        } else if char.is_uppercase() {
            CharClass::Upper
        } else if char.is_numeric() {
            CharClass::Number
        } else if char.is_alphabetic() {
            CharClass::Letter
        } else if char.is_whitespace() {
            CharClass::White
        } else if self.delimiters.contains(&char) {
            CharClass::Delimiter
        } else {
            CharClass::NonWord
        }
    }

    #[inline]
    pub(crate) fn bonus(&self, previous: CharClass, class: CharClass) -> i16 {
        self.matrix[previous as usize][class as usize]
    }
}

fn bonus_for(
    previous: CharClass,
    class: CharClass,
    boundary_white: i16,
    boundary_delimiter: i16,
) -> i16 {
    if class >= CharClass::NonWord {
        match previous {
            CharClass::White => return boundary_white,
            CharClass::Delimiter => return boundary_delimiter,
            CharClass::NonWord => return BONUS_BOUNDARY,
            _ => {}
        }
    }
    if previous == CharClass::Lower && class == CharClass::Upper
        || previous != CharClass::Number && class == CharClass::Number
    {
        return BONUS_CAMEL123;
    }
    match class {
        CharClass::NonWord | CharClass::Delimiter => BONUS_NON_WORD,
        CharClass::White => boundary_white,
        _ => 0,
    }
}

pub(crate) fn classes(scheme: Scheme) -> &'static Classes {
    static DEFAULT: OnceLock<Classes> = OnceLock::new();
    static PATH: OnceLock<Classes> = OnceLock::new();
    match scheme {
        Scheme::Default => DEFAULT.get_or_init(|| Classes::new(Scheme::Default)),
        Scheme::Path => PATH.get_or_init(|| Classes::new(Scheme::Path)),
    }
}

/// Lowercases one character to one character, as Go's `unicode.To(unicode.LowerCase, …)` does, so match
/// positions keep indexing the original text.
#[inline]
pub(crate) fn to_lower(char: char) -> char {
    if char.is_ascii() {
        return char.to_ascii_lowercase();
    }
    char.to_lowercase().next().unwrap_or(char)
}

#[inline]
pub(crate) fn is_space(char: char) -> bool {
    char.is_whitespace()
}
