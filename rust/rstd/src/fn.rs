use std::time::SystemTime;
use std::time::UNIX_EPOCH;
use md5::Digest;
use md5::Md5;
use uuid::Uuid;

pub fn uuid() -> String {
    Uuid::new_v4().to_string()
}

pub fn md5(input: &str) -> String {
    let mut hasher = Md5::new();
    hasher.update(input.as_bytes());
    let hash = hasher.finalize();
    format!("{:x}", hash)
}

pub fn now((): ()) -> u64 {
    let now = SystemTime::now();
    let duration = now.duration_since(UNIX_EPOCH).expect("Time went backwards");
    duration.as_millis() as u64
}
