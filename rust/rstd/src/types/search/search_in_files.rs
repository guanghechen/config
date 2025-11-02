use mlua::prelude::*;
use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchMatchPoint {
    pub l: usize,
    pub r: usize,
}

impl IntoLua for ISearchMatchPoint {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("l", self.l)?;
        table.set("r", self.r)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchBlockMatch {
    pub lnum: usize,
    pub text: String,
    pub offset: usize,
    pub matches: Vec<ISearchMatchPoint>,
}

impl IntoLua for ISearchBlockMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("lnum", self.lnum)?;
        table.set("text", self.text)?;
        table.set("offset", self.offset)?;
        table.set("matches", lua.create_sequence_from(self.matches)?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchFileMatch {
    pub matches: Vec<ISearchBlockMatch>,
}

impl IntoLua for ISearchFileMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("matches", lua.create_sequence_from(self.matches)?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInFilesSucceedResult {
    pub elapsed_time: String,
    pub items: HashMap<String, ISearchFileMatch>,
}

impl IntoLua for ISearchInFilesSucceedResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("elapsed_time", self.elapsed_time)?;
        let items_table = lua.create_table()?;
        for (filepath, filematch) in self.items {
            items_table.set(filepath, filematch)?;
        }
        table.set("items", items_table)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInFilesFailedResult {
    pub elapsed_time: String,
    pub error: String,
}

impl IntoLua for ISearchInFilesFailedResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("elapsed_time", self.elapsed_time)?;
        table.set("error", self.error)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInFilesOptions {
    pub cwd: Option<String>,
    pub flag_case_sensitive: bool,
    pub flag_gitignore: bool,
    pub flag_regex: bool,
    pub max_filesize: Option<String>,
    pub max_matches: Option<i32>,
    pub search_pattern: String,
    pub search_paths: String,
    pub include_patterns: String,
    pub exclude_patterns: String,
    pub specified_filepath: Option<String>,
}

impl FromLua for ISearchInFilesOptions {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        match value {
            LuaValue::Table(table) => Ok(Self {
                cwd: table.get::<Option<String>>("cwd")?,
                flag_case_sensitive: table.get("flag_case_sensitive")?,
                flag_gitignore: table.get("flag_gitignore")?,
                flag_regex: table.get("flag_regex")?,
                max_filesize: table.get::<Option<String>>("max_filesize")?,
                max_matches: table.get::<Option<i32>>("max_matches")?,
                search_pattern: table.get("search_pattern")?,
                search_paths: table
                    .get::<Option<String>>("search_paths")?
                    .unwrap_or_default(),
                include_patterns: table
                    .get::<Option<String>>("include_patterns")?
                    .unwrap_or_default(),
                exclude_patterns: table
                    .get::<Option<String>>("exclude_patterns")?
                    .unwrap_or_default(),
                specified_filepath: table.get::<Option<String>>("specified_filepath")?,
            }),
            other => Err(LuaError::FromLuaConversionError {
                from: other.type_name(),
                to: "rstd.search.ISearchInFilesOptions".into(),
                message: Some("expected table".into()),
            }),
        }
    }
}
