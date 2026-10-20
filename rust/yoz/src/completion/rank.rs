//! Global completion ranking over immutable source snapshots.

use super::fuzzy::{Candidate as FuzzyCandidate, Query, Scratch};
use super::history::{History, Key};
use std::cmp::Ordering;
use std::collections::hash_map::DefaultHasher;
use std::collections::{BinaryHeap, HashSet};
use std::hash::{Hash, Hasher};

const MAX_ITEMS: usize = 200;

struct Nearby<'a> {
    chunks: Vec<&'a str>,
    pairs: [u64; 1024],
}

impl<'a> Nearby<'a> {
    fn new(text: &'a [u8]) -> Self {
        let chunks: Vec<_> = text.utf8_chunks().map(|chunk| chunk.valid()).collect();
        let mut pairs = [0; 1024];
        for chunk in &chunks {
            for bytes in chunk.as_bytes().windows(2) {
                let pair = usize::from(u16::from_le_bytes([bytes[0], bytes[1]]));
                pairs[pair / 64] |= 1 << (pair % 64);
            }
        }
        Self { chunks, pairs }
    }

    fn contains(&self, label: &str) -> bool {
        if label.is_empty() {
            return true;
        }
        let bytes = label.as_bytes();
        if bytes.len() >= 2 {
            let pair = usize::from(u16::from_le_bytes([
                bytes[bytes.len() - 2],
                bytes[bytes.len() - 1],
            ]));
            // A missing trailing byte pair rules out a match without rescanning nearby text.
            if self.pairs[pair / 64] & (1 << (pair % 64)) == 0 {
                return false;
            }
        }
        self.chunks.iter().any(|text| text.contains(label))
    }
}

pub(super) struct Identity {
    bytes: Box<[u8]>,
    hash: u64,
}

impl Identity {
    pub(super) fn new(bytes: &[u8]) -> Self {
        let mut hasher = DefaultHasher::new();
        bytes.hash(&mut hasher);
        Self {
            bytes: bytes.into(),
            hash: hasher.finish(),
        }
    }
}

impl PartialEq for Identity {
    fn eq(&self, other: &Self) -> bool {
        self.hash == other.hash && self.bytes == other.bytes
    }
}

impl Eq for Identity {}

impl Hash for Identity {
    fn hash<H: Hasher>(&self, state: &mut H) {
        // Snapshot preparation hashes the bytes; each query hashes only this fixed-size key.
        self.hash.hash(state);
    }
}

pub(super) struct Candidate {
    pub(super) fuzzy: FuzzyCandidate,
    // Identity can contain opaque edit bytes; matching text is validated separately.
    pub(super) id: Identity,
    pub(super) label: String,
    pub(super) sort_text: Option<String>,
    pub(super) has_sort_text: bool,
    pub(super) history_key: Key,
    pub(super) offset: f64,
    pub(super) deprecated: bool,
    pub(super) region: usize,
}

impl Candidate {
    fn sort_text(&self) -> Option<&str> {
        self.has_sort_text
            .then(|| self.sort_text.as_deref().unwrap_or(&self.label))
    }
}

pub(super) struct Snapshot {
    pub(super) candidates: Vec<Candidate>,
    pub(super) regions: usize,
}

pub(super) struct Request<'a> {
    pub(super) snapshot: &'a Snapshot,
    pub(super) query: &'a str,
    pub(super) eligible: &'a [bool],
}

pub(super) struct Ranked<'a> {
    pub(super) request: usize,
    pub(super) index: usize,
    pub(super) score: f64,
    candidate: &'a Candidate,
}

impl PartialEq for Ranked<'_> {
    fn eq(&self, other: &Self) -> bool {
        self.cmp(other) == Ordering::Equal
    }
}

impl Eq for Ranked<'_> {}

