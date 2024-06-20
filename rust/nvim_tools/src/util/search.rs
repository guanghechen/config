use crate::types::ripgrep_result;
use crate::util::string::parse_comma_list;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, process::Command, time::SystemTime};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchMatchedInlineItem {
    pub front: usize, // related to the parent.lines
    pub tail: usize,  // related to the parent.lines
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchMatchedLineItem {
    pub lines: String,
    pub lnum: usize,
    pub matches: Vec<SearchMatchedInlineItem>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchMatchedFileItem {
    pub matches: Vec<SearchMatchedLineItem>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SearchSucceedResult {
    pub items: HashMap<String, SearchMatchedFileItem>,
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
) -> Result<(SearchSucceedResult, String), SearchFailedResult> {
    let flag_case_sensitive: bool = options.flag_case_sensitive;
    let flag_regex: bool = options.flag_regex;
    let search_pattern: &String = &options.search_pattern;
    let search_paths: Vec<String> = parse_comma_list(&options.search_paths);
    let include_patterns: Vec<String> = parse_comma_list(&options.include_patterns);
    let exclude_patterns: Vec<String> = parse_comma_list(&options.exclude_patterns);

    let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();
    let elapsed_time: String;

    let output = {
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
            .args(&search_paths)
            // -
        ;

        if flag_case_sensitive {
            cmd.arg("--case-sensitive");
        } else {
            cmd.arg("--ignore-case");
        }

        if flag_regex {
            cmd.args(["--regexp", search_pattern]);
        } else {
            cmd.args(["--fixed-strings", search_pattern]);
        }

        for pattern in include_patterns {
            cmd.arg("--glob").arg(pattern);
        }

        for pattern in exclude_patterns {
            cmd.arg("--glob").arg(pattern);
        }

        // print the executing command
        println!("\n{:?}", cmd);

        let start_time = SystemTime::now();

        // return the output of the cmd
        let output = cmd.output().expect("failed to execute ripgrep");

        let end_time = SystemTime::now();
        elapsed_time = end_time
            .duration_since(start_time)
            .unwrap()
            .as_secs_f32()
            .to_string();

        output
    };

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let parts = line_separator_regex
            .split(&stdout)
            .filter(|&x| !x.is_empty());

        let mut result_elapsed_time: String = "0s".to_string();
        let mut file_items_map: HashMap<String, SearchMatchedFileItem> = HashMap::new();
        for part in parts {
            if let Ok(event) = serde_json::from_str::<ripgrep_result::ResultItem>(part) {
                match event.data {
                    ripgrep_result::ResultItemData::Begin { .. } => {}
                    ripgrep_result::ResultItemData::Match {
                        path,
                        lines,
                        line_number,
                        submatches,
                        ..
                    } => {
                        let mut inline_matches: Vec<SearchMatchedInlineItem> = vec![];
                        for submatch in submatches {
                            let item: SearchMatchedInlineItem = SearchMatchedInlineItem {
                                front: submatch.start,
                                tail: submatch.end,
                            };
                            inline_matches.push(item);
                        }
                        let line_matches: SearchMatchedLineItem = SearchMatchedLineItem {
                            lines: lines.text,
                            lnum: line_number,
                            matches: inline_matches,
                        };
                        let filepath: String = path.text.clone();
                        let file_item: &mut SearchMatchedFileItem = file_items_map
                            .entry(filepath.clone())
                            .or_insert(SearchMatchedFileItem { matches: vec![] });
                        file_item.matches.push(line_matches);
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
            items: file_items_map,
        };
        Ok((result, stdout.to_string()))
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok((
                SearchSucceedResult {
                    elapsed_time: format!("{}s", elapsed_time),
                    items: HashMap::new(),
                },
                "".to_string(),
            ))
        } else {
            Err(SearchFailedResult {
                elapsed_time: format!("{}s", elapsed_time),
                error: stderr.to_string(),
            })
        }
    }
}

