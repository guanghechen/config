use crate::types::dto::LineMatch;
use crate::types::dto::MatchPoint;

pub fn search_in_lines<I, S>(
    pattern: &str,
    lines: I,
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<Vec<LineMatch>, String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<str>,
{
    // Convert lines to vector
    let lines_vec: Vec<String> = lines.into_iter().map(|s| s.as_ref().to_string()).collect();

    // Use rstd's search_in_lines and convert types
    let rstd_results = rstd::search::search_in_lines(
        pattern,
        &lines_vec,
        flag_fuzzy,
        flag_regex,
        flag_case_sensitive,
    )?;

    Ok(rstd_results
        .into_iter()
        .map(|rstd_match| LineMatch {
            lnum: rstd_match.lnum,
            score: rstd_match.score,
            matches: rstd_match
                .matches
                .into_iter()
                .map(|rstd_point| MatchPoint {
                    start: rstd_point.start,
                    end: rstd_point.end,
                })
                .collect(),
        })
        .collect())
}
