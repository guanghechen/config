use crate::algorithm::kmp::find_all_matched_points;
use crate::util::regex::compile_regex;
use regex::Captures;

pub fn replace_text_preview(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<String, String> {
    if flag_regex {
        let regex = match compile_regex(search_pattern) {
            Ok(r) => r,
            Err(_) => return Ok(text.to_string()),
        };
        let next_text: String = regex
            .replace_all(text, |caps: &Captures| {
                let mut replacement = replace_pattern.to_string();
                for i in 1..caps.len() {
                    if let Some(cap) = caps.get(i) {
                        let placeholder = format!("${}", i);
                        replacement = replacement.replace(&placeholder, cap.as_str());
                    }
                }

                let m = caps.get(0).unwrap();
                if keep_search_pieces {
                    format!("{}{}", m.as_str(), replacement)
                } else {
                    replacement
                }
            })
            .to_string();
        return Ok(next_text);
    }

    let match_points: Vec<usize> = if flag_case_sensitive {
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None)
    } else {
        let text_lower = text.to_lowercase();
        let pattern_lower = search_pattern.to_lowercase();
        find_all_matched_points(text_lower.as_bytes(), pattern_lower.as_bytes(), None)
    };
    let len_of_search: usize = search_pattern.len();
    let mut pieces: Vec<&str> = vec![];
    let mut i: usize = 0;
    for m in match_points {
        let j: usize = m + len_of_search;
        if keep_search_pieces {
            pieces.push(&text[i..j]);
            pieces.push(replace_pattern);
        } else {
            pieces.push(&text[i..m]);
            pieces.push(replace_pattern);
        }
        i = j;
    }
    pieces.push(&text[i..]);
    Ok(pieces.join(""))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_replace_literal() {
        let text = "hello world, hello rust";
        let result = replace_text_preview(text, "hello", "hi", false, false, true).unwrap();
        assert_eq!(result, "hi world, hi rust");
    }

    #[test]
    fn test_replace_literal_keep_search() {
        let text = "hello world";
        let result = replace_text_preview(text, "hello", " hi", true, false, true).unwrap();
        assert_eq!(result, "hello hi world");
    }

    #[test]
    fn test_replace_regex_valid() {
        let text = "foo123 bar456";
        let result = replace_text_preview(text, r"\d+", "XXX", false, true, true).unwrap();
        assert_eq!(result, "fooXXX barXXX");
    }

    #[test]
    fn test_replace_regex_with_capture_groups() {
        let text = r#"require("foo")"#;
        let result = replace_text_preview(text, r#"require\("(.+?)"\)"#, "import $1", false, true, true).unwrap();
        assert_eq!(result, "import foo");
    }

    #[test]
    fn test_replace_regex_invalid_pattern() {
        let text = "test";
        let result = replace_text_preview(text, r"(unclosed", "replacement", false, true, true);
        // Invalid regex should return original text, not error
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "test");
    }

    #[test]
    fn test_replace_case_insensitive() {
        let text = "Hello HELLO hello";
        let result = replace_text_preview(text, "hello", "hi", false, false, false).unwrap();
        assert_eq!(result, "hi hi hi");
    }

    #[test]
    fn test_replace_case_sensitive() {
        let text = "Hello hello HELLO";
        let result = replace_text_preview(text, "hello", "hi", false, false, true).unwrap();
        assert_eq!(result, "Hello hi HELLO");
    }

    #[test]
    fn test_replace_no_match() {
        let text = "foo bar";
        let result = replace_text_preview(text, "baz", "qux", false, false, true).unwrap();
        assert_eq!(result, "foo bar");
    }

    #[test]
    fn test_replace_empty_pattern() {
        let text = "test";
        let result = replace_text_preview(text, "", "X", false, false, true).unwrap();
        // Empty pattern should not match anything
        assert_eq!(result, "test");
    }

    #[test]
    fn test_replace_regex_multiple_groups() {
        let text = "2024-01-15";
        let result = replace_text_preview(text, r"(\d{4})-(\d{2})-(\d{2})", "$2/$3/$1", false, true, true).unwrap();
        assert_eq!(result, "01/15/2024");
    }
}


