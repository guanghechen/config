//! A parsed pattern against one item, as fzf's `extendedMatch`.

use super::algo::{self, Found, Scratch, Text};
use super::class::Classes;
use super::pattern::{Pattern, Term, TermKind};

pub(crate) struct ItemMatch {
    pub(crate) score: i32,
    /** Smallest start among the sets' matches, for fzf's pathname tiebreak. */
    pub(crate) begin: Option<usize>,
}

pub(crate) struct Options {
    /** fzf scans backward under the path scheme, preferring the rightmost of equal alignments. */
    pub(crate) forward: bool,
    /** Trace fuzzy matches: starts become exact, and positions can be collected. */
    pub(crate) with_pos: bool,
    /** Long input falls back to V1, as fzf does when it matches with a slab. */
    pub(crate) fallback: bool,
}

fn run(
    classes: &Classes,
    term: &Term,
    text: Text,
    options: &Options,
    scratch: &mut Scratch,
) -> Option<Found> {
    let case = term.case_sensitive;
    match term.kind {
        TermKind::Fuzzy => algo::fuzzy_v2(
            classes,
            case,
            options.forward,
            text,
            &term.text,
            options.with_pos,
            scratch,
            options.fallback,
        ),
        TermKind::Exact => algo::exact(classes, case, options.forward, false, text, &term.text),
        TermKind::ExactBoundary => {
            algo::exact(classes, case, options.forward, true, text, &term.text)
        }
        TermKind::Prefix => algo::prefix(classes, case, text, &term.text),
        TermKind::Suffix => algo::suffix(classes, case, text, &term.text),
        TermKind::Equal => algo::equal(classes, case, text, &term.text),
    }
}

/// Every set must match; the first matching term of a set gives its score and offset. `positions`, which
/// needs `options.with_pos`, collects the matched characters.
pub(crate) fn match_item(
    classes: &Classes,
    pattern: &Pattern,
    text: Text,
    options: &Options,
    scratch: &mut Scratch,
    mut positions: Option<&mut Vec<usize>>,
) -> Option<ItemMatch> {
    let mut score = 0;
    let mut begin: Option<usize> = None;
    for set in &pattern.sets {
        let mut matched = false;
        let mut current = 0;
        let mut offset = (0, 0);
        for term in set {
            match run(classes, term, text, options, scratch) {
                Some(found) => {
                    if term.inverse {
                        continue;
                    }
                    matched = true;
                    current = found.score;
                    offset = (found.start, found.end);
                    if let Some(positions) = positions.as_deref_mut() {
                        match term.kind {
                            TermKind::Fuzzy => positions.extend_from_slice(&scratch.positions),
                            _ => positions.extend(found.start..found.end),
                        }
                    }
                    break;
                }
                None if term.inverse => {
                    matched = true;
                    current = 0;
                    offset = (0, 0);
                }
                None => {}
            }
        }
        if !matched {
            return None;
        }
        score += current;
        if offset.0 < offset.1 {
            begin = Some(begin.map_or(offset.0, |begin| begin.min(offset.0)));
        }
    }
    Some(ItemMatch { score, begin })
}

/// Whether the item matches, skipping scores where a cheaper test decides the same.
pub(crate) fn is_match(
    classes: &Classes,
    pattern: &Pattern,
    text: Text,
    options: &Options,
    scratch: &mut Scratch,
) -> bool {
    pattern.sets.iter().all(|set| {
        set.iter().any(|term| {
            let found = match (term.kind, text) {
                // V2 rejects exactly the items lacking the pattern as a subsequence.
                (TermKind::Fuzzy, Text::Bytes(_)) => {
                    algo::fuzzy_index(text, &term.text, term.case_sensitive).is_some()
                }
                // Any occurrence matches; the alignment only decides the score.
                (TermKind::Exact, Text::Bytes(bytes)) => {
                    algo::contains(bytes, &term.text, term.case_sensitive)
                }
                _ => run(classes, term, text, options, scratch).is_some(),
            };
            found != term.inverse
        })
    })
}
