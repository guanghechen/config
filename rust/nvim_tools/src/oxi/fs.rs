use crate::types::dto::FsRenameParams;
use crate::util;

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

pub fn rename_path(params: FsRenameParams) -> Result<util::file::RenameSucceedResult, String> {
    let raw_result = util::file::rename_path(params.old_path, params.new_path, params.force);
    match raw_result {
        Ok(data) => Ok(data),
        Err(data) => Err(data.error),
    }
}
