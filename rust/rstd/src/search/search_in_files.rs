use crate::string;
use crate::types::{
    IRipgrepResult, IRipgrepResultData, IRipgrepResultMatchedPath, ISearchBlockMatch,
    ISearchFileMatch, ISearchInFilesFailedResult, ISearchInFilesOptions,
    ISearchInFilesSucceedResult, ISearchMatchPoint,
};
use regex::Regex;
use std::collections::HashMap;
use std::process::Command;
use std::time::{Duration, SystemTime};

fn make_regex() -> Regex {
    Regex::new(r"\s*(?:\r|\r\n|\n)\s*").expect("failed to compile newline regex")
}

fn format_elapsed(duration: Duration) -> String {
    format!("{:.3}s", duration.as_secs_f32())
}

pub fn search_in_files(
    options: &ISearchInFilesOptions,
) -> Result<ISearchInFilesSucceedResult, ISearchInFilesFailedResult> {
    if options.search_pattern.is_empty() {
        return Ok(ISearchInFilesSucceedResult {
            cmd: String::new(),
            stdout: String::new(),
            elapsed_time: "0s".into(),
            items: HashMap::new(),
        });
    }

    let max_matches: u32 = match options.max_matches {
        Some(value) if value >= 0 => value as u32,
        Some(_) | None => u32::MAX,
    };

    let flag_case_sensitive = options.flag_case_sensitive;
    let flag_gitignore = options.flag_gitignore;
    let flag_regex = options.flag_regex;
    let search_pattern = &options.search_pattern;
    let search_paths = string::parse_comma_list(&options.search_paths);
    let include_patterns = string::parse_comma_list(&options.include_patterns);
    let exclude_patterns = string::parse_comma_list(&options.exclude_patterns);

    let line_separator_regex = make_regex();

    let (cmd, output, elapsed_duration) = {
        let mut cmd = Command::new("rg");
        if let Some(cwd) = &options.cwd {
            if !cwd.is_empty() {
                cmd.current_dir(cwd);
            }
        }

        cmd.arg("--multiline")
            .arg("--hidden")
            .arg("--color=never")
            .arg("--line-number")
            .arg("--column")
            .arg("--no-heading")
            .arg("--no-filename")
            .arg("--json");

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
            if !pattern.is_empty() {
                cmd.args(["--glob", &pattern]);
            }
        }

        for pattern in exclude_patterns {
            if !pattern.is_empty() {
                cmd.args(["--glob", &format!("!{}", pattern)]);
            }
        }

        if flag_regex {
            cmd.args(["--regexp", search_pattern]);
        } else {
            cmd.args(["--fixed-strings", "--", search_pattern]);
        }

        if let Some(specified_filepath) = &options.specified_filepath {
            if !specified_filepath.is_empty() {
                cmd.arg(specified_filepath);
            } else if !search_paths.is_empty() {
                cmd.args(&search_paths);
            }
        } else if !search_paths.is_empty() {
            cmd.args(&search_paths);
        }

        let start_time = SystemTime::now();
        let output = match cmd.output() {
            Ok(output) => output,
            Err(error) => {
                return Err(ISearchInFilesFailedResult {
                    cmd: format!("{:?}", cmd),
                    elapsed_time: "0s".into(),
                    error: format!("Failed to execute ripgrep: {}", error),
                });
            }
        };
        let elapsed = start_time
            .elapsed()
            .unwrap_or_else(|_| Duration::from_secs(0));

        (format!("{:?}", cmd), output, elapsed)
    };

    if output.status.success() {
        let mut matches_count: u32 = 0;
        let mut summary_elapsed: Option<String> = None;
        let mut filematches: HashMap<String, ISearchFileMatch> = HashMap::new();

        let stdout = String::from_utf8_lossy(&output.stdout);
        for chunk in line_separator_regex
            .split(&stdout)
            .filter(|entry| !entry.is_empty())
        {
            if matches_count >= max_matches {
                break;
            }

            if let Ok(event) = serde_json::from_str::<IRipgrepResult>(chunk) {
                match event.data {
                    IRipgrepResultData::Begin { .. } => {}
                    IRipgrepResultData::Match {
                        path,
                        lines,
                        line_number,
                        absolute_offset,
                        submatches,
                    } => {
                        if matches_count >= max_matches {
                            continue;
                        }

                        let filepath = normalize_filepath(&path);
                        let filematch = filematches
                            .entry(filepath)
                            .or_insert_with(|| ISearchFileMatch { matches: vec![] });
                        if filematch.matches.is_empty() {
                            matches_count = matches_count.saturating_add(1);
                        }

                        let mut blocks: Vec<ISearchMatchPoint> = Vec::new();
                        for submatch in submatches.iter() {
                            if matches_count >= max_matches {
                                break;
                            }

                            matches_count = matches_count.saturating_add(1);
                            blocks.push(ISearchMatchPoint {
                                l: submatch.start,
                                r: submatch.end,
                            });
                        }

                        filematch.matches.push(ISearchBlockMatch {
                            lnum: line_number,
                            text: lines.text.clone(),
                            offset: absolute_offset,
                            matches: blocks,
                        });
                    }
                    IRipgrepResultData::End { .. } => {}
                    IRipgrepResultData::Summary { elapsed_total, .. } => {
                        summary_elapsed = Some(elapsed_total.human);
                    }
                }
            }
        }

        let elapsed_time = summary_elapsed.unwrap_or_else(|| format_elapsed(elapsed_duration));
        Ok(ISearchInFilesSucceedResult {
            cmd,
            stdout: stdout.to_string(),
            elapsed_time,
            items: filematches,
        })
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.is_empty() {
            Ok(ISearchInFilesSucceedResult {
                cmd,
                stdout: String::new(),
                elapsed_time: format_elapsed(elapsed_duration),
                items: HashMap::new(),
            })
        } else {
            Err(ISearchInFilesFailedResult {
                cmd,
                elapsed_time: format_elapsed(elapsed_duration),
                error: stderr.to_string(),
            })
        }
    }
}

#[cfg(windows)]
fn normalize_filepath(path: &IRipgrepResultMatchedPath) -> String {
    path.text.replace('\\', "/")
}

#[cfg(not(windows))]
fn normalize_filepath(path: &IRipgrepResultMatchedPath) -> String {
    path.text.clone()
}
