#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Score {
    pub score: i32,
    pub exact: bool,
}

const MATCH_BONUS: i32 = 10;
const CASE_BONUS: i32 = 2;
const BOUNDARY_BONUS: i32 = 8;
const CONSECUTIVE_BONUS: i32 = 12;
const PREFIX_BONUS: i32 = 60;
const WHOLE_WORD_BONUS: i32 = 48;
const MAX_GAP_PENALTY: usize = 8;
const MAX_LEADING_PENALTY: usize = 12;
const MAX_TAIL_PENALTY: usize = 24;
const MIN_TYPO_QUERY_CHARS: usize = 4;
const MIN_TWO_TYPO_QUERY_CHARS: usize = 8;
const MAX_FUZZY_TYPO_QUERY_CHARS: usize = 32;
const MAX_PREFIX_TYPO_QUERY_CHARS: usize = 64;
// For short queries the character mask rejects misses before score-state setup;
// longer near-matches usually benefit from reusing their prefix progress.
const MAX_EAGER_MASK_QUERY_CHARS: usize = 8;
// Tight repairs may beat weak subsequences, but never receive strict exactness.
const TYPO_PENALTY: i32 = 96;
const SECOND_TYPO_PENALTY: i32 = 48;

#[derive(Clone, Copy)]
struct FoldedChar {
    chars: [char; 3],
    len: u8,
}

impl FoldedChar {
    #[inline]
    fn new(value: char) -> Self {
        let mut chars = ['\0'; 3];
        let mut len = 0;
        for character in value.to_lowercase() {
            chars[len] = character;
            len += 1;
        }
        Self {
            chars,
            len: len as u8,
        }
    }
}

impl PartialEq for FoldedChar {
    #[inline]
    fn eq(&self, other: &Self) -> bool {
        self.len == other.len
            && self.chars[..self.len as usize] == other.chars[..other.len as usize]
    }
}

#[derive(Clone, Copy)]
struct QueryChar {
    original: char,
    folded: FoldedChar,
}

impl QueryChar {
    #[inline]
    fn new(value: char) -> Self {
        Self {
            original: value,
            folded: FoldedChar::new(value),
        }
    }

    #[inline]
    fn ascii(value: u8) -> Self {
        Self::new(value as char)
    }

    #[inline]
    fn matches(self, candidate: char) -> bool {
        self.original == candidate || self.folded == FoldedChar::new(candidate)
    }
}

pub struct Query<'a> {
    raw: &'a str,
    unicode: Option<Vec<QueryChar>>,
}

struct TypoVariant {
    chars: Vec<QueryChar>,
    ascii: Option<Vec<u8>>,
    wildcard: Option<usize>,
    edit_index: usize,
}

pub struct TypoQuery {
    chars: Vec<QueryChar>,
    ascii: Option<Vec<u8>>,
    max_edits: u8,
    fuzzy_repairs: bool,
    swaps: Vec<TypoVariant>,
    substitutions: Vec<TypoVariant>,
    deletions: Vec<TypoVariant>,
    ascii_mask: Option<([u64; 2], u32)>,
    two_prefix_ascii_mask: Option<[u64; 2]>,
}

pub struct TypoMatcher<'a> {
    query: &'a TypoQuery,
    candidate_chars: Vec<char>,
}

impl<'a> Query<'a> {
    #[inline]
    pub fn new(value: &'a str) -> Self {
        Self {
            raw: value,
            unicode: (!value.is_ascii()).then(|| value.chars().map(QueryChar::new).collect()),
        }
    }

    #[inline]
    pub fn score(&self, candidate: &str) -> Option<Score> {
        if self.raw.is_empty() {
            return Some(Score {
                score: 0,
                exact: false,
            });
        }

        if self.unicode.is_none() && candidate.is_ascii() {
            return score_ascii(self.raw.as_bytes(), candidate.as_bytes());
        }
        match &self.unicode {
            Some(query) => score_chars(query.iter().copied(), query.len(), candidate),
            None => score_chars(
                self.raw.bytes().map(QueryChar::ascii),
                self.raw.len(),
                candidate,
            ),
        }
    }

    fn matched_ranges(&self, candidate: &str) -> Vec<usize> {
        if self.raw.is_empty() {
            return Vec::new();
        }

        if self.unicode.is_none() && candidate.is_ascii() {
            let candidate = candidate.as_bytes();
            let mut ranges = Vec::with_capacity(self.raw.len() * 2);
            let mut candidate_index = 0;
            for query_byte in self.raw.bytes() {
                while candidate_index < candidate.len()
                    && !candidate[candidate_index].eq_ignore_ascii_case(&query_byte)
                {
                    candidate_index += 1;
                }
                if candidate_index == candidate.len() {
                    return Vec::new();
                }
                push_range(&mut ranges, candidate_index, candidate_index + 1);
                candidate_index += 1;
            }
            return ranges;
        }

        match &self.unicode {
            Some(query) => matched_char_ranges(query.iter().copied(), candidate),
            None => matched_char_ranges(self.raw.bytes().map(QueryChar::ascii), candidate),
        }
    }

    pub fn typo(&self) -> Option<TypoQuery> {
        let chars = match &self.unicode {
            Some(chars) => chars.clone(),
            None => self.raw.bytes().map(QueryChar::ascii).collect(),
        };
        if !(MIN_TYPO_QUERY_CHARS..=MAX_PREFIX_TYPO_QUERY_CHARS).contains(&chars.len()) {
            return None;
        }

        let ascii = self.unicode.is_none().then(|| self.raw.as_bytes().to_vec());
        let max_edits = if chars.len() >= MIN_TWO_TYPO_QUERY_CHARS {
            2
        } else {
            1
        };
        let fuzzy_repairs = chars.len() <= MAX_FUZZY_TYPO_QUERY_CHARS;
        let mut swaps = Vec::new();
        if fuzzy_repairs {
            swaps.reserve(chars.len() - 1);
            for index in 0..chars.len() - 1 {
                if chars[index].folded == chars[index + 1].folded {
                    continue;
                }
                let mut swapped = chars.clone();
                swapped.swap(index, index + 1);
                let mut swapped_ascii = ascii.clone();
                if let Some(value) = &mut swapped_ascii {
                    value.swap(index, index + 1);
                }
                swaps.push(TypoVariant {
                    chars: swapped,
                    ascii: swapped_ascii,
                    wildcard: None,
                    edit_index: index,
                });
            }
        }
        let substitutions = if fuzzy_repairs {
            (0..chars.len())
                .map(|index| TypoVariant {
                    chars: chars.clone(),
                    ascii: ascii.clone(),
                    wildcard: Some(index),
                    edit_index: index,
                })
                .collect()
        } else {
            Vec::new()
        };
        let deletions = if fuzzy_repairs {
            (0..chars.len())
                .map(|index| {
                    let mut deleted = chars.clone();
                    deleted.remove(index);
                    let mut deleted_ascii = ascii.clone();
                    if let Some(value) = &mut deleted_ascii {
                        value.remove(index);
                    }
                    TypoVariant {
                        chars: deleted,
                        ascii: deleted_ascii,
                        wildcard: None,
                        edit_index: index,
                    }
                })
                .collect()
        } else {
            Vec::new()
        };
        let ascii_mask = ascii.as_ref().and_then(|value| {
            fuzzy_repairs.then(|| {
                let mask = ascii_char_mask(value);
                let count = mask[0].count_ones() + mask[1].count_ones();
                (mask, count)
            })
        });
        let two_prefix_ascii_mask = ascii.as_ref().and_then(|value| {
            (max_edits >= 2).then(|| ascii_char_mask(&value[..value.len().min(10)]))
        });
        Some(TypoQuery {
            chars,
            ascii,
            max_edits,
            fuzzy_repairs,
            swaps,
            substitutions,
            deletions,
            ascii_mask,
            two_prefix_ascii_mask,
        })
    }
}

