use crate::types::r#match::LineMatch;
use crate::types::CmdResult;
use crate::util;

pub fn search_in_lines(
    (pattern, lines, flag_fuzzy, flag_regex): (String, Vec<String>, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    util::searcher::search_in_lines(&pattern, &lines, flag_fuzzy, flag_regex)
}

pub fn search_in_text(
    (pattern, text, flag_fuzzy, flag_regex): (String, String, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    util::searcher::search_in_text(&pattern, &text, flag_fuzzy, flag_regex)
}

pub fn search(options_json_str: String) -> String {
    let cmd_result: CmdResult<util::searcher::ISearchInFilesSucceedResult> = if let Ok(options) =
        serde_json::from_str::<util::searcher::ISearchInFilesParams>(&options_json_str)
    {
        let result = util::searcher::search_in_files(&options);
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
