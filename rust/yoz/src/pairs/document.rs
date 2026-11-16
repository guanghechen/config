//! A buffer's lines, tokens and pairs, kept in sync with line edits.

use super::language::{Class, Kind, Language, State, Token};
use super::matching::{self, Lines};
use super::scan::{self, NONE, Tok};
use std::sync::atomic::{AtomicU64, Ordering};

/** Tokens per block of [`Document::block_max`]. */
const BLOCK: usize = 64;
/** Unmatched openings past which indent rematching is skipped: each one scans ahead, so its cost grows faster than
their number, and real code has a few dozen at most. More means the brackets are broken, as after a bulk substitute. */
const REMATCH_LIMIT: usize = 256;

/** One end of a pair: row, byte column and byte length. */
pub(crate) type End = (usize, usize, usize);

/// A revision no document has had, so a cache keyed by revision cannot mistake a rebuilt document for its predecessor.
fn next_revision() -> u64 {
    static REVISION: AtomicU64 = AtomicU64::new(1);
    REVISION.fetch_add(1, Ordering::Relaxed)
}

pub(crate) struct Document {
    language: &'static Language,
    tab_width: u8,
    texts: Vec<Box<[u8]>>,
    /** The state each line passes to the next. */
    carries: Vec<State>,
    /** Rounded indent of each line (see [`scan::indent`]). */
    indents: Vec<u8>,
    /** Line `l` owns `tokens[starts[l]..starts[l + 1]]`. */
    starts: Vec<u32>,
    tokens: Vec<Tok>,
    /** The `match_pair` partner of each token, or [`NONE`]. */
    partners: Vec<u32>,
    /** For each block of [`BLOCK`] tokens, the largest partner of its openings; 0 when none has one. */
    block_max: Vec<u32>,
    /** The stack pass left an opening unmatched. */
    has_unmatched: bool,
    /** Indent rematching moved heights, so pairs may cross and scans cannot skip a pair. */
    rematched: bool,
    /** An edit changed the token sequence: heights, partners and block maxima wait for [`Document::settle`]. */
    unpaired: bool,
    revision: u64,
}

/** Lines an edit retokenized, which replace a range of lines. */
#[derive(Default)]
struct Retokenized {
    texts: Vec<Box<[u8]>>,
    tokens: Vec<Tok>,
    counts: Vec<u32>,
    carries: Vec<State>,
    indents: Vec<u8>,
}

impl Retokenized {
    /// Tokenizes `text` from `state` and returns the state it passes to the next line.
    fn push(&mut self, language: &Language, tab_width: u8, text: Box<[u8]>, state: State) -> State {
        let before = self.tokens.len();
        let carry = scan::scan_line(language, &text, state, &mut self.tokens).carried();
        self.counts.push((self.tokens.len() - before) as u32);
        self.carries.push(carry);
        self.indents.push(scan::indent(&text, tab_width));
        self.texts.push(text);
        carry
    }
}

impl Document {
    pub(crate) fn new(language: &'static Language, tab_width: u8) -> Self {
        Document {
            language,
            tab_width: tab_width.max(1),
            texts: Vec::new(),
            carries: Vec::new(),
            indents: Vec::new(),
            starts: vec![0],
            tokens: Vec::new(),
            partners: Vec::new(),
            block_max: Vec::new(),
            has_unmatched: false,
            rematched: false,
            unpaired: false,
            revision: next_revision(),
        }
    }

    pub(crate) fn revision(&self) -> u64 {
        self.revision
    }

    pub(crate) fn line_count(&self) -> usize {
        self.texts.len()
    }

    /// The state entering `line`.
    fn entering(&self, line: usize) -> State {
        if line == 0 {
            State::Normal
        } else {
            self.carries[line - 1]
        }
    }

