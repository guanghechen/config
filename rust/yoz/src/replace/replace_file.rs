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
    let next_text: String = super::replace_all(&regex, &text, |caps: &Captures| {
        super::expand(caps, replace_pattern)
    });

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

    #[test]
    fn t_replace_file_anchors_every_line_like_search() {
        let dir = TempDir::new();
        let path = dir.path().join("text");
        let file = path.to_str().unwrap();
        fs::write(&path, "a;\r\nb;\nc;").unwrap();
        replace_file(file, ";$", "", true, true).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "a\r\nb\nc");
        /* Lines without `;` match only the empty string, which search never lists. */
        fs::write(&path, "a;\r\nb\nc;\n").unwrap();
        replace_file(file, ";?$", "!", true, true).unwrap();
        assert_eq!(fs::read_to_string(&path).unwrap(), "a!\r\nb\nc!\n");
    }

    #[test]
    fn t_replace_file_expands_each_group_reference_once() {
        let dir = TempDir::new();
        let path = dir.path().join("text");
        let file = path.to_str().unwrap();
        let replaced = |text: &str, pattern: &str, replacement: &str| {
            fs::write(&path, text).unwrap();
            replace_file(file, pattern, replacement, true, true).unwrap();
            fs::read_to_string(&path).unwrap()
        };
        /* A group that took no part expands to nothing. */
        assert_eq!(replaced("a b", "(a)|(b)", "<$1$2>"), "<a> <b>");
        /* Captured text is never expanded again. */
        assert_eq!(replaced("$2 x", r"(\S+) (\S+)", "$1-$2"), "$2-x");
        /* Two digits name a group that exists, and `$$` is a dollar. */
        assert_eq!(
            replaced("abcdefghij", "(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)", "$10$01$$1"),
            "ja$1"
        );
        /* Without a tenth group `$10` is `$1` then 0; references to missing groups stay literal. */
        assert_eq!(replaced("a", "(a)", "$10 $5 $0"), "a0 $5 $0");
    }
}
