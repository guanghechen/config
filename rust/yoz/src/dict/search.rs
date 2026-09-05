use super::en;
use crate::search::{ISearchBuffer, search_in_lines_literal};
use crate::types::{DictMatchMode, IDictSearchOptions};
use std::cmp::Ordering;

const DEFAULT_LANGUAGE: &str = "en";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SearchResultKind {
    Scalar,
    Segment,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchResult {
    pub kind: SearchResultKind,
    pub indexes: Vec<usize>,
}

impl SearchResult {
    fn new(kind: SearchResultKind, indexes: Vec<usize>) -> Option<Self> {
        if indexes.is_empty() {
            None
        } else {
            Some(Self { kind, indexes })
        }
    }

    fn scalar(indexes: Vec<usize>) -> Option<Self> {
        Self::new(SearchResultKind::Scalar, indexes)
    }

    fn segment(indexes: Vec<usize>) -> Option<Self> {
        Self::new(SearchResultKind::Segment, indexes)
    }
}

pub fn search(options: &IDictSearchOptions) -> Vec<SearchResult> {
    let keyword = options.keyword.trim();
    if keyword.is_empty() {
        return Vec::new();
    }

    match options.language.as_str() {
        "" | DEFAULT_LANGUAGE => search_en(keyword, options),
        _ => Vec::new(),
    }
}

fn search_en(keyword: &str, options: &IDictSearchOptions) -> Vec<SearchResult> {
    let keyword_lower = keyword.to_lowercase();
    if keyword_lower.len() < en::ANCHOR_LENGTH {
        return Vec::new();
    }

    if keyword_lower.len() == en::ANCHOR_LENGTH {
        let group = match en::find_group(&keyword_lower) {
            Some(value) => value,
            None => return Vec::new(),
        };
        let segments = collect_group_segments(group, options.include_compounds);
        if let Some(result) = SearchResult::segment(segments) {
            return vec![result];
        }
        return Vec::new();
    }

    let (anchor, tail) = keyword_lower.split_at(en::ANCHOR_LENGTH);
    let group = match en::find_group(anchor) {
        Some(value) => value,
        None => return Vec::new(),
    };

    let candidates = match options.match_mode {
        DictMatchMode::Substring => {
            collect_substring_candidates(group, tail, options.include_compounds)
        }
        DictMatchMode::Prefix => collect_fuzzy_candidates(group, tail, options),
    };

    let results = if candidates.is_empty() && matches!(options.match_mode, DictMatchMode::Prefix) {
        collect_prefix_candidates(group, options.include_compounds)
    } else {
        candidates
    };

    finalize_candidates(results, options.max_items)
        .into_iter()
        .collect()
}

fn collect_prefix_candidates(group: &en::Group, include_compounds: bool) -> Vec<(u32, usize)> {
    let mut results = Vec::new();
    for (idx, tail) in group.tails.iter().enumerate() {
        if !include_compounds && tail.contains(' ') {
            continue;
        }
        let word_index = group.offset + idx;
        let score = 1_000_000u32.saturating_sub(tail.len() as u32);
        if score > 0 {
            results.push((score, word_index));
        }
    }
    results
}

fn collect_fuzzy_candidates(
    group: &en::Group,
    tail: &str,
    options: &IDictSearchOptions,
) -> Vec<(u32, usize)> {
    if group.tails.is_empty() || tail.is_empty() {
        return Vec::new();
    }

    let buffer = ISearchBuffer::from_lines(
        &group
            .tails
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>(),
    );
    let matches = search_in_lines_literal(tail, &buffer, true, false);
    matches
        .into_iter()
        .filter_map(|line_match| {
            if line_match.score == 0 {
                return None;
            }
            let index = line_match.lnum.checked_sub(1)?;
            if index >= group.tails.len() {
                return None;
            }
            if !options.include_compounds && group.tails[index].contains(' ') {
                return None;
            }
            Some((line_match.score, index))
        })
        .map(|(score, index)| (score, group.offset + index))
        .collect()
}

fn collect_substring_candidates(
    group: &en::Group,
    tail: &str,
    include_compounds: bool,
) -> Vec<(u32, usize)> {
    if group.tails.is_empty() || tail.is_empty() {
        return Vec::new();
    }

    let mut results = Vec::new();
    for (idx, candidate) in group.tails.iter().enumerate() {
        if !include_compounds && candidate.contains(' ') {
            continue;
        }
        if let Some(pos) = candidate.find(tail) {
            let word_index = group.offset + idx;
            let word_length = en::ANCHOR_LENGTH + candidate.len();
            let base = 500_000u32.saturating_sub((pos as u32) * 256);
            let score = base.saturating_sub(word_length as u32);
            if score > 0 {
                results.push((score, word_index));
            }
        }
    }
    results
}

fn collect_group_segments(group: &en::Group, include_compounds: bool) -> Vec<usize> {
    if group.tails.is_empty() {
        return Vec::new();
    }

    let mut segments: Vec<usize> = Vec::new();
    let mut current_start: Option<usize> = None;
    let mut last_index: usize = 0;

    for (idx, tail) in group.tails.iter().enumerate() {
        if !include_compounds && tail.contains(' ') {
            if let Some(start) = current_start.take() {
                segments.push(start);
                segments.push(last_index + 1);
            }
            continue;
        }

        let index = group.offset + idx + 1;
        if let Some(start) = current_start {
            if index != last_index + 1 {
                segments.push(start);
                segments.push(last_index + 1);
                current_start = Some(index);
            }
        } else {
            current_start = Some(index);
        }
        last_index = index;
    }

    if let Some(start) = current_start {
        segments.push(start);
        segments.push(last_index + 1);
    }

    segments
}

fn finalize_candidates(mut entries: Vec<(u32, usize)>, max_items: usize) -> Option<SearchResult> {
    if max_items == 0 {
        return None;
    }

    entries.retain(|(score, _)| *score > 0);

    if entries.is_empty() {
        return None;
    }

    entries.sort_by(|left, right| match right.0.cmp(&left.0) {
        Ordering::Equal => left.1.cmp(&right.1),
        other => other,
    });

    entries.truncate(max_items);

    let mut deduped = Vec::with_capacity(entries.len());
    let mut last_index: Option<usize> = None;
    for (_, idx) in entries {
        if last_index == Some(idx) {
            continue;
        }
        deduped.push(idx + 1);
        last_index = Some(idx);
    }

    SearchResult::scalar(deduped)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/dict/search_test.rs"
    ));
}
