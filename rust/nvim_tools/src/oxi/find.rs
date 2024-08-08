use crate::types::CmdResult;
use crate::util;

pub fn find(options_json_str: String) -> String {
    let oxi_result: CmdResult<util::find::FindSucceedResult> =
        if let Ok(options) = serde_json::from_str::<util::find::FindOptions>(&options_json_str) {
            let result = util::find::find(&options);
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

    serde_json::to_string(&oxi_result).unwrap()
}
