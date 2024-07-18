use crate::{types::string::LineMatch, util};
use uuid::Uuid;

pub fn uuid((): ()) -> String {
    let uuid = Uuid::new_v4();
    uuid.to_string()
}

pub fn find_match_points((pattern, text): (String, String)) -> String {
    let lines: Vec<String> = text.lines().map(|s| s.to_string()).collect();
    let matches: Vec<LineMatch> = util::string::find_match_points(&pattern, &lines);
    serde_json::to_string(&matches).unwrap()
}
