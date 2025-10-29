use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepResult {
    #[serde(rename = "type")]
    pub category: String,
    pub data: IRipgrepResultData,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(untagged)]
pub enum IRipgrepResultData {
    Match {
        path: IRipgrepResultMatchedPath,
        lines: IRipgrepResultMatchedLines,
        line_number: usize,
        absolute_offset: usize,
        submatches: Vec<IRipgrepResultSubmatch>,
    },
    End {
        path: IRipgrepResultMatchedPath,
        binary_offset: Option<usize>,
        stats: IRipgrepSummaryStats,
    },
    Begin {
        path: IRipgrepResultMatchedPath,
    },
    Summary {
        elapsed_total: IRipgrepSummaryElapsed,
        stats: IRipgrepSummaryStats,
    },
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepResultMatchedPath {
    pub text: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepResultMatchedLines {
    pub text: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepResultSubmatch {
    #[serde(rename = "match")]
    pub detail: IRipgrepResultSubmatchDetail,
    pub start: usize,
    pub end: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepResultSubmatchDetail {
    pub text: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepSummaryStats {
    pub bytes_printed: usize,
    pub bytes_searched: usize,
    pub elapsed: IRipgrepSummaryElapsed,
    pub matched_lines: usize,
    pub matches: usize,
    pub searches: usize,
    pub searches_with_match: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IRipgrepSummaryElapsed {
    pub human: String,
    pub nanos: usize,
    pub secs: usize,
}
