//! Unicode fuzzy matching and bounded typo scoring, independent of completion metadata.

#[cfg(target_arch = "x86_64")]
mod simd;
#[cfg(target_arch = "x86_64")]
mod simd16;

const UNREACHABLE: i32 = i32::MIN / 4;
const TYPO_COST: i32 = 80;
const CASE_FLAG: u8 = 128;
const CASE_BONUS: u8 = 4;
const MAX_FUZZY_QUERY: usize = 128;

fn case_flag(ch: char) -> u8 {
    if ch.is_ascii_uppercase() {
        CASE_FLAG
    } else {
        0
    }
}

#[derive(Debug)]
pub(super) struct Candidate {
    chars: Vec<char>,
    // The high bit stores ASCII case; the remaining bits hold the boundary bonus.
    bonuses: Vec<u8>,
}

impl Candidate {
    pub(super) fn new(text: &str) -> Self {
        if text.is_ascii() {
            let mut chars = Vec::with_capacity(text.len());
            let mut bonuses = Vec::with_capacity(text.len());
            let mut previous: Option<u8> = None;
            for byte in text.bytes() {
                let boundary = previous.is_none_or(|prev| {
                    !prev.is_ascii_alphanumeric()
                        || (prev.is_ascii_lowercase() && byte.is_ascii_uppercase())
                });
                chars.push(char::from(byte.to_ascii_lowercase()));
                bonuses.push(
                    (if boundary { 24 } else { 0 })
                        | (if byte.is_ascii_uppercase() {
                            CASE_FLAG
                        } else {
                            0
                        }),
                );
                previous = Some(byte);
            }
            return Self { chars, bonuses };
        }
        let capacity = text.chars().count();
        let mut chars = Vec::with_capacity(capacity);
        let mut bonuses = Vec::with_capacity(capacity);
        let mut previous: Option<char> = None;
        for ch in text.chars() {
            let boundary = previous.is_none_or(|prev| {
                !prev.is_alphanumeric() || (prev.is_lowercase() && ch.is_uppercase())
            });
            for lower in ch.to_lowercase() {
                chars.push(lower);
                bonuses.push((if boundary { 24 } else { 0 }) | case_flag(ch));
            }
            previous = Some(ch);
        }
        Self { chars, bonuses }
    }

    #[inline]
    fn bonus(&self, index: usize, casing: u8) -> u8 {
        let value = self.bonuses[index];
        (value & !CASE_FLAG)
            + if value & CASE_FLAG == casing {
                CASE_BONUS
            } else {
                0
            }
    }

    fn is_subsequence(&self, needle: &[char]) -> bool {
        let mut index = 0;
        for ch in &self.chars {
            if *ch == needle[index] {
                index += 1;
                if index == needle.len() {
                    return true;
                }
            }
        }
        false
    }

    fn score<const TRACE: bool>(
        &self,
        needle: &[char],
        casing: &[u8],
        scratch: &mut Scratch,
    ) -> Option<i32> {
        let size = self.chars.len();
        if TRACE {
            scratch.trace.clear();
        }
        scratch.previous.resize(size, UNREACHABLE);
        scratch.current.resize(size, UNREACHABLE);
        scratch.previous.fill(UNREACHABLE);
        for (i, ch) in needle.iter().enumerate() {
            scratch.current.fill(UNREACHABLE);
            let mut best_gap = UNREACHABLE;
            for j in 0..size {
                if j >= 2 {
                    best_gap = best_gap.max(scratch.previous[j - 2] + (j - 2) as i32);
                }
                if self.chars[j] != *ch {
                    continue;
                }
                let previous = if i == 0 {
                    if j == 0 { 40 } else { -(j.min(40) as i32) }
                } else if j == 0 {
                    UNREACHABLE
                } else {
                    (scratch.previous[j - 1] + 12).max(best_gap - j as i32 + 1)
                };
                scratch.current[j] = previous + 16 + i32::from(self.bonus(j, casing[i]));
            }
            std::mem::swap(&mut scratch.previous, &mut scratch.current);
            if TRACE {
                scratch.trace.extend_from_slice(&scratch.previous);
            }
        }
        let score = *scratch.previous.iter().max()?;
        (score > UNREACHABLE / 2).then_some(score)
    }

