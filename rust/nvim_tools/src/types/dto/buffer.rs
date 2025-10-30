use crate::types::dto::LineMatch;
use nvim_oxi::Object;
use nvim_oxi::conversion::Error as ConversionError;
use nvim_oxi::conversion::{FromObject, ToObject};
use nvim_oxi::lua;
use nvim_oxi::serde::{Deserializer, Serializer};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceCurrentMatchInBufferParams {
    pub bufnr: i32,
    pub current_match_index: usize,
    pub matches: Vec<LineMatch>,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl FromObject for ReplaceCurrentMatchInBufferParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ReplaceCurrentMatchInBufferParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ReplaceCurrentMatchInBufferParams {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        let obj = unsafe { Object::pop(lstate)? };
        Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl lua::Pushable for ReplaceCurrentMatchInBufferParams {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceCurrentMatchInBufferResult {
    pub success: bool,
}

impl FromObject for ReplaceCurrentMatchInBufferResult {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ReplaceCurrentMatchInBufferResult {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ReplaceCurrentMatchInBufferResult {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        let obj = unsafe { Object::pop(lstate)? };
        Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl lua::Pushable for ReplaceCurrentMatchInBufferResult {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceAllMatchesInBufferParams {
    pub bufnr: i32,
    pub matches: Vec<LineMatch>,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
}

impl FromObject for ReplaceAllMatchesInBufferParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ReplaceAllMatchesInBufferParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ReplaceAllMatchesInBufferParams {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        let obj = unsafe { Object::pop(lstate)? };
        Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl lua::Pushable for ReplaceAllMatchesInBufferParams {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceAllMatchesInBufferResult {
    pub success: bool,
    pub replaced_count: usize,
}

impl FromObject for ReplaceAllMatchesInBufferResult {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ReplaceAllMatchesInBufferResult {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ReplaceAllMatchesInBufferResult {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        let obj = unsafe { Object::pop(lstate)? };
        Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
    }
}

impl lua::Pushable for ReplaceAllMatchesInBufferResult {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}
