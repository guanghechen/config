use super::os_string;
use mlua::prelude::*;
use std::path::PathBuf;
use std::sync::Arc;
use yoz_git::{BlameCommit, BlameOptions, BlameSnapshot, Outcome};

struct Snapshot(Arc<BlameSnapshot>);
struct Job(yoz_git::BlameJob);

fn commit_table(lua: &Lua, commit: &BlameCommit) -> LuaResult<LuaTable> {
    let table = lua.create_table_with_capacity(0, 13)?;
    for (name, bytes) in [
        ("sha", commit.sha.as_slice()),
        ("abbrev_sha", &commit.sha[..8]),
        ("author", &commit.author),
        ("author_mail", &commit.author_mail),
        ("author_tz", &commit.author_tz),
        ("committer", &commit.committer),
        ("committer_mail", &commit.committer_mail),
        ("committer_tz", &commit.committer_tz),
        ("summary", &commit.summary),
    ] {
        table.set(name, lua.create_string(bytes)?)?;
    }
    table.set("author_time", commit.author_time)?;
    table.set("committer_time", commit.committer_time)?;
    table.set("uncommitted", commit.is_uncommitted())?;
    Ok(table)
}

impl LuaUserData for Snapshot {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("commit_at", |lua, snapshot, lnum: usize| {
            snapshot
                .0
                .commit_at(lnum)
                .map(|commit| commit_table(lua, commit))
                .transpose()
        });
        methods.add_method("commits", |lua, snapshot, ()| {
            let result = lua.create_table_with_capacity(snapshot.0.commits().len(), 0)?;
            for commit in snapshot.0.commits() {
                result.raw_push(commit_table(lua, commit)?)?;
            }
            Ok(result)
        });
        methods.add_method("annotations", |lua, snapshot, labels: LuaTable| {
            // Validate the same array prefix without retaining one Rust handle per commit.
            let mut count = 0;
            for label in labels.sequence_values::<LuaString>() {
                drop(label?);
                count += 1;
            }
            if count != snapshot.0.commits().len() {
                return Err(LuaError::external(
                    "Git blame labels must match the snapshot's commit count",
                ));
            }
            let result = lua.create_table_with_capacity(snapshot.0.lines().len(), 0)?;
            for group in snapshot.0.lines().chunk_by(|a, b| a.commit == b.commit) {
                let label = labels.raw_get::<LuaString>(group[0].commit + 1)?;
                for _ in group {
                    result.raw_push(&label)?;
                }
            }
            Ok(result)
        });
        methods.add_method("entries", |lua, snapshot, ()| {
            let result = lua.create_table_with_capacity(snapshot.0.lines().len(), 0)?;
            for (index, line) in snapshot.0.lines().iter().enumerate() {
                let table = commit_table(lua, &snapshot.0.commits()[line.commit])?;
                table.set("orig_lnum", line.orig_lnum)?;
                table.set("final_lnum", index + 1)?;
                table.set("num_lines", line.num_lines)?;
                table.set("filename", lua.create_string(&line.source.filename)?)?;
                table.set(
                    "previous",
                    line.source
                        .previous
                        .as_deref()
                        .map(|value| lua.create_string(value))
                        .transpose()?,
                )?;
                table.set(
                    "previous_filename",
                    line.source
                        .previous_filename
                        .as_deref()
                        .map(|value| lua.create_string(value))
                        .transpose()?,
                )?;
                result.raw_push(table)?;
            }
            Ok(result)
        });
        methods.add_method("stats", |_, snapshot, ()| Ok(snapshot.0.stats()));
    }
}

impl LuaUserData for Job {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("poll", |lua, job, ()| {
            let (state, result, error) = match job.0.poll().map_err(LuaError::external)? {
                None => ("running", LuaValue::Nil, LuaValue::Nil),
                Some(Outcome::Cancelled) => ("cancelled", LuaValue::Nil, LuaValue::Nil),
                Some(Outcome::Failed(error)) => (
                    "failed",
                    LuaValue::Nil,
                    LuaValue::String(lua.create_string(error)?),
                ),
                Some(Outcome::Completed(snapshot)) => (
                    "completed",
                    LuaValue::UserData(lua.create_userdata(Snapshot(Arc::clone(snapshot)))?),
                    LuaValue::Nil,
                ),
            };
            Ok((state, result, error))
        });
        methods.add_method_mut("cancel", |_, job, ()| {
            job.0.cancel().map_err(LuaError::external)
        });
        methods.add_method_mut("dispose", |_, job, ()| {
            job.0.dispose();
            Ok(())
        });
    }
}

pub(super) fn start(lua: &Lua, options: LuaTable) -> LuaResult<LuaAnyUserData> {
    let cwd = options.get::<LuaString>("cwd")?;
    let path = options.get::<LuaString>("path")?;
    let contents = options.get::<LuaString>("contents")?;
    let options = BlameOptions {
        cwd: PathBuf::from(os_string(&cwd.as_bytes())?),
        path: os_string(&path.as_bytes())?,
        contents: contents.as_bytes().to_vec(),
        environment: std::env::vars_os().collect(),
    };
    lua.create_userdata(Job(
        yoz_git::start_blame(options).map_err(LuaError::external)?
    ))
}
