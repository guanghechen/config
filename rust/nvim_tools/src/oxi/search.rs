use crate::types::CmdResult;
use crate::util;

pub fn search(options_json_str: String) -> String {
    let cmd_result: CmdResult<util::search::SearchFilesSucceedResult> = if let Ok(options) =
        serde_json::from_str::<util::search::SearchFilesOptions>(&options_json_str)
    {
        let result = util::search::search_files(&options);
        match result {
            Ok(data) => CmdResult {
                cmd: data.cmd.to_owned(),
                error: None,
                data: Some(data),
            },
            Err(data) => CmdResult {
                cmd: data.cmd.to_owned(),
                error: Some(data.error),
                data: None,
            },
        }
    } else {
        CmdResult {
            cmd: "null".to_string(),
            error: Some("null".to_string()),
            data: None,
        }
    };
    serde_json::to_string(&cmd_result).unwrap()
}
