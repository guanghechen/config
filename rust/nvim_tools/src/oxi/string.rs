use crate::types::r#match::LineMatch;
use crate::types::FunResult;
use crate::util;
use md5::{Digest, Md5};
use uuid::Uuid;

pub fn count_lines(text: String) -> u32 {
    text.lines().count() as u32
}

pub fn find_match_points_line_by_line(
    (pattern, text, flag_fuzzy, flag_regex): (String, String, bool, bool),
) -> String {
    let result: FunResult<Vec<LineMatch>> =
        match util::string::find_match_points_line_by_line(&pattern, &text, flag_fuzzy, flag_regex)
        {
            Ok(data) => FunResult {
                error: None,
                data: Some(data),
            },
            Err(data) => FunResult {
                error: Some(data),
                data: None,
            },
        };
    serde_json::to_string(&result).unwrap()
}

pub fn get_line_widths(text: String) -> String {
    let widths: Vec<u32> = util::string::get_line_widths(&text);
    serde_json::to_string(&widths).unwrap()
}

pub fn uuid((): ()) -> String {
    let uuid = Uuid::new_v4();
    uuid.to_string()
}

pub fn md5(input: String) -> String {
    let mut hasher = Md5::new();
    hasher.update(input);
    let hash = hasher.finalize();
    format!("{:x}", hash)
}
