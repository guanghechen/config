use super::{canonical, os_string};
use mlua::prelude::*;
use std::path::PathBuf;
use yoz_git::{IgnoreReport, Outcome};

struct Cache(yoz_git::IgnoreCache);
struct Job(yoz_git::IgnoreJob);

fn report_table(lua: &Lua, report: &IgnoreReport) -> LuaResult<LuaTable> {
    let result = lua.create_table_with_capacity(0, 4)?;
    let changed = lua.create_table_with_capacity(report.changed.len(), 0)?;
    for path in &report.changed {
        changed.raw_push(lua.create_string(path)?)?;
    }
    result.set("changed", changed)?;
    result.set("processes", report.processes)?;
    result.set("lstat_calls", report.lstat_calls)?;
    if let Some(warning) = &report.warning {
        let table = lua.create_table()?;
        table.set("code", warning.code)?;
        table.set("stderr", warning.stderr.as_str())?;
        result.set("warning", table)?;
    }
    Ok(result)
}

impl LuaUserData for Cache {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("lookup", |_, cache, path: LuaString| {
            Ok(cache.0.lookup(&canonical(&path.as_bytes())?))
        });
        methods.add_method("clear", |_, cache, ()| {
            cache.0.clear();
            Ok(())
        });
        methods.add_method("start", |lua, cache, paths: LuaTable| {
            let paths = paths
                .sequence_values::<LuaString>()
                .map(|path| canonical(&path?.as_bytes()))
                .collect::<LuaResult<Vec<_>>>()?;
            lua.create_userdata(Job(cache
                .0
                .start(paths, std::env::vars_os().collect())
                .map_err(LuaError::external)?))
        });
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
                Some(Outcome::Completed(report)) => (
                    "completed",
                    LuaValue::Table(report_table(lua, report)?),
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

pub(super) fn new_cache(lua: &Lua, cwd: LuaString) -> LuaResult<LuaAnyUserData> {
    let root = canonical(&cwd.as_bytes())?;
    let cwd = PathBuf::from(os_string(&cwd.as_bytes())?);
    lua.create_userdata(Cache(
        yoz_git::IgnoreCache::new(cwd, root).map_err(LuaError::external)?,
    ))
}
