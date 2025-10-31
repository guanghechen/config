use crate::search::ISearchInLinesMatchPoint;
use crate::types::IMatchLocation;
use mlua::prelude::*;
use serde::{Deserialize, Serialize};

fn expect_table<'lua>(value: LuaValue<'lua>, to: &'static str) -> LuaResult<LuaTable<'lua>> {
    match value {
        LuaValue::Table(table) => Ok(table),
        other => Err(LuaError::FromLuaConversionError {
            from: other.type_name(),
            to,
            message: Some("expected table".into()),
        }),
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceFileParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl<'lua> FromLua<'lua> for IReplaceFileParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceFileParams")?;
        Ok(Self {
            filepath: table.get("filepath")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceFileByMatchesParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

impl<'lua> FromLua<'lua> for IReplaceFileByMatchesParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceFileByMatchesParams")?;
        Ok(Self {
            filepath: table.get("filepath")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
            match_offsets: table.get("match_offsets")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceFileByMatchesAdvanceParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
    pub remain_offsets: Vec<usize>,
}

impl<'lua> FromLua<'lua> for IReplaceFileByMatchesAdvanceParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceFileByMatchesAdvanceParams")?;
        Ok(Self {
            filepath: table.get("filepath")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
            match_offsets: table.get("match_offsets")?,
            remain_offsets: table.get("remain_offsets")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceFilePreviewParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl<'lua> FromLua<'lua> for IReplaceFilePreviewParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceFilePreviewParams")?;
        Ok(Self {
            filepath: table.get("filepath")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            keep_search_pieces: table.get("keep_search_pieces")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceFilePreviewByMatchesAdvanceParams {
    pub filepath: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

impl<'lua> FromLua<'lua> for IReplaceFilePreviewByMatchesAdvanceParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(
            value,
            "rstd.replace.IReplaceFilePreviewByMatchesAdvanceParams",
        )?;
        Ok(Self {
            filepath: table.get("filepath")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            keep_search_pieces: table.get("keep_search_pieces")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
            match_offsets: table.get("match_offsets")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceTextPreviewParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl<'lua> FromLua<'lua> for IReplaceTextPreviewParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceTextPreviewParams")?;
        Ok(Self {
            text: table.get("text")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            keep_search_pieces: table.get("keep_search_pieces")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceTextPreviewByMatchesParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

impl<'lua> FromLua<'lua> for IReplaceTextPreviewByMatchesParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceTextPreviewByMatchesParams")?;
        Ok(Self {
            text: table.get("text")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            keep_search_pieces: table.get("keep_search_pieces")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
            match_offsets: table.get("match_offsets")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceTextPreviewAdvanceParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl<'lua> FromLua<'lua> for IReplaceTextPreviewAdvanceParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(value, "rstd.replace.IReplaceTextPreviewAdvanceParams")?;
        Ok(Self {
            text: table.get("text")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            keep_search_pieces: table.get("keep_search_pieces")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceTextPreviewByMatchesAdvanceParams {
    pub text: String,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub keep_search_pieces: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub match_offsets: Vec<usize>,
}

impl<'lua> FromLua<'lua> for IReplaceTextPreviewByMatchesAdvanceParams {
    fn from_lua(value: LuaValue<'lua>, _lua: &'lua Lua) -> LuaResult<Self> {
        let table = expect_table(
            value,
            "rstd.replace.IReplaceTextPreviewByMatchesAdvanceParams",
        )?;
        Ok(Self {
            text: table.get("text")?,
            search_pattern: table.get("search_pattern")?,
            replace_pattern: table.get("replace_pattern")?,
            keep_search_pieces: table.get("keep_search_pieces")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
            match_offsets: table.get("match_offsets")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplaceFileResult {
    pub locations: Vec<IMatchLocation>,
}

impl<'lua> IntoLua<'lua> for IReplaceFileResult {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("locations", self.locations)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IReplacePreviewResult {
    pub text: String,
    pub matches: Vec<ISearchInLinesMatchPoint>,
}

impl<'lua> IntoLua<'lua> for IReplacePreviewResult {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("text", self.text)?;
        table.set("matches", self.matches)?;
        Ok(LuaValue::Table(table))
    }
}