    fn typo_score(
        &self,
        needle: &[char],
        casing: &[u8],
        errors: usize,
        scratch: &mut Scratch,
    ) -> Option<i32> {
        #[cfg(target_arch = "x86_64")]
        if self.chars.len() >= 8 && std::is_x86_feature_detected!("avx2") {
            if (16..=4096).contains(&self.chars.len())
                && self.chars.len() % 16 < 8
                && needle.len() <= 128
            {
                /* These bounds keep real scores and column-adjusted prefix maxima in i16.
                 * An eight-character tail is cheaper in the i32 kernel than a scalar i16 tail. */
                return unsafe { simd16::typo_score(self, needle, casing, errors, scratch) };
            }
            // CPU detection guards the target-feature function; it checks all vector load bounds.
            return unsafe { simd::typo_score(self, needle, casing, errors, scratch) };
        }
        self.typo_score_scalar::<false>(needle, casing, errors, scratch)
    }

    fn typo_score_scalar<const TRACE: bool>(
        &self,
        needle: &[char],
        casing: &[u8],
        errors: usize,
        scratch: &mut Scratch,
    ) -> Option<i32> {
        let width = self.chars.len() + 1;
        let size = width * (errors + 1);
        let (previous, before_previous, current) = (
            &mut scratch.typo_previous,
            &mut scratch.typo_before_previous,
            &mut scratch.typo_current,
        );
        previous.resize(size, UNREACHABLE);
        before_previous.resize(size, UNREACHABLE);
        current.resize(size, UNREACHABLE);
        previous.fill(UNREACHABLE);
        before_previous.fill(UNREACHABLE);
        for value in &mut previous[..width] {
            *value = 0;
        }
        if TRACE {
            scratch.trace.clear();
            scratch.trace.extend_from_slice(previous);
        }

        for i in 1..=needle.len() {
            current.fill(UNREACHABLE);
            for e in 0..=errors.min(i) {
                if e == i {
                    current[e * width] = -(i as i32) * TYPO_COST;
                }
                for j in 1..width {
                    let index = e * width + j;
                    let mut score = current[index - 1] - 1;
                    if needle[i - 1] == self.chars[j - 1] {
                        score = score.max(
                            previous[index - 1] + 16 + i32::from(self.bonus(j - 1, casing[i - 1])),
                        );
                    }
                    if e > 0 {
                        score = score.max(previous[index - width] - TYPO_COST);
                        score = score.max(previous[index - width - 1] + 16 - TYPO_COST);
                        if i >= 2
                            && j >= 2
                            && needle[i - 1] == self.chars[j - 2]
                            && needle[i - 2] == self.chars[j - 1]
                        {
                            score = score.max(before_previous[index - width - 2] + 32 - TYPO_COST);
                        }
                    }
                    current[index] = score;
                }
            }
            std::mem::swap(before_previous, previous);
            std::mem::swap(previous, current);
            if TRACE {
                scratch.trace.extend_from_slice(previous);
            }
        }
        let score = *previous.iter().max()?;
        (score > UNREACHABLE / 2).then_some(score)
    }
}

#[derive(Default)]
pub(super) struct Scratch {
    trace: Vec<i32>,
    previous: Vec<i32>,
    current: Vec<i32>,
    typo_previous: Vec<i32>,
    typo_before_previous: Vec<i32>,
    typo_current: Vec<i32>,
    #[cfg(target_arch = "x86_64")]
    typo16_previous: Vec<i16>,
    #[cfg(target_arch = "x86_64")]
    typo16_before_previous: Vec<i16>,
    #[cfg(target_arch = "x86_64")]
    typo16_current: Vec<i16>,
}

#[derive(Debug)]
pub struct Matcher {
    candidates: Vec<Candidate>,
}

impl Matcher {
    pub(super) fn len(&self) -> usize {
        self.candidates.len()
    }

    pub fn new(labels: &[String]) -> Self {
        Self {
            candidates: labels.iter().map(|label| Candidate::new(label)).collect(),
        }
    }

    /// Returns one-based candidate indexes and scores in original candidate order.
    pub fn query(&self, query: &str) -> (Vec<usize>, Vec<i32>) {
        let mut indexes = Vec::new();
        let mut scores = Vec::new();
        self.for_each_match(query, |index, score| {
            indexes.push(index);
            scores.push(score);
        });
        (indexes, scores)
    }

