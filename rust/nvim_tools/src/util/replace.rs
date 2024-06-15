use crate::types::ripgrep_result;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, process::Command, time::SystemTime};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceInlineMatchedItem {
    pub start: usize,    // related to the parent.lines
    pub end: usize,      // related to the parent.lines
    pub replace: String, // replaced string
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceLineMatchedItem {
    pub lines: String,
    pub line_start: usize,
    pub matches: Vec<ReplaceInlineMatchedItem>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceFileMatchedItem {
    pub filepath: String,
    pub matches: Vec<ReplaceLineMatchedItem>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceResult {
    pub items: Vec<ReplaceFileMatchedItem>,
    pub elapsed_time: String,
    #[serde(skip_serializing, skip_deserializing)]
    pub stdout: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ReplaceOptions {
    pub cwd: Option<String>,
    pub replace_pattern: String,
    pub search_pattern: String,
    pub search_paths: Vec<String>,
    pub include_patterns: Vec<String>,
    pub exclude_patterns: Vec<String>,
}

pub fn replace(options: ReplaceOptions) -> Result<ReplaceResult, String> {
    let replace_pattern: &String = &options.replace_pattern;
    let search_pattern: &String = &options.search_pattern;
    let search_paths: Vec<String> = options
        .search_paths
        .into_iter()
        .map(|s| s.trim().to_string())
        .filter(|x| !x.is_empty())
        .collect();
    let include_patterns: Vec<String> = options
        .include_patterns
        .into_iter()
        .map(|s| s.trim().to_string())
        .filter(|x| !x.is_empty())
        .collect();
    let exclude_patterns: Vec<String> = options
        .exclude_patterns
        .into_iter()
        .map(|s| format!("!{}", s.trim()))
        .filter(|x| x != "!")
        .collect();

    let search_regex = Regex::new(search_pattern).unwrap();
    let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();
    let elapsed_time: String;

    let output = {
        let mut cmd = Command::new("rg");
        if let Some(cwd) = options.cwd {
            cmd.current_dir(cwd);
        };

        cmd
            .arg("--multiline")
            .arg("--hidden")
            .arg("--color=never")
            .arg("--line-number")
            .arg("--no-heading")
            .arg("--no-filename")
            .arg("--json")
            .args(["--replace", replace_pattern])
            .args(["--regexp", search_pattern])
            .args(&search_paths)
            // -
        ;

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
        let mut file_items_map: HashMap<String, ReplaceFileMatchedItem> = HashMap::new();
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
                        let mut inline_matches: Vec<ReplaceInlineMatchedItem> = vec![];
                        for submatch in submatches {
                            let replace_text = search_regex
                                .replace_all(&submatch.match_text.text, replace_pattern);
                            let item: ReplaceInlineMatchedItem = ReplaceInlineMatchedItem {
                                start: submatch.start,
                                end: submatch.end,
                                replace: replace_text.to_string(),
                            };
                            inline_matches.push(item);
                        }
                        let line_matches: ReplaceLineMatchedItem = ReplaceLineMatchedItem {
                            lines: lines.text,
                            line_start: line_number,
                            matches: inline_matches,
                        };
                        let filepath: String = path.text.clone();
                        let file_item: &mut ReplaceFileMatchedItem = file_items_map
                            .entry(filepath.clone())
                            .or_insert(ReplaceFileMatchedItem {
                                filepath: path.text.clone(),
                                matches: vec![],
                            });
                        file_item.matches.push(line_matches);
                    }
                    ripgrep_result::ResultItemData::End { .. } => {}
                    ripgrep_result::ResultItemData::Summary { elapsed_total, .. } => {
                        result_elapsed_time = elapsed_total.human;
                    }
                }
            }
        }

        let result_items: Vec<ReplaceFileMatchedItem> = file_items_map.values().cloned().collect();
        let result: ReplaceResult = ReplaceResult {
            elapsed_time: result_elapsed_time,
            items: result_items,
            stdout: stdout.to_string(),
        };
        Ok(result)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(ReplaceResult {
                elapsed_time: format!("{}s", elapsed_time),
                items: vec![],
                stdout: "".to_string(),
            })
        } else {
            Err(stderr.to_string())
        }
    }
}
