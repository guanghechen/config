use regex::Regex;
use std::sync::Mutex;

// https://docs.rs/regex/latest/regex/index.html
// I follow the example of the docs to reuse regex when running it multiple times
lazy_static! {
    static ref CACHE_PATTERN: Mutex<String> = Mutex::new(String::new());
    static ref CACHE_REGEX: Mutex<Regex> = Mutex::new(Regex::new(r"").unwrap());
}

pub fn get_static_regex(pattern: &str) -> Result<&'static Mutex<Regex>, String> {
    if *pattern != *CACHE_PATTERN.lock().unwrap() {
        CACHE_PATTERN
            .lock()
            .unwrap()
            .clone_from(&pattern.to_string());
        let regex = Regex::new(pattern);
        return if let Ok(r) = regex {
            *CACHE_REGEX.lock().unwrap() = r;
            Ok(&CACHE_REGEX)
        } else {
            Err("Invalid regex".to_string())
        };
    }
    Ok(&CACHE_REGEX)
}
