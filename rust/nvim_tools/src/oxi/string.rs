use crate::util;
use md5::Digest;
use md5::Md5;
use uuid::Uuid;

pub fn calc_linewidths(text: String) -> Vec<u32> {
    util::string::calc_linewidths(&text)
}

pub fn count_lines(text: String) -> u32 {
    text.lines().count() as u32
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
