use super::*;
use crate::types::{DictMatchMode, IDictSearchOptions};

fn options(keyword: &str, match_mode: DictMatchMode, max_items: usize) -> IDictSearchOptions {
    IDictSearchOptions {
        keyword: keyword.to_string(),
        language: "en".to_string(),
        match_mode,
        include_compounds: false,
        max_items,
    }
}

fn word_from_index(index_1_based: usize) -> String {
    let target = index_1_based.saturating_sub(1);
    for group in en::groups() {
        for (idx, tail) in group.tails.iter().enumerate() {
            if group.offset + idx == target {
                let mut word = String::with_capacity(group.anchor.len() + tail.len());
                word.push_str(group.anchor);
                word.push_str(tail);
                return word;
            }
        }
    }
    panic!("index {} out of bounds", index_1_based);
}

fn expand_indices(results: &[SearchResult]) -> Vec<usize> {
    let mut expanded = Vec::new();
    for result in results {
        match result.kind {
            SearchResultKind::Scalar => {
                expanded.extend(result.indexes.iter().copied());
            }
            SearchResultKind::Segment => {
                for chunk in result.indexes.chunks(2) {
                    if chunk.len() != 2 {
                        continue;
                    }
                    let start = chunk[0];
                    let end = chunk[1];
                    for idx in start..end {
                        expanded.push(idx);
                    }
                }
            }
        }
    }
    expanded
}

#[test]
fn t_prefix_prefers_exact_match() {
    let results = search(&options("wall", DictMatchMode::Prefix, 5));
    assert!(!results.is_empty());
    assert!(
        results
            .iter()
            .all(|result| matches!(result.kind, SearchResultKind::Scalar))
    );
    let indices = expand_indices(&results);
    assert!(!indices.is_empty());
    assert_eq!(word_from_index(indices[0]), "wall");
    assert!(
        indices
            .iter()
            .all(|idx| word_from_index(*idx).starts_with("wal"))
    );
}

#[test]
fn t_shorter_than_anchor_returns_empty() {
    let results = search(&options("wa", DictMatchMode::Prefix, 5));
    assert!(results.is_empty());
}

#[test]
fn t_anchor_length_produces_segment() {
    let results = search(&options("wal", DictMatchMode::Prefix, 5));
    assert_eq!(results.len(), 1);
    let result = &results[0];
    assert_eq!(result.kind, SearchResultKind::Segment);
    assert!(!result.indexes.is_empty());
    assert_eq!(result.indexes.len() % 2, 0);
    let expanded = expand_indices(results.as_slice());
    assert!(expanded.iter().any(|idx| word_from_index(*idx) == "wall"));
}

#[test]
fn t_prefix_returns_results_for_longer_keywords() {
    let results = search(&options("compu", DictMatchMode::Prefix, 5));
    assert!(!results.is_empty());
    let indices = expand_indices(&results);
    assert!(!indices.is_empty());
    assert!(
        indices
            .into_iter()
            .map(word_from_index)
            .any(|word| word == "computer")
    );
}

#[test]
fn t_prefix_handles_short_tail() {
    let results = search(&options("comp", DictMatchMode::Prefix, 5));
    assert!(!results.is_empty());
    let indices = expand_indices(&results);
    assert!(!indices.is_empty());
    assert!(
        indices
            .into_iter()
            .map(word_from_index)
            .any(|word| word.starts_with("comp"))
    );
}

#[test]
fn t_fuzzy_favors_closest_tail() {
    let results = search(&options("walnu", DictMatchMode::Prefix, 3));
    assert!(!results.is_empty());
    let indices = expand_indices(&results);
    assert!(!indices.is_empty());
    assert_eq!(word_from_index(indices[0]), "walnut");
}

#[test]
fn t_substring_ordering_respects_limit() {
    let mut opts = options("zoom", DictMatchMode::Substring, 2);
    let results = search(&opts);
    assert!(!results.is_empty());
    let indices = expand_indices(&results);
    assert!(!indices.is_empty());
    assert!(indices.len() <= 2);
    assert_eq!(word_from_index(indices[0]), "zoom");

    opts.max_items = 1;
    let trimmed = search(&opts);
    let trimmed_indices = expand_indices(&trimmed);
    assert_eq!(trimmed_indices.len(), 1);
    assert_eq!(word_from_index(trimmed_indices[0]), "zoom");
}
