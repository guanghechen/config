use super::*;
use crate::ux::filetree::tests::Directory;
use crate::ux::treeview::{
    ErrorCode,
    memory::{Budget, Charge},
};
use std::fs;
use std::os::unix::fs::symlink;

const CAPACITY: usize = crate::ux::filetree::memory::LIMIT;
fn memory() -> Arc<Memory> {
    Memory::new(Budget::new(64 * 1024 * 1024))
}

#[test]
fn t_staged_copy_rejects_mandatory_memory_before_io_and_can_retry() {
    for data_limit in [true, false] {
        let directory = Directory::new();
        let source = directory.0.join("source");
        fs::write(&source, "data").unwrap();
        let expected = Signature::read(&source, false).unwrap();
        let target = destination(&directory.0.join("target"));
        let data_limit_bytes = if data_limit {
            1024 * 1024
        } else {
            64 * 1024 * 1024
        };
        let budget = Budget::new(data_limit_bytes);
        let _guard = budget.enter();
        let task_memory = Memory::new(budget.clone());
        let mut stage =
            Staging::new(&target, Permissions::from_mode(0o755), task_memory.clone()).unwrap();
        let data_pressure = data_limit.then(|| Charge::new(data_limit_bytes - budget.used() - 32));
        let mut copier = Copier::default();
        let task_pressure =
            (!data_limit).then(|| task_memory.reserve(CAPACITY - task_memory.used()).unwrap());
        let copied = std::cell::Cell::new(0);
        let copy = |stage: &mut Staging, copier: &mut Copier| {
            stage.copy(
                copier,
                &source,
                &expected,
                0,
                OsStr::new("file"),
                &AtomicBool::new(false),
                |bytes| copied.set(copied.get() + bytes),
            )
        };
        let error = copy(&mut stage, &mut copier).unwrap_err();
        assert!(error.get_ref().is_some_and(|error| {
            error
                .downcast_ref::<crate::ux::treeview::Error>()
                .is_some_and(|error| error.code == ErrorCode::ResourceLimit)
        }));
        assert_eq!(copied.get(), 0, "budget failure must precede target IO");
        assert!(!stage.damaged());
        drop(data_pressure);
        drop(task_pressure);
        copy(&mut stage, &mut copier).unwrap();
        assert_eq!(copied.get(), 4);
        stage.publish(&target).unwrap();
        assert_eq!(fs::read(target.path.join("file")).unwrap(), b"data");
        assert_eq!(fs::read(source).unwrap(), b"data");
        drop(stage);
        drop(copier);
        assert_eq!(task_memory.used(), 0);
        assert_eq!(budget.used(), 0);
    }
}

fn destination(path: &Path) -> Destination {
    Destination {
        path: path.to_owned(),
        parent: Signature::read(path.parent().unwrap(), true).unwrap(),
        expected: None,
    }
}

#[test]
fn t_staged_tree_hides_its_root_and_publishes_links_and_readonly_directories() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, "contents").unwrap();
    let target = destination(&directory.0.join("target"));
    let filter = Filter::new(target.parent.identity);
    let mut stage = Staging::new(&target, Permissions::from_mode(0o555), memory()).unwrap();
    let private = stage.temporary.path.clone();
    assert!(filter.read(&private).unwrap().is_none());
    assert!(read(&private).unwrap().is_none());
    let parent = stage
        .create_directory(0, OsStr::new("parent"), Permissions::from_mode(0o555))
        .unwrap();
    let child = stage
        .create_directory(parent, OsStr::new("child"), Permissions::from_mode(0o000))
        .unwrap();
    let mut copier = Copier::default();
    stage
        .copy(
            &mut copier,
            &source,
            &Signature::read(&source, false).unwrap(),
            child,
            OsStr::new("file"),
            &AtomicBool::new(false),
            |_| {},
        )
        .unwrap();
    let link = directory.0.join("link");
    symlink("../source", &link).unwrap();
    stage
        .copy(
            &mut copier,
            &link,
            &Signature::read(&link, false).unwrap(),
            0,
            OsStr::new("link"),
            &AtomicBool::new(false),
            |_| {},
        )
        .unwrap();
    assert!(!target.path.exists());
    stage.publish(&target).unwrap();
    drop(stage);
    assert!(!private.exists());
    assert!(filter.read(&private).unwrap().is_none());
    assert!(read(&target.path).unwrap().is_some());
    assert_eq!(
        fs::read_link(target.path.join("link")).unwrap(),
        Path::new("../source")
    );
    assert_eq!(
        fs::metadata(&target.path).unwrap().permissions().mode() & 0o777,
        0o555
    );
    assert_eq!(
        fs::metadata(target.path.join("parent/child"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0
    );
    fs::set_permissions(
        target.path.join("parent/child"),
        Permissions::from_mode(0o700),
    )
    .unwrap();
    assert_eq!(
        fs::read(target.path.join("parent/child/file")).unwrap(),
        b"contents"
    );
    fs::set_permissions(target.path.join("parent"), Permissions::from_mode(0o700)).unwrap();
    fs::set_permissions(&target.path, Permissions::from_mode(0o700)).unwrap();
}

#[test]
fn t_staged_cancel_discards_the_incomplete_file_and_commits_the_finished_prefix() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, vec![7; super::super::COPY_BUFFER * 2]).unwrap();
    let target = destination(&directory.0.join("target"));
    let mut stage = Staging::new(&target, Permissions::from_mode(0o755), memory()).unwrap();
    let mut copier = Copier::default();
    let cancel = AtomicBool::new(false);
    stage
        .copy(
            &mut copier,
            &source,
            &Signature::read(&source, false).unwrap(),
            0,
            OsStr::new("done"),
            &cancel,
            |_| {},
        )
        .unwrap();
    let failure = stage
        .copy(
            &mut copier,
            &source,
            &Signature::read(&source, false).unwrap(),
            0,
            OsStr::new("partial"),
            &cancel,
            |_| cancel.store(true, std::sync::atomic::Ordering::Release),
        )
        .unwrap_err();
    assert_eq!(failure.kind(), io::ErrorKind::Interrupted);
    assert!(!target.path.exists());
    stage.publish(&target).unwrap();
    assert_eq!(fs::read_dir(&target.path).unwrap().count(), 1);
    assert_eq!(
        fs::metadata(target.path.join("done")).unwrap().len(),
        (super::super::COPY_BUFFER * 2) as u64
    );
}

