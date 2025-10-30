use mlua::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ISearchInTextOptions {
    pub pattern: String,
    pub text: String,
    pub flag_fuzzy: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl FromLua<'_> for ISearchInTextOptions {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        let table = match value {
            LuaValue::Table(t) => t,
            _ => {
                return Err(LuaError::FromLuaConversionError {
                    from: value.type_name(),
                    to: "ISearchInTextOptions",
                    message: Some("expected table".to_string()),
                });
            }
        };

        Ok(Self {
            pattern: table.get("pattern")?,
            text: table.get("text")?,
            flag_fuzzy: table.get("flag_fuzzy")?,
            flag_regex: table.get("flag_regex")?,
            flag_case_sensitive: table.get("flag_case_sensitive")?,
        })
    }
}
