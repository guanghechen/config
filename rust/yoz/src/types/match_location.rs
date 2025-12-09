use mlua::prelude::*;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct IMatchLocation {
    pub offset: usize,
    pub lnum: usize,
    pub col: usize,
    pub line: String,
}

impl IntoLua for IMatchLocation {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("offset", self.offset)?;
        table.set("lnum", self.lnum)?;
        table.set("col", self.col)?;
        table.set("line", self.line)?;
        Ok(LuaValue::Table(table))
    }
}

impl FromLua for IMatchLocation {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        match value {
            LuaValue::Table(table) => Ok(IMatchLocation {
                offset: table.get("offset")?,
                lnum: table.get("lnum")?,
                col: table.get("col")?,
                line: table.get("line")?,
            }),
            value => Err(LuaError::FromLuaConversionError {
                from: value.type_name(),
                to: "IMatchLocation".into(),
                message: Some("expected table".into()),
            }),
        }
    }
}
