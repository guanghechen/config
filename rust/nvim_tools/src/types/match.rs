use serde::{Deserialize, Serialize};
use nvim_oxi::conversion::{Error as ConversionError, FromObject, ToObject};
use nvim_oxi::serde::{Deserializer, Serializer};
use nvim_oxi::lua::{Poppable, Pushable};
use nvim_oxi::Object;

#[derive(Serialize, Deserialize, Debug)]
pub struct LineMatch {
    pub lnum: usize,
    pub score: u32,
    pub matches: Vec<MatchPoint>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct MatchLocation {
    pub offset: usize,
    pub lnum: usize,
    pub col: usize,
    pub line: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct MatchPoint {
    #[serde(rename = "l")]
    pub start: usize, // related to the parent.lines
    #[serde(rename = "r")]
    pub end: usize, // related to the parent.lines
}

impl FromObject for MatchPoint {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for MatchPoint {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
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

impl Poppable for MatchPoint {
    unsafe fn pop(lua_state: *mut nvim_oxi::lua::ffi::lua_State) -> Result<Self, nvim_oxi::lua::Error> {
        let obj = Object::pop(lua_state)?;
        Self::from_object(obj).map_err(nvim_oxi::lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl Pushable for MatchPoint {
    unsafe fn push(self, lua_state: *mut nvim_oxi::lua::ffi::lua_State) -> Result<std::os::raw::c_int, nvim_oxi::lua::Error> {
        let obj = self.to_object().map_err(nvim_oxi::lua::Error::push_error_from_err::<Self, _>)?;
        obj.push(lua_state)
    }
}

impl Poppable for LineMatch {
    unsafe fn pop(lua_state: *mut nvim_oxi::lua::ffi::lua_State) -> Result<Self, nvim_oxi::lua::Error> {
        let obj = Object::pop(lua_state)?;
        Self::from_object(obj).map_err(nvim_oxi::lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl Pushable for LineMatch {
    unsafe fn push(self, lua_state: *mut nvim_oxi::lua::ffi::lua_State) -> Result<std::os::raw::c_int, nvim_oxi::lua::Error> {
        let obj = self.to_object().map_err(nvim_oxi::lua::Error::push_error_from_err::<Self, _>)?;
        obj.push(lua_state)
    }
}
