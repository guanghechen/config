use crate::search::matcher;
use crate::string::get_locations;
use crate::types::IMatchLocation;
use crate::types::replace::IReplaceFileResult;
use regex::Captures;
use std::collections::HashSet;

pub fn replace_file_by_matches_advance(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
    match_offsets: &[usize],
    remain_offsets: &[usize],
) -> Result<IReplaceFileResult, String> {
    let (bom, text) = super::read_text(filepath)?;

    let match_offsets: HashSet<usize> = match_offsets.iter().cloned().collect();

    let mut offset_delta: i64 = 0;
    let mut next_offsets: Vec<usize> = vec![];
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let next_text: String = super::replace_all(&regex, &text, |caps: &Captures| {
        let m = caps.get(0).unwrap();
        let offset: usize = m.start();
        let should_replace: bool = match_offsets.contains(&offset);
        if should_replace {
            let replacement: String = super::expand(caps, replace_pattern);

            let mut i = next_offsets.len();
            while i < remain_offsets.len() {
                let remain_offset: usize = remain_offsets[i];
                if remain_offset > offset {
                    break;
                }

                next_offsets.push((remain_offset as i64 + offset_delta) as usize);
                i += 1;
            }
            offset_delta += (replacement.len() as i64) - (m.end() as i64 - m.start() as i64);

            replacement
        } else {
            m.as_str().to_string()
        }
    });

    let mut i: usize = next_offsets.len();
    while i < remain_offsets.len() {
        let remain_offset: usize = remain_offsets[i];
        next_offsets.push((remain_offset as i64 + offset_delta) as usize);
        i += 1
    }

    if text != next_text {
        super::write_text(filepath, bom, &next_text)?;
    }

    let locations: Vec<IMatchLocation> = get_locations(&next_text, &next_offsets);
    Ok(IReplaceFileResult { locations })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::TempDir;
    use std::fs;

    #[test]
    fn t_remaining_matches_keep_their_rows_in_crlf_files() {
        let dir = TempDir::new();
        let path = dir.path().join("text");
        fs::write(&path, "a foo\r\nb foo\r\nc foo\r\n").unwrap();
        let file = path.to_str().unwrap();
        let result =
            replace_file_by_matches_advance(file, "foo", "quux", false, true, &[2], &[9, 16])
                .unwrap();
        assert_eq!(
            fs::read_to_string(&path).unwrap(),
            "a quux\r\nb foo\r\nc foo\r\n"
        );
        let mapped: Vec<(usize, usize, usize)> = result
            .locations
            .iter()
            .map(|location| (location.offset, location.lnum, location.col))
            .collect();
        assert_eq!(mapped, vec![(10, 2, 2), (17, 3, 2)]);
    }
}