    /// Native-endian (u32 index, i32 score) records avoid one Lua allocation call per scalar.
    pub(super) fn query_packed(&self, query: &str) -> Vec<u8> {
        let mut result = Vec::new();
        self.for_each_match(query, |index, score| {
            result.extend_from_slice(&(index as u32).to_ne_bytes());
            result.extend_from_slice(&score.to_ne_bytes());
        });
        result
    }

    pub(super) fn for_each_match(&self, text: &str, mut matched: impl FnMut(usize, i32)) {
        let query = Query::new(text);
        let mut scratch = Scratch::default();
        for (index, candidate) in self.candidates.iter().enumerate() {
            if let Some(score) = query.score(candidate, &mut scratch) {
                matched(index + 1, score);
            }
        }
    }
}

pub(super) struct Query {
    needle: Vec<char>,
    casing: Vec<u8>,
    errors: usize,
    required: Vec<(char, usize)>,
}

impl Query {
    pub(super) fn new(query: &str) -> Self {
        let mut needle = Vec::with_capacity(query.len().min(MAX_FUZZY_QUERY));
        let mut casing = Vec::with_capacity(query.len().min(MAX_FUZZY_QUERY));
        for ch in query.chars() {
            for lower in ch.to_lowercase() {
                needle.push(lower);
                casing.push(case_flag(ch));
            }
        }
        let errors = if needle.len() <= MAX_FUZZY_QUERY {
            (needle.len() / 4).min(2)
        } else {
            0
        };
        let mut required = Vec::new();
        if errors > 0 {
            for (i, ch) in needle.iter().enumerate() {
                if !needle[..i].contains(ch) {
                    required.push((*ch, needle.iter().filter(|value| *value == ch).count()));
                }
            }
        }
        Self {
            needle,
            casing,
            errors,
            required,
        }
    }

    pub(super) fn score(&self, candidate: &Candidate, scratch: &mut Scratch) -> Option<i32> {
        let Self {
            needle,
            casing,
            errors,
            required,
        } = self;
        let errors = *errors;
        if needle.len() > MAX_FUZZY_QUERY {
            /* Long queries use linear prefix matching, with the contiguous-match
             * score and no dynamic-programming matrix. */
            candidate.chars.starts_with(needle).then(|| {
                let mut score = 40_i32 + 64 - 12;
                for (index, case) in casing.iter().enumerate() {
                    score = score.saturating_add(28 + i32::from(candidate.bonus(index, *case)));
                }
                score.saturating_add(if candidate.chars.len() == needle.len() {
                    100
                } else {
                    0
                })
            })
        } else if needle.is_empty() {
            Some(0)
        } else if candidate.is_subsequence(needle) {
            candidate
                .score::<false>(needle, casing, scratch)
                .map(|score| {
                    score
                        + if candidate.chars == *needle { 100 } else { 0 }
                        + if candidate.chars.starts_with(needle) {
                            64
                        } else {
                            0
                        }
                })
        } else if errors > 0 && candidate.chars.len() + errors >= needle.len() {
            /* A missing character needs a deletion or substitution. Reject impossible
             * candidates before running the edit-distance pass. */
            let mut missing = 0;
            for (ch, needed) in required {
                let available = candidate.chars.iter().filter(|value| *value == ch).count();
                missing += needed.saturating_sub(available);
                if missing > errors {
                    break;
                }
            }
            if missing > errors {
                None
            } else {
                candidate.typo_score(needle, casing, errors, scratch)
            }
        } else {
            None
        }
    }

