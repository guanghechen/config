use mlua::{IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsCollectFilesResult {
    pub files: Vec<String>,
}

impl<'lua> IntoLua<'lua> for IFsCollectFilesResult {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("files", lua.create_sequence_from(self.files)?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsCollectFilesError {
    pub error: String,
}

impl<'lua> IntoLua<'lua> for IFsCollectFilesError {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("error", self.error)?;
        Ok(LuaValue::Table(table))
    }
}
