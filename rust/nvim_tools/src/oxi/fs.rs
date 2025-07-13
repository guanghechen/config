use crate::types::dto::FileMoveParams;
use crate::types::dto::FileMoveSucceedResult;
use crate::types::dto::ReadAllFilesSucceedResult;
use crate::types::dto::ReaddirSucceedResult;
use crate::util;

pub fn collect_files(
    (dirpath, recursive): (String, bool),
) -> Result<ReadAllFilesSucceedResult, String> {
    let raw_result = util::fs::collect_files(dirpath, recursive);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}

pub fn get_filesize(filepath: String) -> Result<String, String> {
    util::fs::get_filesize(filepath)
}

pub fn readdir(dirpath: String) -> Result<ReaddirSucceedResult, String> {
    let raw_result = util::fs::readdir(dirpath);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}

pub fn rename_path(params: FileMoveParams) -> Result<FileMoveSucceedResult, String> {
    let raw_result = util::fs::move_file(params.old_path, params.new_path, params.force);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}
