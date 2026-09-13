use super::job::{self, QueryJob};
use super::process;
use std::collections::HashMap;
use std::ffi::OsString;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct BlameCommit {
    pub sha: Vec<u8>,
    pub author: Vec<u8>,
    pub author_mail: Vec<u8>,
    pub author_time: i64,
    pub author_tz: Vec<u8>,
    pub committer: Vec<u8>,
    pub committer_mail: Vec<u8>,
    pub committer_time: i64,
    pub committer_tz: Vec<u8>,
    pub summary: Vec<u8>,
}

impl BlameCommit {
    pub fn is_uncommitted(&self) -> bool {
        (!self.sha.is_empty() && self.sha.iter().all(|byte| *byte == b'0'))
            || self.author == b"Not Committed Yet"
    }
}

#[derive(Clone, Debug, Default)]
pub struct BlameSource {
    // Preserve Git's porcelain spelling, including quoted filenames, as the Lua collector did.
    pub filename: Vec<u8>,
    pub previous: Option<Vec<u8>>,
    pub previous_filename: Option<Vec<u8>>,
}

#[derive(Debug)]
pub struct BlameLine {
    pub commit: usize,
    pub orig_lnum: usize,
    pub num_lines: usize,
    pub source: Arc<BlameSource>,
}

#[derive(Debug, Default)]
pub struct BlameSnapshot {
    commits: Vec<BlameCommit>,
    lines: Vec<BlameLine>,
    elapsed_ms: f64,
}

impl BlameSnapshot {
    pub fn commits(&self) -> &[BlameCommit] {
        &self.commits
    }
    pub fn lines(&self) -> &[BlameLine] {
        &self.lines
    }
    pub fn commit_at(&self, lnum: usize) -> Option<&BlameCommit> {
        let line = self.lines.get(lnum.checked_sub(1)?)?;
        self.commits.get(line.commit)
    }
    pub fn stats(&self) -> (usize, usize, f64) {
        (self.lines.len(), self.commits.len(), self.elapsed_ms)
    }
}

pub struct BlameOptions {
    pub cwd: PathBuf,
    pub path: OsString,
    pub contents: Vec<u8>,
    pub environment: Vec<(OsString, OsString)>,
}

pub type BlameJob = QueryJob<Arc<BlameSnapshot>>;

pub fn start_blame(options: BlameOptions) -> Result<BlameJob, String> {
    if !options.cwd.is_absolute() || options.path.is_empty() {
        return Err("Git blame requires an absolute cwd and a nonempty path".into());
    }
    job::spawn("yoz-git-blame", move |cancelled| {
        let started = Instant::now();
        let mut args: Vec<OsString> = ["blame", "--porcelain", "--contents", "-", "--"]
            .map(OsString::from)
            .into();
        args.push(options.path);
        let output = process::output(
            &options.cwd,
            &options.environment,
            &args,
            Some(options.contents),
            cancelled,
        )?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
            return Err(if stderr.is_empty() {
                format!(
                    "git blame failed (exit {})",
                    output
                        .status
                        .code()
                        .map(|code| code.to_string())
                        .unwrap_or_else(|| "signal".into())
                )
            } else {
                stderr
            });
        }
        let mut snapshot = parse(&output.stdout, cancelled)?;
        snapshot.elapsed_ms = started.elapsed().as_secs_f64() * 1000.0;
        Ok(Arc::new(snapshot))
    })
}

fn sha(bytes: &[u8]) -> bool {
    matches!(bytes.len(), 40 | 64) && bytes.iter().all(u8::is_ascii_hexdigit)
}

fn number(bytes: &[u8]) -> Result<usize, String> {
    std::str::from_utf8(bytes)
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .filter(|value| *value > 0)
        .ok_or_else(|| "Invalid Git blame line number".into())
}

fn timestamp(bytes: &[u8]) -> Result<i64, String> {
    std::str::from_utf8(bytes)
        .ok()
        .and_then(|value| value.parse().ok())
        .ok_or_else(|| "Invalid Git blame timestamp".into())
}

fn mail(bytes: &[u8]) -> Vec<u8> {
    let bytes = bytes.strip_prefix(b"<").unwrap_or(bytes);
    bytes.strip_suffix(b">").unwrap_or(bytes).to_vec()
}

