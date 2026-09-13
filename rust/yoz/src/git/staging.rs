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
    use super::*;

    fn range(old_start: usize, old_count: usize, new_start: usize, new_count: usize) -> HunkRange {
        HunkRange {
            removed: Span::new(old_start, old_count, None).unwrap(),
            added: Span::new(new_start, new_count, None).unwrap(),
        }
    }

    fn apply(original: &[u8], modified: &[u8], ranges: &[HunkRange]) -> Vec<u8> {
        let original = from_text(original, Eol::Lf);
        let modified = from_text(modified, Eol::Lf);
        let old_lines: Vec<_> = original.lines().collect();
        let new_lines: Vec<_> = modified.lines().collect();
        let hunks: Vec<_> = ranges
            .iter()
            .map(|range| {
                let start = range.added.start.saturating_sub(1);
                LineChange {
                    range: *range,
                    added_lines: &new_lines[start..start + range.added.count],
                }
            })
            .collect();
        apply_line_changes(
            &Document {
                text: &original.text,
                eol: original.eol,
                lines: &old_lines,
            },
            Document {
                text: &modified.text,
                eol: modified.eol,
                lines: &new_lines,
            }
            .info(),
            &hunks,
        )
        .unwrap()
    }

    #[test]
    fn t_normalization_preserves_majority_ties_empty_sentinels_and_arbitrary_bytes() {
        for (input, default, expected, eol) in [
            (b"".as_slice(), Eol::CrLf, b"".as_slice(), Eol::CrLf),
            (b"x", Eol::CrLf, b"x", Eol::CrLf),
            (b"a\r\nb\nc\r", Eol::Lf, b"a\r\nb\r\nc\r\n", Eol::CrLf),
            (b"a\r\nb\n", Eol::CrLf, b"a\nb\n", Eol::Lf),
            (b"\xff\0\r", Eol::Lf, b"\xff\0\r\n", Eol::CrLf),
            (b"\n", Eol::CrLf, b"\n", Eol::Lf),
        ] {
            let document = from_text(input, default);
            assert_eq!(document.text, expected);
            assert_eq!(document.eol, eol);
            assert_eq!(
                document.lines().collect::<Vec<_>>().join(eol.bytes()),
                expected
            );
        }
        assert_eq!(from_text(b"", Eol::Lf).lines().collect::<Vec<_>>(), [b""]);
        assert_eq!(
            from_text(b"\n", Eol::Lf).lines().collect::<Vec<_>>(),
            [b"", b""]
        );
        assert!(Eol::parse(b"\r").is_err());
    }

    #[test]
    fn t_exhaustive_short_normalization_is_idempotent_and_keeps_line_bytes() {
        let alphabet = [b'a', b'\r', b'\n', 0, 255];
        for mut number in 0..15625 {
            let mut text = Vec::new();
            for _ in 0..6 {
                text.push(alphabet[number % alphabet.len()]);
                number /= alphabet.len();
            }
            for default in [Eol::Lf, Eol::CrLf] {
                let document = from_text(&text, default);
                let repeated = from_text(&document.text, document.eol);
                assert_eq!(document.text, repeated.text);
                assert_eq!(document.eol, repeated.eol);
                assert_eq!(
                    document
                        .lines()
                        .collect::<Vec<_>>()
                        .join(document.eol.bytes()),
                    document.text
                );
                let content = document.lines().flatten().copied().collect::<Vec<_>>();
                let expected = text
                    .iter()
                    .copied()
                    .filter(|byte| !matches!(byte, b'\r' | b'\n'))
                    .collect::<Vec<_>>();
                assert_eq!(content, expected);
            }
        }
    }

    #[test]
    fn t_intersection_keeps_zero_anchors_and_whole_unequal_original_spans() {
        let deletion = range(1, 3, 0, 0);
        assert_eq!(deletion.modified_range(), (1, 1));
        assert_eq!(deletion.intersect(1, 1).unwrap().range, deletion);
        assert!(deletion.intersect(0, 0).is_none());
        assert!(deletion.intersect(-2, -1).is_none());
        assert!(deletion.intersect(2, 1).is_none());
        assert_eq!(deletion.invert().added.start(), 1);
        assert_eq!(deletion.invert().invert(), deletion);

        let equal = range(2, 3, 3, 3).intersect(4, 4).unwrap();
        assert_eq!(equal.range, range(3, 1, 4, 1));
        assert_eq!((equal.removed_offset, equal.added_offset), (1, 1));
        let unequal = range(2, 1, 3, 3).intersect(4, 4).unwrap();
        assert_eq!(unequal.range, range(2, 1, 4, 1));
        assert_eq!((unequal.removed_offset, unequal.added_offset), (0, 1));
        assert_eq!(
            range(0, 0, 1, 2).intersect(2, 2).unwrap().range,
            range(0, 0, 2, 1)
        );
    }

    #[test]
    fn t_intersection_and_inversion_preserve_the_optional_eof_contract() {
        let hunk = HunkRange {
            removed: Span::new(1, 3, Some(true)).unwrap(),
            added: Span::new(1, 3, Some(false)).unwrap(),
        };
        let first = hunk.intersect(1, 1).unwrap().range;
        assert_eq!(first.removed.no_nl_at_eof(), None);
        assert_eq!(first.added.no_nl_at_eof(), None);
        assert_eq!(
            hunk.intersect(3, 3).unwrap().range.removed.no_nl_at_eof(),
            Some(true)
        );
        assert_eq!(hunk.invert().removed.no_nl_at_eof(), Some(false));
        assert!(Span::new(0, 1, None).is_err());
        assert!(Span::new(usize::MAX, 1, None).is_err());
    }

    #[test]
    fn t_selection_modes_distinguish_no_changes_empty_reset_and_unequal_unstage() {
        let hunks = [range(1, 1, 1, 2), range(4, 1, 5, 1)];
        let stage = select_hunks(&hunks, 2, 5, Selection::Stage).unwrap();
        assert_eq!(stage.len(), 1);
        assert_eq!(stage[0].range, hunks[0]);
        let partial = select_hunks(&hunks, 2, 2, Selection::StagePartial).unwrap();
        assert_eq!(partial[0].range, range(1, 1, 2, 1));
        assert_eq!(partial[0].added_offset, 1);
        let unstage = select_hunks(&hunks, 2, 2, Selection::Unstage).unwrap();
        assert_eq!(unstage[0].range, range(2, 1, 1, 1));
        assert_eq!(unstage[0].added_offset, 0);
        let reset = select_hunks(&hunks, 1, 2, Selection::Reset).unwrap();
        assert_eq!(reset.len(), 1);
        assert_eq!(reset[0].index, 1);
        assert!(
            select_hunks(&hunks, 1, 5, Selection::Reset)
                .unwrap()
                .is_empty()
        );
        for mode in [
            Selection::Stage,
            Selection::StagePartial,
            Selection::Unstage,
            Selection::Reset,
        ] {
            assert!(select_hunks(&hunks, 10, 10, mode).is_none());
            assert!(select_hunks(&[], 1, 1, mode).is_none());
        }
    }

    #[test]
    fn t_reconstruction_preserves_empty_documents_top_anchors_and_final_newlines() {
        for (old, new, hunk) in [
            (
                b"a\nb\n".as_slice(),
                b"a\nB\n".as_slice(),
                range(2, 1, 2, 1),
            ),
            (b"b\n", b"a\nb\n", range(0, 0, 1, 1)),
            (b"a\nb\n", b"b\n", range(1, 1, 0, 0)),
            (b"a\nb\n", b"a\nb", range(2, 1, 2, 1)),
            (b"a\nb", b"a\nb\n", range(2, 1, 2, 1)),
            (b"", b"a\n", range(0, 0, 1, 1)),
            (b"", b"\n", range(0, 0, 1, 1)),
            (b"a\n", b"", range(1, 1, 0, 0)),
            (b"a", b"", range(1, 1, 0, 0)),
            (b"a\nb", b"", range(1, 2, 0, 0)),
        ] {
            assert_eq!(apply(old, new, &[hunk]), new, "{old:?} -> {new:?}");
        }
    }

    #[test]
    fn t_partial_reconstruction_keeps_per_line_eol_and_unterminated_boundaries() {
        assert_eq!(
            apply(b"a\nb\nc\n", b"A\r\nb\r\nC\r\n", &[range(1, 1, 1, 1)]),
            b"A\r\nb\nc\n"
        );
        assert_eq!(
            apply(b"a\r\nb\r\nc\r\n", b"A\nb\nC\n", &[range(3, 1, 3, 1)]),
            b"a\r\nb\r\nC\n"
        );
        assert_eq!(
            apply(b"a", b"a\r\nb\r\n", &[range(1, 0, 2, 1)]),
            b"a\r\nb\r\n"
        );
        assert_eq!(apply(b"a\nb", b"a\nX\nY", &[range(2, 1, 2, 1)]), b"a\nX\n");
        assert_eq!(apply(b"a\nb\n", b"A\nb", &[range(1, 1, 1, 1)]), b"A\nb\n");
    }

    #[test]
    fn t_document_lines_are_authoritative_and_invalid_hunks_fail_without_partial_output() {
        let lines = [b"kept\r".as_slice(), b"".as_slice()];
        let original = Document {
            text: b"not reparsed\n",
            eol: Eol::Lf,
            lines: &lines,
        };
        let modified = Document {
            text: b"x\ny\n",
            eol: Eol::Lf,
            lines: &[b"x".as_slice(), b"y".as_slice(), b"".as_slice()],
        };
        let changes = [LineChange {
            range: range(1, 0, 2, 1),
            added_lines: &[b"y".as_slice()],
        }];
        assert_eq!(
            apply_line_changes(&original, modified.info(), &changes).unwrap(),
            b"kept\r\ny\n"
        );
        assert_eq!(
            apply_line_changes(&original, modified.info(), &[]).unwrap(),
            original.text
        );
        for hunk in [range(3, 1, 1, 1), range(1, 1, 3, 1), range(1, 1, 1, 2)] {
            assert!(
                apply_line_changes(
                    &original,
                    modified.info(),
                    &[LineChange {
                        range: hunk,
                        added_lines: &[b"x".as_slice()]
                    }]
                )
                .is_err()
            );
        }
    }
}
