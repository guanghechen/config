use crate::util;
use nvim_oxi::conversion::{Error as ConversionError, FromObject, ToObject};
use nvim_oxi::lua::{Poppable, Pushable};
use nvim_oxi::serde::{Deserializer, Serializer};
use nvim_oxi::Object;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RenameParams {
    pub old_path: String,
    pub new_path: String,
    pub force: bool,
}

impl FromObject for RenameParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for RenameParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl Poppable for RenameParams {
    unsafe fn pop(
        lstate: *mut nvim_oxi::lua::ffi::lua_State,
    ) -> Result<Self, nvim_oxi::lua::Error> {
        let obj = Object::pop(lstate)?;
        Self::from_object(obj).map_err(nvim_oxi::lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl Pushable for RenameParams {
    unsafe fn push(
        self,
        lstate: *mut nvim_oxi::lua::ffi::lua_State,
    ) -> Result<std::ffi::c_int, nvim_oxi::lua::Error> {
        self.to_object()
            .map_err(nvim_oxi::lua::Error::push_error_from_err::<Self, _>)?
            .push(lstate)
    }
}

pub fn collect_files(
    (dirpath, recursive): (String, bool),
) -> Result<util::file::ReadAllFilesSucceedResult, String> {
    let raw_result = util::file::collect_files(dirpath, recursive);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}

pub fn get_filesize(filepath: String) -> Result<String, String> {
    util::file::get_filesize(filepath)
}

pub fn readdir(dirpath: String) -> Result<util::file::ReaddirSucceedResult, String> {
    let raw_result = util::file::readdir(dirpath);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}

pub fn rename_path(params: RenameParams) -> Result<util::file::RenameSucceedResult, String> {
    let raw_result = util::file::rename_path(params.old_path, params.new_path, params.force);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}
