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
