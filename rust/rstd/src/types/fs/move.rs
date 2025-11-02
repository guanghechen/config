use mlua::{Error as LuaError, FromLua, IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsMoveParams {
    pub old_path: String,
    pub new_path: String,
    pub force: bool,
}

impl FromLua for IFsMoveParams {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        match value {
            LuaValue::Table(table) => Ok(Self {
                old_path: table.get("old_path")?,
                new_path: table.get("new_path")?,
                force: table.get("force")?,
            }),
            other => Err(LuaError::FromLuaConversionError {
                from: other.type_name(),
                to: "rstd.fs.IFsMoveParams".into(),
                message: Some("expected table".into()),
            }),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsMoveError {
    pub error: String,
}

impl IntoLua for IFsMoveError {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("error", self.error)?;
        Ok(LuaValue::Table(table))
    }
}
