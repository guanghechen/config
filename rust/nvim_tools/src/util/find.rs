use super::string::parse_comma_list;
use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FindSucceedResult {
    #[serde(skip_serializing)]
    pub stdout: String,
    #[serde(skip_serializing)]
    pub cmd: String,

    pub filepaths: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FindFailedResult {
    #[serde(skip_serializing)]
    pub cmd: String,

    pub error: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FindOptions {
    pub cwd: Option<String>,
    pub case_sensitive: bool,
    pub use_regex: bool,
    pub search_pattern: String,
    pub search_paths: String,
    pub exclude_patterns: String,
}

pub fn find(options: &FindOptions) -> Result<FindSucceedResult, FindFailedResult> {
    let case_sensitive: bool = options.case_sensitive;
    let use_regex: bool = options.use_regex;
    let search_pattern: &String = &options.search_pattern;
    let search_paths: Vec<String> = parse_comma_list(&options.search_paths);
    let exclude_patterns: Vec<String> = parse_comma_list(&options.exclude_patterns);

    let (cmd, output) = {
        let mut cmd = Command::new("fd");
        if let Some(cwd) = &options.cwd {
            cmd
                //
                .current_dir(cwd)
                .args(["--base-directory", cwd]);
        };

        cmd
            //
            .arg("--color=never")
            .arg("--hidden")
            .arg("--type=file")
            // -
        ;

        if case_sensitive {
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
            if use_regex {
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
        Ok(FindSucceedResult {
            cmd,
            stdout: stdout.to_string(),
            filepaths,
        })
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(FindSucceedResult {
                cmd,
                stdout: "".to_string(),
                filepaths: vec![],
            })
        } else {
            Err(FindFailedResult {
                cmd,
                error: stderr.to_string(),
            })
        }
    }
}
