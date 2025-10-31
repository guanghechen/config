use super::search_in_lines::{ISearchInLinesLineMatch, ISearchInLinesMatchPoint};
use mlua::prelude::*;
use serde::{Deserialize, Serialize};

pub type ISearchInLinesRegexMatchPoint = ISearchInLinesMatchPoint;
pub type ISearchInLinesRegexLineMatch = ISearchInLinesLineMatch;

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
            _ => {
                return Err(LuaError::FromLuaConversionError {
                    from: value.type_name(),
                    to: "ISearchInLinesRegexOptions",
                    message: Some("expected table".to_string()),
                });
            }
        };

        Ok(Self {
            pattern: table.get("pattern")?,
            lines: table.get("lines")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}
