use super::r#match::{find_matches_per_line, LineMatch, MatchPoint};
use super::string::parse_comma_list;
use crate::types::ripgrep_result;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, process::Command, time::SystemTime};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchBlockMatch {
    pub text: String, // matched content lines
    pub lnum: usize,  // start line number
    pub matches: Vec<MatchPoint>,
    pub lines: Vec<LineMatch>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchFileMatch {
    pub matches: Vec<SearchBlockMatch>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchSucceedResult {
    pub items: HashMap<String, SearchFileMatch>,
    pub elapsed_time: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchFailedResult {
    pub elapsed_time: String,
    pub error: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchOptions {
    pub cwd: Option<String>,
    pub flag_case_sensitive: bool,
    pub flag_regex: bool,
    pub search_pattern: String,
    pub search_paths: String,
    pub include_patterns: String,
    pub exclude_patterns: String,
}

pub fn search(
    options: &SearchOptions,
) -> Result<(SearchSucceedResult, String, String), (SearchFailedResult, String)> {
    let flag_case_sensitive: bool = options.flag_case_sensitive;
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

        let start_time = SystemTime::now();

        // return the output of the cmd
        let output = cmd
            .args(&search_paths)
            .output()
            .expect("failed to execute ripgrep");

        let end_time = SystemTime::now();
        elapsed_time = end_time
            .duration_since(start_time)
            .unwrap()
            .as_secs_f32()
            .to_string();

        (format!("{:?}", cmd), output)
    };

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let parts = line_separator_regex
            .split(&stdout)
            .filter(|&x| !x.is_empty());

        let mut result_elapsed_time: String = "0s".to_string();
        let mut file_matches: HashMap<String, SearchFileMatch> = HashMap::new();
        for part in parts {
            if let Ok(event) = serde_json::from_str::<ripgrep_result::ResultItem>(part) {
                match event.data {
                    ripgrep_result::ResultItemData::Begin { .. } => {}
                    ripgrep_result::ResultItemData::Match {
                        path,
                        lines: matched_lines,
                        line_number,
                        submatches,
                        ..
                    } => {
                        let text: String = matched_lines.text;
                        let mut matches: Vec<MatchPoint> = vec![];
                        for submatch in submatches {
                            let item: MatchPoint = MatchPoint {
                                start: submatch.start,
                                end: submatch.end,
                            };
                            matches.push(item);
                        }

                        let lines: Vec<LineMatch> = find_matches_per_line(&text, &matches);
                        let block_match: SearchBlockMatch = SearchBlockMatch {
                            text,
                            lnum: line_number,
                            matches,
                            lines,
                        };
                        let file_item: &mut SearchFileMatch = file_matches
                            .entry(path.text.clone())
                            .or_insert(SearchFileMatch { matches: vec![] });
                        file_item.matches.push(block_match);
                    }
                    ripgrep_result::ResultItemData::End { .. } => {}
                    ripgrep_result::ResultItemData::Summary { elapsed_total, .. } => {
                        result_elapsed_time = elapsed_total.human;
                    }
                }
            }
        }

        let result: SearchSucceedResult = SearchSucceedResult {
            elapsed_time: result_elapsed_time,
            items: file_matches,
        };
        Ok((result, stdout.to_string(), cmd))
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok((
                SearchSucceedResult {
                    elapsed_time: format!("{}s", elapsed_time),
                    items: HashMap::new(),
                },
                "".to_string(),
                cmd,
            ))
        } else {
            Err((
                SearchFailedResult {
                    elapsed_time: format!("{}s", elapsed_time),
                    error: stderr.to_string(),
                },
                cmd,
            ))
        }
    }
}
