use super::*;
use crate::ux::filetree::Request;
use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant};

struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!("yoz-explorer-{}", uuid::Uuid::new_v4()));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
fn request<T: Clone>(value: Request<T>) -> T {
    let start = Instant::now();
    loop {
        if let Some(value) = value.poll() {
            return value.unwrap();
        }
        assert!(start.elapsed() < Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(1));
    }
}
fn reply(explorer: &Explorer, ticket: Ticket) -> Reply {
    let Outcome::Reply(reply) = ticket.wait() else {
        panic!("expected reply")
    };
    assert!(!matches!(reply, Reply::Rejected { .. }), "{reply:?}");
    if let Reply::Applied { revisions, .. } | Reply::Locked { revisions, .. } = &reply {
        let started = Instant::now();
        while Some(explorer.state.snapshot().unwrap().state_revision()) < revisions.state {
            assert!(started.elapsed() < Duration::from_secs(10));
            std::thread::sleep(Duration::from_millis(1));
        }
    }
    reply
}
fn explorer(path: &std::path::Path) -> Explorer {
    let tree = request(Filetree::open(path.to_path_buf()));
    for name in ["a", "b"] {
        request(tree.resolve(path.join(name)));
    }
    let Outcome::State(state) = tree.create_state(None, DisplayOptions::default()).wait() else {
        panic!("expected state")
    };
    Explorer::new(tree, state).unwrap()
}

#[test]
fn t_marking_switches_purpose_atomically_without_restamping_selected_nodes() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    let original = explorer.state.snapshot().unwrap();
    reply(
        &explorer,
        explorer.mark(original.clone(), 0, 1, Mark::Copy, false),
    );
    let copied = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&copied), Some("copy"));
    assert_eq!(copied.summary.known_roots, 1);
    let selection_revision = copied.selection_revision();
    reply(
        &explorer,
        explorer.mark(copied.clone(), 0, 1, Mark::Cut, false),
    );
    let cut = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&cut), Some("cut"));
    assert_eq!(cut.selection_revision(), selection_revision);
    assert_eq!(mode(&copied), Some("copy"));
    assert_eq!(mode(&original), None);
    reply(&explorer, explorer.mark(cut, 1, 2, Mark::Toggle, false));
    let both = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&both), Some("cut"));
    assert_eq!(both.summary.known_roots, 2);
    reply(&explorer, explorer.mark(both, 0, 2, Mark::Toggle, true));
    let empty = explorer.state.snapshot().unwrap();
    assert!(empty.summary.is_empty());
    assert_eq!(mode(&empty), None);
}

#[test]
fn t_select_mark_exits_transfer_without_unselecting_then_toggles() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    reply(
        &explorer,
        explorer.mark(explorer.state.snapshot().unwrap(), 0, 1, Mark::Copy, false),
    );
    let copied = explorer.state.snapshot().unwrap();
    let revision = copied.selection_revision();
    reply(&explorer, explorer.mark(copied, 0, 1, Mark::Select, false));
    let selected = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&selected), Some("select"));
    assert_eq!(selected.summary.known_roots, 1);
    assert_eq!(selected.selection_revision(), revision);
    reply(
        &explorer,
        explorer.mark(selected, 0, 1, Mark::Select, false),
    );
    let empty = explorer.state.snapshot().unwrap();
    assert!(empty.summary.is_empty());
    assert_eq!(mode(&empty), None);
    reply(&explorer, explorer.mark(empty, 1, 2, Mark::Cut, false));
    reply(
        &explorer,
        explorer.mark(
            explorer.state.snapshot().unwrap(),
            0,
            1,
            Mark::Select,
            false,
        ),
    );
    let both = explorer.state.snapshot().unwrap();
    assert_eq!(mode(&both), Some("select"));
    assert_eq!(both.summary.known_roots, 2);
}

#[test]
fn t_visual_union_restamps_and_task_lock_rejects_mode_changes() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    reply(
        &explorer,
        explorer.mark(explorer.state.snapshot().unwrap(), 0, 1, Mark::Copy, false),
    );
    let before = explorer.state.snapshot().unwrap();
    reply(
        &explorer,
        explorer.mark(before.clone(), 0, 2, Mark::Copy, true),
    );
    let after = explorer.state.snapshot().unwrap();
    assert!(after.selection_revision() > before.selection_revision());
    assert_eq!(after.summary.known_roots, 2);
    let locked = reply(
        &explorer,
        explorer.state.submit(Action::Lock(
            explorer.state.id(),
            after.selection_revision(),
            None,
        )),
    );
    let Reply::Locked { token, .. } = locked else {
        panic!("lock")
    };
    for mark in [Mark::Cut, Mark::Select] {
        let result = explorer
            .mark(explorer.state.snapshot().unwrap(), 0, 1, mark, false)
            .wait();
        assert!(
            matches!(result, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Busy)
        );
        assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("copy"));
    }
    reply(
        &explorer,
        explorer
            .state
            .submit(Action::Unlock(explorer.state.id(), token)),
    );
}

