//! Pairing: blink.pairs' `calculate_stack_heights` (a stack pass, then indent rematching of unmatched openings) and
//! its `match_pair` relation, over the occurrences of a whole buffer in position order.

use super::language::{Class, Kind, Language};
use super::scan::{NONE, Tok};

/** What pairing needs to know about lines: the token range and rounded indent of each. */
pub(crate) struct Lines<'a> {
    /** Line `l` owns tokens `starts[l]..starts[l + 1]`. */
    pub(crate) starts: &'a [u32],
    /** Rounded indent of each line (see [`super::scan::indent`]). */
    pub(crate) indents: &'a [u8],
}

impl Lines<'_> {
    fn indent_of(&self, index: usize) -> u8 {
        self.indents[line_of(self.starts, index)]
    }
}

/// The line owning token `index`, where line `l` owns tokens `starts[l]..starts[l + 1]`.
pub(crate) fn line_of(starts: &[u32], index: usize) -> usize {
    starts.partition_point(|&start| start as usize <= index) - 1
}

/// The stack pass. Every occurrence gets a height, and `partners` the [`partners`] these heights define. Returns
/// the unmatched openings in position order.
pub(crate) fn stack_pass(
    tokens: &mut [Tok],
    language: &Language,
    partners: &mut Vec<u32>,
) -> Vec<u32> {
    partners.clear();
    partners.resize(tokens.len(), NONE);
    let mut stack: Vec<u32> = Vec::new();
    let mut unmatched: Vec<u32> = Vec::new();
    for index in 0..tokens.len() {
        let current = tokens[index];
        if current.kind == Kind::Opening {
            stack.push(index as u32);
            continue;
        }
        let Some(position) = stack
            .iter()
            .rposition(|&opening| tokens[opening as usize].token == current.token)
        else {
            tokens[index].height = NONE;
            continue;
        };
        // Openings above the one found are skipped, and the pair's height is the depth after the pop.
        unmatched.extend_from_slice(&stack[position + 1..]);
        let opening = stack[position] as usize;
        stack.truncate(position);
        tokens[opening].height = position as u32;
        tokens[index].height = position as u32;
        partners[opening] = index as u32;
        partners[index] = opening as u32;
    }
    unmatched.extend_from_slice(&stack);
    unmatched.sort_unstable();
    // A matched occurrence pairs with the one the stack paired it with: everything between is nested deeper. The
    // closing of a string, comment or span directly follows its opening, so only openings stay unmatched; one of
    // those pairs with the next unmatched opening of its token, and an unmatched delimiter with nothing.
    let mut next = vec![NONE; language.tokens.len()];
    for &opening in unmatched.iter().rev() {
        let current = &mut tokens[opening as usize];
        current.height = NONE;
        if !is_delimiter(language, current) {
            partners[opening as usize] =
                std::mem::replace(&mut next[usize::from(current.token)], opening);
        }
    }
    unmatched
}

fn is_delimiter(language: &Language, occurrence: &Tok) -> bool {
    language.tokens[usize::from(occurrence.token)].class == Class::Delimiter
}

/// The occurrence `index` pairs with under blink.pairs' `match_pair`, as current heights define it: the next
/// occurrence of the same token at the same height after an opening, the previous one before a closing. An unmatched
/// delimiter and a non-pair occurrence have none.
fn match_pair_scan(tokens: &[Tok], language: &Language, index: usize) -> Option<(usize, usize)> {
    let current = tokens[index];
    if current.height == NONE && is_delimiter(language, &current) {
        return None;
    }
    let same = |other: &Tok| other.token == current.token && other.height == current.height;
    match current.kind {
        Kind::Opening => (index + 1..tokens.len())
            .find(|&other| same(&tokens[other]))
            .map(|other| (index, other)),
        Kind::Closing => (0..index)
            .rev()
            .find(|&other| same(&tokens[other]))
            .map(|other| (other, index)),
        Kind::NonPair => None,
    }
}

/// The pair of occurrence `index` that `partners` records, ordered opening first.
pub(crate) fn paired(tokens: &[Tok], partners: &[u32], index: usize) -> Option<(usize, usize)> {
    let partner = partners[index];
    if partner == NONE {
        return None;
    }
    match tokens[index].kind {
        Kind::Opening => Some((index, partner as usize)),
        Kind::Closing => Some((partner as usize, index)),
        Kind::NonPair => None,
    }
}

