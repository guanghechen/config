use super::{FindFilesJob, IFindFilesOptions, start_find_files};
use crate::job::Outcome;
use mlua::prelude::*;

struct Job(FindFilesJob);

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
                Some(Outcome::Completed(result)) => {
                    let table = lua.create_table()?;
                    let filepaths = result.filepaths.iter().map(String::as_str);
                    table.set("filepaths", lua.create_sequence_from(filepaths)?)?;
                    ("completed", LuaValue::Table(table), LuaValue::Nil)
                }
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

pub(crate) fn start(lua: &Lua, options: LuaValue) -> LuaResult<LuaAnyUserData> {
    let options = IFindFilesOptions::from_lua(options, lua)?;
    let job = start_find_files(&options).map_err(LuaError::external)?;
    lua.create_userdata(Job(job))
}