    /// Replaces lines `first..old_end` with `lines`, as `nvim_buf_attach`'s `on_lines` reports an edit, and returns
    /// the new revision. Later lines are retokenized while the state entering them changes. Pairs keep their heights
    /// when the edited lines keep the same sequence of tokens; otherwise the next [`Document::settle`] recomputes them,
    /// so typing `()`, which Insert mode reports as two edits, pairs once.
    pub(crate) fn edit(&mut self, first: usize, old_end: usize, lines: Vec<Box<[u8]>>) -> u64 {
        let count = self.texts.len();
        let first = first.min(count);
        let old_end = old_end.clamp(first, count);
        let mut state = self.entering(first);
        let mut new = Retokenized::default();
        for text in lines {
            state = new.push(self.language, self.tab_width, text, state);
        }
        let mut end = old_end;
        while end < count && state != self.entering(end) {
            let text = std::mem::take(&mut self.texts[end]);
            state = new.push(self.language, self.tab_width, text, state);
            end += 1;
        }

        let replaced = self.starts[first] as usize..self.starts[end] as usize;
        // Heights follow from the token sequence; indent rematching also reads the indent of each token's line.
        let neutral = !self.unpaired
            && replaced.len() == new.tokens.len()
            && self.tokens[replaced.clone()]
                .iter()
                .zip(&new.tokens)
                .all(|(old, fresh)| old.token == fresh.token && old.kind == fresh.kind)
            && (!self.has_unmatched || self.same_token_lines(first, end, &new));
        if neutral {
            for (fresh, old) in new.tokens.iter_mut().zip(&self.tokens[replaced.clone()]) {
                fresh.height = old.height;
            }
        }
        let delta = new.tokens.len() as i64 - replaced.len() as i64;
        let starts = new.counts.iter().scan(self.starts[first], |start, &count| {
            let line = *start;
            *start += count;
            Some(line)
        });
        let lines = new.counts.len();
        self.starts.splice(first..end, starts.collect::<Vec<_>>());
        if delta != 0 {
            for start in &mut self.starts[first + lines..] {
                *start = (i64::from(*start) + delta) as u32;
            }
        }
        self.tokens.splice(replaced, new.tokens);
        self.texts.splice(first..end, new.texts);
        self.carries.splice(first..end, new.carries);
        self.indents.splice(first..end, new.indents);
        self.unpaired = !neutral;
        self.revision = next_revision();
        self.revision
    }

    /// Recomputes pairs left stale by an edit. Queries read settled pairs.
    pub(crate) fn settle(&mut self) {
        if self.unpaired {
            self.pair();
            self.unpaired = false;
        }
    }

    /// Sets the width a tab counts in indents, which indent rematching compares.
    pub(crate) fn set_tab_width(&mut self, tab_width: u8) -> u64 {
        let tab_width = tab_width.max(1);
        if tab_width != self.tab_width {
            self.tab_width = tab_width;
            for (indent, text) in self.indents.iter_mut().zip(&self.texts) {
                *indent = scan::indent(text, tab_width);
            }
            self.unpaired = true;
            self.revision = next_revision();
        }
        self.revision
    }

    /// Whether lines `first..end` carry as many tokens at the same rounded indents as the lines replacing them.
    fn same_token_lines(&self, first: usize, end: usize, new: &Retokenized) -> bool {
        end - first == new.counts.len()
            && (first..end).zip(new.counts.iter().zip(&new.indents)).all(
                |(line, (&count, &indent))| {
                    self.starts[line + 1] - self.starts[line] == count
                        && (count == 0 || self.indents[line] == indent)
                },
            )
    }

    /// Recomputes heights, partners and block maxima of the whole buffer.
    fn pair(&mut self) {
        let unmatched = matching::stack_pass(&mut self.tokens, self.language, &mut self.partners);
        self.has_unmatched = !unmatched.is_empty();
        let lines = Lines {
            starts: &self.starts,
            indents: &self.indents,
        };
        self.rematched = unmatched.len() <= REMATCH_LIMIT
            && matching::rematch(
                &mut self.tokens,
                self.language,
                &lines,
                &unmatched,
                &self.partners,
            );
        if self.rematched {
            matching::partners(&self.tokens, self.language, &mut self.partners);
        }
        self.block_max = self
            .tokens
            .chunks(BLOCK)
            .zip(self.partners.chunks(BLOCK))
            .map(|(tokens, partners)| {
                tokens
                    .iter()
                    .zip(partners)
                    .filter(|&(current, &partner)| current.kind == Kind::Opening && partner != NONE)
                    .map(|(_, &partner)| partner)
                    .max()
                    .unwrap_or(0)
            })
            .collect();
    }

