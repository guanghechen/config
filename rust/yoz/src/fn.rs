use md5::Digest;
use md5::Md5;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;
use uuid::Uuid;

pub fn uuid() -> String {
    Uuid::new_v4().to_string()
}

pub fn md5(input: &[u8]) -> String {
    let mut hasher = Md5::new();
    hasher.update(input);
    let hash = hasher.finalize();
    format!("{:x}", hash)
}

pub fn now((): ()) -> u64 {
    let now = SystemTime::now();
    let duration = now.duration_since(UNIX_EPOCH).expect("Time went backwards");
    duration.as_millis() as u64
}

#[cfg(test)]
mod tests {
    use super::md5;

    #[test]
    fn t_md5_hashes_bytes_whether_or_not_they_are_utf8() {
        assert_eq!(md5(b"abc"), "900150983cd24fb0d6963f7d28e17f72");
        assert_eq!(md5(b"caf\xe9"), "961f50f6282239d09e48f812c1ca7276");
    }
}
