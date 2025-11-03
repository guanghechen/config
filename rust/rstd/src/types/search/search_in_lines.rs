use mlua::prelude::*;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct ISearchInLinesMatchPoint {
    #[serde(rename = "l")]
    pub start: usize,
    #[serde(rename = "r")]
    pub end: usize,
}

impl IntoLua for ISearchInLinesMatchPoint {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("l", self.start)?;
        table.set("r", self.end)?;
        Ok(LuaValue::Table(table))
    }
}

impl FromLua for ISearchInLinesMatchPoint {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => {
                return Err(LuaError::FromLuaConversionError {
                    from: value.type_name(),
                    to: "ISearchInLinesMatchPoint".into(),
                    message: Some("expected table".to_string()),
                });
            }
        };

        Ok(Self {
            start: table.get("l")?,
            end: table.get("r")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInLinesLineMatch {
    pub lnum: usize,
    pub score: u32,
    pub matches: Vec<ISearchInLinesMatchPoint>,
}

impl IntoLua for ISearchInLinesLineMatch {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("lnum", self.lnum)?;
        table.set("score", self.score)?;
        table.set("matches", self.matches)?;
        Ok(LuaValue::Table(table))
    }
}

impl FromLua for ISearchInLinesLineMatch {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => {
                return Err(LuaError::FromLuaConversionError {
                    from: value.type_name(),
                    to: "ISearchInLinesLineMatch".into(),
                    message: Some("expected table".to_string()),
                });
            }
        };

        Ok(Self {
            lnum: table.get("lnum")?,
            score: table.get("score")?,
            matches: table.get("matches")?,
        })
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInLinesOptions {
    pub pattern: String,
    pub lines: Vec<String>,
    pub flag_fuzzy: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl FromLua for ISearchInLinesOptions {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => {
                return Err(LuaError::FromLuaConversionError {
                    from: value.type_name(),
                    to: "ISearchInLinesOptions".into(),
                    message: Some("expected table".to_string()),
                });
            }
        };

        Ok(Self {
            pattern: table.get("pattern")?,
            lines: table.get("lines")?,
            flag_fuzzy: table.get("flag_fuzzy")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}
