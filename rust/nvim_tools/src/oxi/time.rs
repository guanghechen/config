use std::time::{SystemTime, UNIX_EPOCH};

pub fn now((): ()) -> u64 {
    // Get the current time
    let now = SystemTime::now();

    // Calculate the number of milliseconds since the Unix epoch
    let duration = now.duration_since(UNIX_EPOCH).expect("Time went backwards");

    duration.as_millis() as u64
}
