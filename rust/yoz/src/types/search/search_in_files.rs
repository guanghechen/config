use super::search_in_lines::ISearchInLinesLineMatch;
use mlua::prelude::*;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub struct ITextMatch {
    pub lx: u32,
    pub ly: u32,
    pub cx: u32,
    pub cy: u32,
    pub ox: usize,
    pub oy: usize,
    pub s: String,
    pub sx: u32,
    pub sy: u32,
}

impl IntoLua for ITextMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        (&self).into_lua(lua)
    }
}

impl IntoLua for &ITextMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table_with_capacity(0, 9)?;
        table.set("lx", self.lx)?;
        table.set("ly", self.ly)?;
        table.set("cx", self.cx)?;
        table.set("cy", self.cy)?;
        table.set("ox", self.ox)?;
        table.set("oy", self.oy)?;
        table.set("s", self.s.as_str())?;
        table.set("sx", self.sx)?;
        table.set("sy", self.sy)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub struct IFileMatch {
    pub p: String,
    pub matches: Vec<ITextMatch>,
}

impl IntoLua for IFileMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        (&self).into_lua(lua)
    }
}

impl IntoLua for &IFileMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table_with_capacity(0, 2)?;
        table.set("p", self.p.as_str())?;
        table.set("matches", lua.create_sequence_from(self.matches.iter())?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub struct ISearchFileResult {
    pub elapsed_time: u64,
    pub items: Vec<IFileMatch>,
    pub limit_reached: bool,
}

impl IntoLua for ISearchFileResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        (&self).into_lua(lua)
    }
}

impl IntoLua for &ISearchFileResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table_with_capacity(0, 3)?;
        table.set("elapsed_time", self.elapsed_time)?;
        table.set("items", lua.create_sequence_from(self.items.iter())?)?;
        table.set("limit_reached", self.limit_reached)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchTextResult {
    pub elapsed_time: u64,
    pub matches: Vec<ITextMatch>,
    pub lines: Vec<ISearchInLinesLineMatch>,
}

impl IntoLua for ISearchTextResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("elapsed_time", self.elapsed_time)?;
        table.set("matches", lua.create_sequence_from(self.matches)?)?;
        table.set("lines", lua.create_sequence_from(self.lines)?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub struct ISearchFailedResult {
    pub elapsed_time: u64,
    pub error: String,
}

impl IntoLua for ISearchFailedResult {
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
                to: "yoz.search.ISearchInFilesOptions".into(),
                message: Some("expected table".into()),
            }),
        }
    }
}
