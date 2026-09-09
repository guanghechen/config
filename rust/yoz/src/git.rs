//! Lua boundary for the standalone Git domain. Workers never own Lua values.
mod blame;
mod ignore;
mod staging;
mod word_diff;

use mlua::prelude::*;
use std::ffi::OsString;
use std::path::PathBuf;
use std::sync::Arc;
use yoz_git::{CODES, Entry, Info, Numstat, Options, Outcome, Snapshot, Stage, StatusJob};

fn integer(value: LuaValue) -> LuaResult<i64> {
    match value {
        LuaValue::Integer(value) if value.unsigned_abs() <= 9_007_199_254_740_991 => Ok(value),
        LuaValue::Number(value)
            if value.is_finite()
                && value.fract() == 0.0
                && value.abs() <= 9_007_199_254_740_991.0 =>
        {
            Ok(value as i64)
        }
        _ => Err(LuaError::external(
            "Git line coordinates must be exact integers",
        )),
    }
}

fn canonical(path: &[u8]) -> LuaResult<Vec<u8>> {
    #[cfg(windows)]
    {
        let text = std::str::from_utf8(path).map_err(LuaError::external)?;
        Ok(crate::canonical_path::normalize(text, false).into_bytes())
    }
    #[cfg(not(windows))]
    {
        let mut end = path.len();
        while end > 1 && path[end - 1] == b'/' {
            end -= 1;
        }
        Ok(path[..end].to_vec())
    }
}

fn os_string(bytes: &[u8]) -> LuaResult<OsString> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStringExt;
        Ok(OsString::from_vec(bytes.to_vec()))
    }
    #[cfg(not(unix))]
    {
        Ok(OsString::from(
            std::str::from_utf8(bytes).map_err(LuaError::external)?,
        ))
    }
}

fn bytes(lua: &Lua, value: &Option<Vec<u8>>) -> LuaResult<Option<LuaString>> {
    value
        .as_deref()
        .map(|value| lua.create_string(value))
        .transpose()
}

fn codes(lua: &Lua, bits: u16) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    for &(code, flag, _) in CODES {
        if bits & flag != 0 {
            result.set(lua.create_string([code])?, true)?;
        }
    }
    Ok(result)
}

fn categories(lua: &Lua, info: &Info) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    for category in info.categories() {
        result.set(category, true)?;
    }
    Ok(result)
}

fn info_table(lua: &Lua, info: Info) -> LuaResult<LuaTable> {
    let result = lua.create_table_with_capacity(0, 5)?;
    result.set("codes", info.codes)?;
    result.set("stage", info.stage.map(Stage::as_str))?;
    result.set("display", info.display)?;
    result.set("staged_display", info.staged_display)?;
    result.set(
        "summary",
        info.summary
            .map(|code| lua.create_string([code]))
            .transpose()?,
    )?;
    Ok(result)
}

fn entry_table(lua: &Lua, path: &[u8], entry: &Entry) -> LuaResult<LuaTable> {
    let info = entry.info();
    let result = lua.create_table_with_capacity(0, 18)?;
    result.set("path", lua.create_string(path)?)?;
    result.set("relative", lua.create_string(&entry.relative)?)?;
    result.set("categories", categories(lua, &info)?)?;
    result.set("codes", codes(lua, info.codes)?)?;
    result.set("display", info.display)?;
    result.set("stage", info.stage.map(Stage::as_str))?;
    result.set(
        "summary",
        info.summary
            .map(|code| lua.create_string([code]))
            .transpose()?,
    )?;
    result.set("staged", codes(lua, entry.staged)?)?;
    result.set("unstaged", codes(lua, entry.unstaged)?)?;
    result.set("staged_bits", entry.staged)?;
    result.set("unstaged_bits", entry.unstaged)?;
    result.set("staged_display", info.staged_display)?;
    result.set("unstaged_display", entry.unstaged_display())?;
    result.set("staged_old_object_name", bytes(lua, &entry.staged_old)?)?;
    result.set("staged_new_object_name", bytes(lua, &entry.staged_new)?)?;
    result.set("unstaged_old_object_name", bytes(lua, &entry.unstaged_old)?)?;
    result.set("unstaged_new_object_name", bytes(lua, &entry.unstaged_new)?)?;
    result.set("staged_prev_relative", bytes(lua, &entry.staged_previous)?)?;
    result.set(
        "unstaged_prev_relative",
        bytes(lua, &entry.unstaged_previous)?,
    )?;
    Ok(result)
}

struct StatusSnapshot(Arc<Snapshot>);

impl StatusSnapshot {
    fn entries(&self, lua: &Lua) -> LuaResult<LuaTable> {
        let result = lua.create_table_with_capacity(0, self.0.entries().len())?;
        for (path, entry) in self.0.entries() {
            result.set(lua.create_string(path)?, entry_table(lua, path, entry)?)?;
        }
        Ok(result)
    }

