use serde::Deserialize;
use serde::Serialize;
use nvim_oxi::conversion::Error as ConversionError;
use nvim_oxi::conversion::FromObject;
use nvim_oxi::conversion::ToObject;
use nvim_oxi::serde::Deserializer;
use nvim_oxi::serde::Serializer;
use nvim_oxi::lua;
use nvim_oxi::Object;

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "lowercase")]
pub enum FileType {
    Directory,
    File,
}

impl FileType {
    const DIRECTORY_ORDINAL: u32 = 1;
    const FILE_ORDINAL: u32 = 2;

    pub fn ordinal(&self) -> u32 {
        match self {
            FileType::Directory => Self::DIRECTORY_ORDINAL,
            FileType::File => Self::FILE_ORDINAL,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileItemWithStatus {
    #[serde(rename = "type")]
    pub filetype: FileType,
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

impl FromObject for FileItemWithStatus {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for FileItemWithStatus {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for FileItemWithStatus {
    unsafe fn pop(lstate: *mut lua::ffi::State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for FileItemWithStatus {
    unsafe fn push(self, lstate: *mut lua::ffi::State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}