    fn matched_indices(&self, candidate: &Candidate) -> Option<Vec<usize>> {
        let size = candidate.chars.len();
        if self.needle.is_empty() || size == 0 {
            return None;
        }
        if self.needle.len() > MAX_FUZZY_QUERY {
            return candidate
                .chars
                .starts_with(&self.needle)
                .then(|| (0..self.needle.len()).collect());
        }
        /* Trace only visible labels, with a 4 MiB score-table budget. Very long labels
         * remain matchable but do not allocate an unbounded table for highlighting. */
        if (self.needle.len() + 1)
            .checked_mul(size + 1)?
            .checked_mul(self.errors + 1)?
            > 1_048_576
        {
            return None;
        }
        let mut scratch = Scratch::default();
        let mut indices = Vec::new();
        if candidate.is_subsequence(&self.needle) {
            let score = candidate.score::<true>(&self.needle, &self.casing, &mut scratch)?;
            let mut col = scratch.previous.iter().position(|value| *value == score)?;
            for row in (0..self.needle.len()).rev() {
                indices.push(col);
                if row == 0 {
                    break;
                }
                let previous = &scratch.trace[(row - 1) * size..row * size];
                let target = scratch.trace[row * size + col]
                    - 16
                    - i32::from(candidate.bonus(col, self.casing[row]));
                col = if col > 0 && previous[col - 1] + 12 == target {
                    col - 1
                } else {
                    (0..col.saturating_sub(1))
                        .rev()
                        .find(|index| previous[*index] - col as i32 + *index as i32 + 1 == target)?
                };
            }
        } else {
            if self.errors == 0 || size + self.errors < self.needle.len() {
                return None;
            }
            let score = candidate.typo_score_scalar::<true>(
                &self.needle,
                &self.casing,
                self.errors,
                &mut scratch,
            )?;
            let last = scratch
                .typo_previous
                .iter()
                .position(|value| *value == score)?;
            let width = size + 1;
            let stride = width * (self.errors + 1);
            let at = |row: usize, errors: usize, col: usize| {
                scratch.trace[row * stride + errors * width + col]
            };
            let (mut row, mut errors, mut col) = (self.needle.len(), last / width, last % width);
            while row > 0 {
                let current = at(row, errors, col);
                if col > 0 && current == at(row, errors, col - 1) - 1 {
                    col -= 1;
                } else if col > 0
                    && self.needle[row - 1] == candidate.chars[col - 1]
                    && current
                        == at(row - 1, errors, col - 1)
                            + 16
                            + i32::from(candidate.bonus(col - 1, self.casing[row - 1]))
                {
                    indices.push(col - 1);
                    row -= 1;
                    col -= 1;
                } else if errors > 0 && current == at(row - 1, errors - 1, col) - TYPO_COST {
                    row -= 1;
                    errors -= 1;
                } else if errors > 0
                    && col > 0
                    && current == at(row - 1, errors - 1, col - 1) + 16 - TYPO_COST
                {
                    indices.push(col - 1);
                    row -= 1;
                    col -= 1;
                    errors -= 1;
                } else if errors > 0
                    && row >= 2
                    && col >= 2
                    && self.needle[row - 1] == candidate.chars[col - 2]
                    && self.needle[row - 2] == candidate.chars[col - 1]
                    && current == at(row - 2, errors - 1, col - 2) + 32 - TYPO_COST
                {
                    indices.extend([col - 1, col - 2]);
                    row -= 2;
                    col -= 2;
                    errors -= 1;
                } else {
                    return None;
                }
            }
        }
        indices.reverse();
        Some(indices)
    }
}

