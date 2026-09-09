//! Byte-oriented inputs and highlight ranges around an externally computed histogram diff.

use crate::staging::HunkRange;

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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/word_diff_test.rs"
    ));
}
