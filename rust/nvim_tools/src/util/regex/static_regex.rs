use regex::Regex;

pub fn compile_regex(pattern: &str) -> Result<Regex, String> {
    Regex::new(pattern).map_err(|e| format!("Invalid regex pattern: {}", e))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_regex() {
        let result = compile_regex(r"hello\s+world");
        assert!(result.is_ok());

        let regex = result.unwrap();
        assert!(regex.is_match("hello  world"));
        assert!(regex.is_match("hello\tworld"));
        assert!(!regex.is_match("helloworld"));
    }

    #[test]
    fn test_invalid_regex_unclosed_bracket() {
        let result = compile_regex(r"hello[world");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Invalid regex pattern"));
    }

    #[test]
    fn test_invalid_regex_unclosed_paren() {
        let result = compile_regex(r"hello(world");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Invalid regex pattern"));
    }
}
