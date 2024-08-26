use crate::util::string;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FindFilesSucceedResult {
    #[serde(skip_serializing)]
    pub cmd: String,
    #[serde(skip_serializing)]
    pub stdout: String,

    pub filepaths: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FindFilesFailedResult {
    #[serde(skip_serializing)]
    pub cmd: String,

    pub error: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FindFilesOptions {
    pub workspace: String,
    pub cwd: String,
    pub flag_case_sensitive: bool,
    pub flag_gitignore: bool,
    pub flag_regex: bool,
    pub search_pattern: String,
    pub search_paths: String,
    pub exclude_patterns: String,
}

pub fn find_files(
    options: &FindFilesOptions,
) -> Result<FindFilesSucceedResult, FindFilesFailedResult> {
    let workspace: &String = &options.workspace;
    let cwd: &String = &options.cwd;
    let falg_case_sensitive: bool = options.flag_case_sensitive;
    let flag_gitignore: bool = options.flag_gitignore;
    let flag_regex: bool = options.flag_regex;
    let search_pattern: &String = &options.search_pattern;
    let search_paths: Vec<String> = string::parse_comma_list(&options.search_paths);
    let exclude_patterns: Vec<String> = string::parse_comma_list(&options.exclude_patterns);

    let (cmd, output) = {
        let mut cmd = Command::new("fd");
        cmd
            //
            .current_dir(cwd)
            .args(["--base-directory", cwd])
            .arg("--color=never")
            .arg("--hidden")
            .arg("--type=file")
            // -
        ;

        if flag_gitignore {
            let mut gitignore_path = PathBuf::from(workspace);
            gitignore_path.push(".gitignore");
            if gitignore_path.exists() {
                cmd.args(["--ignore-file", &gitignore_path.to_string_lossy()]);
            }
        } else {
            cmd.arg("--no-ignore-vcs");
        }

        if falg_case_sensitive {
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

        if !options.search_pattern.is_empty() {
            if flag_regex {
                cmd.args(["--regex", search_pattern]);
            } else {
                cmd.args(["--fixed-strings", search_pattern]);
            }
        }

        // return the output of the cmd
        let output = cmd.output().expect("failed to execute fd");
        (format!("{:?}", cmd), output)
    };

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let filepaths: Vec<String> = stdout
            .lines()
            .map(|x| x.to_owned())
            .filter(|x| !x.is_empty())
            .collect();
        Ok(FindFilesSucceedResult {
            cmd,
            stdout: stdout.to_string(),
            filepaths,
        })
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(FindFilesSucceedResult {
                cmd,
                stdout: "".to_string(),
                filepaths: vec![],
            })
        } else {
            Err(FindFilesFailedResult {
                cmd,
                error: stderr.to_string(),
            })
        }
    }
}
