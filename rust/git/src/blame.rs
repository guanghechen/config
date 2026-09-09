use crate::job::{self, QueryJob};
use crate::process;
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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/blame_test.rs"
    ));
}
