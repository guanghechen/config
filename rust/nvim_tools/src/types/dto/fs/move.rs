use nvim_oxi::conversion::Error as ConversionError;
use nvim_oxi::conversion::FromObject;
use nvim_oxi::conversion::ToObject;
use nvim_oxi::lua;
use nvim_oxi::lua::Poppable;
use nvim_oxi::lua::Pushable;
use nvim_oxi::serde::Deserializer;
use nvim_oxi::serde::Serializer;
use nvim_oxi::Object;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileMoveParams {
    pub old_path: String,
    pub new_path: String,
    pub force: bool,
}

impl FromObject for FileMoveParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for FileMoveParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl Poppable for FileMoveParams {
    unsafe fn pop(
        lstate: *mut nvim_oxi::lua::ffi::lua_State,
    ) -> Result<Self, nvim_oxi::lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(nvim_oxi::lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl Pushable for FileMoveParams {
    unsafe fn push(
        self,
        lstate: *mut nvim_oxi::lua::ffi::lua_State,
    ) -> Result<std::ffi::c_int, nvim_oxi::lua::Error> {
        unsafe {
            self.to_object()
                .map_err(nvim_oxi::lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileMoveSucceedResult {
    pub ok: bool,
}

impl FromObject for FileMoveSucceedResult {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for FileMoveSucceedResult {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for FileMoveSucceedResult {
    unsafe fn pop(lstate: *mut lua::ffi::lua_State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for FileMoveSucceedResult {
    unsafe fn push(self, lstate: *mut lua::ffi::lua_State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileMoveFailedResult {
    pub error: String,
}

impl FromObject for FileMoveFailedResult {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for FileMoveFailedResult {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for FileMoveFailedResult {
    unsafe fn pop(lstate: *mut lua::ffi::lua_State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for FileMoveFailedResult {
    unsafe fn push(self, lstate: *mut lua::ffi::lua_State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}