    fn export(&self, lua: &Lua) -> LuaResult<LuaTable> {
        let result = lua.create_table()?;
        result.set("status_map", self.entries(lua)?)?;
        let groups = lua.create_table()?;
        for category in [
            "added",
            "conflict",
            "copied",
            "deleted",
            "ignored",
            "modified",
            "renamed",
            "staged",
            "type_changed",
            "unstaged",
            "untracked",
        ] {
            groups.set(category, lua.create_table()?)?;
        }
        for (path, entry) in self.0.entries() {
            for category in entry.info().categories() {
                groups
                    .get::<LuaTable>(category)?
                    .set(lua.create_string(path)?, true)?;
            }
        }
        result.set("status_groups", groups)?;
        if let Some(stats) = self.0.numstats() {
            let table = lua.create_table()?;
            for (name, entries) in [("staged", &stats.staged), ("unstaged", &stats.unstaged)] {
                let map = lua.create_table_with_capacity(0, entries.len())?;
                for (
                    path,
                    Numstat {
                        insertions,
                        deletions,
                    },
                ) in entries
                {
                    let item = lua.create_table()?;
                    item.set("insertions", *insertions)?;
                    item.set("deletions", *deletions)?;
                    map.set(lua.create_string(path)?, item)?;
                }
                table.set(name, map)?;
            }
            result.set("numstats", table)?;
        }
        Ok(result)
    }
}

impl LuaUserData for StatusSnapshot {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("equals", |_, snapshot, other: LuaAnyUserData| {
            let other = other.borrow::<StatusSnapshot>()?;
            Ok(Arc::ptr_eq(&snapshot.0, &other.0) || snapshot.0.same_status(&other.0))
        });
        methods.add_method(
            "lookup",
            |lua, snapshot, (path, directory): (LuaString, Option<bool>)| {
                let path = canonical(&path.as_bytes())?;
                snapshot
                    .0
                    .lookup(&path, directory.unwrap_or(false))
                    .map(|info| info_table(lua, info))
                    .transpose()
            },
        );
        methods.add_method("entries", |lua, snapshot, ()| snapshot.entries(lua));
        methods.add_method("export", |lua, snapshot, ()| snapshot.export(lua));
        methods.add_method("display", |lua, snapshot, ()| {
            let result = lua.create_table_with_capacity(0, snapshot.0.entries().len())?;
            for (path, entry) in snapshot.0.entries() {
                result.set(lua.create_string(path)?, entry.info().display)?;
            }
            Ok(result)
        });
        methods.add_method("changed_files", |lua, snapshot, ()| {
            let (staged, unstaged) = (lua.create_table()?, lua.create_table()?);
            for (path, entry) in snapshot.0.entries() {
                if matches!(entry.stage(), Some(Stage::Staged | Stage::Mixed)) {
                    staged.raw_push(lua.create_string(path)?)?;
                }
                if matches!(entry.stage(), Some(Stage::Unstaged | Stage::Mixed))
                    || (entry.staged | entry.unstaged) & 2 != 0
                {
                    unstaged.raw_push(lua.create_string(path)?)?;
                }
            }
            Ok((staged, unstaged))
        });
        methods.add_method("stats", |_, snapshot, ()| Ok(snapshot.0.stats()));
    }
}

struct Job(StatusJob);

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
                    LuaValue::UserData(lua.create_userdata(StatusSnapshot(Arc::clone(snapshot)))?),
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

pub fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    result.set("staging", staging::module(lua)?)?;
    result.set("word_diff", word_diff::module(lua)?)?;
    result.set("ignore_cache", lua.create_function(ignore::new_cache)?)?;
    result.set("start_blame", lua.create_function(blame::start)?)?;
    result.set(
        "empty_status",
        lua.create_function(|lua, ()| {
            lua.create_userdata(StatusSnapshot(Arc::new(Snapshot::default())))
        })?,
    )?;
    result.set(
        "start_status",
        lua.create_function(|lua, options: LuaTable| {
            let cwd = options.get::<LuaString>("cwd")?;
            let base = options.get::<Option<LuaString>>("base")?;
            let options = Options {
                cwd: PathBuf::from(os_string(&cwd.as_bytes())?),
                root: canonical(&cwd.as_bytes())?,
                environment: std::env::vars_os().collect(),
                base: base.map(|value| os_string(&value.as_bytes())).transpose()?,
                include_numstat: options
                    .get::<Option<bool>>("include_numstat")?
                    .unwrap_or(false),
                include_untracked: options
                    .get::<Option<bool>>("include_untracked")?
                    .unwrap_or(true),
            };
            lua.create_userdata(Job(
                yoz_git::start_status(options).map_err(LuaError::external)?
            ))
        })?,
    )?;
    let codes = lua.create_table()?;
    for &(code, flag, _) in CODES {
        codes.set(lua.create_string([code])?, flag)?;
    }
    result.set("codes", codes)?;
    Ok(result)
}