/// blink.pairs' `stack_height_at` for the position of occurrence `index`: from the first occurrence with a height at
/// or after it, else before it.
pub(crate) fn height_at(tokens: &[Tok], language: &Language, index: usize) -> u32 {
    first_height(tokens[index..].iter(), language, Kind::Closing)
        .or_else(|| first_height(tokens[..index].iter().rev(), language, Kind::Opening))
        .unwrap_or(0)
}

/// The height of the first occurrence that has one, plus one when it is of the `facing` kind, which nests its side
/// of the position, less the unmatched delimiter openings crossed on the way.
fn first_height<'a>(
    occurrences: impl Iterator<Item = &'a Tok>,
    language: &Language,
    facing: Kind,
) -> Option<u32> {
    let mut unmatched_openings: u32 = 0;
    for current in occurrences {
        if current.height != NONE {
            let nested = u32::from(current.kind == facing);
            return Some(
                current
                    .height
                    .saturating_add(nested)
                    .saturating_sub(unmatched_openings),
            );
        }
        if is_delimiter(language, current) {
            match current.kind {
                Kind::Opening => unmatched_openings = unmatched_openings.saturating_add(1),
                Kind::Closing => unmatched_openings = unmatched_openings.saturating_sub(1),
                Kind::NonPair => {}
            }
        }
    }
    None
}

/// Indent rematching of each unmatched opening, last first. Returns whether any height changed.
///
/// An unmatched opening takes over the first later pair of its token, within the region nested deeper than it, whose
/// closing sits at the opening's rounded indent and at a different indent from that pair's opening. That opening
/// becomes unmatched, later occurrences up to the next closing at the taken height move one level out, and the
/// displaced opening is rematched in turn. Until the first change, `stacked` (the stack pass's partners) answers which
/// pair a candidate belongs to; afterwards the heights are scanned.
pub(crate) fn rematch(
    tokens: &mut [Tok],
    language: &Language,
    lines: &Lines,
    unmatched: &[u32],
    stacked: &[u32],
) -> bool {
    let mut changed = false;
    for &start in unmatched.iter().rev() {
        let mut index = start as usize;
        loop {
            let indent = lines.indent_of(index);
            let token = tokens[index].token;
            let height = height_at(tokens, language, index);
            let mut found = None;
            for candidate in index + 1..tokens.len() {
                let current = tokens[candidate];
                if current.height != NONE && current.height <= height {
                    break;
                }
                if current.token != token {
                    continue;
                }
                let pair = if changed {
                    match_pair_scan(tokens, language, candidate)
                } else {
                    paired(tokens, stacked, candidate)
                };
                if let Some((open, close)) = pair {
                    let close_indent = lines.indent_of(close);
                    if close_indent == indent && close_indent != lines.indent_of(open) {
                        found = Some((open, close));
                        break;
                    }
                }
            }
            let Some((open, close)) = found else {
                break;
            };
            changed = true;
            tokens[open].height = NONE;
            tokens[index].height = height;
            tokens[close].height = height;
            for current in &mut tokens[close + 1..] {
                if current.height == height && current.kind == Kind::Closing {
                    break;
                }
                if current.height != NONE {
                    current.height = current.height.saturating_sub(1);
                }
            }
            index = open;
        }
    }
    changed
}

/// The `match_pair` partner of every occurrence, or [`NONE`]: the next occurrence of the same token and height after
/// an opening, the previous one before a closing; none for a non-pair occurrence or an unmatched delimiter.
pub(crate) fn partners(tokens: &[Tok], language: &Language, out: &mut Vec<u32>) {
    out.clear();
    out.resize(tokens.len(), NONE);
    // The most recent occurrence of each token at each height, unmatched ones at level 0.
    let mut last: Vec<Vec<u32>> = vec![Vec::new(); language.tokens.len()];
    for (index, current) in tokens.iter().enumerate() {
        let level = current.height.wrapping_add(1) as usize;
        let slots = &mut last[usize::from(current.token)];
        if slots.len() <= level {
            slots.resize(level + 1, NONE);
        }
        let previous = std::mem::replace(&mut slots[level], index as u32);
        if previous == NONE || (current.height == NONE && is_delimiter(language, current)) {
            continue;
        }
        // The previous occurrence of the key is an opening's next one, and a closing's previous one.
        if tokens[previous as usize].kind == Kind::Opening {
            out[previous as usize] = index as u32;
        }
        if current.kind == Kind::Closing {
            out[index] = previous;
        }
    }
}
