use crate::types::dto::search::search_in_files::SearchInFilesFailedResult;
use crate::types::dto::search::search_in_files::SearchInFilesSucceedResult;
use crate::types::dto::MatchPoint;
use crate::types::dto::SearchBlockMatch;
use crate::types::dto::SearchFileMatch;
use crate::types::dto::SearchInFilesParams;
use crate::types::third_party::ripgrep;
use crate::util::string;
use regex::Regex;
use std::collections::HashMap;
use std::process::Command;
use std::time::SystemTime;

pub fn search_in_files(
    params: &SearchInFilesParams,
) -> Result<SearchInFilesSucceedResult, SearchInFilesFailedResult> {
    if params.search_pattern.is_empty() {
        return Ok(SearchInFilesSucceedResult {
            stdout: "".to_string(),
            cmd: "".to_string(),
            elapsed_time: "0s".to_string(),
            items: HashMap::new(),
        });
    }
    let max_matches: u32 = match params.max_matches {
        Some(value) => {
            if value < 0 {
                u32::MAX
            } else {
                value as u32
            }
        }
        None => u32::MAX,
    };
    let flag_case_sensitive: bool = params.flag_case_sensitive;
    let flag_gitignore: bool = params.flag_gitignore;
    let flag_regex: bool = params.flag_regex;
    let search_pattern: &str = &params.search_pattern;
    let search_paths: Vec<String> = string::parse_comma_list(&params.search_paths);
    let include_patterns: Vec<String> = string::parse_comma_list(&params.include_patterns);
    let exclude_patterns: Vec<String> = string::parse_comma_list(&params.exclude_patterns);

    let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();
    let elapsed_time: String;

    let (cmd, output) = {
        let mut cmd = Command::new("rg");
        if let Some(cwd) = &params.cwd {
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

        if let Some(max_filesize) = &params.max_filesize {
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
            cmd.args(["--fixed-strings", "--", search_pattern]);
        }

        let mut search_in_single_file: bool = false;
        if let Some(specified_filepath) = &params.specified_filepath {
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
        let mut filematches: HashMap<String, SearchFileMatch> = HashMap::new();

        let stdout = String::from_utf8_lossy(&output.stdout);
        let parts = line_separator_regex
            .split(&stdout)
            .filter(|&x| !x.is_empty());
        for part in parts {
            if matches_count == max_matches {
                break;
            }

            if let Ok(event) = serde_json::from_str::<ripgrep::IRipgrepResult>(part) {
                match event.data {
                    ripgrep::IRipgrepResultData::Begin { .. } => {}
                    ripgrep::IRipgrepResultData::Match {
                        path,
                        lines: ripgrep::IRipgrepResultMatchedLines { text, .. },
                        line_number: lnum,
                        absolute_offset: offset,
                        submatches,
                        ..
                    } => {
                        #[cfg(windows)]
                        let filepath: String = path.text.replace('\\', "/");

                        #[cfg(not(windows))]
                        let filepath: String = path.text.to_string();

                        let filematch: &mut SearchFileMatch = filematches
                            .entry(filepath)
                            .or_insert(SearchFileMatch { matches: vec![] });
                        if filematch.matches.is_empty() {
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
                        filematch.matches.push(SearchBlockMatch {
                            lnum,
                            text,
                            offset,
                            matches,
                        });
                    }
                    ripgrep::IRipgrepResultData::End { .. } => {}
                    ripgrep::IRipgrepResultData::Summary { elapsed_total, .. } => {
                        result_elapsed_time = elapsed_total.human;
                    }
                }
            }
        }

        let result: SearchInFilesSucceedResult = SearchInFilesSucceedResult {
            cmd,
            stdout: stdout.to_string(),
            elapsed_time: result_elapsed_time,
            items: filematches,
        };
        Ok(result)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(SearchInFilesSucceedResult {
                cmd,
                stdout: "".to_string(),
                elapsed_time: format!("{}s", elapsed_time),
                items: HashMap::new(),
            })
        } else {
            Err(SearchInFilesFailedResult {
                cmd,
                elapsed_time: format!("{}s", elapsed_time),
                error: stderr.to_string(),
            })
        }
    }
}