fn parse(output: &[u8], cancelled: &AtomicBool) -> Result<BlameSnapshot, String> {
    if output.is_empty() {
        return Ok(BlameSnapshot::default());
    }
    if !output.is_empty() && !output.ends_with(b"\n") {
        return Err("Incomplete Git blame output".into());
    }
    let mut snapshot = BlameSnapshot::default();
    let mut commits = HashMap::<Vec<u8>, (usize, Arc<BlameSource>)>::new();
    let mut rows = output[..output.len() - 1].split(|byte| *byte == b'\n');
    let mut remaining = 0;
    let mut group_sha = Vec::new();
    let mut next_orig = 0;
    while let Some(header) = rows.next() {
        if cancelled.load(Ordering::Acquire) {
            return Err(process::CANCELLED.into());
        }
        let fields: Vec<_> = header.split(|byte| *byte == b' ').collect();
        if !(fields.len() == 3 || fields.len() == 4) || !sha(fields[0]) {
            return Err("Malformed Git blame header".into());
        }
        let orig_lnum = number(fields[1])?;
        let final_lnum = number(fields[2])?;
        if final_lnum != snapshot.lines.len() + 1 {
            return Err("Non-contiguous Git blame output".into());
        }
        let num_lines = if fields.len() == 4 {
            number(fields[3])?
        } else {
            1
        };
        if remaining == 0 {
            if fields.len() != 4 {
                return Err("Git blame group size missing".into());
            }
            remaining = num_lines;
            group_sha = fields[0].to_vec();
        } else if fields.len() != 3 || group_sha != fields[0] || next_orig != orig_lnum {
            return Err("Incomplete Git blame group".into());
        }
        remaining -= 1;
        next_orig = orig_lnum
            .checked_add(1)
            .ok_or("Git blame line number overflow")?;

        let existing = commits.get(fields[0]);
        let index = existing.map(|entry| entry.0);
        let mut source = existing
            .map(|entry| Arc::clone(&entry.1))
            .unwrap_or_default();
        let mut detail = index.is_none().then(|| BlameCommit {
            sha: fields[0].to_vec(),
            ..BlameCommit::default()
        });
        let mut seen = 0u16;
        loop {
            if cancelled.load(Ordering::Acquire) {
                return Err(process::CANCELLED.into());
            }
            let row = rows.next().ok_or("Incomplete Git blame record")?;
            if row.starts_with(b"\t") {
                break;
            }
            let Some(split) = row.iter().position(|byte| *byte == b' ') else {
                continue;
            };
            let (key, value) = (&row[..split], &row[split + 1..]);
            if key == b"filename" {
                if source.filename != value {
                    Arc::make_mut(&mut source).filename = value.to_vec();
                }
                continue;
            }
            if key == b"previous" {
                let split = value
                    .iter()
                    .position(|byte| *byte == b' ')
                    .ok_or("Malformed Git blame previous record")?;
                if !sha(&value[..split]) || value[split + 1..].is_empty() {
                    return Err("Malformed Git blame previous record".into());
                }
                let source = Arc::make_mut(&mut source);
                source.previous = Some(value[..split].to_vec());
                source.previous_filename = Some(value[split + 1..].to_vec());
                continue;
            }
            let flag = match key {
                b"author" => 1,
                b"author-mail" => 2,
                b"author-time" => 4,
                b"author-tz" => 8,
                b"committer" => 16,
                b"committer-mail" => 32,
                b"committer-time" => 64,
                b"committer-tz" => 128,
                b"summary" => 256,
                _ => continue,
            };
            seen |= flag;
            let info = detail
                .get_or_insert_with(|| snapshot.commits[index.expect("known commit")].clone());
            match key {
                b"author" => info.author = value.to_vec(),
                b"author-mail" => info.author_mail = mail(value),
                b"author-time" => info.author_time = timestamp(value)?,
                b"author-tz" => info.author_tz = value.to_vec(),
                b"committer" => info.committer = value.to_vec(),
                b"committer-mail" => info.committer_mail = mail(value),
                b"committer-time" => info.committer_time = timestamp(value)?,
                b"committer-tz" => info.committer_tz = value.to_vec(),
                b"summary" => info.summary = value.to_vec(),
                _ => unreachable!(),
            }
        }
        if source.filename.is_empty() || (index.is_none() && seen != 511) {
            return Err("Incomplete Git blame metadata".into());
        }
        let commit = match index {
            Some(index) => {
                if detail
                    .as_ref()
                    .is_some_and(|detail| *detail != snapshot.commits[index])
                {
                    return Err("Conflicting Git blame commit metadata".into());
                }
                index
            }
            None => {
                let index = snapshot.commits.len();
                snapshot.commits.push(detail.expect("new commit"));
                commits.insert(fields[0].to_vec(), (index, Arc::clone(&source)));
                index
            }
        };
        snapshot.lines.push(BlameLine {
            commit,
            orig_lnum,
            num_lines,
            source,
        });
    }
    if remaining != 0 {
        return Err("Incomplete Git blame group".into());
    }
    Ok(snapshot)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::git::Outcome;
    use crate::git::test_support::Fixture;
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
}
