use nvim_oxi::conversion::Error as ConversionError;
use nvim_oxi::conversion::FromObject;
use nvim_oxi::conversion::ToObject;
use nvim_oxi::lua::Poppable;
use nvim_oxi::lua::Pushable;
use nvim_oxi::serde::Deserializer;
use nvim_oxi::serde::Serializer;
use nvim_oxi::Object;
use serde::Deserialize;
use serde::Serialize;

use crate::types::dto::MatchPoint;

#[derive(Serialize, Deserialize, Debug)]
pub struct LineMatch {
    pub lnum: usize,
    pub score: u32,
    pub matches: Vec<MatchPoint>,
}

impl FromObject for LineMatch {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for LineMatch {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl Poppable for LineMatch {
    unsafe fn pop(
        lua_state: *mut nvim_oxi::lua::ffi::lua_State,
    ) -> Result<Self, nvim_oxi::lua::Error> {
        unsafe {
            let obj = Object::pop(lua_state)?;
            Self::from_object(obj).map_err(nvim_oxi::lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl Pushable for LineMatch {
    unsafe fn push(
        self,
        lua_state: *mut nvim_oxi::lua::ffi::lua_State,
    ) -> Result<std::os::raw::c_int, nvim_oxi::lua::Error> {
        unsafe {
            let obj = self
                .to_object()
                .map_err(nvim_oxi::lua::Error::push_error_from_err::<Self, _>)?;
            obj.push(lua_state)
        }
    }
}