#[test]
fn t_staged_publication_preserves_a_late_destination_and_cleans_after_parent_rename() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, "source").unwrap();
    let parent = directory.0.join("parent");
    fs::create_dir(&parent).unwrap();
    let target = destination(&parent.join("target"));
    let mut stage = Staging::new(&target, Permissions::from_mode(0o555), memory()).unwrap();
    let name = stage.temporary.path.file_name().unwrap().to_owned();
    stage
        .copy(
            &mut Copier::default(),
            &source,
            &Signature::read(&source, false).unwrap(),
            0,
            OsStr::new("file"),
            &AtomicBool::new(false),
            |_| {},
        )
        .unwrap();
    fs::write(&target.path, "external").unwrap();
    assert!(stage.publish(&target).is_err());
    assert_eq!(fs::read(&target.path).unwrap(), b"external");
    let relocated = directory.0.join("relocated");
    fs::rename(&parent, &relocated).unwrap();
    stage.clean().unwrap();
    assert!(!relocated.join(name).exists());
    assert_eq!(fs::read(relocated.join("target")).unwrap(), b"external");
}

#[test]
fn t_staged_replaced_and_unowned_entries_are_not_published_or_deleted() {
    for replace in [false, true] {
        let directory = Directory::new();
        let source = directory.0.join("source");
        fs::write(&source, "source").unwrap();
        let target = destination(&directory.0.join("target"));
        let mut stage = Staging::new(&target, Permissions::from_mode(0o755), memory()).unwrap();
        let private = stage.temporary.path.clone();
        stage
            .copy(
                &mut Copier::default(),
                &source,
                &Signature::read(&source, false).unwrap(),
                0,
                OsStr::new("owned"),
                &AtomicBool::new(false),
                |_| {},
            )
            .unwrap();
        let foreign = private.join(if replace { "owned" } else { "external" });
        if replace {
            fs::rename(&foreign, directory.0.join("original")).unwrap();
        }
        fs::write(&foreign, "external").unwrap();
        assert!(stage.publish(&target).is_err());
        assert!(!target.path.exists());
        assert!(stage.clean().is_err());
        assert_eq!(fs::read(&foreign).unwrap(), b"external");
        assert!(read(&private).unwrap().is_some());
    }
}

#[test]
fn t_staging_budget_precedes_io_and_lookalike_names_remain_visible() {
    let directory = Directory::new();
    let lookalike = directory.0.join(".yoz-filetree-user.tmp");
    fs::create_dir(&lookalike).unwrap();
    let target = destination(&directory.0.join("target"));
    let filter = Filter::new(target.parent.identity);
    assert!(filter.read(&lookalike).unwrap().is_some());
    let budget = Budget::new(1024);
    let _guard = budget.enter();
    let error = Staging::new(
        &target,
        Permissions::from_mode(0o700),
        Memory::new(budget.clone()),
    )
    .err()
    .unwrap();
    assert_eq!(
        error
            .get_ref()
            .unwrap()
            .downcast_ref::<crate::ux::treeview::Error>()
            .unwrap()
            .code,
        ErrorCode::ResourceLimit
    );
    assert_eq!(fs::read_dir(&directory.0).unwrap().count(), 1);
    assert_eq!(budget.used(), 0);
    drop(_guard);
    let task_memory = memory();
    let mut staged =
        Staging::new(&target, Permissions::from_mode(0o700), task_memory.clone()).unwrap();
    let _pressure = task_memory.reserve(CAPACITY - task_memory.used()).unwrap();
    let error = staged
        .create_directory(
            0,
            OsStr::new("over-capacity"),
            Permissions::from_mode(0o700),
        )
        .unwrap_err();
    assert_eq!(
        crate::ux::filetree::resource::io_error("stage directory", error).code,
        ErrorCode::ResourceLimit
    );
    assert_eq!(fs::read_dir(&staged.temporary.path).unwrap().count(), 0);
}