#[inline]
fn push_range(ranges: &mut Vec<usize>, start: usize, end: usize) {
    let len = ranges.len();
    if len >= 2 && ranges[len - 1] == start {
        ranges[len - 1] = end;
    } else {
        ranges.extend([start, end]);
    }
}

fn matched_char_ranges<I>(query: I, candidate: &str) -> Vec<usize>
where
    I: IntoIterator<Item = QueryChar>,
{
    let mut ranges = Vec::new();
    let mut candidate_chars = candidate.char_indices();
    for query_char in query {
        let matched = candidate_chars
            .by_ref()
            .find(|(_, candidate_char)| query_char.matches(*candidate_char));
        let Some((start, candidate_char)) = matched else {
            return Vec::new();
        };
        push_range(&mut ranges, start, start + candidate_char.len_utf8());
    }
    ranges
}

impl TypoQuery {
    pub fn score(&self, candidate: &str) -> Option<Score> {
        self.matcher().score(candidate)
    }

    pub fn matcher(&self) -> TypoMatcher<'_> {
        TypoMatcher {
            query: self,
            candidate_chars: Vec::new(),
        }
    }

    fn score_with_scratch(
        &self,
        candidate: &str,
        candidate_chars: &mut Vec<char>,
    ) -> Option<Score> {
        if let Some(query) = &self.ascii
            && candidate.is_ascii()
        {
            let candidate = candidate.as_bytes();
            // A repaired prefix is the strongest completion signal and the
            // common typo path. Detect it before rescoring fuzzy variants.
            if let Some(prefix) = self.score_ascii_prefix(query, candidate) {
                return Some(prefix);
            }
            if !self.fuzzy_repairs {
                return None;
            }
            if !self.matches_ascii_mask(candidate, 1) {
                return None;
            }
            return self.score_ascii_fallback(query, candidate);
        }

        candidate_chars.clear();
        candidate_chars.extend(candidate.chars());
        if let Some(prefix) = self.score_char_prefix(candidate_chars) {
            return Some(prefix);
        }
        if !self.fuzzy_repairs {
            return None;
        }
        self.score_char_fallback(candidate_chars)
    }

    #[inline]
    fn score_ascii_prefix(&self, query: &[u8], candidate: &[u8]) -> Option<Score> {
        score_typo_prefix_ascii(query, candidate, candidate.len()).or_else(|| {
            (self.max_edits >= 2 && self.matches_two_prefix_ascii_mask(candidate))
                .then(|| score_two_typo_prefix_ascii(query, candidate))
                .flatten()
        })
    }

    #[inline]
    fn score_char_prefix(&self, candidate: &[char]) -> Option<Score> {
        score_typo_prefix_chars(&self.chars, candidate).or_else(|| {
            (self.max_edits >= 2)
                .then(|| score_two_typo_prefix_chars(&self.chars, candidate))
                .flatten()
        })
    }

    fn score_ascii_fallback(&self, query: &[u8], candidate: &[u8]) -> Option<Score> {
        let context = ascii_match_context(query, candidate);
        self.score_ascii_fallback_with_context(query, candidate, &context)
    }

    fn score_ascii_with_context(
        &self,
        query: &[u8],
        candidate: &[u8],
        context: &AsciiMatchContext,
        check_mask: bool,
    ) -> Option<Score> {
        if let Some(prefix) = self.score_ascii_prefix(query, candidate) {
            return Some(prefix);
        }
        if check_mask && !self.matches_ascii_mask(candidate, 1) {
            return None;
        }
        self.score_ascii_fallback_with_context(query, candidate, context)
    }

    #[inline]
    fn matches_ascii_mask(&self, candidate: &[u8], edits: u32) -> bool {
        let (required, count) = self.ascii_mask.expect("ASCII typo mask");
        let available = ascii_char_mask(candidate);
        let shared =
            (required[0] & available[0]).count_ones() + (required[1] & available[1]).count_ones();
        shared + edits >= count
    }

    #[inline]
    fn matches_two_prefix_ascii_mask(&self, candidate: &[u8]) -> bool {
        let required = self
            .two_prefix_ascii_mask
            .expect("two-typo ASCII prefix mask");
        let mut missing = 0;
        for byte in candidate.iter().take(8) {
            let folded = byte.to_ascii_lowercase() as usize;
            if required[folded / 64] & (1 << (folded % 64)) == 0 {
                missing += 1;
                if missing > 2 {
                    return false;
                }
            }
        }
        true
    }

    fn score_ascii_fallback_with_context(
        &self,
        query: &[u8],
        candidate: &[u8],
        context: &AsciiMatchContext,
    ) -> Option<Score> {
        let mut best = None;
        for variant in &self.swaps {
            if ascii_swap_matches(query, candidate, &context.bounds, variant.edit_index) {
                let variant_query = variant.ascii.as_deref().expect("ASCII typo variant");
                update_best(
                    &mut best,
                    score_typo_ascii_from_prefix(
                        variant_query,
                        None,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    ),
                );
            }
        }
        for variant in &self.substitutions {
            if substitution_matches(&context.bounds, variant.edit_index) {
                let variant_query = variant.ascii.as_deref().expect("ASCII typo variant");
                update_best(
                    &mut best,
                    score_typo_ascii_from_prefix(
                        variant_query,
                        variant.wildcard,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    ),
                );
            }
        }
        for variant in &self.deletions {
            if deletion_matches(&context.bounds, variant.edit_index) {
                update_best(
                    &mut best,
                    score_typo_ascii_from_prefix(
                        variant.ascii.as_deref().expect("ASCII typo variant"),
                        None,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    ),
                );
            }
        }
        best
    }

    fn score_char_fallback(&self, candidate: &[char]) -> Option<Score> {
        let context = char_match_context(&self.chars, candidate);
        self.score_char_fallback_with_context(candidate, &context)
    }

    fn score_char_fallback_with_context(
        &self,
        candidate: &[char],
        context: &CharMatchContext,
    ) -> Option<Score> {
        let mut best = None;
        for variant in &self.swaps {
            if char_swap_matches(&self.chars, candidate, &context.bounds, variant.edit_index) {
                update_best(
                    &mut best,
                    score_typo_chars_from_prefix(
                        &variant.chars,
                        None,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    ),
                );
            }
        }
        for variant in &self.substitutions {
            if substitution_matches(&context.bounds, variant.edit_index) {
                update_best(
                    &mut best,
                    score_typo_chars_from_prefix(
                        &variant.chars,
                        variant.wildcard,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    ),
                );
            }
        }
        for variant in &self.deletions {
            if deletion_matches(&context.bounds, variant.edit_index) {
                update_best(
                    &mut best,
                    score_typo_chars_from_prefix(
                        &variant.chars,
                        None,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    ),
                );
            }
        }
        best
    }
}

impl TypoMatcher<'_> {
    pub fn score(&mut self, candidate: &str) -> Option<Score> {
        self.query
            .score_with_scratch(candidate, &mut self.candidate_chars)
    }

    pub fn score_both(&mut self, candidate: &str) -> (Option<Score>, Option<Score>) {
        if let Some(query) = &self.query.ascii
            && candidate.is_ascii()
        {
            let candidate = candidate.as_bytes();
            if !self.query.fuzzy_repairs {
                if let Some(strict) = score_ascii(query, candidate) {
                    return (Some(strict), None);
                }
                return (None, self.query.score_ascii_prefix(query, candidate));
            }
            let mask_checked = query.len() <= MAX_EAGER_MASK_QUERY_CHARS;
            if mask_checked
                && !self
                    .query
                    .matches_ascii_mask(candidate, u32::from(self.query.max_edits))
            {
                return (None, None);
            }
            let mut context = ascii_prefix_context(query, candidate);
            if context.matched_prefix == query.len() {
                let state = context.prefixes[query.len()];
                return (
                    Some(finish_ascii_score(
                        state,
                        query.len(),
                        candidate.len(),
                        0,
                        true,
                    )),
                    None,
                );
            }
            fill_ascii_backward(query, candidate, &mut context.bounds);
            let typo = self.query.score_ascii_with_context(
                query,
                candidate,
                &context,
                !mask_checked && context.matched_prefix + 2 < query.len(),
            );
            return (None, typo);
        }

        if !self.query.fuzzy_repairs {
            if let Some(strict) = score_chars(
                self.query.chars.iter().copied(),
                self.query.chars.len(),
                candidate,
            ) {
                return (Some(strict), None);
            }
            self.candidate_chars.clear();
            self.candidate_chars.extend(candidate.chars());
            return (None, self.query.score_char_prefix(&self.candidate_chars));
        }

        self.candidate_chars.clear();
        self.candidate_chars.extend(candidate.chars());
        let mut context = char_prefix_context(&self.query.chars, &self.candidate_chars);
        if context.matched_prefix == self.query.chars.len() {
            let state = context.prefixes[self.query.chars.len()];
            return (
                Some(finish_char_score(
                    state,
                    self.query.chars.len(),
                    self.candidate_chars.len(),
                    0,
                    true,
                )),
                None,
            );
        }
        fill_char_backward(
            &self.query.chars,
            &self.candidate_chars,
            &mut context.bounds,
        );
        if let Some(prefix) = self.query.score_char_prefix(&self.candidate_chars) {
            return (None, Some(prefix));
        }
        (
            None,
            self.query
                .score_char_fallback_with_context(&self.candidate_chars, &context),
        )
    }
}

