//! Match functions ported from fzf's `algo.go` (v0.74.5, MIT, © Junegunn Choi): FuzzyMatchV2 (a modified
//! Smith-Waterman that finds the highest-scoring alignment), FuzzyMatchV1 (greedy, for long input) and the
//! exact, prefix, suffix and equal matchers. Positions and offsets index characters of the text.
//!
//! `pattern` is lowercase when matching case-insensitively. ASCII text matches as bytes, with fzf's fast
//! paths for one- and two-character patterns.

use super::class::{
    BONUS_BOUNDARY, BONUS_CONSECUTIVE, BONUS_FIRST_CHAR_MULTIPLIER, CharClass, Classes,
    SCORE_GAP_EXTENSION, SCORE_GAP_START, SCORE_MATCH, is_space, to_lower,
};

/** fzf's per-thread int16 slab; V2 falls back to V1 when the score matrix would not fit in it. */
pub(crate) const SLAB16: usize = 100 * 1024;
/** Longer patterns could overflow the 16-bit score matrix. */
const MAX_PATTERN: usize = 1000;

#[derive(Clone, Copy)]
pub(crate) enum Text<'a> {
    Bytes(&'a [u8]),
    Chars(&'a [char]),
}

impl Text<'_> {
    #[inline]
    pub(crate) fn len(&self) -> usize {
        match self {
            Text::Bytes(bytes) => bytes.len(),
            Text::Chars(chars) => chars.len(),
        }
    }

    #[inline]
    pub(crate) fn get(&self, index: usize) -> char {
        match self {
            Text::Bytes(bytes) => bytes[index] as char,
            Text::Chars(chars) => chars[index],
        }
    }

    pub(crate) fn leading_whitespaces(&self) -> usize {
        (0..self.len())
            .take_while(|&index| is_space(self.get(index)))
            .count()
    }

    pub(crate) fn trailing_whitespaces(&self) -> usize {
        (0..self.len())
            .rev()
            .take_while(|&index| is_space(self.get(index)))
            .count()
    }

    /// Length without leading and trailing whitespace, fzf's `TrimLength`.
    pub(crate) fn trim_len(&self) -> usize {
        let trailing = self.trailing_whitespaces();
        if trailing == self.len() {
            return 0;
        }
        self.len() - trailing - self.leading_whitespaces()
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct Found {
    /** The first matched character when positions were traced, otherwise a lower bound. */
    pub(crate) start: usize,
    pub(crate) end: usize,
    pub(crate) score: i32,
}

/// Reusable buffers; one per thread, like fzf's slab.
#[derive(Default)]
pub(crate) struct Scratch {
    h0: Vec<i16>,
    c0: Vec<i16>,
    b: Vec<i16>,
    f: Vec<i32>,
    h: Vec<i16>,
    c: Vec<i16>,
    bytes: Vec<u8>,
    chars: Vec<char>,
    pattern: Vec<u8>,
    /** Matched character indices of the last fuzzy match traced with `with_pos`, in no particular order. */
    pub(crate) positions: Vec<usize>,
}

/// A text element: ASCII items match as bytes, others as characters.
pub(super) trait Symbol: Copy + Eq + Default {
    /// The class, and the element to compare, lowercased unless `case_sensitive`.
    fn fold(self, classes: &Classes, case_sensitive: bool) -> (Self, CharClass);
}

impl Symbol for u8 {
    #[inline]
    fn fold(self, classes: &Classes, case_sensitive: bool) -> (u8, CharClass) {
        let class = classes.of_byte(self);
        (
            if !case_sensitive && class == CharClass::Upper {
                self + 32
            } else {
                self
            },
            class,
        )
    }
}

impl Symbol for char {
    #[inline]
    fn fold(self, classes: &Classes, case_sensitive: bool) -> (char, CharClass) {
        if self.is_ascii() {
            let (byte, class) = (self as u8).fold(classes, case_sensitive);
            return (byte as char, class);
        }
        let class = classes.of(self);
        (
            if !case_sensitive && class == CharClass::Upper {
                to_lower(self)
            } else {
                self
            },
            class,
        )
    }
}

#[inline]
fn index_at(index: usize, max: usize, forward: bool) -> usize {
    if forward { index } else { max - index - 1 }
}

#[inline]
fn lower_any(char: char, case_sensitive: bool) -> char {
    if case_sensitive { char } else { to_lower(char) }
}

fn bonus_at(classes: &Classes, text: Text, index: usize) -> i16 {
    if index == 0 {
        return classes.boundary_white;
    }
    classes.bonus(classes.of(text.get(index - 1)), classes.of(text.get(index)))
}

const ONES: u64 = 0x0101_0101_0101_0101;
const LOW7: u64 = 0x7f7f_7f7f_7f7f_7f7f;

/// 0x80 in every zero byte of `word`, without the false positives of the shorter carry trick.
#[inline]
fn zero_bytes(word: u64) -> u64 {
    !(((word & LOW7) + LOW7) | word | LOW7)
}

#[inline]
fn word_at(bytes: &[u8], at: usize) -> u64 {
    u64::from_le_bytes(bytes[at..at + 8].try_into().unwrap())
}

/// The byte to search for and the mask that folds case: `value | 0x20` equals a lowercase letter only
/// for that letter and its uppercase form.
#[inline]
fn needle(case_sensitive: bool, byte: u8) -> (u8, u8) {
    (
        byte,
        if !case_sensitive && byte.is_ascii_lowercase() {
            0x20
        } else {
            0
        },
    )
}

/// fzf's `trySkip`: the first occurrence of `byte` at or after `from`, eight bytes at a time.
#[inline]
fn try_skip(bytes: &[u8], case_sensitive: bool, byte: u8, from: usize) -> Option<usize> {
    let (byte, fold) = needle(case_sensitive, byte);
    let (pattern, mask) = (byte as u64 * ONES, fold as u64 * ONES);
    let mut at = from;
    while at + 8 <= bytes.len() {
        let found = zero_bytes((word_at(bytes, at) | mask) ^ pattern);
        if found != 0 {
            return Some(at + (found.trailing_zeros() / 8) as usize);
        }
        at += 8;
    }
    bytes[at..]
        .iter()
        .position(|&value| value | fold == byte)
        .map(|index| at + index)
}

/// The last occurrence of `byte` in `bytes`.
#[inline]
fn last_index(bytes: &[u8], case_sensitive: bool, byte: u8) -> Option<usize> {
    let (byte, fold) = needle(case_sensitive, byte);
    let (pattern, mask) = (byte as u64 * ONES, fold as u64 * ONES);
    let mut end = bytes.len();
    while end >= 8 {
        let found = zero_bytes((word_at(bytes, end - 8) | mask) ^ pattern);
        if found != 0 {
            return Some(end - 8 + (7 - found.leading_zeros() / 8) as usize);
        }
        end -= 8;
    }
    bytes[..end].iter().rposition(|&value| value | fold == byte)
}

/// fzf's `asciiFuzzyIndex`: the range that can hold a match, from one character before the first
/// pattern character through the last occurrence of the final one. Text that is not ASCII is searched
/// whole.
pub(crate) fn fuzzy_index(
    text: Text,
    pattern: &[char],
    case_sensitive: bool,
) -> Option<(usize, usize)> {
    let Text::Bytes(bytes) = text else {
        return Some((0, text.len()));
    };
    if !pattern.iter().all(char::is_ascii) {
        return None;
    }
    let (mut first, mut index, mut last, mut byte) = (0, 0, 0, 0u8);
    for (at, &char) in pattern.iter().enumerate() {
        byte = char as u8;
        index = try_skip(bytes, case_sensitive, byte, index)?;
        if at == 0 && index > 0 {
            // Step back so the first character's bonus sees its predecessor.
            first = index - 1;
        }
        last = index;
        index += 1;
    }
    match last_index(&bytes[last + 1..], case_sensitive, byte) {
        Some(end) => Some((first, last + 1 + end + 1)),
        None => Some((first, last + 1)),
    }
}

/// FuzzyMatchV2. `fallback` mirrors fzf passing a slab: without one, long input never falls back to V1.
/// With `with_pos`, the start is exact and `scratch.positions` holds the matched characters.
// Hot path that keeps fzf's argument list; packing the slices and flags into a struct would only rename them.
#[allow(clippy::too_many_arguments)]
pub(crate) fn fuzzy_v2(
    classes: &Classes,
    case_sensitive: bool,
    forward: bool,
    text: Text,
    pattern: &[char],
    with_pos: bool,
    scratch: &mut Scratch,
    fallback: bool,
) -> Option<Found> {
    let m = pattern.len();
    if with_pos {
        scratch.positions.clear();
    }
    if m == 0 {
        return Some(Found {
            start: 0,
            end: 0,
            score: 0,
        });
    }
    let full = text.len();
    if m > full {
        return None;
    }
    if fallback && full * m > SLAB16 || m > MAX_PATTERN {
        let positions = with_pos.then_some(&mut scratch.positions);
        return fuzzy_v1(classes, case_sensitive, forward, text, pattern, positions);
    }
    match text {
        Text::Bytes(bytes) => {
            if !pattern.iter().all(char::is_ascii) {
                return None;
            }
            if m == 1 {
                return single(
                    classes,
                    case_sensitive,
                    forward,
                    bytes,
                    pattern[0] as u8,
                    with_pos,
                    scratch,
                );
            }
            let (min_idx, max_idx) = fuzzy_index(text, pattern, case_sensitive)?;
            if m == 2 {
                let pair = (pattern[0] as u8, pattern[1] as u8);
                return two(
                    classes,
                    case_sensitive,
                    forward,
                    bytes,
                    pair,
                    min_idx,
                    max_idx,
                    with_pos,
                    scratch,
                );
            }
            let mut buffer = std::mem::take(&mut scratch.pattern);
            buffer.clear();
            buffer.extend(pattern.iter().map(|&char| char as u8));
            let mut t = std::mem::take(&mut scratch.bytes);
            t.clear();
            t.extend_from_slice(&bytes[min_idx..max_idx]);
            let found = general(
                classes,
                case_sensitive,
                forward,
                &mut t,
                &buffer,
                min_idx,
                with_pos,
                scratch,
            );
            scratch.pattern = buffer;
            scratch.bytes = t;
            found
        }
        Text::Chars(chars) => {
            let mut t = std::mem::take(&mut scratch.chars);
            t.clear();
            t.extend_from_slice(chars);
            let found = general(
                classes,
                case_sensitive,
                forward,
                &mut t,
                pattern,
                0,
                with_pos,
                scratch,
            );
            scratch.chars = t;
            found
        }
    }
}

/// fzf's `fuzzyMatchV2Single`: the occurrence with the best first-character bonus, without score arrays.
pub(super) fn single(
    classes: &Classes,
    case_sensitive: bool,
    forward: bool,
    bytes: &[u8],
    byte: u8,
    with_pos: bool,
    scratch: &mut Scratch,
) -> Option<Found> {
    let (mut max_score, mut max_score_pos) = (0i16, None::<usize>);
    let mut index = 0;
    while let Some(at) = try_skip(bytes, case_sensitive, byte, index) {
        let class = classes.of_byte(bytes[at]);
        let previous = if at > 0 {
            classes.of_byte(bytes[at - 1])
        } else {
            classes.initial
        };
        let bonus = classes.bonus(previous, class);
        let score = SCORE_MATCH + bonus * BONUS_FIRST_CHAR_MULTIPLIER;
        if forward && score > max_score || !forward && score >= max_score {
            max_score = score;
            max_score_pos = Some(at);
            if forward && bonus >= BONUS_BOUNDARY {
                break;
            }
        }
        index = at + 1;
    }
    let at = max_score_pos?;
    if with_pos {
        scratch.positions.push(at);
    }
    Some(Found {
        start: at,
        end: at + 1,
        score: max_score as i32,
    })
}

/// fzf's `fuzzyMatchV2Two`: rows 0 and 1 of V2 in one pass over scalars; the rows are stored only for
/// the backtrace.
// Hot path that keeps fzf's argument list; packing the slices and flags into a struct would only rename them.
#[allow(clippy::too_many_arguments)]
pub(super) fn two(
    classes: &Classes,
    case_sensitive: bool,
    forward: bool,
    bytes: &[u8],
    (pchar0, pchar1): (u8, u8),
    min_idx: usize,
    max_idx: usize,
    with_pos: bool,
    scratch: &mut Scratch,
) -> Option<Found> {
    let n = max_idx - min_idx;
    let Scratch {
        h0,
        c0,
        h,
        c,
        positions,
        ..
    } = scratch;
    if with_pos {
        for row in [&mut *h0, &mut *c0, &mut *h, &mut *c] {
            row.clear();
            row.resize(n, 0);
        }
    }

    let (mut max_score, mut max_score_pos) = (0i16, 0usize);
    let mut prev_class = classes.initial;
    let (mut f0, mut f1) = (None::<usize>, None::<usize>);
    let (mut h0_prev, mut c0_prev, mut b_prev) = (0i16, 0i16, 0i16);
    let mut in_gap0 = false;
    let mut h1_prev = 0i16;
    let mut in_gap1 = false;

    for (off, &byte) in bytes[min_idx..max_idx].iter().enumerate() {
        let (lower, class) = byte.fold(classes, case_sensitive);
        let bonus = classes.bonus(prev_class, class);
        prev_class = class;

        if f0.is_none() {
            if lower == pchar0 {
                f0 = Some(off);
            }
        } else if lower == pchar1 && f1.is_none() {
            f1 = Some(off);
        }

        let (h0_cur, c0_cur);
        if lower == pchar0 {
            h0_cur = SCORE_MATCH + bonus * BONUS_FIRST_CHAR_MULTIPLIER;
            c0_cur = 1;
            in_gap0 = false;
        } else {
            h0_cur = (h0_prev
                + if in_gap0 {
                    SCORE_GAP_EXTENSION
                } else {
                    SCORE_GAP_START
                })
            .max(0);
            c0_cur = 0;
            in_gap0 = true;
        }
        if with_pos {
            h0[off] = h0_cur;
            c0[off] = c0_cur;
        }

        if let Some(first) = f1.filter(|&first| off >= first) {
            let (mut s1, mut consecutive) = (0i16, 0i16);
            let left = if off == first { 0 } else { h1_prev };
            let s2 = left
                + if in_gap1 {
                    SCORE_GAP_EXTENSION
                } else {
                    SCORE_GAP_START
                };
            if lower == pchar1 {
                s1 = h0_prev + SCORE_MATCH;
                let mut boosted = bonus;
                consecutive = c0_prev + 1;
                if consecutive > 1 {
                    if bonus >= BONUS_BOUNDARY && bonus > b_prev {
                        consecutive = 1;
                    } else {
                        boosted = bonus.max(BONUS_CONSECUTIVE).max(b_prev);
                    }
                }
                if s1 + boosted < s2 {
                    s1 += bonus;
                    consecutive = 0;
                } else {
                    s1 += boosted;
                }
            }
            in_gap1 = s1 < s2;
            let score = s1.max(s2).max(0);
            if forward && score > max_score || !forward && score >= max_score {
                max_score = score;
                max_score_pos = off;
            }
            h1_prev = score;
            if with_pos {
                h[off] = score;
                c[off] = consecutive;
            }
        }

        h0_prev = h0_cur;
        c0_prev = c0_cur;
        b_prev = bonus;
    }

    let (f0, f1) = (f0?, f1?);
    let end = min_idx + max_score_pos + 1;
    if !with_pos {
        return Some(Found {
            start: min_idx + f0,
            end,
            score: max_score as i32,
        });
    }

    // The backtrace of the general path, specialized to two rows; row 1 is unwritten left of f1.
    let (mut i, mut j) = (1, max_score_pos);
    let mut prefer_match = true;
    loop {
        let (s, current, s1, s2);
        if i == 1 {
            (s, current) = (h[j], c[j]);
            s1 = if j >= f1 { h0[j - 1] } else { 0 };
            s2 = if j > f1 { h[j - 1] } else { 0 };
        } else {
            (s, current) = (h0[j], c0[j]);
            s1 = 0;
            s2 = if j > f0 { h0[j - 1] } else { 0 };
        }
        let row = i;
        if s > s1 && (s > s2 || s == s2 && prefer_match) {
            positions.push(j + min_idx);
            if i == 0 {
                break;
            }
            i -= 1;
        }
        prefer_match = current > 1 || row == 0 && j + 1 < n && j + 1 >= f1 && c[j + 1] > 0;
        j -= 1;
    }
    Some(Found {
        start: min_idx + j,
        end,
        score: max_score as i32,
    })
}

/// Phases 2 to 4 of V2 over `t`, the candidate range copied from the text; lowercased in place.
// Hot path that keeps fzf's argument list; packing the slices and flags into a struct would only rename them.
#[allow(clippy::too_many_arguments)]
pub(super) fn general<S: Symbol>(
    classes: &Classes,
    case_sensitive: bool,
    forward: bool,
    t: &mut [S],
    pattern: &[S],
    min_idx: usize,
    with_pos: bool,
    scratch: &mut Scratch,
) -> Option<Found> {
    let (m, n) = (pattern.len(), t.len());
    let Scratch {
        h0,
        c0,
        b,
        f,
        h,
        c,
        positions,
        ..
    } = scratch;
    for row in [&mut *h0, &mut *c0, &mut *b] {
        row.clear();
        row.resize(n, 0);
    }
    f.clear();
    f.resize(m, 0);

    // Phase 2. Bonus for each position, the first occurrence of each pattern character and row 0.
    let (h0, c0, b) = (&mut h0[..n], &mut c0[..n], &mut b[..n]);
    let (mut max_score, mut max_score_pos) = (0i16, 0usize);
    let (mut pidx, mut last_idx) = (0usize, 0usize);
    let pchar0 = pattern[0];
    let mut pchar = pattern[0];
    let mut prev_h0 = 0i16;
    let mut prev_class = classes.initial;
    let mut in_gap = false;
    for off in 0..n {
        let (char, class) = t[off].fold(classes, case_sensitive);
        t[off] = char;
        let bonus = classes.bonus(prev_class, class);
        b[off] = bonus;
        prev_class = class;

        if char == pchar {
            if pidx < m {
                f[pidx] = off as i32;
                pidx += 1;
                pchar = pattern[pidx.min(m - 1)];
            }
            last_idx = off;
        }

        if char == pchar0 {
            let score = SCORE_MATCH + bonus * BONUS_FIRST_CHAR_MULTIPLIER;
            h0[off] = score;
            c0[off] = 1;
            if m == 1 && (forward && score > max_score || !forward && score >= max_score) {
                max_score = score;
                max_score_pos = off;
                if forward && bonus >= BONUS_BOUNDARY {
                    break;
                }
            }
            in_gap = false;
        } else {
            h0[off] = (prev_h0
                + if in_gap {
                    SCORE_GAP_EXTENSION
                } else {
                    SCORE_GAP_START
                })
            .max(0);
            c0[off] = 0;
            in_gap = true;
        }
        prev_h0 = h0[off];
    }
    if pidx != m {
        return None;
    }
    if m == 1 {
        if with_pos {
            positions.push(min_idx + max_score_pos);
        }
        let start = min_idx + max_score_pos;
        return Some(Found {
            start,
            end: start + 1,
            score: max_score as i32,
        });
    }

    // Phase 3. Fill in the score matrix; omitting a pattern character is not allowed.
    let f0 = f[0] as usize;
    let width = last_idx - f0 + 1;
    for matrix in [&mut *h, &mut *c] {
        matrix.clear();
        matrix.resize(width * m, 0);
    }
    h[..width].copy_from_slice(&h0[f0..=last_idx]);
    c[..width].copy_from_slice(&c0[f0..=last_idx]);

    for row_index in 1..m {
        let first = f[row_index] as usize;
        let pchar = pattern[row_index];
        let row = row_index * width;
        let len = last_idx + 1 - first;
        let column = first - f0;
        // This row from column `first`, and the row above from the column before.
        let (h_above, h_row) = h.split_at_mut(row);
        let (c_above, c_row) = c.split_at_mut(row);
        h_row[column - 1] = 0;
        let h_diagonal = &h_above[row - width + column - 1..][..len];
        let c_diagonal = &c_above[row - width + column - 1..][..len];
        let h_row = &mut h_row[column..][..len];
        let c_row = &mut c_row[column..][..len];
        let t_row = &t[first..][..len];
        let b_row = &b[first..][..len];
        let last_row = row_index == m - 1;
        let (mut left, mut in_gap) = (0i16, false);
        for k in 0..len {
            let s2 = left
                + if in_gap {
                    SCORE_GAP_EXTENSION
                } else {
                    SCORE_GAP_START
                };
            let mut s1 = 0i16;
            let mut consecutive = 0i16;
            if pchar == t_row[k] {
                s1 = h_diagonal[k] + SCORE_MATCH;
                let mut bonus = b_row[k];
                consecutive = c_diagonal[k] + 1;
                if consecutive > 1 {
                    let first_bonus = b[first + k + 1 - consecutive as usize];
                    // Break the consecutive chunk at a stronger boundary.
                    if bonus >= BONUS_BOUNDARY && bonus > first_bonus {
                        consecutive = 1;
                    } else {
                        bonus = bonus.max(BONUS_CONSECUTIVE).max(first_bonus);
                    }
                }
                if s1 + bonus < s2 {
                    s1 += b_row[k];
                    consecutive = 0;
                } else {
                    s1 += bonus;
                }
            }
            c_row[k] = consecutive;
            in_gap = s1 < s2;
            let score = s1.max(s2).max(0);
            if last_row && (forward && score > max_score || !forward && score >= max_score) {
                max_score = score;
                max_score_pos = first + k;
            }
            h_row[k] = score;
            left = score;
        }
    }

    // Phase 4. Backtrace the character positions.
    let mut j = f0;
    if with_pos {
        let mut i = m - 1;
        j = max_score_pos;
        let mut prefer_match = true;
        loop {
            let row = i * width;
            let j0 = j - f0;
            let s = h[row + j0];
            let (mut s1, mut s2) = (0i16, 0i16);
            if i > 0 && j >= f[i] as usize {
                s1 = h[row - width + j0 - 1];
            }
            if j > f[i] as usize {
                s2 = h[row + j0 - 1];
            }
            let current = i;
            if s > s1 && (s > s2 || s == s2 && prefer_match) {
                positions.push(j + min_idx);
                if i == 0 {
                    break;
                }
                i -= 1;
            }
            // The row below is only written from column F[row + 1].
            prefer_match = c[row + j0] > 1
                || current + 1 < m
                    && j < last_idx
                    && (j + 1) as i32 >= f[current + 1]
                    && c[row + width + j0 + 1] > 0;
            j -= 1;
        }
    }
    Some(Found {
        start: min_idx + j,
        end: min_idx + max_score_pos + 1,
        score: max_score as i32,
    })
}

/// Scores the span the way V2 would; used by V1 and the exact matchers.
fn calculate_score(
    classes: &Classes,
    case_sensitive: bool,
    text: Text,
    pattern: &[char],
    start: usize,
    end: usize,
    mut positions: Option<&mut Vec<usize>>,
) -> i32 {
    let (mut pidx, mut score, mut in_gap, mut consecutive, mut first_bonus) =
        (0usize, 0i32, false, 0, 0i16);
    let mut prev_class = if start > 0 {
        classes.of(text.get(start - 1))
    } else {
        classes.initial
    };
    for index in start..end {
        let original = text.get(index);
        let class = classes.of(original);
        let char = lower_any(original, case_sensitive);
        if char == pattern[pidx] {
            if let Some(positions) = positions.as_mut() {
                positions.push(index);
            }
            score += SCORE_MATCH as i32;
            let mut bonus = classes.bonus(prev_class, class);
            if consecutive == 0 {
                first_bonus = bonus;
            } else {
                if bonus >= BONUS_BOUNDARY && bonus > first_bonus {
                    first_bonus = bonus;
                }
                bonus = bonus.max(first_bonus).max(BONUS_CONSECUTIVE);
            }
            score += if pidx == 0 {
                (bonus * BONUS_FIRST_CHAR_MULTIPLIER) as i32
            } else {
                bonus as i32
            };
            in_gap = false;
            consecutive += 1;
            pidx += 1;
        } else {
            score += if in_gap {
                SCORE_GAP_EXTENSION
            } else {
                SCORE_GAP_START
            } as i32;
            in_gap = true;
            consecutive = 0;
            first_bonus = 0;
        }
        prev_class = class;
    }
    score
}

/// FuzzyMatchV1: the first occurrence scanning in `forward` direction, then shrunk from its end.
pub(crate) fn fuzzy_v1(
    classes: &Classes,
    case_sensitive: bool,
    forward: bool,
    text: Text,
    pattern: &[char],
    positions: Option<&mut Vec<usize>>,
) -> Option<Found> {
    if pattern.is_empty() {
        return Some(Found {
            start: 0,
            end: 0,
            score: 0,
        });
    }
    fuzzy_index(text, pattern, case_sensitive)?;
    let (len, m) = (text.len(), pattern.len());
    let (mut pidx, mut start, mut end) = (0usize, None, None);
    for index in 0..len {
        let char = lower_any(text.get(index_at(index, len, forward)), case_sensitive);
        if char == pattern[index_at(pidx, m, forward)] {
            start.get_or_insert(index);
            pidx += 1;
            if pidx == m {
                end = Some(index + 1);
                break;
            }
        }
    }
    let (Some(mut start), Some(mut end)) = (start, end) else {
        return None;
    };
    let mut pidx = pidx as isize - 1;
    for index in (start..end).rev() {
        let char = lower_any(text.get(index_at(index, len, forward)), case_sensitive);
        if char == pattern[index_at(pidx as usize, m, forward)] {
            pidx -= 1;
            if pidx < 0 {
                start = index;
                break;
            }
        }
    }
    if !forward {
        (start, end) = (len - end, len - start);
    }
    let score = calculate_score(
        classes,
        case_sensitive,
        text,
        pattern,
        start,
        end,
        positions,
    );
    Some(Found { start, end, score })
}

/// ExactMatchNaive, or ExactMatchBoundary when `boundary` holds: the occurrence with the best bonus at
/// its first character.
pub(crate) fn exact(
    classes: &Classes,
    case_sensitive: bool,
    forward: bool,
    boundary: bool,
    text: Text,
    pattern: &[char],
) -> Option<Found> {
    if pattern.is_empty() {
        return Some(Found {
            start: 0,
            end: 0,
            score: 0,
        });
    }
    let (len, m) = (text.len(), pattern.len());
    if len < m {
        return None;
    }
    fuzzy_index(text, pattern, case_sensitive)?;

    let mut pidx = 0usize;
    let (mut best_pos, mut bonus, mut boundary_bonus, mut best_bonus) =
        (None::<usize>, 0i16, 0i16, -1i16);
    let mut index = 0isize;
    while (index as usize) < len {
        let at = index_at(index as usize, len, forward);
        let char = lower_any(text.get(at), case_sensitive);
        let pattern_at = index_at(pidx, m, forward);
        let mut ok = pattern[pattern_at] == char;
        if ok {
            if pattern_at == 0 {
                bonus = bonus_at(classes, text, at);
            }
            if boundary {
                if forward && pattern_at == 0 {
                    boundary_bonus = bonus;
                } else if !forward && pattern_at == m - 1 {
                    boundary_bonus = if at < len - 1 {
                        bonus_at(classes, text, at + 1)
                    } else {
                        classes.boundary_white
                    };
                }
                ok = boundary_bonus >= BONUS_BOUNDARY;
                if ok && pattern_at == 0 {
                    ok = at == 0 || classes.of(text.get(at - 1)) <= CharClass::Delimiter;
                }
                if ok && pattern_at == m - 1 {
                    ok = at == len - 1 || classes.of(text.get(at + 1)) <= CharClass::Delimiter;
                }
            }
        }
        if ok {
            pidx += 1;
            if pidx == m {
                if bonus > best_bonus {
                    best_pos = Some(index as usize);
                    best_bonus = bonus;
                }
                if bonus >= BONUS_BOUNDARY {
                    break;
                }
                index -= pidx as isize - 1;
                pidx = 0;
                bonus = 0;
            }
        } else {
            index -= pidx as isize;
            pidx = 0;
            bonus = 0;
        }
        index += 1;
    }
    let best = best_pos?;
    let (start, end) = if forward {
        (best + 1 - m, best + 1)
    } else {
        (len - (best + 1), len - (best + 1 - m))
    };
    let score = if boundary {
        // Underscore boundaries rank below the other kinds; `bonus` is fzf's value at the loop's end.
        let mut score = bonus as i32;
        let mut deduct = (bonus - BONUS_BOUNDARY) as i32 + 1;
        if start > 0 && text.get(start - 1) == '_' {
            score -= deduct + 1;
            deduct = 1;
        }
        if end < len && text.get(end) == '_' {
            score -= deduct;
        }
        score + SCORE_MATCH as i32 * m as i32 + classes.boundary_white as i32 * (m as i32 + 1)
    } else {
        calculate_score(classes, case_sensitive, text, pattern, start, end, None)
    };
    Some(Found { start, end, score })
}

pub(crate) fn prefix(
    classes: &Classes,
    case_sensitive: bool,
    text: Text,
    pattern: &[char],
) -> Option<Found> {
    if pattern.is_empty() {
        return Some(Found {
            start: 0,
            end: 0,
            score: 0,
        });
    }
    let trimmed = if is_space(pattern[0]) {
        0
    } else {
        text.leading_whitespaces()
    };
    if text.len() - trimmed < pattern.len() {
        return None;
    }
    for (index, &char) in pattern.iter().enumerate() {
        if lower_any(text.get(trimmed + index), case_sensitive) != char {
            return None;
        }
    }
    let end = trimmed + pattern.len();
    let score = calculate_score(classes, case_sensitive, text, pattern, trimmed, end, None);
    Some(Found {
        start: trimmed,
        end,
        score,
    })
}

pub(crate) fn suffix(
    classes: &Classes,
    case_sensitive: bool,
    text: Text,
    pattern: &[char],
) -> Option<Found> {
    let mut trimmed = text.len();
    if pattern.last().is_none_or(|&char| !is_space(char)) {
        trimmed -= text.trailing_whitespaces();
    }
    if pattern.is_empty() {
        return Some(Found {
            start: trimmed,
            end: trimmed,
            score: 0,
        });
    }
    let diff = trimmed.checked_sub(pattern.len())?;
    for (index, &char) in pattern.iter().enumerate() {
        if lower_any(text.get(index + diff), case_sensitive) != char {
            return None;
        }
    }
    let score = calculate_score(classes, case_sensitive, text, pattern, diff, trimmed, None);
    Some(Found {
        start: diff,
        end: trimmed,
        score,
    })
}

pub(crate) fn equal(
    classes: &Classes,
    case_sensitive: bool,
    text: Text,
    pattern: &[char],
) -> Option<Found> {
    let m = pattern.len();
    if m == 0 {
        return None;
    }
    let leading = if is_space(pattern[0]) {
        0
    } else {
        text.leading_whitespaces()
    };
    let trailing = if is_space(pattern[m - 1]) {
        0
    } else {
        text.trailing_whitespaces()
    };
    if text.len() < leading + trailing || text.len() - leading - trailing != m {
        return None;
    }
    for (index, &char) in pattern.iter().enumerate() {
        if lower_any(text.get(leading + index), case_sensitive) != char {
            return None;
        }
    }
    let white = classes.boundary_white as i32;
    let score =
        (SCORE_MATCH as i32 + white) * m as i32 + (BONUS_FIRST_CHAR_MULTIPLIER as i32 - 1) * white;
    Some(Found {
        start: leading,
        end: leading + m,
        score,
    })
}
