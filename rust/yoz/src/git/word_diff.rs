//! Byte-oriented inputs and highlight ranges around an externally computed histogram diff.

use super::staging::HunkRange;

const MAX_BYTES: usize = 500;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Change {
    pub old_start: usize,
    pub old_end: usize,
    pub new_start: usize,
    pub new_end: usize,
}

/// Keep the existing 500-byte diff limit and separate bytes, not Unicode characters.
pub fn bytes_as_lines(text: &[u8]) -> Vec<u8> {
    let text = &text[..text.len().min(MAX_BYTES)];
    let mut result = Vec::with_capacity((text.len() * 2).saturating_sub(1));
    for (index, &byte) in text.iter().enumerate() {
        if index != 0 {
            result.push(b'\n');
        }
        result.push(byte);
    }
    result
}

#[derive(Eq, PartialEq)]
enum Category {
    Lower,
    Upper,
    Number,
    Space,
    Separator,
    Other,
}

fn category(byte: u8) -> Category {
    match byte {
        b'a'..=b'z' => Category::Lower,
        b'A'..=b'Z' => Category::Upper,
        b'0'..=b'9' => Category::Number,
        b' ' | b'\t' => Category::Space,
        b',' | b';' | b'.' | b':' => Category::Separator,
        _ => Category::Other,
    }
}

fn is_boundary(text: &[u8], offset: usize) -> bool {
    offset == 0 || offset >= text.len() || category(text[offset - 1]) != category(text[offset])
}

fn append_merged(changes: &mut Vec<Change>, current: Change, gap: usize) {
    if let Some(previous) = changes.last_mut()
        && current.old_start <= previous.old_end.saturating_add(gap)
        && current.new_start <= previous.new_end.saturating_add(gap)
    {
        previous.old_end = previous.old_end.max(current.old_end);
        previous.new_end = previous.new_end.max(current.new_end);
        return;
    }
    changes.push(current);
}

