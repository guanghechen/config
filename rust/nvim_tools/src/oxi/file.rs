use crate::types::FunResult;
use crate::util;
use serde::Deserialize;

#[derive(Deserialize)]
struct RenameParams {
    old_path: String,
    new_path: String,
    force: bool,
}

pub fn get_filesize(filepath: String) -> String {
    let raw_result = util::file::get_filesize(filepath);
    let result: FunResult<String> = match raw_result {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(data) => FunResult {
            error: Some(data),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}

pub fn readdir(dirpath: String) -> String {
    let raw_result = util::file::readdir(dirpath);
    let result: FunResult<util::file::ReaddirSucceedResult> = match raw_result {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(data) => FunResult {
            error: Some(data.error),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}

pub fn rename_path(stringified_params: String) -> String {
    let params: RenameParams = match serde_json::from_str(&stringified_params) {
        Ok(p) => p,
        Err(e) => {
            let result: FunResult<util::file::RenameSucceedResult> = FunResult {
                error: Some(format!("Failed to parse JSON parameters: {}", e)),
                data: None,
            };
            return serde_json::to_string(&result).unwrap();
        }
    };

    let raw_result = util::file::rename_path(params.old_path, params.new_path, params.force);
    let result: FunResult<util::file::RenameSucceedResult> = match raw_result {
        Ok(data) => FunResult {
            error: None,
            data: Some(data),
        },
        Err(data) => FunResult {
            error: Some(data.error),
            data: None,
        },
    };
    serde_json::to_string(&result).unwrap()
}
