use super::*;
use crate::Outcome;
use crate::test_support::Fixture;
use std::time::Duration;

fn block(sha: &str, orig: usize, final_lnum: usize, count: usize) -> String {
    format!(
        "{sha} {orig} {final_lnum} {count}\nauthor Alice\nauthor-mail <alice@example.com>\nauthor-time 1\nauthor-tz +0800\ncommitter Bob\ncommitter-mail <bob@example.com>\ncommitter-time 2\ncommitter-tz -0400\nsummary 100% done\nfilename file\n\ttext\n"
    )
}

fn query(fixture: &Fixture, path: &str, contents: &[u8]) -> BlameJob {
    start_blame(BlameOptions {
        cwd: fixture.0.clone(),
        path: path.into(),
        contents: contents.to_vec(),
        environment: std::env::vars_os().collect(),
    })
    .unwrap()
}

fn finish(job: &mut BlameJob) -> Arc<BlameSnapshot> {
    let started = Instant::now();
    loop {
        match job.poll().unwrap() {
            Some(Outcome::Completed(snapshot)) => return Arc::clone(snapshot),
            Some(other) => panic!("unexpected outcome: {other:?}"),
            None => {}
        }
        assert!(started.elapsed() < Duration::from_secs(5));
        std::thread::sleep(Duration::from_millis(1));
    }
}

#[test]
fn t_groups_share_commit_metadata_and_preserve_line_identity() {
    let sha = "a".repeat(40);
    let text = block(&sha, 10, 1, 2)
        + &format!("{sha} 11 2\n\tsecond\n{sha} 20 3 1\nfilename renamed\n\tthird\n");
    let snapshot = parse(text.as_bytes(), &AtomicBool::new(false)).unwrap();
    assert_eq!(snapshot.commits.len(), 1);
    assert_eq!(snapshot.lines.len(), 3);
    assert_eq!(snapshot.lines[0].orig_lnum, 10);
    assert_eq!(snapshot.lines[0].num_lines, 2);
    assert_eq!(snapshot.lines[1].num_lines, 1);
    assert_eq!(snapshot.lines[2].source.filename, b"renamed");
    assert!(Arc::ptr_eq(
        &snapshot.lines[0].source,
        &snapshot.lines[1].source
    ));
    assert_eq!(snapshot.commits[0].author_mail, b"alice@example.com");
    assert_eq!(snapshot.commits[0].summary, b"100% done");
    assert!(snapshot.commit_at(0).is_none());
    assert!(snapshot.commit_at(4).is_none());
}

#[test]
fn t_sha256_zero_hash_and_literal_metadata_are_preserved() {
    let sha = "0".repeat(64);
    let text = block(&sha, 1, 1, 1)
        .replace("summary 100% done", "summary <sha> 100% done")
        .replace(
            "filename file",
            &format!(
                "previous {} \"old\\nfile\"\nfilename \"new\\tfile\"",
                "b".repeat(64)
            ),
        );
    let snapshot = parse(text.as_bytes(), &AtomicBool::new(false)).unwrap();
    assert!(snapshot.commits[0].is_uncommitted());
    assert_eq!(snapshot.commits[0].sha.len(), 64);
    assert_eq!(snapshot.lines[0].source.filename, b"\"new\\tfile\"");
    assert_eq!(
        snapshot.lines[0].source.previous_filename.as_deref(),
        Some(b"\"old\\nfile\"".as_slice())
    );
}

#[test]
fn t_metadata_and_source_bytes_need_not_be_utf8() {
    let sha = "a".repeat(40);
    let mut text = block(&sha, 1, 1, 1).into_bytes();
    let index = text.windows(5).position(|value| value == b"Alice").unwrap();
    text[index] = 255;
    let snapshot = parse(&text, &AtomicBool::new(false)).unwrap();
    assert_eq!(snapshot.commits[0].author[0], 255);
}

#[test]
fn t_incomplete_malformed_or_conflicting_output_never_publishes_a_partial_snapshot() {
    let sha = "a".repeat(40);
    let valid = block(&sha, 1, 1, 1);
    for text in [
        valid.trim_end().to_owned(),
        valid.replace("\ttext\n", ""),
        block(&sha, 1, 1, 2),
        block(&sha, 1, 2, 1),
        valid.replace("author-time 1", "author-time invalid"),
        valid.replace("author-mail <alice@example.com>\n", ""),
        valid.clone() + &block(&sha, 2, 2, 1).replace("author Alice", "author Other"),
    ] {
        assert!(
            parse(text.as_bytes(), &AtomicBool::new(false)).is_err(),
            "accepted {text:?}"
        );
    }
    assert!(
        parse(b"", &AtomicBool::new(false))
            .unwrap()
            .lines
            .is_empty()
    );
    assert!(parse(valid.as_bytes(), &AtomicBool::new(true)).is_err());
}

#[test]
fn t_real_query_uses_supplied_contents_without_modifying_the_worktree_or_index() {
    let fixture = Fixture::new();
    fixture.write("file", "base\nunchanged\n");
    fixture.commit();
    let index = std::fs::read(fixture.0.join(".git/index")).unwrap();
    let mut job = query(&fixture, "file", b"UNSAVED\nbase\nunchanged\n");
    let snapshot = finish(&mut job);
    assert!(snapshot.commit_at(1).unwrap().is_uncommitted());
    assert!(!snapshot.commit_at(2).unwrap().is_uncommitted());
    assert_eq!(snapshot.lines.len(), 3);
    assert_eq!(
        std::fs::read(fixture.0.join("file")).unwrap(),
        b"base\nunchanged\n"
    );
    assert_eq!(std::fs::read(fixture.0.join(".git/index")).unwrap(), index);
    assert!(Arc::ptr_eq(&snapshot, &finish(&mut job)));
}

#[test]
fn t_empty_contents_and_missing_final_newline_retain_git_line_semantics() {
    let fixture = Fixture::new();
    fixture.write("file", "base\n");
    fixture.commit();
    assert!(finish(&mut query(&fixture, "file", b"")).lines.is_empty());
    let snapshot = finish(&mut query(&fixture, "file", b"base"));
    assert_eq!(snapshot.lines.len(), 1);
}

#[test]
fn t_cancelled_job_and_disposal_keep_terminal_contracts() {
    let fixture = Fixture::new();
    fixture.write("file", "base\n");
    fixture.commit();
    let mut job = query(&fixture, "file", b"base\n");
    job.cancel().unwrap();
    let started = Instant::now();
    while job.poll().unwrap().is_none() {
        assert!(started.elapsed() < Duration::from_secs(5));
        std::thread::sleep(Duration::from_millis(1));
    }
    assert!(matches!(job.poll().unwrap(), Some(Outcome::Cancelled)));
    job.dispose();
    job.dispose();
    assert!(job.poll().is_err());
}
