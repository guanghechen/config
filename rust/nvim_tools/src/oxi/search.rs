use crate::types::dto::CmdResult;
use crate::types::dto::LineMatch;
use crate::types::dto::SearchInFilesParams;
use crate::types::dto::search::search_in_files::SearchInFilesSucceedResult;
use crate::util;
use nvim_oxi::api::Buffer;

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

pub fn search_in_buffer(
    (pattern, bufnr, flag_fuzzy, flag_regex): (String, i32, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    let buffer = Buffer::from(bufnr);

    if !buffer.is_valid() {
        return Err(format!("Invalid buffer number: {}", bufnr));
    }

    let lines_result = buffer.get_lines(.., false);

    match lines_result {
        Ok(lines_iter) => {
            let lines: Vec<String> = lines_iter
                .map(|s| s.to_string())
                .collect();
            util::search::search_in_lines(&pattern, &lines, flag_fuzzy, flag_regex)
        },
        Err(err) => Err(format!("Failed to read buffer {}: {}", bufnr, err)),
    }
}
