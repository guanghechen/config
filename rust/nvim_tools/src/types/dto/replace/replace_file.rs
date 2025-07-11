use nvim_oxi::conversion::{Error as ConversionError, FromObject, ToObject};
use nvim_oxi::serde::{Deserializer, Serializer};
use nvim_oxi::{lua, Object};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileParams {
    pub filepath: String,
    pub flag_case_sensitive: bool,
    pub flag_regex: bool,
    pub replace_pattern: String,
    pub search_pattern: String,
}

impl FromObject for ReplaceFileParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ReplaceFileParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ReplaceFileParams {
    unsafe fn pop(lstate: *mut lua::ffi::lua_State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for ReplaceFileParams {
    unsafe fn push(self, lstate: *mut lua::ffi::lua_State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}
