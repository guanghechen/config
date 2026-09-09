use crate::model::{Entry, Numstats, Snapshot};
use crate::parse::{self, Porcelain, RawRecord};
use crate::process;
use std::collections::BTreeMap;
use std::ffi::OsString;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::Instant;

#[derive(Clone, Debug)]
pub struct Options {
    pub cwd: PathBuf,
    pub root: Vec<u8>,
    pub environment: Vec<(OsString, OsString)>,
    pub base: Option<OsString>,
    pub include_numstat: bool,
    pub include_untracked: bool,
}

fn args(values: &[&str]) -> Vec<OsString> {
    values.iter().map(OsString::from).collect()
}

fn apply(
    entries: &mut BTreeMap<Vec<u8>, Entry>,
    root: &[u8],
    records: Vec<RawRecord>,
    staged: bool,
) {
    for record in records {
        let item = parse::entry(entries, root, &record.relative);
        if staged {
            item.staged |= record.code;
            item.staged_previous = record.previous;
            item.staged_old = record.old;
            item.staged_new = record.new;
        } else {
            item.unstaged |= record.code;
            item.unstaged_previous = record.previous;
            item.unstaged_old = record.old;
            item.unstaged_new = record.new;
        }
    }
}

pub fn collect(options: &Options, cancelled: &AtomicBool) -> Result<Snapshot, String> {
    let started = Instant::now();
    let mut commands = 0;
    let mut untracked = None;
    if options.base.is_none() && !options.include_numstat {
        let query = args(&[
            "status",
            "--porcelain=v2",
            "-z",
            if options.include_untracked {
                "--untracked-files=all"
            } else {
                "--untracked-files=no"
            },
            "--ignored=no",
        ]);
        let output = process::run(&options.cwd, &options.environment, &query, cancelled)?;
        commands += 1;
        match parse::porcelain(&output, &options.root)? {
            Porcelain::Complete(entries) => {
                let mut result = Snapshot::new(entries, None);
                result.commands = commands;
                result.elapsed_ms = started.elapsed().as_secs_f64() * 1000.0;
                return Ok(result);
            }
            Porcelain::Raw { untracked: paths } => untracked = Some(paths),
        }
    }
    let mut staged_args = args(&["diff", "--staged", "--raw", "--abbrev=64"]);
    let mut unstaged_args = args(&["diff", "--raw", "--abbrev=64"]);
    if options.include_numstat {
        staged_args.push("--numstat".into());
        unstaged_args.push("--numstat".into());
    }
    staged_args.push("-z".into());
    unstaged_args.push("-z".into());
    if let Some(base) = &options.base {
        staged_args.push(base.clone());
    }
    staged_args.push("--".into());
    unstaged_args.push("--".into());
    let mut queries = vec![staged_args, unstaged_args];
    if options.include_untracked && untracked.is_none() {
        queries.push(args(&["ls-files", "--exclude-standard", "--others", "-z"]));
    }
    commands += queries.len();
    let outputs = thread::scope(|scope| {
        let handles: Vec<_> = queries
            .iter()
            .map(|query| {
                scope.spawn(|| process::run(&options.cwd, &options.environment, query, cancelled))
            })
            .collect();
        handles
            .into_iter()
            .map(|handle| {
                handle
                    .join()
                    .map_err(|_| "Git query worker panicked".to_owned())?
            })
            .collect::<Result<Vec<_>, String>>()
    })?;
    if cancelled.load(Ordering::Acquire) {
        return Err(process::CANCELLED.into());
    }
    let (staged, staged_stats) = parse::raw(&outputs[0], options.include_numstat)?;
    let (unstaged, unstaged_stats) = parse::raw(&outputs[1], options.include_numstat)?;
    let mut entries = BTreeMap::new();
    apply(&mut entries, &options.root, staged, true);
    apply(&mut entries, &options.root, unstaged, false);
    if options.include_untracked {
        let paths = match untracked {
            Some(paths) => paths,
            None => parse::paths(&outputs[2])?,
        };
        for relative in paths {
            parse::entry(&mut entries, &options.root, &relative).unstaged |= 2;
        }
    }
    let numstats = options.include_numstat.then_some(Numstats {
        staged: staged_stats,
        unstaged: unstaged_stats,
    });
    let mut result = Snapshot::new(entries, numstats);
    result.commands = commands;
    result.elapsed_ms = started.elapsed().as_secs_f64() * 1000.0;
    Ok(result)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/status_test.rs"
    ));
}
