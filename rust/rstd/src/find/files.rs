use crate::string;
use crate::types::{IFindFilesFailedResult, IFindFilesOptions, IFindFilesSucceedResult};
use std::path::PathBuf;
use std::process::Command;

pub fn find_files(
    options: &IFindFilesOptions,
) -> Result<IFindFilesSucceedResult, IFindFilesFailedResult> {
    let workspace: &str = &options.workspace;
    let cwd: &str = &options.cwd;
    let flag_case_sensitive: bool = options.flag_case_sensitive;
    let flag_gitignore: bool = options.flag_gitignore;
    let flag_regex: bool = options.flag_regex;
    let search_pattern: &str = &options.search_pattern;
    let search_paths: Vec<String> = string::parse_comma_list(&options.search_paths);
    let exclude_patterns: Vec<String> = string::parse_comma_list(&options.exclude_patterns);

    let (cmd, output) = {
        let mut cmd = Command::new("fd");
        cmd.current_dir(cwd)
            .args(["--base-directory", cwd])
            .arg("--color=never")
            .arg("--hidden")
            .arg("--type=file");

        if flag_gitignore {
            let mut gitignore_path = PathBuf::from(workspace);
            gitignore_path.push(".gitignore");
            if gitignore_path.exists() {
                cmd.args(["--ignore-file", &gitignore_path.to_string_lossy()]);
            }
        } else {
            cmd.arg("--no-ignore-vcs");
        }

        if flag_case_sensitive {
            cmd.arg("--case-sensitive");
        } else {
            cmd.arg("--ignore-case");
        }

        for search_path in &search_paths {
            cmd.args(["--search-path", search_path]);
        }

        for pattern in exclude_patterns {
            cmd.args(["--exclude", &pattern]);
        }

        if !search_pattern.is_empty() {
            if flag_regex {
                cmd.args(["--regex", search_pattern]);
            } else {
                cmd.args(["--fixed-strings", search_pattern]);
            }
        }

        let output = cmd.output().expect("failed to execute fd");
        (format!("{:?}", cmd), output)
    };

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);

        #[cfg(not(windows))]
        let filepaths: Vec<String> = stdout
            .lines()
            .map(|x| x.to_owned())
            .filter(|x| !x.is_empty())
            .collect();

        #[cfg(windows)]
        let filepaths: Vec<String> = stdout
            .lines()
            .map(|x| x.replace('\\', "/"))
            .filter(|x| !x.is_empty())
            .collect();

        Ok(IFindFilesSucceedResult {
            cmd,
            stdout: stdout.to_string(),
            filepaths,
        })
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(IFindFilesSucceedResult {
                cmd,
                stdout: "".to_string(),
                filepaths: vec![],
            })
        } else {
            Err(IFindFilesFailedResult {
                cmd,
                error: stderr.to_string(),
            })
        }
    }
}
