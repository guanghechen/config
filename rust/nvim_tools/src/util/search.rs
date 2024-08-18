use super::string::parse_comma_list;
use crate::types::ripgrep_result;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, process::Command, time::SystemTime};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MatchPoint {
    #[serde(rename = "l")]
    pub start: usize, // related to the parent.lines
    #[serde(rename = "r")]
    pub end: usize, // related to the parent.lines
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchBlockMatch {
    pub lnum: usize,  // start line number
    pub text: String, // block match lines.
    pub matches: Vec<MatchPoint>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchFileMatch {
    pub matches: Vec<SearchBlockMatch>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchSucceedResult {
    #[serde(skip_serializing)]
    pub cmd: String,
    #[serde(skip_serializing)]
    pub stdout: String,

    pub items: HashMap<String, SearchFileMatch>,
    pub elapsed_time: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchFailedResult {
    #[serde(skip_serializing)]
    pub cmd: String,

    pub elapsed_time: String,
    pub error: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchOptions {
    pub cwd: Option<String>,
    pub max_matches: Option<i32>,
    pub flag_case_sensitive: bool,
    pub flag_gitignore: bool,
    pub flag_regex: bool,
    pub max_filesize: Option<String>,
    pub search_pattern: String,
    pub search_paths: String,
    pub include_patterns: String,
    pub exclude_patterns: String,
    pub specified_filepath: Option<String>,
}

pub fn search(options: &SearchOptions) -> Result<SearchSucceedResult, SearchFailedResult> {
    if options.search_pattern.is_empty() {
        return Ok(SearchSucceedResult {
            stdout: "".to_string(),
            cmd: "".to_string(),
            elapsed_time: "0s".to_string(),
            items: HashMap::new(),
        });
    }
    let max_matches: u32 = match options.max_matches {
        Some(value) => {
            if value < 0 {
                u32::MAX
            } else {
                value as u32
            }
        }
        None => u32::MAX,
    };
    let flag_case_sensitive: bool = options.flag_case_sensitive;
    let flag_gitignore: bool = options.flag_gitignore;
    let flag_regex: bool = options.flag_regex;
    let search_pattern: &String = &options.search_pattern;
    let search_paths: Vec<String> = parse_comma_list(&options.search_paths);
    let include_patterns: Vec<String> = parse_comma_list(&options.include_patterns);
    let exclude_patterns: Vec<String> = parse_comma_list(&options.exclude_patterns);

    let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();
    let elapsed_time: String;

    let (cmd, output) = {
        let mut cmd = Command::new("rg");
        if let Some(cwd) = &options.cwd {
            cmd.current_dir(cwd);
        };

        cmd
            .arg("--multiline")
            .arg("--hidden")
            .arg("--color=never")
            .arg("--line-number")
            .arg("--column")
            .arg("--no-heading")
            .arg("--no-filename")
            .arg("--json")
            // -
        ;

        if !flag_gitignore {
            cmd.arg("--no-ignore-vcs");
        }

        if let Some(max_filesize) = &options.max_filesize {
            if !max_filesize.is_empty() {
                cmd.args(["--max-filesize", max_filesize]);
            }
        }

        if flag_case_sensitive {
            cmd.arg("--case-sensitive");
        } else {
            cmd.arg("--ignore-case");
        }

        for pattern in include_patterns {
            cmd.arg("--glob").arg(pattern);
        }

        for pattern in exclude_patterns {
            cmd.arg("--glob").arg(format!("!{}", pattern));
        }

        if flag_regex {
            cmd.args(["--regexp", search_pattern]);
        } else {
            cmd.args(["--fixed-strings", search_pattern]);
        }

        let mut search_in_single_file: bool = false;
        if let Some(specified_filepath) = &options.specified_filepath {
            if !specified_filepath.is_empty() {
                search_in_single_file = true;
                cmd.arg(specified_filepath);
            }
        }

        if !search_in_single_file {
            cmd.args(&search_paths);
        }

        let start_time = SystemTime::now();

        // return the output of the cmd
        let output = cmd.output().expect("failed to execute ripgrep");

        let end_time = SystemTime::now();
        elapsed_time = end_time
            .duration_since(start_time)
            .unwrap()
            .as_secs_f32()
            .to_string();

        (format!("{:?}", cmd), output)
    };

    if output.status.success() {
        let mut matches_count: u32 = 0;
        let mut result_elapsed_time: String = "0s".to_string();
        let mut file_matches: HashMap<String, SearchFileMatch> = HashMap::new();

        let stdout = String::from_utf8_lossy(&output.stdout);
        let parts = line_separator_regex
            .split(&stdout)
            .filter(|&x| !x.is_empty());
        for part in parts {
            if matches_count == max_matches {
                break;
            }

            if let Ok(event) = serde_json::from_str::<ripgrep_result::ResultItem>(part) {
                match event.data {
                    ripgrep_result::ResultItemData::Begin { .. } => {}
                    ripgrep_result::ResultItemData::Match {
                        path,
                        lines: ripgrep_result::Lines { text, .. },
                        line_number: lnum,
                        submatches,
                        ..
                    } => {
                        let file_item: &mut SearchFileMatch = file_matches
                            .entry(path.text.to_string())
                            .or_insert(SearchFileMatch { matches: vec![] });
                        if file_item.matches.is_empty() {
                            matches_count += 1;
                        }

                        let mut matches: Vec<MatchPoint> = vec![];
                        for submatch in submatches.iter() {
                            if matches_count == max_matches {
                                break;
                            }
                            matches_count += 1;
                            matches.push(MatchPoint {
                                start: submatch.start,
                                end: submatch.end,
                            });
                        }
                        file_item.matches.push(SearchBlockMatch {
                            lnum,
                            text,
                            matches,
                        });
                    }
                    ripgrep_result::ResultItemData::End { .. } => {}
                    ripgrep_result::ResultItemData::Summary { elapsed_total, .. } => {
                        result_elapsed_time = elapsed_total.human;
                    }
                }
            }
        }

        let result: SearchSucceedResult = SearchSucceedResult {
            cmd,
            stdout: stdout.to_string(),
            elapsed_time: result_elapsed_time,
            items: file_matches,
        };
        Ok(result)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(SearchSucceedResult {
                cmd,
                stdout: "".to_string(),
                elapsed_time: format!("{}s", elapsed_time),
                items: HashMap::new(),
            })
        } else {
            Err(SearchFailedResult {
                cmd,
                elapsed_time: format!("{}s", elapsed_time),
                error: stderr.to_string(),
            })
        }
    }
}
