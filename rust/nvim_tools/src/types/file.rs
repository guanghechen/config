use serde::{Deserialize, Serialize};

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
