use crate::types::FunResult;
use crate::util;

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
