mod ripgrep_result {
    // 在您的 Cargo.toml 文件中包含 serde 和 serde_json 依赖
    // serde = { version = "1.0", features = ["derive"] }
    // serde_json = "1.0"

    use serde::{Deserialize, Serialize};

    // 定义与 JSON 数据匹配的 Rust 结构体
    #[derive(Serialize, Deserialize, Debug)]
    pub struct ResultItem {
        #[serde(rename = "type")]
        pub category: String,
        pub data: ResultItemData,
    }

    #[derive(Serialize, Deserialize, Debug)]
    #[serde(untagged)]
    pub enum ResultItemData {
        Match {
            path: Path,
            lines: Lines,
            line_number: usize,
            absolute_offset: usize,
            submatches: Vec<SubMatch>,
        },
        End {
            path: Path,
            binary_offset: Option<usize>,
            stats: Stats,
        },
        Begin {
            path: Path,
        },
        Summary {
            elapsed_total: Elapsed,
            stats: SummaryStats,
        },
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct Path {
        pub text: String,
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct Lines {
        pub text: String,
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct SubMatch {
        #[serde(rename = "match")]
        pub match_text: MatchText,
        pub start: usize,
        pub end: usize,
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct MatchText {
        pub text: String,
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct Stats {
        pub elapsed: Elapsed,
        pub searches: usize,
        pub searches_with_match: usize,
        pub bytes_searched: usize,
        pub bytes_printed: usize,
        pub matched_lines: usize,
        pub matches: usize,
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct SummaryStats {
        pub bytes_printed: usize,
        pub bytes_searched: usize,
        pub elapsed: Elapsed,
        pub matched_lines: usize,
        pub matches: usize,
        pub searches: usize,
        pub searches_with_match: usize,
    }

    #[derive(Serialize, Deserialize, Debug)]
    pub struct Elapsed {
        pub secs: usize,
        pub nanos: usize,
        pub human: String,
    }
}

#[cfg(test)]
mod tests {
    use regex::Regex;
    use serde::{Deserialize, Serialize};
    use std::{collections::HashMap, process::Command};

    use crate::ripgrep_result;

    #[derive(Serialize, Deserialize, Debug, Clone)]
    struct InlineMatchedItem {
        start: usize,    // related to the parent.lines
        end: usize,      // related to the parent.lines
        replace: String, // replaced string
    }

    #[derive(Serialize, Deserialize, Debug, Clone)]
    struct LineMatchedItem {
        lines: String,
        line_start: usize,
        matches: Vec<InlineMatchedItem>,
    }

    #[derive(Serialize, Deserialize, Debug, Clone)]
    struct FileMatchedItem {
        filepath: String,
        matches: Vec<LineMatchedItem>,
    }

    #[derive(Serialize, Deserialize, Debug, Clone)]
    struct MatchedResult {
        items: Vec<FileMatchedItem>,
        elapsed_time: String,
    }

    #[test]
    fn test_rg() {
        let search_pattern = r"#\[test\]\n\s*fn (\w+)";
        let replace_pattern = r"fn h!!!_$1_!!!w";
        let search_paths = vec!["src", "tests"];
        let search_regex = Regex::new(search_pattern).unwrap();
        let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();

        let output = {
            let mut cmd = Command::new("rg");
            cmd.arg("--multiline")
                .arg("--hidden")
                .arg("--color=never")
                .arg("--line-number")
                .arg("--no-heading")
                .arg("--no-filename")
                .arg("--json")
                .args(["--replace", "hello"])
                .args(["--regexp", search_pattern])
                .args(&search_paths)
                // -
            ;

            // print the executing command
            println!("\n{:?}", cmd);

            // return the output of the cmd
            cmd.output().expect("failed to execute ripgrep")
        };

        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let parts = line_separator_regex
                .split(&stdout)
                .filter(|&x| !x.is_empty());

            let mut result_elapsed_time: String = "0s".to_string();
            let mut file_items_map: HashMap<String, FileMatchedItem> = HashMap::new();
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
                            let mut inline_matches: Vec<InlineMatchedItem> = vec![];
                            for submatch in submatches {
                                let replace_text = search_regex
                                    .replace_all(&submatch.match_text.text, replace_pattern);
                                let item: InlineMatchedItem = InlineMatchedItem {
                                    start: submatch.start,
                                    end: submatch.end,
                                    replace: replace_text.to_string(),
                                };
                                inline_matches.push(item);
                            }
                            let line_matches: LineMatchedItem = LineMatchedItem {
                                lines: lines.text,
                                line_start: line_number,
                                matches: inline_matches,
                            };
                            let filepath: String = path.text.clone();
                            let file_item: &mut FileMatchedItem = file_items_map
                                .entry(filepath.clone())
                                .or_insert(FileMatchedItem {
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

            let result_items: Vec<FileMatchedItem> = file_items_map.values().cloned().collect();
            let result: MatchedResult = MatchedResult {
                elapsed_time: result_elapsed_time,
                items: result_items,
            };
            let serialized_result = serde_json::to_string(&result).unwrap();

            println!(
                "\n-----stdout-----\n{:?}\n----------------\n{:?}\n----------------",
                serialized_result,
                line_separator_regex
                    .split(&stdout)
                    .filter(|&x| !x.is_empty())
                    .collect::<Vec<_>>()
            );
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            eprintln!("stderr:\n{}", stderr);
        }
    }
}
