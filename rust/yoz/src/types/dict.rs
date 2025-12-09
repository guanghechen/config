use mlua::prelude::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DictMatchMode {
    Prefix,
    Substring,
}

#[derive(Debug, Clone)]
pub struct IDictSearchOptions {
    pub keyword: String,
    pub language: String,
    pub match_mode: DictMatchMode,
    pub include_compounds: bool,
    pub max_items: usize,
}

impl Default for IDictSearchOptions {
    fn default() -> Self {
        Self {
            keyword: String::new(),
            language: "en".to_string(),
            match_mode: DictMatchMode::Prefix,
            include_compounds: false,
            max_items: 20,
        }
    }
}

impl FromLua for IDictSearchOptions {
    fn from_lua(value: LuaValue, _lua: &Lua) -> LuaResult<Self> {
        match value {
            LuaValue::String(string) => Ok(Self {
                keyword: string.to_str()?.to_string(),
                ..Self::default()
            }),
            LuaValue::Table(table) => {
                let keyword = table.get::<Option<String>>("keyword")?.unwrap_or_default();
                let language = table
                    .get::<Option<String>>("language")?
                    .unwrap_or_else(|| "en".to_string());
                let match_mode = match table
                    .get::<Option<String>>("match_mode")?
                    .unwrap_or_else(|| "prefix".to_string())
                    .as_str()
                {
                    "substring" => DictMatchMode::Substring,
                    _ => DictMatchMode::Prefix,
                };
                let include_compounds = table
                    .get::<Option<bool>>("include_compounds")?
                    .unwrap_or(false);
                let max_items = table
                    .get::<Option<u32>>("max_items")?
                    .map(|value| value.max(1) as usize)
                    .unwrap_or(20);

                Ok(Self {
                    keyword,
                    language,
                    match_mode,
                    include_compounds,
                    max_items,
                })
            }
            LuaValue::Nil => Err(LuaError::FromLuaConversionError {
                from: "nil",
                to: "IDictSearchOptions".to_string(),
                message: Some("expected dictionary search options".into()),
            }),
            other => Err(LuaError::FromLuaConversionError {
                from: other.type_name(),
                to: "IDictSearchOptions".to_string(),
                message: Some("expected string or table".into()),
            }),
        }
    }
}
