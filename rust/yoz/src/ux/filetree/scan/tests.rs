use super::*;
use crate::test_support::TempDir;
use crate::ux::treeview::{DataScope, Engine, Import, Limits, Record};
use std::fs;

#[test]
fn t_entries_removed_after_enumeration_do_not_fail_the_directory_scan() {
    let directory = TempDir::new();
    for index in 0..1000 {
        fs::write(directory.path().join(format!("file-{index:04}")), b"test").unwrap();
    }
    let mut entry = Entry::read(directory.path()).unwrap();
    entry.anchor = Some(directory.path().to_path_buf());
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("root", entry.node_data())],
        })
        .unwrap();
    let root = engine.source().id("root").unwrap();
    let staging = Arc::new(AtomicUsize::new(0));
    let cancelled = AtomicBool::new(false);
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &cancelled,
    )
    .unwrap();
    /* Prime the listing's buffered names, then remove every entry. read_dir reads metadata after each
     * name and drops removed entries; macOS reads a batch with its metadata, which stays in this scan
     * until a later read, but no entry beyond that batch. */
    scan.iterator.next().unwrap().unwrap();
    for index in 0..1000 {
        fs::remove_file(directory.path().join(format!("file-{index:04}"))).unwrap();
    }
    let mut members = 0;
    loop {
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &cancelled,
            )
            .unwrap();
        members += page.members.len();
        if page.done {
            break;
        }
    }
    if cfg!(target_os = "macos") {
        assert!(members < 1000, "{members}");
    } else {
        assert_eq!(members, 0);
    }
    drop(scan);
    assert_eq!(staging.load(Ordering::Acquire), 0);
}

#[test]
fn t_scan_keeps_progressing_with_other_scans_holding_the_staging_budget() {
    let directory = TempDir::new();
    for index in 0..4096 {
        fs::write(directory.path().join(format!("file-{index:04}")), b"test").unwrap();
    }
    let mut entry = Entry::read(directory.path()).unwrap();
    entry.anchor = Some(directory.path().to_path_buf());
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("root", entry.node_data())],
        })
        .unwrap();
    let root = engine.source().id("root").unwrap();
    let staging = Arc::new(AtomicUsize::new(0));
    let cancelled = AtomicBool::new(false);
    let mut held = Reservation::new(engine.memory.clone(), staging.clone());
    held.add(STAGING_BYTES - 3 * PAGE_BYTES).unwrap();
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &cancelled,
    )
    .unwrap();
    let mut members = HashSet::new();
    loop {
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &cancelled,
            )
            .unwrap();
        assert!(staging.load(Ordering::Acquire) <= STAGING_BYTES);
        for member in &page.members {
            assert!(members.insert(member.clone()));
        }
        if page.done {
            break;
        }
    }
    assert_eq!(members.len(), 4096);
    drop(scan);
    drop(held);
    assert_eq!(staging.load(Ordering::Acquire), 0);
}

#[test]
fn t_deferred_storage_remains_charged_after_its_entries_leave_the_queue() {
    let directory = TempDir::new();
    let mut root = Entry::read(directory.path()).unwrap();
    root.anchor = Some(directory.path().to_path_buf());
    let mut records = vec![Record::new("root", root.node_data())];
    for index in 0..1025 {
        let name = format!("old-{index:04}");
        let path = directory.path().join(&name);
        fs::write(&path, b"test").unwrap();
        records.push(Record {
            key: name.into(),
            parent: Some("root".into()),
            data: Entry::read(&path).unwrap().node_data(),
            completeness: Some(Completeness::Complete),
        });
        fs::rename(&path, directory.path().join(format!("new-{index:04}"))).unwrap();
    }
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let root = engine.source().id("root").unwrap();
    let before = engine.memory.used();
    let staging = Arc::new(AtomicUsize::new(0));
    let cancelled = AtomicBool::new(false);
    let mut scan = Scan::new(
        engine.source(),
        root,
        Reservation::new(engine.memory.clone(), staging.clone()),
        &cancelled,
    )
    .unwrap();
    let initialized = staging.load(Ordering::Acquire);
    let mut members = 0;
    loop {
        let page = scan
            .page(
                root,
                Reservation::new(engine.memory.clone(), staging.clone()),
                &cancelled,
            )
            .unwrap();
        members += page.members.len();
        let done = page.done;
        drop(page);
        let retained = scan.deferred.capacity() * std::mem::size_of::<Observation>();
        assert!(
            staging.load(Ordering::Acquire) >= initialized + retained,
            "dropping a page cannot release the scan's retained deferred storage"
        );
        assert!(engine.memory.used() >= before + initialized + retained);
        if done {
            break;
        }
    }
    assert_eq!(members, 1025);
    assert!(scan.deferred.is_empty());
    assert!(scan.deferred.capacity() >= 1025);
    let retained = scan.deferred.capacity() * std::mem::size_of::<Observation>();
    let mut other = Reservation::new(engine.memory.clone(), staging.clone());
    assert_eq!(
        other
            .add(STAGING_BYTES - initialized - retained + 1)
            .unwrap_err()
            .code,
        crate::ux::treeview::ErrorCode::ResourceLimit
    );
    drop(other);
    drop(scan);
    assert_eq!(staging.load(Ordering::Acquire), 0);
    assert_eq!(engine.memory.used(), before);
}