const NO_MATCH: usize = usize::MAX;

struct MatchBounds {
    forward: [usize; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
    backward: [usize; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
}

#[derive(Clone, Copy)]
struct AsciiScoreState {
    candidate_index: usize,
    total: i32,
    prefix: bool,
}

struct AsciiMatchContext {
    bounds: MatchBounds,
    prefixes: [AsciiScoreState; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
    matched_prefix: usize,
}

#[derive(Clone, Copy)]
struct CharScoreState {
    candidate_index: usize,
    total: i32,
    prefix: bool,
}

struct CharMatchContext {
    bounds: MatchBounds,
    prefixes: [CharScoreState; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
    matched_prefix: usize,
}

#[inline]
fn update_best(best: &mut Option<Score>, matched: Option<Score>) {
    if let Some(matched) = matched
        && best.is_none_or(|current| matched.score > current.score)
    {
        *best = Some(matched);
    }
}

fn ascii_prefix_context(query: &[u8], candidate: &[u8]) -> AsciiMatchContext {
    let mut bounds = MatchBounds {
        forward: [NO_MATCH; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
        backward: [NO_MATCH; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
    };
    let mut state = AsciiScoreState {
        candidate_index: 0,
        total: 0,
        prefix: true,
    };
    let mut prefixes = [state; MAX_FUZZY_TYPO_QUERY_CHARS + 1];
    let mut matched_prefix = 0usize;
    bounds.forward[0] = 0;
    for (query_index, query_byte) in query.iter().copied().enumerate() {
        let mut matched_index = state.candidate_index;
        while matched_index < candidate.len()
            && !candidate[matched_index].eq_ignore_ascii_case(&query_byte)
        {
            matched_index += 1;
        }
        if matched_index == candidate.len() {
            break;
        }
        state.prefix &= matched_index == query_index;
        state.total += MATCH_BONUS;
        if candidate[matched_index] == query_byte {
            state.total += CASE_BONUS;
        }
        if is_ascii_boundary(candidate, matched_index) {
            state.total += BOUNDARY_BONUS;
        }
        if query_index > 0 {
            let skipped = matched_index - state.candidate_index;
            if skipped == 0 {
                state.total += CONSECUTIVE_BONUS;
            } else {
                state.total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            state.total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }
        state.candidate_index = matched_index + 1;
        bounds.forward[query_index + 1] = state.candidate_index;
        prefixes[query_index + 1] = state;
        matched_prefix = query_index + 1;
    }

    AsciiMatchContext {
        bounds,
        prefixes,
        matched_prefix,
    }
}

fn fill_ascii_backward(query: &[u8], candidate: &[u8], bounds: &mut MatchBounds) {
    bounds.backward[query.len()] = candidate.len();
    let mut candidate_index = candidate.len();
    for query_index in (0..query.len()).rev() {
        let mut matched = false;
        while candidate_index > 0 {
            candidate_index -= 1;
            if candidate[candidate_index].eq_ignore_ascii_case(&query[query_index]) {
                matched = true;
                break;
            }
        }
        if !matched {
            break;
        }
        bounds.backward[query_index] = candidate_index;
    }
}

fn ascii_match_context(query: &[u8], candidate: &[u8]) -> AsciiMatchContext {
    let mut context = ascii_prefix_context(query, candidate);
    fill_ascii_backward(query, candidate, &mut context.bounds);
    context
}

fn finish_ascii_score(
    mut state: AsciiScoreState,
    query_len: usize,
    candidate_len: usize,
    penalty: i32,
    exact: bool,
) -> Score {
    let tail = candidate_len.saturating_sub(query_len);
    state.total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if state.prefix {
        state.total += PREFIX_BONUS;
    }
    if candidate_len == query_len && state.prefix {
        state.total += WHOLE_WORD_BONUS;
    }
    Score {
        score: state.total - penalty,
        exact: exact && state.prefix,
    }
}

fn char_prefix_context(query: &[QueryChar], candidate: &[char]) -> CharMatchContext {
    let mut bounds = MatchBounds {
        forward: [NO_MATCH; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
        backward: [NO_MATCH; MAX_FUZZY_TYPO_QUERY_CHARS + 1],
    };
    let mut state = CharScoreState {
        candidate_index: 0,
        total: 0,
        prefix: true,
    };
    let mut prefixes = [state; MAX_FUZZY_TYPO_QUERY_CHARS + 1];
    let mut matched_prefix = 0usize;
    bounds.forward[0] = 0;
    for (query_index, query_char) in query.iter().copied().enumerate() {
        let mut matched_index = state.candidate_index;
        while matched_index < candidate.len() && !query_char.matches(candidate[matched_index]) {
            matched_index += 1;
        }
        if matched_index == candidate.len() {
            break;
        }
        let matched = candidate[matched_index];
        state.prefix &= matched_index == query_index;
        state.total += MATCH_BONUS;
        if matched == query_char.original {
            state.total += CASE_BONUS;
        }
        if is_boundary(
            matched_index
                .checked_sub(1)
                .map(|previous| candidate[previous]),
            matched,
        ) {
            state.total += BOUNDARY_BONUS;
        }
        if query_index > 0 {
            let skipped = matched_index - state.candidate_index;
            if skipped == 0 {
                state.total += CONSECUTIVE_BONUS;
            } else {
                state.total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            state.total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }
        state.candidate_index = matched_index + 1;
        bounds.forward[query_index + 1] = state.candidate_index;
        prefixes[query_index + 1] = state;
        matched_prefix = query_index + 1;
    }

    CharMatchContext {
        bounds,
        prefixes,
        matched_prefix,
    }
}

fn fill_char_backward(query: &[QueryChar], candidate: &[char], bounds: &mut MatchBounds) {
    bounds.backward[query.len()] = candidate.len();
    let mut candidate_index = candidate.len();
    for query_index in (0..query.len()).rev() {
        let mut matched = false;
        while candidate_index > 0 {
            candidate_index -= 1;
            if query[query_index].matches(candidate[candidate_index]) {
                matched = true;
                break;
            }
        }
        if !matched {
            break;
        }
        bounds.backward[query_index] = candidate_index;
    }
}

fn char_match_context(query: &[QueryChar], candidate: &[char]) -> CharMatchContext {
    let mut context = char_prefix_context(query, candidate);
    fill_char_backward(query, candidate, &mut context.bounds);
    context
}

fn finish_char_score(
    mut state: CharScoreState,
    query_len: usize,
    candidate_len: usize,
    penalty: i32,
    exact: bool,
) -> Score {
    let tail = candidate_len.saturating_sub(query_len);
    state.total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if state.prefix {
        state.total += PREFIX_BONUS;
    }
    if candidate_len == query_len && state.prefix {
        state.total += WHOLE_WORD_BONUS;
    }
    Score {
        score: state.total - penalty,
        exact: exact && state.prefix,
    }
}

#[inline]
fn substitution_matches(bounds: &MatchBounds, index: usize) -> bool {
    let start = bounds.forward[index];
    let end = bounds.backward[index + 1];
    start != NO_MATCH && end != NO_MATCH && start < end
}

#[inline]
fn deletion_matches(bounds: &MatchBounds, index: usize) -> bool {
    let start = bounds.forward[index];
    let end = bounds.backward[index + 1];
    start != NO_MATCH && end != NO_MATCH && start <= end
}

fn ascii_swap_matches(query: &[u8], candidate: &[u8], bounds: &MatchBounds, index: usize) -> bool {
    let mut candidate_index = bounds.forward[index];
    let end = bounds.backward[index + 2];
    if candidate_index == NO_MATCH || end == NO_MATCH {
        return false;
    }
    for query_byte in [query[index + 1], query[index]] {
        while candidate_index < end && !candidate[candidate_index].eq_ignore_ascii_case(&query_byte)
        {
            candidate_index += 1;
        }
        if candidate_index == end {
            return false;
        }
        candidate_index += 1;
    }
    true
}

fn char_swap_matches(
    query: &[QueryChar],
    candidate: &[char],
    bounds: &MatchBounds,
    index: usize,
) -> bool {
    let mut candidate_index = bounds.forward[index];
    let end = bounds.backward[index + 2];
    if candidate_index == NO_MATCH || end == NO_MATCH {
        return false;
    }
    for query_char in [query[index + 1], query[index]] {
        while candidate_index < end && !query_char.matches(candidate[candidate_index]) {
            candidate_index += 1;
        }
        if candidate_index == end {
            return false;
        }
        candidate_index += 1;
    }
    true
}

#[inline]
fn typo_prefix_score(
    matched_len: usize,
    case_matches: usize,
    boundary_matches: usize,
    candidate_len: usize,
    edits: u8,
) -> Score {
    let mut total = MATCH_BONUS * matched_len as i32
        + CASE_BONUS * case_matches as i32
        + BOUNDARY_BONUS * boundary_matches as i32
        + CONSECUTIVE_BONUS * matched_len.saturating_sub(1) as i32
        + PREFIX_BONUS;
    let tail = candidate_len.saturating_sub(matched_len);
    total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if candidate_len == matched_len {
        total += WHOLE_WORD_BONUS;
    }
    Score {
        score: total - TYPO_PENALTY - SECOND_TYPO_PENALTY * i32::from(edits.saturating_sub(1)),
        exact: false,
    }
}

fn ascii_deletion_prefix_matches(query: &[u8], candidate: &[u8]) -> bool {
    let mut query_index = 0usize;
    let mut candidate_index = 0usize;
    let mut deleted = false;
    while candidate_index + 1 < query.len() {
        if candidate[candidate_index].eq_ignore_ascii_case(&query[query_index]) {
            candidate_index += 1;
            query_index += 1;
        } else if !deleted {
            deleted = true;
            query_index += 1;
        } else {
            return false;
        }
    }
    true
}

fn char_deletion_prefix_matches(query: &[QueryChar], candidate: &[char]) -> bool {
    let mut query_index = 0usize;
    let mut candidate_index = 0usize;
    let mut deleted = false;
    while candidate_index + 1 < query.len() {
        if query[query_index].matches(candidate[candidate_index]) {
            candidate_index += 1;
            query_index += 1;
        } else if !deleted {
            deleted = true;
            query_index += 1;
        } else {
            return false;
        }
    }
    true
}

fn ascii_deletion_case_matches(query: &[u8], candidate: &[u8]) -> Option<usize> {
    if !ascii_deletion_prefix_matches(query, candidate) {
        return None;
    }
    let repaired_len = query.len() - 1;
    let mut prefix_matches = [false; MAX_PREFIX_TYPO_QUERY_CHARS + 1];
    let mut prefix_cases = [0usize; MAX_PREFIX_TYPO_QUERY_CHARS + 1];
    prefix_matches[0] = true;
    for index in 0..repaired_len {
        prefix_matches[index + 1] =
            prefix_matches[index] && candidate[index].eq_ignore_ascii_case(&query[index]);
        prefix_cases[index + 1] =
            prefix_cases[index] + usize::from(candidate[index] == query[index]);
    }

    let mut suffix_matches = [false; MAX_PREFIX_TYPO_QUERY_CHARS];
    let mut suffix_cases = [0usize; MAX_PREFIX_TYPO_QUERY_CHARS];
    suffix_matches[repaired_len] = true;
    for index in (0..repaired_len).rev() {
        suffix_matches[index] =
            suffix_matches[index + 1] && candidate[index].eq_ignore_ascii_case(&query[index + 1]);
        suffix_cases[index] =
            suffix_cases[index + 1] + usize::from(candidate[index] == query[index + 1]);
    }

    (0..query.len())
        .filter(|&deleted| prefix_matches[deleted] && suffix_matches[deleted])
        .map(|deleted| prefix_cases[deleted] + suffix_cases[deleted])
        .max()
}

fn char_deletion_case_matches(query: &[QueryChar], candidate: &[char]) -> Option<usize> {
    if !char_deletion_prefix_matches(query, candidate) {
        return None;
    }
    let repaired_len = query.len() - 1;
    let mut prefix_matches = [false; MAX_PREFIX_TYPO_QUERY_CHARS + 1];
    let mut prefix_cases = [0usize; MAX_PREFIX_TYPO_QUERY_CHARS + 1];
    prefix_matches[0] = true;
    for index in 0..repaired_len {
        prefix_matches[index + 1] = prefix_matches[index] && query[index].matches(candidate[index]);
        prefix_cases[index + 1] =
            prefix_cases[index] + usize::from(candidate[index] == query[index].original);
    }

    let mut suffix_matches = [false; MAX_PREFIX_TYPO_QUERY_CHARS];
    let mut suffix_cases = [0usize; MAX_PREFIX_TYPO_QUERY_CHARS];
    suffix_matches[repaired_len] = true;
    for index in (0..repaired_len).rev() {
        suffix_matches[index] =
            suffix_matches[index + 1] && query[index + 1].matches(candidate[index]);
        suffix_cases[index] =
            suffix_cases[index + 1] + usize::from(candidate[index] == query[index + 1].original);
    }

    (0..query.len())
        .filter(|&deleted| prefix_matches[deleted] && suffix_matches[deleted])
        .map(|deleted| prefix_cases[deleted] + suffix_cases[deleted])
        .max()
}

#[inline]
fn score_typo_prefix_ascii(query: &[u8], candidate: &[u8], candidate_len: usize) -> Option<Score> {
    let query_len = query.len();

    if candidate.len() >= query_len {
        let mut mismatches = [0usize; 2];
        let mut mismatch_count = 0usize;
        let mut case_matches = 0usize;
        for index in 0..query_len {
            if candidate[index].eq_ignore_ascii_case(&query[index]) {
                case_matches += usize::from(candidate[index] == query[index]);
            } else {
                if mismatch_count < mismatches.len() {
                    mismatches[mismatch_count] = index;
                }
                mismatch_count += 1;
                if mismatch_count > mismatches.len() {
                    break;
                }
            }
        }

        if mismatch_count == 1 {
            let boundaries = (0..query_len)
                .filter(|&index| is_ascii_boundary(candidate, index))
                .count();
            return Some(typo_prefix_score(
                query_len,
                case_matches,
                boundaries,
                candidate_len,
                1,
            ));
        } else if mismatch_count == 2 {
            let left = mismatches[0];
            let right = mismatches[1];
            if right == left + 1
                && candidate[left].eq_ignore_ascii_case(&query[right])
                && candidate[right].eq_ignore_ascii_case(&query[left])
            {
                let boundaries = (0..query_len)
                    .filter(|&index| is_ascii_boundary(candidate, index))
                    .count();
                case_matches += usize::from(candidate[left] == query[right]);
                case_matches += usize::from(candidate[right] == query[left]);
                return Some(typo_prefix_score(
                    query_len,
                    case_matches,
                    boundaries,
                    candidate_len,
                    1,
                ));
            }
        }
    }

    let repaired_len = query_len - 1;
    if candidate.len() >= repaired_len
        && let Some(case_matches) = ascii_deletion_case_matches(query, &candidate[..repaired_len])
    {
        let boundaries = (0..repaired_len)
            .filter(|&index| is_ascii_boundary(candidate, index))
            .count();
        return Some(typo_prefix_score(
            repaired_len,
            case_matches,
            boundaries,
            candidate_len,
            1,
        ));
    }
    None
}

#[inline]
fn score_typo_prefix_chars(query: &[QueryChar], candidate: &[char]) -> Option<Score> {
    let query_len = query.len();

    if candidate.len() >= query_len {
        let mut mismatches = [0usize; 2];
        let mut mismatch_count = 0usize;
        let mut case_matches = 0usize;
        for index in 0..query_len {
            if query[index].matches(candidate[index]) {
                case_matches += usize::from(candidate[index] == query[index].original);
            } else {
                if mismatch_count < mismatches.len() {
                    mismatches[mismatch_count] = index;
                }
                mismatch_count += 1;
                if mismatch_count > mismatches.len() {
                    break;
                }
            }
        }

        if mismatch_count == 1 {
            let boundaries = candidate[..query_len]
                .iter()
                .copied()
                .enumerate()
                .filter(|(index, character)| {
                    is_boundary(
                        index.checked_sub(1).map(|previous| candidate[previous]),
                        *character,
                    )
                })
                .count();
            return Some(typo_prefix_score(
                query_len,
                case_matches,
                boundaries,
                candidate.len(),
                1,
            ));
        } else if mismatch_count == 2 {
            let left = mismatches[0];
            let right = mismatches[1];
            if right == left + 1
                && query[right].matches(candidate[left])
                && query[left].matches(candidate[right])
            {
                let boundaries = candidate[..query_len]
                    .iter()
                    .copied()
                    .enumerate()
                    .filter(|(index, character)| {
                        is_boundary(
                            index.checked_sub(1).map(|previous| candidate[previous]),
                            *character,
                        )
                    })
                    .count();
                case_matches += usize::from(candidate[left] == query[right].original);
                case_matches += usize::from(candidate[right] == query[left].original);
                return Some(typo_prefix_score(
                    query_len,
                    case_matches,
                    boundaries,
                    candidate.len(),
                    1,
                ));
            }
        }
    }

    let repaired_len = query_len - 1;
    if candidate.len() >= repaired_len
        && let Some(case_matches) = char_deletion_case_matches(query, &candidate[..repaired_len])
    {
        let boundaries = candidate[..repaired_len]
            .iter()
            .copied()
            .enumerate()
            .filter(|(index, character)| {
                is_boundary(
                    index.checked_sub(1).map(|previous| candidate[previous]),
                    *character,
                )
            })
            .count();
        return Some(typo_prefix_score(
            repaired_len,
            case_matches,
            boundaries,
            candidate.len(),
            1,
        ));
    }
    None
}

#[derive(Clone, Copy)]
struct PrefixRepairState {
    query_index: usize,
    candidate_index: usize,
    edits: u8,
    case_matches: usize,
    boundary_matches: usize,
}

#[inline]
fn score_two_typo_prefix_ascii(query: &[u8], candidate: &[u8]) -> Option<Score> {
    const EDITS: u8 = 2;
    const MAX_STATES: usize = 8;

    let mut best = None;
    let initial = PrefixRepairState {
        query_index: 0,
        candidate_index: 0,
        edits: 0,
        case_matches: 0,
        boundary_matches: 0,
    };
    let mut states = [initial; MAX_STATES];
    let mut state_count = 1usize;
    while state_count > 0 {
        state_count -= 1;
        let mut state = states[state_count];
        loop {
            if state.query_index == query.len() {
                if state.edits == EDITS {
                    update_best(
                        &mut best,
                        Some(typo_prefix_score(
                            state.candidate_index,
                            state.case_matches,
                            state.boundary_matches,
                            candidate.len(),
                            EDITS,
                        )),
                    );
                }
                break;
            }

            let remaining_edits = usize::from(EDITS - state.edits);
            if query.len() - state.query_index
                > candidate.len() - state.candidate_index + remaining_edits
            {
                break;
            }
            if state.candidate_index == candidate.len() {
                if query.len() - state.query_index == remaining_edits {
                    update_best(
                        &mut best,
                        Some(typo_prefix_score(
                            state.candidate_index,
                            state.case_matches,
                            state.boundary_matches,
                            candidate.len(),
                            EDITS,
                        )),
                    );
                }
                break;
            }

            let query_byte = query[state.query_index];
            let candidate_byte = candidate[state.candidate_index];
            let boundary = usize::from(is_ascii_boundary(candidate, state.candidate_index));
            if candidate_byte.eq_ignore_ascii_case(&query_byte) {
                state.query_index += 1;
                state.candidate_index += 1;
                state.case_matches += usize::from(candidate_byte == query_byte);
                state.boundary_matches += boundary;
                continue;
            }
            if state.edits == EDITS {
                break;
            }

            debug_assert!(state_count + 4 <= MAX_STATES);
            states[state_count] = PrefixRepairState {
                query_index: state.query_index + 1,
                candidate_index: state.candidate_index + 1,
                edits: state.edits + 1,
                boundary_matches: state.boundary_matches + boundary,
                ..state
            };
            state_count += 1;
            states[state_count] = PrefixRepairState {
                query_index: state.query_index + 1,
                edits: state.edits + 1,
                ..state
            };
            state_count += 1;

            if state.query_index + 1 < query.len()
                && state.candidate_index + 1 < candidate.len()
                && candidate_byte.eq_ignore_ascii_case(&query[state.query_index + 1])
                && candidate[state.candidate_index + 1].eq_ignore_ascii_case(&query_byte)
            {
                let next_candidate = candidate[state.candidate_index + 1];
                states[state_count] = PrefixRepairState {
                    query_index: state.query_index + 2,
                    candidate_index: state.candidate_index + 2,
                    edits: state.edits + 1,
                    case_matches: state.case_matches
                        + usize::from(candidate_byte == query[state.query_index + 1])
                        + usize::from(next_candidate == query_byte),
                    boundary_matches: state.boundary_matches
                        + boundary
                        + usize::from(is_ascii_boundary(candidate, state.candidate_index + 1)),
                };
                state_count += 1;
            }
            if state.edits == 0
                && state.query_index + 2 < query.len()
                && state.candidate_index + 1 < candidate.len()
                && candidate_byte.eq_ignore_ascii_case(&query[state.query_index + 2])
                && candidate[state.candidate_index + 1].eq_ignore_ascii_case(&query_byte)
            {
                let next_candidate = candidate[state.candidate_index + 1];
                states[state_count] = PrefixRepairState {
                    query_index: state.query_index + 3,
                    candidate_index: state.candidate_index + 2,
                    edits: EDITS,
                    case_matches: state.case_matches
                        + usize::from(candidate_byte == query[state.query_index + 2])
                        + usize::from(next_candidate == query_byte),
                    boundary_matches: state.boundary_matches
                        + boundary
                        + usize::from(is_ascii_boundary(candidate, state.candidate_index + 1)),
                };
                state_count += 1;
            }
            break;
        }
    }
    best
}

#[inline]
fn score_two_typo_prefix_chars(query: &[QueryChar], candidate: &[char]) -> Option<Score> {
    const EDITS: u8 = 2;
    const MAX_STATES: usize = 8;

    let mut best = None;
    let initial = PrefixRepairState {
        query_index: 0,
        candidate_index: 0,
        edits: 0,
        case_matches: 0,
        boundary_matches: 0,
    };
    let mut states = [initial; MAX_STATES];
    let mut state_count = 1usize;
    while state_count > 0 {
        state_count -= 1;
        let mut state = states[state_count];
        loop {
            if state.query_index == query.len() {
                if state.edits == EDITS {
                    update_best(
                        &mut best,
                        Some(typo_prefix_score(
                            state.candidate_index,
                            state.case_matches,
                            state.boundary_matches,
                            candidate.len(),
                            EDITS,
                        )),
                    );
                }
                break;
            }

            let remaining_edits = usize::from(EDITS - state.edits);
            if query.len() - state.query_index
                > candidate.len() - state.candidate_index + remaining_edits
            {
                break;
            }
            if state.candidate_index == candidate.len() {
                if query.len() - state.query_index == remaining_edits {
                    update_best(
                        &mut best,
                        Some(typo_prefix_score(
                            state.candidate_index,
                            state.case_matches,
                            state.boundary_matches,
                            candidate.len(),
                            EDITS,
                        )),
                    );
                }
                break;
            }

            let query_char = query[state.query_index];
            let candidate_char = candidate[state.candidate_index];
            let boundary = usize::from(is_boundary(
                state
                    .candidate_index
                    .checked_sub(1)
                    .map(|previous| candidate[previous]),
                candidate_char,
            ));
            if query_char.matches(candidate_char) {
                state.query_index += 1;
                state.candidate_index += 1;
                state.case_matches += usize::from(candidate_char == query_char.original);
                state.boundary_matches += boundary;
                continue;
            }
            if state.edits == EDITS {
                break;
            }

            debug_assert!(state_count + 4 <= MAX_STATES);
            states[state_count] = PrefixRepairState {
                query_index: state.query_index + 1,
                candidate_index: state.candidate_index + 1,
                edits: state.edits + 1,
                boundary_matches: state.boundary_matches + boundary,
                ..state
            };
            state_count += 1;
            states[state_count] = PrefixRepairState {
                query_index: state.query_index + 1,
                edits: state.edits + 1,
                ..state
            };
            state_count += 1;

            if state.query_index + 1 < query.len()
                && state.candidate_index + 1 < candidate.len()
                && query[state.query_index + 1].matches(candidate_char)
                && query_char.matches(candidate[state.candidate_index + 1])
            {
                let next_candidate = candidate[state.candidate_index + 1];
                states[state_count] = PrefixRepairState {
                    query_index: state.query_index + 2,
                    candidate_index: state.candidate_index + 2,
                    edits: state.edits + 1,
                    case_matches: state.case_matches
                        + usize::from(candidate_char == query[state.query_index + 1].original)
                        + usize::from(next_candidate == query_char.original),
                    boundary_matches: state.boundary_matches
                        + boundary
                        + usize::from(is_boundary(Some(candidate_char), next_candidate)),
                };
                state_count += 1;
            }
            if state.edits == 0
                && state.query_index + 2 < query.len()
                && state.candidate_index + 1 < candidate.len()
                && query[state.query_index + 2].matches(candidate_char)
                && query_char.matches(candidate[state.candidate_index + 1])
            {
                let next_candidate = candidate[state.candidate_index + 1];
                states[state_count] = PrefixRepairState {
                    query_index: state.query_index + 3,
                    candidate_index: state.candidate_index + 2,
                    edits: EDITS,
                    case_matches: state.case_matches
                        + usize::from(candidate_char == query[state.query_index + 2].original)
                        + usize::from(next_candidate == query_char.original),
                    boundary_matches: state.boundary_matches
                        + boundary
                        + usize::from(is_boundary(Some(candidate_char), next_candidate)),
                };
                state_count += 1;
            }
            break;
        }
    }
    best
}

#[inline]
fn ascii_char_mask(value: &[u8]) -> [u64; 2] {
    let mut mask = [0; 2];
    for byte in value {
        let folded = byte.to_ascii_lowercase() as usize;
        mask[folded / 64] |= 1 << (folded % 64);
    }
    mask
}

#[inline]
fn is_ascii_boundary(bytes: &[u8], index: usize) -> bool {
    if index == 0 {
        return true;
    }

    let previous = bytes[index - 1];
    let current = bytes[index];
    !previous.is_ascii_alphanumeric()
        || (previous.is_ascii_lowercase() && current.is_ascii_uppercase())
        || (previous.is_ascii_digit() && current.is_ascii_alphabetic())
}

#[inline]
fn score_ascii(query: &[u8], candidate: &[u8]) -> Option<Score> {
    let mut candidate_index = 0usize;
    let mut previous_match: Option<usize> = None;
    let mut total = 0i32;
    let mut prefix = true;

    for (query_index, &query_byte) in query.iter().enumerate() {
        let mut matched_index = None;
        while candidate_index < candidate.len() {
            if candidate[candidate_index].eq_ignore_ascii_case(&query_byte) {
                matched_index = Some(candidate_index);
                break;
            }
            candidate_index += 1;
        }

        let matched_index = matched_index?;
        let matched = candidate[matched_index];
        prefix &= matched_index == query_index;
        total += MATCH_BONUS;
        if matched == query_byte {
            total += CASE_BONUS;
        }
        if is_ascii_boundary(candidate, matched_index) {
            total += BOUNDARY_BONUS;
        }
        if let Some(previous) = previous_match {
            let skipped = matched_index - previous - 1;
            if skipped == 0 {
                total += CONSECUTIVE_BONUS;
            } else {
                total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }

        previous_match = Some(matched_index);
        candidate_index = matched_index + 1;
    }

    let tail = candidate.len().saturating_sub(query.len());
    total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if prefix {
        total += PREFIX_BONUS;
    }
    if candidate.len() == query.len() && prefix {
        total += WHOLE_WORD_BONUS;
    }

    Some(Score {
        score: total,
        exact: prefix,
    })
}

#[inline]
#[cfg(test)]
fn score_typo_ascii(query: &[u8], wildcard: Option<usize>, candidate: &[u8]) -> Option<Score> {
    let mut candidate_index = 0usize;
    let mut previous_match: Option<usize> = None;
    let mut total = 0i32;
    let mut prefix = true;

    for (query_index, &query_byte) in query.iter().enumerate() {
        let mut matched_index = None;
        while candidate_index < candidate.len() {
            if wildcard == Some(query_index)
                || candidate[candidate_index].eq_ignore_ascii_case(&query_byte)
            {
                matched_index = Some(candidate_index);
                break;
            }
            candidate_index += 1;
        }

        let matched_index = matched_index?;
        let matched = candidate[matched_index];
        prefix &= matched_index == query_index;
        total += MATCH_BONUS;
        if wildcard != Some(query_index) && matched == query_byte {
            total += CASE_BONUS;
        }
        if is_ascii_boundary(candidate, matched_index) {
            total += BOUNDARY_BONUS;
        }
        if let Some(previous) = previous_match {
            let skipped = matched_index - previous - 1;
            if skipped == 0 {
                total += CONSECUTIVE_BONUS;
            } else {
                total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }

        previous_match = Some(matched_index);
        candidate_index = matched_index + 1;
    }

    let tail = candidate.len().saturating_sub(query.len());
    total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if prefix {
        total += PREFIX_BONUS;
    }
    if candidate.len() == query.len() && prefix {
        total += WHOLE_WORD_BONUS;
    }

    Some(Score {
        score: total - TYPO_PENALTY,
        exact: false,
    })
}

#[inline]
fn score_typo_ascii_from_prefix(
    query: &[u8],
    wildcard: Option<usize>,
    candidate: &[u8],
    start: usize,
    mut state: AsciiScoreState,
) -> Option<Score> {
    let mut previous_match = (start > 0).then(|| state.candidate_index - 1);
    for (query_index, query_byte) in query.iter().copied().enumerate().skip(start) {
        let matched_index = if wildcard == Some(query_index) {
            (state.candidate_index < candidate.len()).then_some(state.candidate_index)?
        } else {
            let mut matched_index = state.candidate_index;
            while matched_index < candidate.len()
                && !candidate[matched_index].eq_ignore_ascii_case(&query_byte)
            {
                matched_index += 1;
            }
            (matched_index < candidate.len()).then_some(matched_index)?
        };
        let matched = candidate[matched_index];
        state.prefix &= matched_index == query_index;
        state.total += MATCH_BONUS;
        if wildcard != Some(query_index) && matched == query_byte {
            state.total += CASE_BONUS;
        }
        if is_ascii_boundary(candidate, matched_index) {
            state.total += BOUNDARY_BONUS;
        }
        if let Some(previous) = previous_match {
            let skipped = matched_index - previous - 1;
            if skipped == 0 {
                state.total += CONSECUTIVE_BONUS;
            } else {
                state.total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            state.total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }
        previous_match = Some(matched_index);
        state.candidate_index = matched_index + 1;
    }

    let tail = candidate.len().saturating_sub(query.len());
    state.total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if state.prefix {
        state.total += PREFIX_BONUS;
    }
    if candidate.len() == query.len() && state.prefix {
        state.total += WHOLE_WORD_BONUS;
    }
    Some(Score {
        score: state.total - TYPO_PENALTY,
        exact: false,
    })
}

#[inline]
fn is_boundary(previous: Option<char>, current: char) -> bool {
    previous.is_none_or(|previous| {
        !previous.is_alphanumeric()
            || (previous.is_lowercase() && current.is_uppercase())
            || (previous.is_numeric() && current.is_alphabetic())
    })
}

#[inline]
fn score_chars<I>(query: I, query_len: usize, candidate: &str) -> Option<Score>
where
    I: IntoIterator<Item = QueryChar>,
{
    let mut candidate_chars = candidate.chars();
    let mut candidate_index = 0usize;
    let mut previous_candidate = None;
    let mut previous_match: Option<usize> = None;
    let mut total = 0i32;
    let mut prefix = true;

    for (query_index, query_char) in query.into_iter().enumerate() {
        loop {
            let candidate_char = candidate_chars.next()?;
            let matched_index = candidate_index;
            candidate_index += 1;
            let boundary = is_boundary(previous_candidate, candidate_char);
            previous_candidate = Some(candidate_char);
            if !query_char.matches(candidate_char) {
                continue;
            }

            prefix &= matched_index == query_index;
            total += MATCH_BONUS;
            if candidate_char == query_char.original {
                total += CASE_BONUS;
            }
            if boundary {
                total += BOUNDARY_BONUS;
            }
            if let Some(previous) = previous_match {
                let skipped = matched_index - previous - 1;
                if skipped == 0 {
                    total += CONSECUTIVE_BONUS;
                } else {
                    total -= skipped.min(MAX_GAP_PENALTY) as i32;
                }
            } else if matched_index > 0 {
                total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
            }
            previous_match = Some(matched_index);
            break;
        }
    }

    let candidate_len = candidate_index + candidate_chars.count();
    let tail = candidate_len.saturating_sub(query_len);
    total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if prefix {
        total += PREFIX_BONUS;
    }
    if candidate_len == query_len && prefix {
        total += WHOLE_WORD_BONUS;
    }

    Some(Score {
        score: total,
        exact: prefix,
    })
}

#[inline]
fn score_typo_chars_from_prefix(
    query: &[QueryChar],
    wildcard: Option<usize>,
    candidate: &[char],
    start: usize,
    mut state: CharScoreState,
) -> Option<Score> {
    let mut previous_match = (start > 0).then(|| state.candidate_index - 1);
    for (query_index, query_char) in query.iter().copied().enumerate().skip(start) {
        let matched_index = loop {
            let candidate_char = *candidate.get(state.candidate_index)?;
            let matched_index = state.candidate_index;
            state.candidate_index += 1;
            if wildcard != Some(query_index) && !query_char.matches(candidate_char) {
                continue;
            }
            break matched_index;
        };

        let candidate_char = candidate[matched_index];
        state.prefix &= matched_index == query_index;
        state.total += MATCH_BONUS;
        if wildcard != Some(query_index) && candidate_char == query_char.original {
            state.total += CASE_BONUS;
        }
        if is_boundary(
            matched_index
                .checked_sub(1)
                .map(|previous| candidate[previous]),
            candidate_char,
        ) {
            state.total += BOUNDARY_BONUS;
        }
        if let Some(previous) = previous_match {
            let skipped = matched_index - previous - 1;
            if skipped == 0 {
                state.total += CONSECUTIVE_BONUS;
            } else if matched_index > 0 {
                state.total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            state.total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }
        previous_match = Some(matched_index);
    }

    let tail = candidate.len().saturating_sub(query.len());
    state.total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if state.prefix {
        state.total += PREFIX_BONUS;
    }
    if candidate.len() == query.len() && state.prefix {
        state.total += WHOLE_WORD_BONUS;
    }

    Some(Score {
        score: state.total - TYPO_PENALTY,
        exact: false,
    })
}

#[inline]
#[cfg(test)]
fn score_typo_char_slice(
    query: &[QueryChar],
    wildcard: Option<usize>,
    candidate: &[char],
) -> Option<Score> {
    score_typo_chars_from_prefix(
        query,
        wildcard,
        candidate,
        0,
        CharScoreState {
            candidate_index: 0,
            total: 0,
            prefix: true,
        },
    )
}

pub fn score(query: &str, candidate: &str) -> Option<Score> {
    Query::new(query).score(candidate)
}

pub fn matched_ranges(query: &str, candidates: &[String]) -> Vec<Vec<usize>> {
    let query = Query::new(query);
    candidates
        .iter()
        .map(|candidate| query.matched_ranges(candidate))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_supports_unicode_subsequences() {
        let matched = score("你界", "你好世界").unwrap();
        assert!(matched.score > 0);
        assert!(!matched.exact);
    }

    #[test]
    fn t_rejects_missing_characters() {
        assert_eq!(score("xyz", "example"), None);
    }

    #[test]
    fn t_prefers_prefixes() {
        assert!(
            score("cmp", "completion").unwrap().score > score("cmp", "create_map").unwrap().score
        );
    }

    #[test]
    fn t_prefers_shorter_prefix_tails() {
        assert!(score("fun", "fund").unwrap().score > score("fun", "function").unwrap().score);
    }

    #[test]
    fn t_prefers_tighter_gaps() {
        assert!(score("abc", "a_bc").unwrap().score > score("abc", "a___bc").unwrap().score);
    }

    #[test]
    fn t_scores_equal_character_gaps_independently_of_utf8_width() {
        assert_eq!(
            score("ab", "axb").unwrap().score,
            score("ab", "a你b").unwrap().score
        );
    }

    #[test]
    fn t_supports_streaming_unicode_case_folding() {
        assert!(score("Σ", "σigma").is_some());
    }

    #[test]
    fn t_projects_strict_match_byte_ranges() {
        let candidates = [
            "Completion".to_owned(),
            "你好世界".to_owned(),
            "ÄpfelBeta".to_owned(),
            "other".to_owned(),
        ];

        assert_eq!(
            matched_ranges("cmp", &candidates[..1]),
            vec![vec![0, 1, 2, 4]]
        );
        assert_eq!(
            matched_ranges("你界", &candidates[1..2]),
            vec![vec![0, 3, 9, 12]]
        );
        assert_eq!(
            matched_ranges("äb", &candidates[2..3]),
            vec![vec![0, 2, 6, 7]]
        );
        assert_eq!(
            matched_ranges("xyz", &candidates[3..]),
            vec![Vec::<usize>::new()]
        );
        assert_eq!(
            matched_ranges("", &candidates[..1]),
            vec![Vec::<usize>::new()]
        );
    }

    #[test]
    fn t_supports_one_typo_variants() {
        let transposed = Query::new("pritn").typo().unwrap();
        assert_eq!(transposed.max_edits, 1);
        assert!(transposed.score("print").is_some());

        let substituted = Query::new("pront").typo().unwrap();
        assert!(substituted.score("print").is_some());

        let extra = Query::new("priint").typo().unwrap();
        assert!(extra.score("print").is_some());

        let multiple = Query::new("prxyt").typo().unwrap();
        assert!(multiple.score("print").is_none());

        let unicode = Query::new("你好界世").typo().unwrap();
        assert!(unicode.score("你好世界").is_some());
    }

    #[test]
    fn t_supports_two_typo_prefix_repairs() {
        for (query, candidate) in [
            ("complxtjon", "completion"),
            ("xycdefgh", "abcdefgh"),
            ("compxletionx", "completion"),
            ("abcedfghxj", "abcdefghij"),
            ("bacdfegh", "abcdefgh"),
            ("baabacaa", "baacbaa"),
            ("你坏世界和战未来", "你好世界和平未来"),
            ("甲乙丙丁戊己庚辛", "甲乙丙己丁庚辛"),
        ] {
            let typo = Query::new(query).typo().unwrap();
            assert_eq!(typo.max_edits, 2, "{query}");
            let repaired = typo
                .score(candidate)
                .unwrap_or_else(|| panic!("{query} -> {candidate}"));
            assert!(!repaired.exact, "{query}");
        }

        let typo = Query::new("xycdefgh").typo().unwrap();
        let (strict, repaired) = typo.matcher().score_both("abcdefgh");
        assert!(strict.is_none());
        assert!(repaired.is_some());
    }

    #[test]
    fn t_long_queries_keep_prefix_repairs_without_widening_fuzzy_scratch() {
        let candidate = "abcdefghijklmnopqrstuvwxyz0123456789ABCD";
        let query = "abcdefghijxlmnopqrstuvwxyz0123456789AxCD";
        let typo = Query::new(query).typo().unwrap();

        assert_eq!(typo.max_edits, 2);
        assert!(!typo.fuzzy_repairs);
        assert!(typo.score(candidate).is_some());
    }

    #[test]
    fn t_short_queries_do_not_receive_a_second_typo() {
        let typo = Query::new("abcxefy").typo().unwrap();
        assert_eq!(typo.max_edits, 1);
        assert!(typo.score("abcdefg").is_none());
    }

    fn reference_prefix_distance(query: &[u8], candidate: &[u8]) -> usize {
        let mut rows = [[u8::MAX; 9]; 9];
        for (index, row) in rows.iter_mut().enumerate().take(query.len() + 1) {
            row[0] = index as u8;
        }
        for query_len in 1..=query.len() {
            for candidate_len in 1..=candidate.len() {
                let mut cost = rows[query_len - 1][candidate_len].saturating_add(1);
                cost = cost.min(
                    rows[query_len - 1][candidate_len - 1].saturating_add(u8::from(
                        query[query_len - 1] != candidate[candidate_len - 1],
                    )),
                );
                if query_len >= 2
                    && candidate_len >= 2
                    && query[query_len - 1] == candidate[candidate_len - 2]
                    && query[query_len - 2] == candidate[candidate_len - 1]
                {
                    cost = cost.min(rows[query_len - 2][candidate_len - 2].saturating_add(1));
                }
                rows[query_len][candidate_len] = cost;
            }
        }
        usize::from(rows[query.len()][candidate.len()])
    }

    fn binary_word(value: usize, len: usize) -> Vec<u8> {
        (0..len)
            .map(|index| {
                if value & (1 << index) == 0 {
                    b'a'
                } else {
                    b'b'
                }
            })
            .collect()
    }

    #[test]
    fn t_two_typo_prefix_search_matches_bounded_reference() {
        let query_len = 8;
        for query_value in 0..1 << query_len {
            let query = binary_word(query_value, query_len);
            for candidate_len in query_len - 2..=query_len {
                for candidate_value in 0..1 << candidate_len {
                    let candidate = binary_word(candidate_value, candidate_len);
                    let distance = (query_len - 2..=candidate_len)
                        .map(|prefix_len| {
                            reference_prefix_distance(&query, &candidate[..prefix_len])
                        })
                        .min();
                    let expected = distance.is_some_and(|distance| distance <= 2);
                    let actual = score_ascii(&query, &candidate).is_some()
                        || score_typo_prefix_ascii(&query, &candidate, candidate.len()).is_some()
                        || score_two_typo_prefix_ascii(&query, &candidate).is_some();
                    assert_eq!(
                        expected,
                        actual,
                        "query={:?} candidate={:?}",
                        String::from_utf8_lossy(&query),
                        String::from_utf8_lossy(&candidate)
                    );
                }
            }
        }
    }

    #[test]
    fn t_prefers_a_prefix_repair_over_weaker_typo_alignments() {
        let repaired = Query::new("aabc").typo().unwrap().score("aaacb").unwrap();

        assert!(repaired.score > 0);
        assert!(!repaired.exact);
    }

    #[test]
    fn t_fuzzy_typo_uses_the_best_available_alignment() {
        let repaired = Query::new("a_bb")
            .typo()
            .unwrap()
            .score("__b_babb")
            .unwrap();

        assert!(repaired.score > 0);
    }

    #[test]
    fn t_fuzzy_typo_does_not_short_circuit_on_a_lower_score() {
        let repaired = Query::new("c_c_ccab_")
            .typo()
            .unwrap()
            .score("__ccddcc_ccab_bb")
            .unwrap();

        assert_eq!(repaired.score, 114);
    }

    #[test]
    fn t_combined_matching_preserves_strict_scores() {
        for (query, candidate) in [
            ("cdvl42", "candidate_value_00042"),
            ("候c值一", "候选candidate值一00042"),
        ] {
            let strict = Query::new(query);
            let typo = strict.typo().unwrap();
            let mut matcher = typo.matcher();
            let (combined, _) = matcher.score_both(candidate);

            assert_eq!(combined, strict.score(candidate));
        }
    }

    #[test]
    fn t_shared_ascii_prefix_scoring_matches_full_scoring() {
        let typo = Query::new("abcdefghijklmnopqrstuvxw").typo().unwrap();
        let query = typo.ascii.as_deref().unwrap();
        let candidate = b"__a_b_c_d_e_f_g_h_i_j_k_l_m_n_o_p_q_r_s_t_u_v_w_x_candidate";
        let context = ascii_match_context(query, candidate);

        for variants in [
            &typo.swaps[..],
            &typo.substitutions[..],
            &typo.deletions[..],
        ] {
            for variant in variants {
                let variant_query = variant.ascii.as_deref().unwrap();
                let actual = (variant.edit_index <= context.matched_prefix)
                    .then(|| {
                        score_typo_ascii_from_prefix(
                            variant_query,
                            variant.wildcard,
                            candidate,
                            variant.edit_index,
                            context.prefixes[variant.edit_index],
                        )
                    })
                    .flatten();
                assert_eq!(
                    actual,
                    score_typo_ascii(variant_query, variant.wildcard, candidate)
                );
            }
        }
    }

    #[test]
    fn t_shared_unicode_prefix_scoring_matches_full_scoring() {
        let typo = Query::new("你一二三四界世").typo().unwrap();
        let candidate = "__你_一_二_三_四_世_界_candidate"
            .chars()
            .collect::<Vec<_>>();
        let context = char_match_context(&typo.chars, &candidate);

        for variants in [
            &typo.swaps[..],
            &typo.substitutions[..],
            &typo.deletions[..],
        ] {
            for variant in variants {
                let actual = (variant.edit_index <= context.matched_prefix)
                    .then(|| {
                        score_typo_chars_from_prefix(
                            &variant.chars,
                            variant.wildcard,
                            &candidate,
                            variant.edit_index,
                            context.prefixes[variant.edit_index],
                        )
                    })
                    .flatten();
                assert_eq!(
                    actual,
                    score_typo_char_slice(&variant.chars, variant.wildcard, &candidate)
                );
            }
        }
    }

    #[test]
    fn t_bounds_typo_query_length() {
        assert!(Query::new("abc").typo().is_none());
        assert_eq!(Query::new("abcdefgh").typo().unwrap().max_edits, 2);
        let too_long = "a".repeat(MAX_PREFIX_TYPO_QUERY_CHARS + 1);
        assert!(Query::new(&too_long).typo().is_none());
    }
}
