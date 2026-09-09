use super::*;

#[test]
fn t_raw_identity_rename_and_numstat_share_literal_paths() {
    let (records, stats) = raw(b":100644 100644 aaaaaaa bbbbbbb R100\0old\tfile\0new\nfile\0:100644 100644 aaaaaaa bbbbbbb M\0binary\0"
        .iter().chain(b"3\t1\t\0old\tfile\0new\nfile\0-\t-\tbinary\0").copied().collect::<Vec<_>>().as_slice(), true).unwrap();
    assert_eq!(records[0].relative, b"new\nfile");
    assert_eq!(
        records[0].previous.as_deref(),
        Some(b"old\tfile".as_slice())
    );
    assert_eq!(records[0].old.as_deref(), Some(b"aaaaaaa".as_slice()));
    assert_eq!(stats[b"new\nfile".as_slice()].insertions, 3);
    assert!(!stats.contains_key(b"binary".as_slice()));
}

#[test]
fn t_porcelain_mixed_snapshot_and_untracked_are_complete() {
    let Porcelain::Complete(entries) = porcelain(
        b"1 MM N... 100644 100644 100644 aaaaaaa bbbbbbb mixed\0? untracked\0",
        b"/repo",
    )
    .unwrap() else {
        panic!("complete")
    };
    let item = &entries[b"/repo/mixed".as_slice()];
    assert_eq!(item.info().display, "MM");
    assert_eq!(item.unstaged_old.as_deref(), Some(b"bbbbbbb".as_slice()));
    assert!(item.unstaged_new.is_none());
    assert_eq!(entries[b"/repo/untracked".as_slice()].info().stage, None);
}

#[test]
fn t_unborn_intent_to_add_and_non_utf8_paths() {
    let Porcelain::Complete(entries) = porcelain(
        b"1 A. N... 000000 100644 100644 0000000 aaaaaaa \xff\r\n\\name\0"
            .iter()
            .chain(b"1 .A N... 000000 000000 100644 0000000 0000000 intent\0")
            .copied()
            .collect::<Vec<_>>()
            .as_slice(),
        b"/repo",
    )
    .unwrap() else {
        panic!("complete")
    };
    assert!(
        entries[b"/repo/\xff\r\n\\name".as_slice()]
            .staged_old
            .is_none()
    );
    assert!(entries[b"/repo/intent".as_slice()].unstaged_old.is_none());
    assert_eq!(entries[b"/repo/intent".as_slice()].unstaged, 16);
}

#[test]
fn t_rename_source_cannot_be_mistaken_for_an_untracked_record() {
    let Porcelain::Raw { untracked } = porcelain(b"2 R. N... 100644 100644 100644 aaaaaaa bbbbbbb R100 target\0? not-an-untracked-record\0? real\0", b"/repo").unwrap() else { panic!("raw required") };
    assert_eq!(untracked, vec![b"real".to_vec()]);
}

#[test]
fn t_rename_candidates_and_submodules_require_raw_semantics() {
    for output in [
        b"1 A. N... 000000 100644 100644 0000000 bbbbbbb copy\0\
          1 M. N... 100644 100644 100644 aaaaaaa ccccccc original\0"
            .as_slice(),
        b"u UU N... 100644 100644 100644 100644 aaaaaaa bbbbbbb ccccccc file\0",
        b"1 .M S..U 160000 160000 160000 aaaaaaa aaaaaaa module\0",
    ] {
        assert!(matches!(
            porcelain(output, b"/repo").unwrap(),
            Porcelain::Raw { .. }
        ));
    }
}

#[test]
fn t_malformed_records_reject_partial_snapshots() {
    for output in [
        b"? incomplete".as_slice(),
        b"? good\0invalid\0",
        b"1 broken\0",
        b"? \0",
        b"2 R. N... 100644 100644 100644 aaaaaaa bbbbbbb R100 target\0",
    ] {
        assert!(porcelain(output, b"/repo").is_err());
    }
    assert!(raw(b":100644 100644 aaaaaaa bbbbbbb R100\0old\0", false).is_err());
    assert!(raw(b"1\t0\t\0only-source\0", true).is_err());
}