impl PartialOrd for Ranked<'_> {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Ranked<'_> {
    fn cmp(&self, other: &Self) -> Ordering {
        // The worst retained result is the largest element in the heap.
        other
            .score
            .total_cmp(&self.score)
            .then_with(|| self.candidate.sort_text().cmp(&other.candidate.sort_text()))
            .then_with(|| self.request.cmp(&other.request))
            .then_with(|| self.index.cmp(&other.index))
    }
}

pub(super) fn query<'a>(
    requests: &[Request<'a>],
    nearby: &[u8],
    mut history: Option<&mut History>,
    now: i64,
) -> Vec<Ranked<'a>> {
    let nearby = Nearby::new(nearby);
    let mut retained = BinaryHeap::with_capacity(MAX_ITEMS);
    let mut seen = HashSet::new();
    let mut scratch = Scratch::default();
    for (request_index, request) in requests.iter().enumerate() {
        let query = Query::new(request.query);
        for (index, candidate) in request.snapshot.candidates.iter().enumerate() {
            if !request.eligible[candidate.region] {
                continue;
            }
            let Some(base) = query.score(&candidate.fuzzy, &mut scratch) else {
                continue;
            };
            if !seen.insert(&candidate.id) {
                continue;
            }
            let mut score =
                f64::from(base) + candidate.offset - if candidate.deprecated { 2.0 } else { 0.0 };
            if let Some(history) = history.as_deref_mut() {
                score += f64::from(history.score(&candidate.history_key, now).min(6));
            }
            if !request.query.is_empty() && nearby.contains(&candidate.label) {
                score += 2.0;
            }
            let ranked = Ranked {
                request: request_index + 1,
                index: index + 1,
                score,
                candidate,
            };
            if retained.len() < MAX_ITEMS {
                retained.push(ranked);
            } else if let Some(mut worst) = retained.peek_mut() {
                if ranked < *worst {
                    *worst = ranked;
                }
            }
        }
    }
    retained.into_sorted_vec()
}

#[cfg(test)]
mod tests {
    use super::super::history;
    use super::*;

    #[test]
    fn t_nearby_filter_preserves_literal_matches_including_short_labels_and_invalid_bytes() {
        for text in [
            b"".as_slice(),
            b"alpha.omega\0beta",
            b"alpha\xffbeta",
            "前缀é变量".as_bytes(),
        ] {
            let nearby = Nearby::new(text);
            for label in [
                "", "a", "alpha", "omega", "beta", "ph", "ab", "\0b", "é", "变量", "缀é变",
            ] {
                let expected = label.is_empty()
                    || text
                        .utf8_chunks()
                        .any(|chunk| chunk.valid().contains(label));
                assert_eq!(nearby.contains(label), expected, "{text:?}: {label:?}");
            }
        }
    }

    fn candidate(id: &[u8], label: &str, sort: &str, offset: f64) -> Candidate {
        Candidate {
            fuzzy: FuzzyCandidate::new(label),
            id: Identity::new(id),
            label: label.into(),
            sort_text: (sort != label).then(|| sort.into()),
            has_sort_text: true,
            history_key: history::candidate_key("lua", id),
            offset,
            deprecated: false,
            region: 0,
        }
    }

    #[test]
    fn t_ranking_combines_scores_before_global_top_k() {
        let mut first = Snapshot {
            candidates: Vec::new(),
            regions: 1,
        };
        for index in 0..300 {
            let label = format!("item_{index:03}");
            first
                .candidates
                .push(candidate(label.as_bytes(), "match", &label, 1.0));
        }
        let second = Snapshot {
            candidates: vec![candidate(b"winner", "match", "zzzz", 3.0)],
            regions: 1,
        };
        let requests = [
            Request {
                snapshot: &first,
                query: "mat",
                eligible: &[true],
            },
            Request {
                snapshot: &second,
                query: "mat",
                eligible: &[true],
            },
        ];
        let ranked = query(&requests, b"", None, 0);
        assert_eq!(ranked.len(), 200);
        assert_eq!((ranked[0].request, ranked[0].index), (2, 1));
        assert_eq!(ranked[1].candidate.id.bytes.as_ref(), b"item_000");
        assert_eq!(ranked[199].candidate.id.bytes.as_ref(), b"item_198");
    }

