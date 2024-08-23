use crate::types::r#match::LineMatch;
use crate::util;
use uuid::Uuid;

pub fn count_lines(text: String) -> u32 {
    return text.lines().count() as u32;
}

pub fn find_match_points((pattern, text, flag_fuzzy): (String, String, bool)) -> String {
    let lines: Vec<String> = text.lines().map(|s| s.to_string()).collect();
    let matches: Vec<LineMatch> = util::string::find_match_points(&pattern, &lines, flag_fuzzy);
    serde_json::to_string(&matches).unwrap()
}

pub fn get_line_widths(text: String) -> String {
    let widths: Vec<u32> = util::string::get_line_widths(&text);
    serde_json::to_string(&widths).unwrap()
}

pub fn uuid((): ()) -> String {
    let uuid = Uuid::new_v4();
    uuid.to_string()
}
