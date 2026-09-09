use super::*;
use crate::test_support::Fixture;

#[test]
fn t_real_snapshot_preserves_mixed_changes_and_numstat() {
    let fixture = Fixture::new();
    fixture.write("mixed", "base\n");
    fixture.commit();
    fixture.write("mixed", "base\nstaged\n");
    fixture.git(&["add", "mixed"], None);
    fixture.write("mixed", "base\nstaged\nunstaged\n");
    fixture.write("new", "new\n");
    let stop = AtomicBool::new(false);
    let mut options = fixture.options();
    let plain = collect(&options, &stop).unwrap();
    assert_eq!(plain.commands, 1);
    options.include_numstat = true;
    let numbered = collect(&options, &stop).unwrap();
    assert!(plain.same_status(&numbered));
    let stats = numbered.numstats.unwrap();
    assert_eq!(stats.staged[b"mixed".as_slice()].insertions, 1);
    assert_eq!(stats.unstaged[b"mixed".as_slice()].insertions, 1);
}

#[test]
fn t_real_copy_policy_matches_raw_diff_with_disabled_status_renames() {
    let fixture = Fixture::new();
    fixture.git(&["config", "diff.renames", "copies"], None);
    fixture.git(&["config", "status.renames", "false"], None);
    fixture.write("source", "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n");
    fixture.commit();
    fixture.write("copy", "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n");
    fixture.write("source", "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\n");
    fixture.git(&["add", "."], None);
    let result = collect(&fixture.options(), &AtomicBool::new(false)).unwrap();
    assert_eq!(result.commands, 3);
    let copy = result
        .entries
        .values()
        .find(|entry| entry.relative == b"copy")
        .unwrap();
    assert_eq!(copy.staged, 64);
    assert_eq!(copy.staged_previous.as_deref(), Some(b"source".as_slice()));
}

#[test]
fn t_real_unborn_and_explicit_base() {
    let fixture = Fixture::new();
    fixture.write("new", "base\n");
    fixture.git(&["add", "new"], None);
    let stop = AtomicBool::new(false);
    let mut options = fixture.options();
    let result = collect(&options, &stop).unwrap();
    assert!(result.entries.values().next().unwrap().staged_old.is_none());
    fixture.git(&["commit", "-qm", "first"], None);
    fixture.write("new", "staged\n");
    fixture.git(&["add", "new"], None);
    options.base = Some("HEAD".into());
    options.include_untracked = false;
    let result = collect(&options, &stop).unwrap();
    assert_eq!(result.commands, 2);
    assert_eq!(result.entries.values().next().unwrap().staged, 4);
}

#[test]
fn t_read_only_status_does_not_rewrite_index() {
    let fixture = Fixture::new();
    fixture.write("file", "base\n");
    fixture.commit();
    fixture.write("file", "changed\n");
    let before = std::fs::read(fixture.0.join(".git/index")).unwrap();
    collect(&fixture.options(), &AtomicBool::new(false)).unwrap();
    assert_eq!(before, std::fs::read(fixture.0.join(".git/index")).unwrap());
}
