use mlua::{Error as LuaError, FromLua, IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFindFilesSucceedResult {
    pub filepaths: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFindFilesFailedResult {
    pub error: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFindFilesOptions {
    pub cwd: String,
    pub flag_case_sensitive: bool,
    pub flag_gitignore: bool,
    pub flag_regex: bool,
    pub search_pattern: String,
    pub search_paths: String,
    pub exclude_patterns: String,
}

impl FromLua for IFindFilesOptions {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        match value {
            LuaValue::Table(table) => Ok(Self {
                cwd: table.get("cwd")?,
                flag_case_sensitive: table.get("flag_case_sensitive")?,
                flag_gitignore: table.get("flag_gitignore")?,
                flag_regex: table.get("flag_regex")?,
                search_pattern: table.get("search_pattern")?,
                search_paths: table.get("search_paths")?,
                exclude_patterns: table.get("exclude_patterns")?,
            }),
            other => Err(LuaError::FromLuaConversionError {
                from: other.type_name(),
                to: "rstd.find.IFindFilesOptions".into(),
                message: Some("expected table".into()),
            }),
        }
    }
}

impl IntoLua for IFindFilesSucceedResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        let filepaths = lua.create_sequence_from(self.filepaths)?;
        table.set("filepaths", filepaths)?;
        Ok(LuaValue::Table(table))
    }
}

impl IntoLua for IFindFilesFailedResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("error", self.error)?;
        Ok(LuaValue::Table(table))
    }
}
