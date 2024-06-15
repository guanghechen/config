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
