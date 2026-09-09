//! Byte-preserving document normalization and partial-hunk projection. No I/O.

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Eol {
    Lf,
    CrLf,
}

impl Eol {
    pub fn parse(bytes: &[u8]) -> Result<Self, String> {
        match bytes {
            b"\n" => Ok(Self::Lf),
            b"\r\n" => Ok(Self::CrLf),
            _ => Err("Git document EOL must be LF or CRLF".into()),
        }
    }

    pub fn bytes(self) -> &'static [u8] {
        match self {
            Self::Lf => b"\n",
            Self::CrLf => b"\r\n",
        }
    }
}

pub struct NormalizedDocument {
    pub text: Vec<u8>,
    pub eol: Eol,
}

impl NormalizedDocument {
    pub fn lines(&self) -> impl Iterator<Item = &[u8]> {
        self.text.split(|byte| *byte == b'\n').map(|line| {
            if self.eol == Eol::CrLf {
                line.strip_suffix(b"\r").unwrap_or(line)
            } else {
                line
            }
        })
    }
}

pub fn from_text(text: &[u8], default_eol: Eol) -> NormalizedDocument {
    let (mut cr, mut lf, mut index) = (0usize, 0usize, 0usize);
    while index < text.len() {
        match text[index] {
            b'\r' => {
                cr += 1;
                if text.get(index + 1) == Some(&b'\n') {
                    index += 1;
                }
            }
            b'\n' => lf += 1,
            _ => {}
        }
        index += 1;
    }
    // Preserve VS Code's majority rule: a lone CR votes for CRLF; ties select LF.
    let eol = if cr + lf == 0 {
        default_eol
    } else if cr > lf {
        Eol::CrLf
    } else {
        Eol::Lf
    };
    let mut normalized = Vec::with_capacity(text.len());
    index = 0;
    while index < text.len() {
        match text[index] {
            b'\r' => {
                normalized.extend_from_slice(eol.bytes());
                if text.get(index + 1) == Some(&b'\n') {
                    index += 1;
                }
            }
            b'\n' => normalized.extend_from_slice(eol.bytes()),
            byte => normalized.push(byte),
        }
        index += 1;
    }
    NormalizedDocument {
        text: normalized,
        eol,
    }
}

/// A zero-count side uses the preceding-line anchor, including zero at BOF.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Span {
    start: usize,
    count: usize,
    no_nl_at_eof: Option<bool>,
}

impl Span {
    pub fn new(start: usize, count: usize, no_nl_at_eof: Option<bool>) -> Result<Self, String> {
        if (start == 0 && count != 0) || start.checked_add(count).is_none() {
            return Err("Invalid Git hunk span".into());
        }
        Ok(Self {
            start,
            count,
            no_nl_at_eof,
        })
    }

    pub fn start(self) -> usize {
        self.start
    }

    pub fn count(self) -> usize {
        self.count
    }

    pub fn no_nl_at_eof(self) -> Option<bool> {
        self.no_nl_at_eof
    }

    pub fn last(self) -> usize {
        self.start + self.count.saturating_sub(1)
    }

