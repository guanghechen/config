use crate::search::matcher;

/// Fails with the reason when replacing cannot use a search pattern: file search also takes a pattern that matches
/// bytes outside UTF-8, as `(?-u:\xFF)` does, while replacing edits UTF-8 text.
pub fn check_pattern(
    search_pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<(), String> {
    matcher(search_pattern, flag_regex, flag_case_sensitive).map(|_| ())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_check_pattern_rejects_only_patterns_that_match_bytes_outside_utf8() {
        let error = check_pattern(r"(?-u:\xC3\xA9)", true, true).unwrap_err();
        assert!(error.contains("invalid UTF-8"), "{error}");
        assert!(check_pattern(r"(?-u:\xFF)", true, false).is_err());

        /* A byte below 0x80 is ASCII, `\xE9` outside `(?-u)` is the character U+00E9, and literal text is text. */
        assert_eq!(check_pattern(r"(?-u:\x41)b", true, true), Ok(()));
        assert_eq!(check_pattern(r"caf\xE9", true, false), Ok(()));
        assert_eq!(check_pattern(r"(?-u:\xFF)", false, true), Ok(()));
    }
}