pub(super) fn match_ranges(query: &str, text: &str) -> Vec<[usize; 2]> {
    let query = Query::new(query);
    let candidate = Candidate::new(text);
    let Some(indices) = query.matched_indices(&candidate) else {
        return Vec::new();
    };
    let bytes: Vec<_> = text
        .char_indices()
        .flat_map(|(start, ch)| {
            ch.to_lowercase()
                .map(move |_| [start, start + ch.len_utf8()])
        })
        .collect();
    let mut ranges: Vec<[usize; 2]> = Vec::new();
    for index in indices {
        let [start, end] = bytes[index];
        if let Some(last) = ranges.last_mut().filter(|last| start <= last[1]) {
            last[1] = end;
        } else {
            ranges.push([start, end]);
        }
    }
    ranges
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_ascii_candidate_metadata_agrees_with_unicode_classification() {
        let check = |text: &str| {
            let mut chars = Vec::new();
            let mut bonuses = Vec::new();
            let mut previous: Option<char> = None;
            for ch in text.chars() {
                let boundary = previous.is_none_or(|prev| {
                    !prev.is_alphanumeric() || (prev.is_lowercase() && ch.is_uppercase())
                });
                for lower in ch.to_lowercase() {
                    chars.push(lower);
                    bonuses.push((if boundary { 24 } else { 0 }) | case_flag(ch));
                }
                previous = Some(ch);
            }
            let candidate = Candidate::new(text);
            assert_eq!(candidate.chars, chars, "{text:?}");
            assert_eq!(candidate.bonuses, bonuses, "{text:?}");
        };
        check("");
        for first in 0u8..=127 {
            check(&char::from(first).to_string());
            for second in 0u8..=127 {
                check(std::str::from_utf8(&[first, second]).unwrap());
            }
        }
        for text in [
            "getCurrentUser",
            "get_current_user",
            "foo::Bar",
            "foo-bar",
            "a1B",
            "İstanbul",
            "Straße",
            "中文变量",
            "😀Name",
            "Éclair",
            "aßB",
            "aİB",
        ] {
            check(text);
        }
    }

    #[test]
    fn t_match_ranges_trace_subsequences_and_typos_with_original_utf8_boundaries() {
        assert_eq!(
            match_ranges("gcu", "get_current_user"),
            [[0, 1], [4, 5], [12, 13]]
        );
        for query in ["compleiton", "complextion", "completiom"] {
            assert_eq!(match_ranges(query, "completion"), [[0, 10]], "{query}");
        }
        assert_eq!(match_ranges("中变", "中文变量"), [[0, 3], [6, 9]]);
        assert_eq!(match_ranges("i\u{307}", "İstanbul"), [[0, 2]]);
        assert!(match_ranges("zzzz", "completion").is_empty());
        assert!(match_ranges("", "completion").is_empty());
        assert_eq!(match_ranges(&"a".repeat(129), &"a".repeat(130)), [[0, 129]]);
        assert!(match_ranges(&"a".repeat(128), &"a".repeat(10000)).is_empty());
    }

    #[test]
    fn t_traces_agree_with_matching_across_case_unicode_and_edit_paths() {
        let alphabet = ['a', 'B', 'c', '_', '中', 'é', 'İ'];
        let mut seed = 73_u32;
        let mut next = || {
            seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
            seed as usize
        };
        for case in 0..500 {
            let size = 4 + next() % 60;
            let text: String = (0..size)
                .map(|_| alphabet[next() % alphabet.len()])
                .collect();
            let mut query: Vec<char> = text.chars().step_by(2).take(12).collect();
            if case % 2 == 0 && query.len() >= 4 {
                query.swap(1, 2);
                if case % 3 == 0 {
                    query[1] = 'x';
                }
            }
            let query = Query::new(&query.into_iter().collect::<String>());
            let candidate = Candidate::new(&text);
            let expected = query.score(&candidate, &mut Scratch::default());
            let traced = query.matched_indices(&candidate);
            assert_eq!(traced.is_some(), expected.is_some(), "{case}: {text:?}");
            if let Some(indices) = traced {
                assert!(!indices.is_empty());
                assert!(indices.iter().all(|index| *index < candidate.chars.len()));
                assert!(indices.windows(2).all(|pair| pair[0] < pair[1]));
            }
        }
    }

    fn matcher(labels: &[&str]) -> Matcher {
        Matcher::new(
            &labels
                .iter()
                .map(|label| label.to_string())
                .collect::<Vec<_>>(),
        )
    }

    #[test]
    fn t_matches_subsequences_and_unicode() {
        let value = matcher(&["getCurrentUser", "get_config_url", "中文变量", "other"]);
        assert_eq!(value.query("gcu").0, vec![1, 2]);
        assert_eq!(value.query("中变").0, vec![3]);
        assert_eq!(value.query("OTHER").0, vec![4]);
    }

    #[test]
    fn t_prefers_exact_prefix_and_word_boundaries() {
        let value = matcher(&["foo", "fooBar", "xfoo", "fOtherOotherO"]);
        let (_, scores) = value.query("foo");
        assert!(scores[0] > scores[1]);
        assert!(scores[1] > scores[2]);
        assert!(
            scores[1] > scores[3],
            "prefix should beat separated boundaries: {scores:?}"
        );
        let (_, scores) = matcher(&["getCurrentUser", "getconfigurationurl"]).query("gcu");
        assert!(scores[0] > scores[1]);
    }

    #[test]
    fn t_ascii_case_changes_preference_without_filtering_other_cases() {
        let value = matcher(&["getClientUrl", "getCurrentUser", "get_current_user"]);
        let (lower_indexes, lower) = value.query("gcu");
        let (upper_indexes, upper) = value.query("GCU");
        assert_eq!(lower_indexes, upper_indexes);
        assert!(lower[2] > lower[0] && lower[2] > lower[1]);
        assert!(upper[0] > upper[2] && upper[1] > upper[2]);
        let (_, scores) = matcher(&["foo", "FOO"]).query("FOO");
        assert!(scores[1] > scores[0]);
    }

    #[test]
    fn t_handles_transposition_deletion_and_substitution() {
        let value = matcher(&["completion"]);
        assert_eq!(value.query("compleiton").0, vec![1]);
        assert_eq!(value.query("complextion").0, vec![1]);
        assert_eq!(value.query("completiom").0, vec![1]);
        assert!(value.query("xxxyyyzzz").0.is_empty());
        assert!(value.query("zmp").0.is_empty());
    }

    #[test]
    fn t_exact_matches_outrank_typos() {
        let (_, scores) = matcher(&["completion", "completiom"]).query("completion");
        assert!(scores[0] > scores[1]);
    }

    #[test]
    fn t_empty_and_long_queries_are_bounded() {
        let value = matcher(&["", "a", "another"]);
        assert_eq!(value.query("").0, vec![1, 2, 3]);
        assert_eq!(value.query("a").0, vec![2, 3]);
        assert!(value.query(&"a".repeat(129)).0.is_empty());
    }

    #[test]
    fn t_long_queries_keep_exact_prefix_case_and_unicode_matches() {
        for query in ["a".repeat(129), "İa".repeat(65), "x".repeat(16384)] {
            let prefix = format!("{query}.lua");
            let unrelated = format!("z{query}");
            let value = matcher(&[&prefix, &query, &unrelated]);
            let (indexes, scores) = value.query(&query);
            assert_eq!(indexes, [1, 2]);
            assert!(scores[1] > scores[0], "exact match outranks its extension");
            assert_eq!(match_ranges(&query, &prefix), [[0, query.len()]]);
            assert!(match_ranges(&query, &unrelated).is_empty());
            assert!(value.query(&format!("{query}missing")).0.is_empty());
        }
        let query = "Aa".repeat(65);
        let lower = query.to_lowercase();
        let (indexes, scores) = matcher(&[&query, &lower]).query(&query);
        assert_eq!(indexes, [1, 2]);
        assert!(
            scores[0] > scores[1],
            "matching ASCII case retains its bonus"
        );
    }

    #[test]
    fn t_query_reuses_original_candidate_indexes() {
        let value = matcher(&["alpha", "beta", "alpine"]);
        assert_eq!(value.query("al").0, vec![1, 3]);
        assert_eq!(value.query("bet").0, vec![2]);
        assert_eq!(value.query("al").0, vec![1, 3]);
    }

    #[test]
    fn t_typo_scratch_does_not_leak_between_candidate_lengths() {
        let labels = [
            "completion",
            "complete",
            "completiom",
            "completions_with_a_long_suffix",
            "completion",
            "中文变量",
            "",
        ];
        let value = matcher(&labels);
        for query in [
            "compleiton",
            "complextion",
            "completiom",
            "completino",
            "变量中文",
        ] {
            let (indexes, scores) = value.query(query);
            let mut expected_indexes = Vec::new();
            let mut expected_scores = Vec::new();
            for (index, label) in labels.iter().enumerate() {
                let (matched, individual_scores) = matcher(&[label]).query(query);
                if !matched.is_empty() {
                    expected_indexes.push(index + 1);
                    expected_scores.push(individual_scores[0]);
                }
            }
            assert_eq!(indexes, expected_indexes, "{query}");
            assert_eq!(scores, expected_scores, "{query}");
        }
    }

    #[test]
    fn t_packed_results_preserve_indexes_and_signed_scores() {
        let value = matcher(&[
            "completion",
            "complete",
            "foo",
            "变量名称",
            "different",
            "xbcd",
        ]);
        assert!(value.query("abcd").1.iter().any(|score| *score < 0));
        for query in [
            "",
            "foo",
            "变量",
            "compleiton",
            "abcd",
            "xyzzzz",
            &"a".repeat(129),
        ] {
            let (indexes, scores) = value.query(query);
            let packed = value.query_packed(query);
            assert_eq!(packed.len(), indexes.len() * 8);
            for (position, record) in packed.as_chunks::<8>().0.iter().enumerate() {
                assert_eq!(
                    u32::from_ne_bytes(record[..4].try_into().unwrap()) as usize,
                    indexes[position]
                );
                assert_eq!(
                    i32::from_ne_bytes(record[4..].try_into().unwrap()),
                    scores[position]
                );
            }
        }
    }

    #[cfg(target_arch = "x86_64")]
    #[test]
    fn t_avx2_matches_scalar_scores_across_unicode_and_vector_boundaries() {
        if !std::is_x86_feature_detected!("avx2") {
            return;
        }
        let alphabet = [
            'a',
            'b',
            'C',
            'd',
            '_',
            '中',
            'é',
            'İ',
            '😀',
            '\0',
            '\u{10061}',
        ];
        let lengths = [
            0, 1, 7, 8, 9, 15, 16, 17, 23, 24, 25, 31, 32, 33, 63, 64, 65, 129,
        ];
        let mut seed = 0x1234_5678_u32;
        let mut next = || {
            seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
            seed as usize
        };
        let mut scalar = Scratch::default();
        let mut vector = Scratch::default();
        for case in 0..3000 {
            let size = lengths[case % lengths.len()];
            let text: String = (0..size)
                .map(|_| alphabet[next() % alphabet.len()])
                .collect();
            let candidate = Candidate::new(&text);
            let query_size = next() % 20;
            let mut needle: Vec<char> = if case % 2 == 0 {
                candidate.chars.iter().copied().take(query_size).collect()
            } else {
                (0..query_size)
                    .map(|_| alphabet[next() % alphabet.len()])
                    .collect()
            };
            if needle.len() > 2 {
                let position = next() % (needle.len() - 1);
                needle.swap(position, position + 1);
                if case % 3 == 0 {
                    needle[position] = 'x';
                }
            }
            let casing: Vec<_> = needle.iter().copied().map(case_flag).collect();
            for errors in 0..=2 {
                let expected =
                    candidate.typo_score_scalar::<false>(&needle, &casing, errors, &mut scalar);
                let actual =
                    unsafe { simd::typo_score(&candidate, &needle, &casing, errors, &mut vector) };
                assert_eq!(
                    actual, expected,
                    "case {case}: {text:?}, {needle:?}, errors={errors}"
                );
                let narrow = unsafe {
                    simd16::typo_score(&candidate, &needle, &casing, errors, &mut vector)
                };
                assert_eq!(
                    narrow, expected,
                    "i16 case {case}: {text:?}, {needle:?}, errors={errors}"
                );
            }
        }
        let candidate = Candidate::new(&"aB_中".repeat(50));
        let needle: Vec<char> = "ab中".repeat(42).chars().collect();
        let casing: Vec<_> = needle.iter().copied().map(case_flag).collect();
        assert_eq!(
            unsafe { simd::typo_score(&candidate, &needle, &casing, 2, &mut vector) },
            candidate.typo_score_scalar::<false>(&needle, &casing, 2, &mut scalar)
        );
        let candidate = Candidate::new(&format!("a{}b", "_".repeat(4094)));
        let needle: Vec<char> = "abx".chars().collect();
        let casing: Vec<_> = needle.iter().copied().map(case_flag).collect();
        assert_eq!(
            unsafe { simd16::typo_score(&candidate, &needle, &casing, 2, &mut vector) },
            candidate.typo_score_scalar::<false>(&needle, &casing, 2, &mut scalar)
        );
        let candidate = Candidate::new(&format!("abcd{}efgh", "_".repeat(40000)));
        let needle: Vec<char> = "abdcfegh".chars().collect();
        let casing: Vec<_> = needle.iter().copied().map(case_flag).collect();
        let expected = candidate.typo_score_scalar::<false>(&needle, &casing, 2, &mut scalar);
        assert!(expected.is_some_and(|score| score < -8192));
        assert_eq!(
            candidate.typo_score(&needle, &casing, 2, &mut vector),
            expected
        );
    }
}
