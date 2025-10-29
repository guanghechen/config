use mlua::prelude::*;
use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchMatchPoint {
    pub l: usize,
    pub r: usize,
}

impl<'lua> IntoLua<'lua> for ISearchMatchPoint {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
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

impl<'lua> IntoLua<'lua> for ISearchBlockMatch {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
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

impl<'lua> IntoLua<'lua> for ISearchFileMatch {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("matches", lua.create_sequence_from(self.matches)?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInFilesSucceedResult {
    #[serde(skip_serializing)]
    pub cmd: String,
    #[serde(skip_serializing)]
    pub stdout: String,

    pub elapsed_time: String,
    pub items: HashMap<String, ISearchFileMatch>,
}

impl<'lua> IntoLua<'lua> for ISearchInFilesSucceedResult {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
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
    #[serde(skip_serializing)]
    pub cmd: String,

    pub elapsed_time: String,
    pub error: String,
}

impl<'lua> IntoLua<'lua> for ISearchInFilesFailedResult {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
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

impl<'lua> FromLua<'lua> for ISearchInFilesOptions {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        match value {
            LuaValue::Table(table) => Ok(Self {
                cwd: table.get::<_, Option<String>>("cwd")?,
                flag_case_sensitive: table.get("flag_case_sensitive")?,
                flag_gitignore: table.get("flag_gitignore")?,
                flag_regex: table.get("flag_regex")?,
                max_filesize: table.get::<_, Option<String>>("max_filesize")?,
                max_matches: table.get::<_, Option<i32>>("max_matches")?,
                search_pattern: table.get("search_pattern")?,
                search_paths: table
                    .get::<_, Option<String>>("search_paths")?
                    .unwrap_or_default(),
                include_patterns: table
                    .get::<_, Option<String>>("include_patterns")?
                    .unwrap_or_default(),
                exclude_patterns: table
                    .get::<_, Option<String>>("exclude_patterns")?
                    .unwrap_or_default(),
                specified_filepath: table.get::<_, Option<String>>("specified_filepath")?,
            }),
            other => Err(LuaError::FromLuaConversionError {
                from: other.type_name(),
                to: "rstd.search.ISearchInFilesOptions",
                message: Some("expected table".into()),
            }),
        }
    }
}