#[test]
fn t_range_inspection_deduplicates_subtrees_without_changing_locked_selection() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    fs::create_dir(directory.0.join("nested")).unwrap();
    fs::write(directory.0.join("nested/file"), "content").unwrap();
    let explorer = explorer(&directory.0);
    let a = request(explorer.tree.resolve(directory.0.join("a")));
    let nested = request(explorer.tree.resolve(directory.0.join("nested")));
    let file = request(explorer.tree.resolve(directory.0.join("nested/file")));
    reply(&explorer, explorer.navigate(file.node, true));
    let frame = explorer.state.snapshot().unwrap();
    let at = frame.position(a.node).unwrap();
    reply(
        &explorer,
        explorer.mark(frame, at, at + 1, Mark::Cut, false),
    );
    let frame = explorer.state.snapshot().unwrap();
    let Reply::Locked { token, .. } = reply(
        &explorer,
        explorer.state.submit(Action::Lock(
            explorer.state.id(),
            frame.selection_revision(),
            None,
        )),
    ) else {
        panic!("lock");
    };
    let before = explorer.state.status().unwrap().revisions;
    let Reply::Inspected { sources, .. } = reply(
        &explorer,
        explorer.inspect_range(
            frame.clone(),
            frame.position(nested.node).unwrap(),
            frame.position(file.node).unwrap() + 1,
        ),
    ) else {
        panic!("range inspection");
    };
    assert_eq!(&*sources.subtree_roots, &[nested.node]);
    assert!(sources.self_only_nodes.is_empty());
    assert!(sources.needed_children.is_empty());
    assert_eq!(explorer.state.status().unwrap().revisions, before);
    let Reply::Inspected { sources, .. } = reply(
        &explorer,
        explorer
            .state
            .dispatch(Command::InspectSelection, Context::default()),
    ) else {
        panic!("selection inspection");
    };
    assert_eq!(&*sources.subtree_roots, &[a.node]);
    assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("cut"));
    reply(
        &explorer,
        explorer
            .state
            .submit(Action::Unlock(explorer.state.id(), token)),
    );
}

#[test]
fn t_range_inspection_rejects_foreign_frames_invalid_bounds_and_removed_roots() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    let explorer = explorer(&directory.0);
    let a = request(explorer.tree.resolve(directory.0.join("a")));
    let frame = explorer.state.snapshot().unwrap();
    let Outcome::State(other) = explorer
        .tree
        .create_state(None, DisplayOptions::default())
        .wait()
    else {
        panic!("state");
    };
    let foreign = explorer
        .inspect_range(other.snapshot().unwrap(), 0, 1)
        .wait();
    assert!(
        matches!(foreign, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Stale)
    );
    let invalid = explorer
        .inspect_range(frame.clone(), 0, frame.len() + 1)
        .wait();
    assert!(
        matches!(invalid, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::InvalidUpdate)
    );
    fs::remove_file(directory.0.join("a")).unwrap();
    explorer.tree.refresh(&explorer.state).unwrap().wait();
    let started = Instant::now();
    while explorer.tree.source().contains(a.node) {
        assert!(started.elapsed() < Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(1));
    }
    let at = frame.position(a.node).unwrap();
    let removed = explorer.inspect_range(frame, at, at + 1).wait();
    assert!(
        matches!(removed, Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::MissingNode)
    );
}

#[test]
fn t_reveal_updates_root_expansion_and_cursor_without_changing_selection() {
    let directory = Directory::new();
    for name in ["a", "b"] {
        fs::write(directory.0.join(name), "content").unwrap();
    }
    fs::create_dir(directory.0.join("nested")).unwrap();
    fs::write(directory.0.join("nested/file"), "content").unwrap();
    let explorer = explorer(&directory.0);
    let a = request(explorer.tree.resolve(directory.0.join("a")));
    let file = request(explorer.tree.resolve(directory.0.join("nested/file")));
    let frame = explorer.state.snapshot().unwrap();
    let at = frame.position(a.node).unwrap();
    reply(
        &explorer,
        explorer.mark(frame, at, at + 1, Mark::Cut, false),
    );
    let selection = explorer.state.snapshot().unwrap().selection_revision();
    reply(&explorer, explorer.navigate(file.node, true));
    let frame = explorer.state.snapshot().unwrap();
    assert_eq!(frame.cursor(), Some(file.node));
    assert!(frame.position(file.node).is_some());
    assert_eq!(*frame.root(), Root::ChildrenOf(explorer.workspace));
    assert_eq!(frame.selection_revision(), selection);
    assert_eq!(mode(&frame), Some("cut"));
    let nested = file.source.node(file.node).unwrap().parent.unwrap();
    reply(&explorer, explorer.navigate(nested, false));
    assert_eq!(explorer.previous(), Some(explorer.workspace));
    assert_eq!(mode(&explorer.state.snapshot().unwrap()), Some("cut"));
}

#[test]
fn t_reveal_resolves_an_external_target_after_the_display_root_is_removed() {
    let directory = Directory::new();
    let workspace = directory.0.join("workspace");
    fs::create_dir(&workspace).unwrap();
    for name in ["a", "b"] {
        fs::write(workspace.join(name), "content").unwrap();
    }
    let target = directory.0.join("external");
    fs::write(&target, "content").unwrap();
    let explorer = explorer(&workspace);
    fs::remove_dir_all(&workspace).unwrap();
    assert_eq!(request(explorer.reveal_path(target.clone())), target);
    explorer.tree.refresh(&explorer.state).unwrap().wait();
    assert_eq!(request(explorer.reveal_path(target.clone())), target);
    let resource = request(explorer.tree.resolve(target));
    reply(&explorer, explorer.navigate(resource.node, true));
    let frame = explorer.state.snapshot().unwrap();
    assert_eq!(frame.cursor(), Some(resource.node));
    assert!(frame.position(resource.node).is_some());
}
