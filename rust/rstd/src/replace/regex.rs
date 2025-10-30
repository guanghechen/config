use regex::Regex;

pub fn compile_regex(pattern: &str) -> Result<Regex, String> {
    Regex::new(pattern).map_err(|e| format!("Invalid regex pattern: {}", e))
}