    fn slice(self, offset: usize, count: usize) -> Self {
        Self {
            start: self.start + offset,
            count,
            no_nl_at_eof: self
                .no_nl_at_eof
                .filter(|flag| *flag && offset + count >= self.count),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct HunkRange {
    pub removed: Span,
    pub added: Span,
}

pub struct Intersection {
    pub range: HunkRange,
    pub removed_offset: usize,
    pub added_offset: usize,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Selection {
    Stage,
    StagePartial,
    Unstage,
    Reset,
}

pub struct SelectedHunk {
    pub index: usize,
    pub range: HunkRange,
    pub added_offset: usize,
}

/// None means no selected change. A reset may select changes but retain no hunks.
pub fn select_hunks(
    hunks: &[HunkRange],
    top: i64,
    bot: i64,
    mode: Selection,
) -> Option<Vec<SelectedHunk>> {
    let mut selected = Vec::new();
    let mut touched = false;
    for (index, &range) in hunks.iter().enumerate() {
        if mode == Selection::Reset {
            if range.touches(top, bot) {
                touched = true;
                continue;
            }
        } else if mode == Selection::Stage {
            if !range.touches(top, bot) {
                continue;
            }
        } else {
            let Some(clipped) = range.intersect(top, bot) else {
                continue;
            };
            selected.push(if mode == Selection::Unstage {
                SelectedHunk {
                    index,
                    range: clipped.range.invert(),
                    added_offset: clipped.removed_offset,
                }
            } else {
                SelectedHunk {
                    index,
                    range: clipped.range,
                    added_offset: clipped.added_offset,
                }
            });
            continue;
        }
        selected.push(SelectedHunk {
            index,
            range,
            added_offset: 0,
        });
        if mode == Selection::Stage {
            break;
        }
    }
    if mode == Selection::Unstage {
        selected.sort_by_key(|hunk| hunk.range.sort_key());
    }
    if (mode == Selection::Reset && !touched) || (mode != Selection::Reset && selected.is_empty()) {
        None
    } else {
        Some(selected)
    }
}

impl HunkRange {
    pub fn modified_range(self) -> (usize, usize) {
        (self.added.start.max(1), self.added.last().max(1))
    }

    pub fn touches(self, top: i64, bot: i64) -> bool {
        let (start, end) = self.modified_range();
        bot >= 0
            && top <= bot
            && (end as u128) >= top.max(0) as u128
            && (start as u128) <= bot as u128
    }

    pub fn intersect(self, top: i64, bot: i64) -> Option<Intersection> {
        if !self.touches(top, bot) {
            return None;
        }
        if self.added.count == 0 {
            return Some(Intersection {
                range: self,
                removed_offset: 0,
                added_offset: 0,
            });
        }
        let start = self.added.start.max(top.max(0) as usize);
        let end = self
            .added
            .last()
            .min(usize::try_from(bot).unwrap_or(usize::MAX));
        let count = end - start + 1;
        let added_offset = start - self.added.start;
        let (removed_offset, removed_count) = if self.removed.count == self.added.count {
            (added_offset, count)
        } else {
            (0, self.removed.count)
        };
        Some(Intersection {
            range: Self {
                removed: self.removed.slice(removed_offset, removed_count),
                added: self.added.slice(added_offset, count),
            },
            removed_offset,
            added_offset,
        })
    }

    pub fn invert(self) -> Self {
        Self {
            removed: self.added,
            added: self.removed,
        }
    }

    pub fn sort_key(self) -> (usize, usize, usize, usize) {
        (
            self.added.start,
            self.added.count,
            self.removed.start,
            self.removed.count,
        )
    }

    pub fn kind(self) -> &'static str {
        if self.removed.count == 0 {
            "add"
        } else if self.added.count == 0 {
            "delete"
        } else {
            "change"
        }
    }

    pub fn head(self) -> String {
        format!(
            "@@ -{},{} +{},{} @@",
            self.removed.start, self.removed.count, self.added.start, self.added.count
        )
    }
}

/// Lines retain the final empty sentinel. Text may intentionally retain mixed EOLs.
pub struct Document<'a, T> {
    pub text: &'a [u8],
    pub eol: Eol,
    pub lines: &'a [T],
}

#[derive(Clone, Copy)]
pub struct DocumentInfo {
    pub eol: Eol,
    pub line_count: usize,
    pub has_eol: bool,
}

impl DocumentInfo {
    pub fn new(text: &[u8], eol: Eol, line_count: usize, last_line_empty: bool) -> Self {
        let has_eol = !text.is_empty() && text.ends_with(eol.bytes());
        let line_count = if text.is_empty() {
            0
        } else {
            line_count.saturating_sub(usize::from(has_eol && last_line_empty))
        };
        Self {
            eol,
            line_count,
            has_eol,
        }
    }
}

impl<T: AsRef<[u8]>> Document<'_, T> {
    pub fn info(&self) -> DocumentInfo {
        DocumentInfo::new(
            self.text,
            self.eol,
            self.lines.len(),
            self.lines
                .last()
                .is_some_and(|line| line.as_ref().is_empty()),
        )
    }
}

pub struct LineChange<'a, T> {
    pub range: HunkRange,
    pub added_lines: &'a [T],
}

#[derive(Clone, Copy)]
struct Entry<'a> {
    line: &'a [u8],
    terminated: bool,
    eol: Eol,
}

fn push<'a>(output: &mut Vec<u8>, last: &mut Option<Entry<'a>>, entry: Entry<'a>) {
    if let Some(previous) = last.replace(entry) {
        output.extend_from_slice(previous.line);
        output.extend_from_slice(if previous.terminated {
            previous.eol.bytes()
        } else {
            entry.eol.bytes()
        });
    }
}

pub fn apply_line_changes<T: AsRef<[u8]>>(
    original: &Document<'_, T>,
    modified: DocumentInfo,
    hunks: &[LineChange<'_, T>],
) -> Result<Vec<u8>, String> {
    let Some(last_hunk) = hunks.last() else {
        return Ok(original.text.to_vec());
    };
    let original_info = original.info();
    let original_lines = &original.lines[..original_info.line_count];
    let original_has_eol = original_info.has_eol;
    let mut output = Vec::with_capacity(original.text.len());
    let mut last = None;
    let mut current = 0;
    for hunk in hunks {
        let removed = hunk.range.removed;
        let added = hunk.range.added;
        if removed.last() > original_lines.len()
            || added.last() > modified.line_count
            || added.count != hunk.added_lines.len()
        {
            return Err("Git hunk does not match its documents".into());
        }
        let before = if removed.count == 0 {
            removed.start
        } else {
            removed.start - 1
        };
        for index in current..before {
            push(
                &mut output,
                &mut last,
                Entry {
                    line: original_lines[index].as_ref(),
                    terminated: index + 1 < original_lines.len() || original_has_eol,
                    eol: original.eol,
                },
            );
        }
        current = current.max(before + removed.count);
        for (offset, line) in hunk.added_lines.iter().enumerate() {
            push(
                &mut output,
                &mut last,
                Entry {
                    line: line.as_ref(),
                    terminated: added.start + offset < modified.line_count || modified.has_eol,
                    eol: modified.eol,
                },
            );
        }
    }
    let ends_in_original = current < original_lines.len();
    for (index, line) in original_lines.iter().enumerate().skip(current) {
        push(
            &mut output,
            &mut last,
            Entry {
                line: line.as_ref(),
                terminated: index + 1 < original_lines.len() || original_has_eol,
                eol: original.eol,
            },
        );
    }
    if let Some(last) = last {
        let ends_in_modified =
            !ends_in_original && last_hunk.range.added.last() >= modified.line_count;
        let (keeps_eol, final_eol) = if ends_in_modified {
            (modified.has_eol, modified.eol)
        } else if !ends_in_original && last_hunk.range.added.count > 0 {
            (last.terminated, last.eol)
        } else {
            (original_has_eol, original.eol)
        };
        output.extend_from_slice(last.line);
        if keeps_eol {
            output.extend_from_slice(if last.terminated {
                last.eol.bytes()
            } else {
                final_eol.bytes()
            });
        }
    }
    Ok(output)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/staging_test.rs"
    ));
}
