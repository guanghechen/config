use mlua::IntoLua;
use mlua::Lua;
use mlua::Result as LuaResult;
use mlua::Value as LuaValue;
use serde::Deserialize;
use serde::Serialize;

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

impl IntoLua for IFsFileType {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
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

impl IntoLua for IFsFileItemWithStatus {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
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

impl IntoLua for IFsReaddirResult {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
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

impl IntoLua for IFsReaddirError {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("error", self.error)?;
        Ok(LuaValue::Table(table))
    }
}
