use crate::types::dto::CmdResult;
use crate::types::dto::LineMatch;
use crate::types::dto::SearchInFilesParams;
use crate::types::dto::search::search_in_files::SearchInFilesSucceedResult;
use crate::util;

pub fn search_in_lines(
    (pattern, lines, flag_fuzzy, flag_regex): (String, Vec<String>, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    util::search::search_in_lines(&pattern, &lines, flag_fuzzy, flag_regex)
}

pub fn search_in_text(
    (pattern, text, flag_fuzzy, flag_regex): (String, String, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    util::search::search_in_text(&pattern, &text, flag_fuzzy, flag_regex)
}

pub fn search_in_files(
    params: SearchInFilesParams,
) -> CmdResult<SearchInFilesSucceedResult> {
    let options = SearchInFilesParams {
        cwd: params.cwd,
        max_matches: params.max_matches,
        flag_case_sensitive: params.flag_case_sensitive,
        flag_gitignore: params.flag_gitignore,
        flag_regex: params.flag_regex,
        max_filesize: params.max_filesize,
        search_pattern: params.search_pattern,
        search_paths: params.search_paths,
        include_patterns: params.include_patterns,
        exclude_patterns: params.exclude_patterns,
        specified_filepath: params.specified_filepath,
    };

    let cmd_result: CmdResult<SearchInFilesSucceedResult> = {
        let result = util::search::search_in_files(&options);
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
    };
    cmd_result
}