    fn line_tokens(&self, row: usize) -> std::ops::Range<usize> {
        self.starts[row] as usize..self.starts[row + 1] as usize
    }

    fn token_def(&self, index: usize) -> &'static Token {
        &self.language.tokens[usize::from(self.tokens[index].token)]
    }

    /// The column after token `index`.
    fn end_col(&self, index: usize) -> usize {
        let current = self.tokens[index];
        current.col as usize + self.token_def(index).len(current.kind)
    }

    /// Index of the first token at or after `row`, `col`; the end past the last row.
    fn tokens_before(&self, row: usize, col: usize) -> usize {
        if row >= self.texts.len() {
            return self.tokens.len();
        }
        let range = self.line_tokens(row);
        range.start + self.tokens[range].partition_point(|current| (current.col as usize) < col)
    }

    /// The token on `row` whose text covers `col`, as blink.pairs' `match_at` finds it: tokens of a row do not
    /// overlap, so it is the last one starting at or before `col`.
    fn token_at(&self, row: usize, col: usize) -> Option<usize> {
        let after = self.tokens_before(row, col + 1);
        (row < self.texts.len() && after > self.starts[row] as usize)
            .then(|| after - 1)
            .filter(|&index| col < self.end_col(index))
    }

    /// Row, column and length of token `index`.
    fn end(&self, index: usize) -> End {
        let current = self.tokens[index];
        let len = self.token_def(index).len(current.kind);
        (
            matching::line_of(&self.starts, index),
            current.col as usize,
            len,
        )
    }

    fn pair_of(&self, index: usize) -> Option<(End, End)> {
        let (open, close) = matching::paired(&self.tokens, &self.partners, index)?;
        Some((self.end(open), self.end(close)))
    }

    /// The class of the string, comment or span that `row`, `col` lies in, `None` in code: the state after the row's
    /// last token before `col`, or else the state entering the row. A position within an opening or closing lies in
    /// none. Reads tokens only, so it needs no settled pairs.
    pub(crate) fn inside(&self, row: usize, col: usize) -> Option<Class> {
        if row >= self.texts.len() {
            return None;
        }
        let before = self.tokens_before(row, col);
        if before == self.starts[row] as usize {
            return match self.entering(row) {
                State::InBlockString(_) => Some(Class::BlockString),
                State::InBlockComment(_) => Some(Class::BlockComment),
                State::InBlockSpan(_) => Some(Class::BlockSpan),
                _ => None,
            };
        }
        let index = before - 1;
        if self.end_col(index) > col {
            return None;
        }
        match (self.token_def(index).class, self.tokens[index].kind) {
            (Class::Delimiter, _) | (_, Kind::Closing) => None,
            (class, _) => Some(class),
        }
    }

    /// The pair of the token at `row`, `col`, as blink.pairs' `match_pair`.
    pub(crate) fn match_pair(&self, row: usize, col: usize) -> Option<(End, End)> {
        debug_assert!(!self.unpaired, "query before settle");
        self.pair_of(self.token_at(row, col)?)
    }

    /// The pair of the token at `row`, `col`; off any token, the innermost pair around it: the last opening before it
    /// whose partner follows it, as blink.pairs' `surrounding_match_pair`.
    pub(crate) fn surrounding_pair(&self, row: usize, col: usize) -> Option<(End, End)> {
        debug_assert!(!self.unpaired, "query before settle");
        if let Some(index) = self.token_at(row, col) {
            return self.pair_of(index);
        }
        let cursor = self.tokens_before(row, col);
        let encloses = |index: usize| {
            let partner = self.partners[index];
            self.tokens[index].kind == Kind::Opening
                && partner != NONE
                && partner as usize >= cursor
        };
        let mut index = cursor;
        while index > 0 {
            let block = (index - 1) / BLOCK;
            let block_start = block * BLOCK;
            if (self.block_max[block] as usize) < cursor {
                index = block_start;
                continue;
            }
            while index > block_start {
                index -= 1;
                if encloses(index) {
                    return self.pair_of(index);
                }
            }
        }
        None
    }

    /// An unmatched delimiter of the `open`/`close` token at the cursor's level that typing its other side at `row`,
    /// `col` would pair with: a closing after the position, or an opening before it, as `wanted` says. These are
    /// blink.pairs' `unmatched_closing_after` and `unmatched_opening_before`.
    ///
    /// Walks the delimiters away from the position. A matched delimiter below the cursor's level ends the walk,
    /// unless it is of the wanted kind and token, which lowers the level.
    pub(crate) fn unmatched(
        &self,
        open: &str,
        close: &str,
        row: usize,
        col: usize,
        wanted: Kind,
    ) -> Option<(usize, usize)> {
        debug_assert!(!self.unpaired, "query before settle");
        let target = self.language.tokens.iter().position(|token| {
            token.class == Class::Delimiter && token.open == open && token.close == close
        })? as u8;
        // The kind facing the cursor nests away from it.
        let after = wanted == Kind::Closing;
        let facing = if after { Kind::Opening } else { Kind::Closing };
        let cursor = self.tokens_before(row, col);
        let mut lowest = matching::height_at(&self.tokens, self.language, cursor);
        let mut level = lowest;
        // The next token is `index` walking forward, `index - 1` walking back.
        let mut index = cursor;
        while let Some(at) = if after {
            (index < self.tokens.len()).then_some(index)
        } else {
            index.checked_sub(1)
        } {
            index = if after { at + 1 } else { at };
            let current = self.tokens[at];
            if self.token_def(at).class != Class::Delimiter {
                continue;
            }
            if current.height != NONE {
                if current.height < lowest {
                    if current.kind == wanted && current.token == target {
                        lowest = current.height;
                    } else {
                        return None;
                    }
                }
                level = current.height + u32::from(current.kind == facing);
                // Without rematching, everything inside a pair is nested deeper, so the pair cannot hold the answer.
                if !self.rematched && current.kind == facing {
                    level = current.height;
                    let partner = self.partners[at] as usize;
                    index = if after { partner + 1 } else { partner };
                    continue;
                }
            }
            if current.kind == wanted
                && current.token == target
                && current.height == NONE
                && level == lowest
            {
                return Some((matching::line_of(&self.starts, at), current.col as usize));
            }
        }
        None
    }

    /// Delimiters from `first` (row, column) up to `last` (exclusive) as row, column, end column and height (`None`
    /// when unmatched); a decoration provider's range, which on a long line covers only its visible part.
    pub(crate) fn highlights(
        &self,
        first: (usize, usize),
        last: (usize, usize),
    ) -> impl Iterator<Item = (usize, usize, usize, Option<u32>)> + '_ {
        debug_assert!(!self.unpaired, "query before settle");
        let rows = first.0.min(self.texts.len())..(last.0 + 1).min(self.texts.len());
        rows.flat_map(move |row| {
            let range = self.line_tokens(row);
            let from = if row == first.0 {
                self.tokens_before(row, first.1)
            } else {
                range.start
            };
            let to = if row == last.0 {
                self.tokens_before(row, last.1)
            } else {
                range.end
            };
            (from..to.max(from))
                .filter(|&index| self.token_def(index).class == Class::Delimiter)
                .map(move |index| {
                    let current = self.tokens[index];
                    let height = (current.height != NONE).then_some(current.height);
                    (row, current.col as usize, self.end_col(index), height)
                })
        })
    }

    /// Every token of `row` as column, kind, token and height (`None` when unmatched), for inspection and tests.
    pub(crate) fn row_tokens(&self, row: usize) -> Vec<(usize, Kind, &'static Token, Option<u32>)> {
        debug_assert!(!self.unpaired, "query before settle");
        if row >= self.texts.len() {
            return Vec::new();
        }
        self.line_tokens(row)
            .map(|index| {
                let current = self.tokens[index];
                let height = (current.height != NONE).then_some(current.height);
                (
                    current.col as usize,
                    current.kind,
                    self.token_def(index),
                    height,
                )
            })
            .collect()
    }
}