    #[test]
    fn t_invalid_regions_and_nonmatching_duplicates_cannot_hide_valid_candidates() {
        let mut invalid = candidate(b"same", "foo", "0", 100.0);
        invalid.region = 1;
        let snapshot = Snapshot {
            candidates: vec![
                invalid,
                candidate(b"same", "bar", "1", 0.0),
                candidate(b"same", "foo", "2", 0.0),
            ],
            regions: 2,
        };
        let ranked = query(
            &[Request {
                snapshot: &snapshot,
                query: "foo",
                eligible: &[true, false],
            }],
            b"",
            None,
            0,
        );
        assert_eq!(ranked.len(), 1);
        assert_eq!(ranked[0].index, 3);
    }

    #[test]
    fn t_history_proximity_deprecation_and_empty_queries_keep_their_weights() {
        let first = candidate(b"first", "same", "a", 0.0);
        let mut preferred = candidate(b"preferred", "same", "b", 0.0);
        preferred.deprecated = true;
        let mut history = History::default();
        history.access(preferred.history_key, 100);
        let snapshot = Snapshot {
            candidates: vec![first, preferred],
            regions: 1,
        };
        let requests = [Request {
            snapshot: &snapshot,
            query: "sa",
            eligible: &[true],
        }];
        let without = query(&requests, b"same", None, 100);
        let with = query(&requests, b"same", Some(&mut history), 100);
        assert_eq!(without[0].index, 1);
        assert_eq!(with[0].index, 2);
        assert_eq!(with[0].score - without[1].score, 4.0);
        let empty = query(
            &[Request {
                snapshot: &snapshot,
                query: "",
                eligible: &[true],
            }],
            b"same",
            Some(&mut history),
            100,
        );
        assert_eq!(
            (empty[0].index, empty[0].score, empty[1].score),
            (2, 2.0, 0.0)
        );
    }

    #[test]
    fn t_opaque_ids_keep_input_order_and_check_bytes_on_hash_collisions() {
        let identities: &[&[u8]] = &[b"a\xff", b"a\x80", b"a\0", b"a\xc3\xbf", b"a\xff"];
        let mut snapshot = Snapshot {
            candidates: identities
                .iter()
                .map(|id| candidate(id, "same", "same", 0.0))
                .collect(),
            regions: 1,
        };
        for candidate in &mut snapshot.candidates {
            // Equal cached hashes must not merge different byte identities.
            candidate.id.hash = 0;
        }
        let ranked = query(
            &[Request {
                snapshot: &snapshot,
                query: "",
                eligible: &[true],
            }],
            b"",
            None,
            0,
        );
        assert_eq!(
            ranked.iter().map(|item| item.index).collect::<Vec<_>>(),
            vec![1, 2, 3, 4]
        );
    }

    #[test]
    fn t_missing_sort_text_and_equal_sort_keys_preserve_candidate_order() {
        let mut beta = candidate(b"z", "beta", "beta", 0.0);
        let mut alpha = candidate(b"a", "alpha", "alpha", 0.0);
        beta.has_sort_text = false;
        alpha.has_sort_text = false;
        let snapshot = Snapshot {
            candidates: vec![beta, alpha, candidate(b"explicit", "first", "0", 0.0)],
            regions: 1,
        };
        let ranked = query(
            &[Request {
                snapshot: &snapshot,
                query: "",
                eligible: &[true],
            }],
            b"",
            None,
            0,
        );
        assert_eq!(
            ranked.iter().map(|item| item.index).collect::<Vec<_>>(),
            [1, 2, 3]
        );
    }
}
