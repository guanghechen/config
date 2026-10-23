use crate::search::matcher;
use regex::Captures;
use std::fs::File;
use std::io::Read;
use std::io::Write;

/// Perform replacement on the entire file.
pub fn replace_file(
    filepath: &str,
    search_pattern: &str,
    replace_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<bool, String> {
    let mut file = File::open(filepath).map_err(|e| e.to_string())?;
    let mut text = String::new();
    file.read_to_string(&mut text).map_err(|e| e.to_string())?;

    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
    let next_text: String = regex
        .replace_all(&text, |caps: &Captures| {
            let mut replacement = replace_pattern.to_string();
            for i in 1..caps.len() {
                if let Some(cap) = caps.get(i) {
                    let placeholder = format!("${}", i);
                    replacement = replacement.replace(&placeholder, cap.as_str());
                }
            }
            replacement
        })
        .to_string();

    if text != next_text {
        let mut new_file = File::create(filepath).map_err(|e| e.to_string())?;
        new_file
            .write_all(next_text.as_bytes())
            .map_err(|e| e.to_string())?;
    }

    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::TempDir;
    use std::fs;

    #[test]
    fn t_replace_file_matches_like_search() {
        let dir = TempDir::new();
        let path = dir.path().join("text");
        let file = path.to_str().unwrap();
        fs::write(&path, "İab").unwrap();
        replace_file(file, "a", "X", false, false).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "İXb");
        fs::write(&path, "Foo foo").unwrap();
        replace_file(file, "foo", "X", true, false).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "X X");
    }
}
