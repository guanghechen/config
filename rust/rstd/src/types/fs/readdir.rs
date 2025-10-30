use mlua::{IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "lowercase")]
pub enum IFsFileType {
    Directory,
    File,
}

impl IFsFileType {
    const DIRECTORY_ORDINAL: u32 = 1;
    const FILE_ORDINAL: u32 = 2;

    pub fn ordinal(&self) -> u32 {
        match self {
            Self::Directory => Self::DIRECTORY_ORDINAL,
            Self::File => Self::FILE_ORDINAL,
        }
    }

    fn as_str(&self) -> &'static str {
        match self {
            Self::Directory => "directory",
            Self::File => "file",
        }
    }
}

impl<'lua> IntoLua<'lua> for IFsFileType {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        Ok(LuaValue::String(lua.create_string(self.as_str())?))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsFileItemWithStatus {
    #[serde(rename = "type")]
    pub filetype: IFsFileType,
    #[serde(rename = "name")]
    pub filename: String,
    #[serde(rename = "perm")]
    pub permission: String,
    #[serde(rename = "size")]
    pub filesize: String,
    pub owner: String,
    pub group: String,
    #[serde(rename = "date")]
    pub modify_time: String,
}

impl<'lua> IntoLua<'lua> for IFsFileItemWithStatus {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("type", self.filetype)?;
        table.set("name", self.filename)?;
        table.set("perm", self.permission)?;
        table.set("size", self.filesize)?;
        table.set("owner", self.owner)?;
        table.set("group", self.group)?;
        table.set("date", self.modify_time)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsReaddirResult {
    pub itself: IFsFileItemWithStatus,
    pub items: Vec<IFsFileItemWithStatus>,
}

impl<'lua> IntoLua<'lua> for IFsReaddirResult {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("itself", self.itself)?;
        table.set("items", lua.create_sequence_from(self.items)?)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct IFsReaddirError {
    pub error: String,
}

impl<'lua> IntoLua<'lua> for IFsReaddirError {
    fn into_lua(self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let table = lua.create_table()?;
        table.set("error", self.error)?;
        Ok(LuaValue::Table(table))
    }
}
