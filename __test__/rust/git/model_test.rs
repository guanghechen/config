use super::*;

fn item(code: u8, staged: bool) -> Entry {
    let mut entry = Entry::default();
    if staged {
        entry.staged = code_bit(code).unwrap();
    } else {
        entry.unstaged = code_bit(code).unwrap();
    }
    entry
}

#[test]
fn t_directory_union_preserves_stage_and_code_priority() {
    let entries = BTreeMap::from([
        (b"/repo/dir/first".to_vec(), item(b'A', true)),
        (b"/repo/dir/second".to_vec(), item(b'M', false)),
        (b"/repo/dir/link".to_vec(), item(b'?', false)),
    ]);
    let snapshot = Snapshot::new(entries, None);
    let info = snapshot.lookup(b"/repo/dir", true).unwrap();
    assert_eq!(info.display, "UMA");
    assert_eq!(info.summary, Some(b'?'));
    assert_eq!(info.stage, Some(Stage::Mixed));
    assert_eq!(snapshot.lookup(b"/", true).unwrap().display, "UMA");
    assert!(snapshot.lookup(b"/repo/directory", true).is_none());
}

#[test]
fn t_untracked_symlink_own_entry_and_descendants() {
    let snapshot = Snapshot::new(
        BTreeMap::from([(b"/repo/link".to_vec(), item(b'?', false))]),
        None,
    );
    for directory in [false, true] {
        assert_eq!(
            snapshot
                .lookup(b"/repo/link/sub/file", directory)
                .unwrap()
                .display,
            "U"
        );
    }
    assert_eq!(snapshot.lookup(b"/repo/link", true).unwrap().stage, None);
    assert!(snapshot.lookup(b"/repo/link-other", true).is_none());
}

#[test]
fn t_own_directory_entry_merges_without_leaking_parent_status() {
    let snapshot = Snapshot::new(
        BTreeMap::from([
            (b"/repo/link".to_vec(), item(b'?', false)),
            (b"/repo/link/sub/file".to_vec(), item(b'M', false)),
        ]),
        None,
    );
    assert_eq!(snapshot.lookup(b"/repo/link", true).unwrap().display, "UM");
    assert_eq!(
        snapshot.lookup(b"/repo/link/sub", true).unwrap().display,
        "M"
    );
}

#[test]
fn t_paths_preserve_bytes_and_canonical_windows_keys() {
    let snapshot = Snapshot::new(
        BTreeMap::from([
            (b"C:/repo/dir/file".to_vec(), item(b'M', false)),
            (b"/repo/back\\slash/\xff".to_vec(), item(b'A', true)),
        ]),
        None,
    );
    assert_eq!(snapshot.lookup(b"C:/repo/dir", true).unwrap().display, "M");
    assert_eq!(
        snapshot.lookup(b"/repo/back\\slash", true).unwrap().display,
        "A"
    );
    assert!(snapshot.lookup(b"/repo/back/slash", true).is_none());
}

#[test]
fn t_status_equality_excludes_query_timing() {
    let mut left = Snapshot::new(
        BTreeMap::from([(b"/repo/file".to_vec(), item(b'M', false))]),
        None,
    );
    let right = Snapshot::new(left.entries.clone(), None);
    left.elapsed_ms = 100.0;
    left.commands = 3;
    assert!(left.same_status(&right));
    left.entries
        .get_mut(b"/repo/file".as_slice())
        .unwrap()
        .unstaged = 8;
    assert!(!left.same_status(&right));
}

#[test]
fn t_untracked_descendant_files_do_not_inherit_parent_staged_deletions() {
    let mut entry = item(b'?', false);
    entry.staged = 8;
    let snapshot = Snapshot::new(BTreeMap::from([(b"/repo/link".to_vec(), entry)]), None);
    assert_eq!(
        snapshot.lookup(b"/repo/link/file", false).unwrap().display,
        "U"
    );
    assert_eq!(
        snapshot.lookup(b"/repo/link/dir", true).unwrap().display,
        "UD"
    );
    assert_eq!(
        snapshot.lookup(b"/repo/link", true).unwrap().staged_display,
        "D"
    );
}

#[test]
fn t_directory_own_staged_status_preserves_the_staged_segment() {
    let snapshot = Snapshot::new(
        BTreeMap::from([
            (b"/repo/module".to_vec(), item(b'M', true)),
            (b"/repo/module/file".to_vec(), item(b'?', false)),
        ]),
        None,
    );
    assert_eq!(
        snapshot
            .lookup(b"/repo/module", true)
            .unwrap()
            .staged_display,
        "M"
    );
}
