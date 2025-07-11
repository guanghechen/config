use crate::types::dto::CmdResult;
use crate::types::dto::FindFilesParams;
use crate::util;

pub fn find_files(params: FindFilesParams) -> CmdResult<util::find::FindFilesSucceedResult> {
    let options = util::find::FindFilesOptions {
        workspace: params.workspace,
        cwd: params.cwd,
        flag_case_sensitive: params.flag_case_sensitive,
        flag_gitignore: params.flag_gitignore,
        flag_regex: params.flag_regex,
        search_pattern: params.search_pattern,
        search_paths: params.search_paths,
        exclude_patterns: params.exclude_patterns,
    };

    let cmd_result: CmdResult<util::find::FindFilesSucceedResult> = {
        let result = util::find::find_files(&options);
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
