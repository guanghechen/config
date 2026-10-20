//! Completion acceptance history, using the existing MD5 keys and timestamp ring format.

use md5::{Digest, Md5};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

pub(super) type Key = [u8; 16];

pub(super) fn key(value: &[u8]) -> Key {
    Md5::digest(value).into()
}

pub(super) fn candidate_key(filetype: &str, identity: &[u8]) -> Key {
    let mut digest = Md5::new();
    digest.update(filetype);
    digest.update([0]);
    digest.update(identity);
    digest.finalize().into()
}

pub(super) fn parse_key(text: &str) -> Option<Key> {
    if text.len() != 32 {
        return None;
    }
    let mut key = [0; 16];
    for (index, bytes) in text.as_bytes().chunks_exact(2).enumerate() {
        let high = char::from(bytes[0]).to_digit(16)?;
        let low = char::from(bytes[1]).to_digit(16)?;
        key[index] = (high * 16 + low) as u8;
    }
    Some(key)
}

pub(super) fn format_key(key: &Key) -> String {
    use std::fmt::Write;
    let mut text = String::with_capacity(32);
    for byte in key {
        write!(text, "{byte:02x}").unwrap();
    }
    text
}

pub(super) fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

#[derive(Debug, Clone)]
pub(super) struct Entry {
    pub(super) timestamps: Vec<i64>,
    pub(super) index: usize,
    base_score: f64,
}

impl Entry {
    pub(super) fn new(timestamps: Vec<i64>, index: usize) -> Self {
        let mut entry = Self {
            timestamps,
            index,
            base_score: 0.0,
        };
        entry.replay();
        entry
    }

    fn replay(&mut self) {
        let mut score = 0.0;
        let mut previous = self.timestamps[(self.index + 1) % self.timestamps.len()];
        for offset in 1..=self.timestamps.len() {
            let timestamp = self.timestamps[(self.index + offset) % self.timestamps.len()];
            let elapsed = timestamp.saturating_sub(previous).max(0) as f64;
            score = score * (1.0 + elapsed).powf(-0.2) + 4.0;
            previous = timestamp;
        }
        self.base_score = score;
    }

    fn score(&self, now: i64) -> i32 {
        let elapsed = now.saturating_sub(self.timestamps[self.index]).max(0) as f64;
        (self.base_score * (1.0 + elapsed).powf(-0.2)).round() as i32
    }
}

pub(super) struct History {
    pub(super) max_timestamps: usize,
    pub(super) entries: HashMap<Key, Entry>,
}

impl Default for History {
    fn default() -> Self {
        Self {
            max_timestamps: 10,
            entries: HashMap::new(),
        }
    }
}

impl History {
    pub(super) fn access(&mut self, key: Key, now: i64) {
        let entry = self.entries.entry(key).or_insert_with(|| Entry {
            timestamps: Vec::new(),
            index: 0,
            base_score: 0.0,
        });
        if entry.timestamps.len() < self.max_timestamps {
            entry.timestamps.push(now);
            entry.index = entry.timestamps.len() - 1;
        } else {
            entry.index = (entry.index + 1) % self.max_timestamps;
            entry.timestamps[entry.index] = now;
        }
        // Only load/access changes the ring; hot queries decay its cached accumulated score.
        entry.replay();
    }

    pub(super) fn score(&mut self, key: &Key, now: i64) -> i32 {
        let Some(entry) = self.entries.get(key) else {
            return 0;
        };
        let score = entry.score(now);
        if score == 0 {
            self.entries.remove(key);
        }
        score
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_recent_acceptance_decays_continuously_without_amplifying_future_times() {
        let now = 4_000_000;
        for (age, expected) in [(-1, 4), (0, 4), (1, 3), (60, 2), (3600, 1), (86400, 0)] {
            let entry = Entry::new(vec![now - age], 0);
            assert_eq!(entry.score(now), expected, "age {age}");
        }
    }

    #[test]
    fn t_ring_replaces_oldest_visits_and_expired_entries_are_released() {
        let mut history = History {
            max_timestamps: 3,
            ..History::default()
        };
        let id = key(b"lua\0lsp\0lua_ls\0alpha");
        for timestamp in 1..=5 {
            history.access(id, timestamp);
        }
        assert_eq!(history.entries[&id].timestamps, [4, 5, 3]);
        assert_eq!(history.entries[&id].index, 1);
        assert_eq!(history.score(&id, 5), 11);
        assert_eq!(history.score(&id, 9_000_000_000), 0);
        assert!(history.entries.is_empty());
    }

    #[test]
    fn t_timestamp_replay_uses_acceptance_order_and_preserves_the_ring_bound() {
        let entry = Entry::new(vec![0, 60, 120], 2);
        assert_eq!(entry.score(120), 7);
        assert_eq!(entry.score(180), 3);
        let rotated = Entry::new(vec![120, 0, 60], 0);
        assert_eq!(rotated.score(180), entry.score(180));
        let repeated = Entry::new(vec![100; 10], 9);
        assert_eq!(repeated.score(100), 40);
    }

    #[test]
    fn t_cached_scores_follow_the_retained_acceptance_order_through_wraps_and_clock_changes() {
        let mut history = History {
            max_timestamps: 3,
            ..History::default()
        };
        let id = key(b"entry");
        let mut accepted = Vec::new();
        for time in [100, 160, 150, 210, 210, 390, 420] {
            accepted.push(time);
            if accepted.len() > 3 {
                accepted.remove(0);
            }
            history.access(id, time);
            for now in [time - 1, time, time + 90, time + 3600] {
                let mut expected: f64 = 0.0;
                let mut previous = accepted[0];
                for timestamp in &accepted {
                    expected =
                        expected * (1.0 + (timestamp - previous).max(0) as f64).powf(-0.2) + 4.0;
                    previous = *timestamp;
                }
                expected *= (1.0 + (now - previous).max(0) as f64).powf(-0.2);
                assert_eq!(history.entries[&id].score(now), expected.round() as i32);
            }
        }
    }

    #[test]
    fn t_candidate_digest_matches_the_persisted_key_namespace() {
        assert_eq!(
            candidate_key("lua", b"lsp\0lua_ls\0alpha"),
            key(b"lua\0lsp\0lua_ls\0alpha")
        );
        assert_ne!(
            candidate_key("lua", b"alpha"),
            candidate_key("python", b"alpha")
        );
        assert_eq!(
            candidate_key("lua", b"lsp\0\xff.a"),
            key(b"lua\0lsp\0\xff.a")
        );
        assert_ne!(
            candidate_key("lua", b"prefix\xff"),
            candidate_key("lua", b"prefix\x80")
        );
        let digest = key(b"lua\0lsp\0lua_ls\0alpha");
        assert_eq!(parse_key(&format_key(&digest)), Some(digest));
        assert!(parse_key("not a key").is_none());
        assert!(parse_key(&"\u{00e9}".repeat(16)).is_none());
    }
}