/// Nil raw data means the Neovim diff failed; an empty slice means no highlighted changes.
pub fn finish(old: &[u8], new: &[u8], raw: Option<&[HunkRange]>) -> Vec<Change> {
    let Some(raw) = raw else {
        return vec![Change {
            old_start: 0,
            old_end: old.len().min(MAX_BYTES),
            new_start: 0,
            new_end: new.len().min(MAX_BYTES),
        }];
    };
    let mut merged = Vec::with_capacity(raw.len());
    for hunk in raw {
        let old_start = hunk.removed.start() - usize::from(hunk.removed.count() != 0);
        let new_start = hunk.added.start() - usize::from(hunk.added.count() != 0);
        append_merged(
            &mut merged,
            Change {
                old_start,
                old_end: old_start + hunk.removed.count(),
                new_start,
                new_end: new_start + hunk.added.count(),
            },
            2,
        );
    }
    let mut result = Vec::with_capacity(merged.len());
    for mut change in merged {
        // Boundary expansion uses the full source, even when diff inputs were truncated.
        while change.old_start > 0 && !is_boundary(old, change.old_start) {
            change.old_start -= 1;
        }
        while change.old_end < old.len() && !is_boundary(old, change.old_end) {
            change.old_end += 1;
        }
        while change.new_start > 0 && !is_boundary(new, change.new_start) {
            change.new_start -= 1;
        }
        while change.new_end < new.len() && !is_boundary(new, change.new_end) {
            change.new_end += 1;
        }
        if change.old_end > change.old_start || change.new_end > change.new_start {
            append_merged(&mut result, change, 0);
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::git::staging::Span;

    fn range(old_start: usize, old_count: usize, new_start: usize, new_count: usize) -> HunkRange {
        HunkRange {
            removed: Span::new(old_start, old_count, None).unwrap(),
            added: Span::new(new_start, new_count, None).unwrap(),
        }
    }

    #[test]
    fn t_inputs_preserve_bytes_and_truncate_before_separating() {
        for bytes in [b"".as_slice(), b"a", b"\0\xff\n\r", "中文🙂".as_bytes()] {
            let expected = bytes
                .iter()
                .map(std::slice::from_ref)
                .collect::<Vec<_>>()
                .join(&b'\n');
            assert_eq!(bytes_as_lines(bytes), expected);
        }
        let mut bytes = vec![b'a'; 499];
        bytes.extend_from_slice("中".as_bytes());
        let encoded = bytes_as_lines(&bytes);
        assert_eq!(encoded.len(), 999);
        assert_eq!(encoded.last(), Some(&0xe4));
        assert_eq!(
            encoded.iter().step_by(2).copied().collect::<Vec<_>>(),
            bytes[..500]
        );
    }

    #[test]
    fn t_categories_keep_existing_ascii_and_byte_boundaries() {
        for left in 0..=255u8 {
            for right in 0..=255u8 {
                let text = [left, right];
                assert!(is_boundary(&text, 0));
                assert!(is_boundary(&text, 2));
                assert!(is_boundary(&text, 99));
                assert_eq!(is_boundary(&text, 1), category(left) != category(right));
            }
        }
        assert!(!is_boundary("中文".as_bytes(), 3));
        assert!(is_boundary(b"aB", 1));
        assert!(is_boundary(b"Ab", 1));
        assert!(!is_boundary(b" \t", 1));
        assert!(!is_boundary(b",;.:", 2));
    }

    #[test]
    fn t_word_ranges_preserve_zero_based_exclusive_ends_and_empty_sides() {
        assert_eq!(
            finish(b"fooBar", b"fooBaz", Some(&[range(6, 1, 6, 1)])),
            [Change {
                old_start: 4,
                old_end: 6,
                new_start: 4,
                new_end: 6,
            }]
        );
        assert_eq!(
            finish(b"a b", b"aXY b", Some(&[range(1, 0, 2, 2)])),
            [Change {
                old_start: 1,
                old_end: 1,
                new_start: 1,
                new_end: 3,
            }]
        );
        assert_eq!(
            finish(b"aXY b", b"a b", Some(&[range(2, 2, 1, 0)])),
            [Change {
                old_start: 1,
                old_end: 3,
                new_start: 1,
                new_end: 1,
            }]
        );
    }

    #[test]
    fn t_merge_requires_both_sides_and_runs_again_after_boundary_expansion() {
        let first = Change {
            old_start: 0,
            old_end: 1,
            new_start: 0,
            new_end: 1,
        };
        let close = Change {
            old_start: 3,
            old_end: 4,
            new_start: 3,
            new_end: 4,
        };
        let mut changes = vec![first];
        append_merged(&mut changes, close, 2);
        assert_eq!(
            changes,
            [Change {
                old_end: 4,
                new_end: 4,
                ..first
            }]
        );
        for far in [
            Change {
                old_start: 4,
                old_end: 5,
                ..close
            },
            Change {
                new_start: 4,
                new_end: 5,
                ..close
            },
        ] {
            let mut changes = vec![first];
            append_merged(&mut changes, far, 2);
            assert_eq!(changes, [first, far]);
        }
        let raw = [range(1, 1, 1, 1), range(7, 1, 7, 1)];
        assert_eq!(
            finish(b"abcdefghij", b"ABCDEFGHIJ", Some(&raw)),
            [Change {
                old_start: 0,
                old_end: 10,
                new_start: 0,
                new_end: 10,
            }]
        );
    }

    #[test]
    fn t_failure_and_empty_raw_results_have_distinct_contracts() {
        let text = vec![b'a'; 1000];
        assert_eq!(
            finish(&text, b"b", None),
            [Change {
                old_start: 0,
                old_end: 500,
                new_start: 0,
                new_end: 1
            }]
        );
        assert!(finish(&text, b"b", Some(&[])).is_empty());
        assert!(finish(b"a b", b"a b", Some(&[range(1, 0, 1, 0)])).is_empty());
    }

    #[test]
    fn t_boundary_expansion_still_uses_the_full_source_after_truncation() {
        let old = vec![b'a'; 65_536];
        let new = vec![b'b'; 65_536];
        assert_eq!(
            finish(&old, &new, Some(&[range(1, 500, 1, 500)])),
            [Change {
                old_start: 0,
                old_end: 65_536,
                new_start: 0,
                new_end: 65_536,
            }]
        );
        assert_eq!(
            finish(b"\xff\0\r", b"\xfe\0\r", Some(&[range(1, 1, 1, 1)])),
            [Change {
                old_start: 0,
                old_end: 3,
                new_start: 0,
                new_end: 3,
            }]
        );
    }
}
