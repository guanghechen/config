use super::super::*;
use crate::test_support::{TempDir, eventually};
use crate::ux::filetree::test_support::*;
use std::fs;

/** Deleting `locked` (whose members cannot be read) and `free` together, as one batch. */
#[test]
fn t_a_member_that_cannot_be_read_fails_alone_and_the_batch_goes_on() {
    let _operations = operations();
    use std::os::unix::fs::PermissionsExt;
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = TempDir::new();
    fs::create_dir(dir.path().join("locked")).unwrap();
    fs::write(dir.path().join("locked/member"), "member").unwrap();
    fs::write(dir.path().join("free"), "free").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "locked", None, OperationKind::Delete);
    /* The later snapshot holds both occurrences. */
    let free = request(tree.resolve(dir.path().join("free")));
    operation.nodes = vec![operation.nodes[0], free.node].into();
    operation.source = free.source;

    /* Without search permission the directory still lists its names, but no member can be read. */
    let locked = dir.path().join("locked");
    fs::set_permissions(&locked, fs::Permissions::from_mode(0o600)).unwrap();
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().terminal);
    fs::set_permissions(&locked, fs::Permissions::from_mode(0o700)).unwrap();

    let status = job.status();
    assert!(status.error.is_none(), "{:?}", status.error);
    let results = job.results(0, status.results).unwrap();
    let outcome = |path: PathBuf| {
        results
            .iter()
            .find(|result| result.source() == path)
            .map(|result| result.status)
    };
    assert_eq!(outcome(locked.join("member")), Some(ItemStatus::Failed));
    assert_eq!(outcome(locked.clone()), Some(ItemStatus::Failed));
    assert_eq!(outcome(dir.path().join("free")), Some(ItemStatus::Success));
    assert!(locked.join("member").exists());
    assert!(!dir.path().join("free").exists());
}

/** Copying `locked` (whose members cannot be read) and `free` together into `dst`. */
#[test]
fn t_copying_a_directory_with_an_unreadable_member_copies_the_rest() {
    let _operations = operations();
    use std::os::unix::fs::PermissionsExt;
    if unsafe { libc::geteuid() } == 0 {
        return;
    }
    let dir = TempDir::new();
    fs::create_dir_all(dir.path().join("locked")).unwrap();
    fs::create_dir(dir.path().join("dst")).unwrap();
    fs::write(dir.path().join("locked/member"), "member").unwrap();
    fs::write(dir.path().join("free"), "free").unwrap();
    let tree = request(Filetree::open(dir.path().to_path_buf()));
    let mut operation = plan(&tree, "locked", Some("dst"), OperationKind::Copy);
    let free = request(tree.resolve(dir.path().join("free")));
    operation.nodes = vec![operation.nodes[0], free.node].into();
    operation.source = free.source;

    let locked = dir.path().join("locked");
    fs::set_permissions(&locked, fs::Permissions::from_mode(0o600)).unwrap();
    let job = tree.start_operation(operation).unwrap();
    eventually(|| job.status().terminal);
    fs::set_permissions(&locked, fs::Permissions::from_mode(0o700)).unwrap();

    let status = job.status();
    assert!(status.error.is_none(), "{:?}", status.error);
    let results = job.results(0, status.results).unwrap();
    let member = results
        .iter()
        .find(|result| result.source() == locked.join("member"))
        .expect("the member's result");
    assert_eq!(member.status, ItemStatus::Failed);
    assert_eq!(member.target(), Some(dir.path().join("dst/locked/member")));
    assert!(member.error().is_some());
    assert!(
        results
            .iter()
            .any(|result| result.source() == dir.path().join("free")
                && result.status == ItemStatus::Success)
    );
    assert_eq!(
        fs::read_to_string(dir.path().join("dst/free")).unwrap(),
        "free"
    );
    assert!(!dir.path().join("dst/locked/member").exists());
}
