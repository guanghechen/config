use nvim_oxi::conversion::Error as ConversionError;
use nvim_oxi::conversion::FromObject;
use nvim_oxi::conversion::ToObject;
use nvim_oxi::serde::Deserializer;
use nvim_oxi::serde::Serializer;
use nvim_oxi::lua;
use nvim_oxi::Object;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ShowReplacePreviewInBufferParams {
    pub bufnr: i32,
    pub search_pattern: String,
    pub replace_pattern: String,
    pub flag_fuzzy: bool,
    pub flag_regex: bool,
    pub flag_case_sensitive: bool,
    pub namespace_id: Option<i32>,
    pub highlight_group_search: Option<String>,
    pub highlight_group_replace: Option<String>,
}

impl FromObject for ShowReplacePreviewInBufferParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ShowReplacePreviewInBufferParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ShowReplacePreviewInBufferParams {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for ShowReplacePreviewInBufferParams {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ShowReplacePreviewInBufferResult {
    pub bufnr: i32,
    pub error: Option<String>,
    pub preview_applied: bool,
    pub matches_count: usize,
    pub search_matches: Vec<crate::types::dto::LineMatch>,
    pub replacement_lines: Vec<String>,
    pub replacement_matches: Vec<crate::types::dto::ReplacementPoint>,
}

impl FromObject for ShowReplacePreviewInBufferResult {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for ShowReplacePreviewInBufferResult {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for ShowReplacePreviewInBufferResult {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for ShowReplacePreviewInBufferResult {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}