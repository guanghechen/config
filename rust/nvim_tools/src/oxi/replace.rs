use fancy_regex::Regex;
use std::{
    fs::File,
    io::{BufRead, BufReader, Write},
    sync::Mutex,
};

// https://docs.rs/regex/latest/regex/index.html
// I follow the example of the docs to reuse regex when running it multiple times
lazy_static! {
    static ref CACHE_PATTERN: Mutex<String> = Mutex::new("".to_string());
    static ref CACHE_REGEX: Mutex<Regex> = Mutex::new(Regex::new(r"").unwrap());
}

fn get_static_regex(pattern: String) -> Result<&'static Mutex<Regex>, String> {
    if pattern != *CACHE_PATTERN.lock().unwrap() {
        CACHE_PATTERN.lock().unwrap().clone_from(&pattern);
        let regex = Regex::new(&pattern);
        return if let Ok(r) = regex {
            *CACHE_REGEX.lock().unwrap() = r;
            Ok(&CACHE_REGEX)
        } else {
            Err("Invalid regex".to_string())
        };
    }
    Ok(&CACHE_REGEX)
}

/// Replaces all non-overlapping matches in `text` with the replacement provided.
pub fn replace_text(text: String, search_query: String, replace_query: String) -> String {
    if let Ok(r) = get_static_regex(search_query) {
        let regex = r.lock().unwrap();
        return regex.replace_all(&text, &replace_query).to_string();
    }
    text
}

/// Replace text on specify line number of file
pub fn replace_file(
    file_path: String,
    lnum: i32,
    search_query: String,
    replace_query: String,
) -> bool {
    if File::open(&file_path).is_err() {
        return false;
    }
    let static_regex = get_static_regex(search_query);
    if static_regex.is_err() {
        return false;
    }
    let regex = static_regex.unwrap().lock().unwrap();
    let file = File::open(&file_path);
    if file.is_err() {
        return false;
    }
    let f = BufReader::new(file.unwrap());
    let mut lines: Vec<String> = Vec::new();
    let mut is_modified = false;

    // Is this good?
    // I only want replace 1 line with another line
    let mut line_number = 1;
    for line in f.lines() {
        // it only read a valid utf-8
        if line.is_err() {
            return false;
        }
        let text = line.unwrap();
        if line_number == (lnum as usize) {
            let new_line = regex.replace_all(&text, &replace_query).to_string();
            if new_line != text {
                is_modified = true;
                lines.push(new_line);
            } else {
                lines.push(text);
            }
        } else {
            lines.push(text);
        }
        line_number += 1;
    }
    if is_modified {
        let mut new_file = File::create(&file_path).unwrap();
        new_file.write_all(lines.join("\n").as_bytes()).unwrap();
        return true;
    }
    false
}
