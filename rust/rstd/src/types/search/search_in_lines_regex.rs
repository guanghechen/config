use mlua::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct ISearchInLinesRegexMatchPoint {
    #[serde(rename = "l")]
    pub start: usize,
    #[serde(rename = "r")]
    pub end: usize,
}

impl IntoLua<'_> for ISearchInLinesRegexMatchPoint {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue<'_>> {
        let table = lua.create_table()?;
        table.set("l", self.start)?;
        table.set("r", self.end)?;
        Ok(LuaValue::Table(table))
    }
}

impl FromLua<'_> for ISearchInLinesRegexMatchPoint {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => return Err(LuaError::FromLuaConversionError {
                from: value.type_name(),
                to: "ISearchInLinesRegexMatchPoint",
                message: Some("expected table".to_string()),
            }),
        };

        Ok(Self {
            start: table.get("l")?,
            end: table.get("r")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInLinesRegexLineMatch {
    pub lnum: usize,
    pub score: u32,
    pub matches: Vec<ISearchInLinesRegexMatchPoint>,
}

impl IntoLua<'_> for ISearchInLinesRegexLineMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue<'_>> {
        let table = lua.create_table()?;
        table.set("lnum", self.lnum)?;
        table.set("score", self.score)?;
        table.set("matches", self.matches)?;
        Ok(LuaValue::Table(table))
    }
}

impl FromLua<'_> for ISearchInLinesRegexLineMatch {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => return Err(LuaError::FromLuaConversionError {
                from: value.type_name(),
                to: "ISearchInLinesRegexLineMatch",
                message: Some("expected table".to_string()),
            }),
        };

        Ok(Self {
            lnum: table.get("lnum")?,
            score: table.get("score")?,
            matches: table.get("matches")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInLinesRegexOptions {
    pub pattern: String,
    pub lines: Vec<String>,
    pub flag_case_sensitive: bool,
}

impl FromLua<'_> for ISearchInLinesRegexOptions {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => return Err(LuaError::FromLuaConversionError {
                from: value.type_name(),
                to: "ISearchInLinesRegexOptions",
                message: Some("expected table".to_string()),
            }),
        };

        Ok(Self {
            pattern: table.get("pattern")?,
            lines: table.get("lines")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}
