pub mod fuzzy;
pub mod keyword;
pub mod word;

use std::cmp::Ordering;
use std::sync::OnceLock;

const USAGE_SCALE: u32 = 1 << 16;
const USAGE_HALF_LIFE_SECONDS: i64 = 7 * 24 * 60 * 60;
const USAGE_MAX_SCORE: u32 = 64 * USAGE_SCALE;
// Four effective accepts produce half of the maximum ranking bonus.
const USAGE_BASELINE: u64 = 4 * USAGE_SCALE as u64;
const USAGE_MAX_BONUS: u64 = 96;
// A 256-step half-life table keeps the hot path in integer arithmetic.
const DECAY_STEPS: usize = 256;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Usage {
    score: u32,
    pub last_used: i64,
}

impl Usage {
    pub fn from_count(count: u32, last_used: i64) -> Self {
        Self {
            score: count.min(64) * USAGE_SCALE,
            last_used,
        }
    }

    pub fn from_score(score: f64, last_used: i64) -> Self {
        let score = if score.is_finite() {
            (score.max(0.0) * USAGE_SCALE as f64).round()
        } else {
            0.0
        };
        Self {
            score: score.min(USAGE_MAX_SCORE as f64) as u32,
            last_used,
        }
    }

    pub fn score(self) -> f64 {
        self.score as f64 / USAGE_SCALE as f64
    }

    pub fn decayed(self, now: i64) -> Self {
        Self {
            score: decay_score_exact(self.score, self.last_used, now),
            last_used: now,
        }
    }

    pub fn record(self, now: i64) -> Self {
        let decayed = decay_score_exact(self.score, self.last_used, now);
        Self {
            score: decayed.saturating_add(USAGE_SCALE).min(USAGE_MAX_SCORE),
            last_used: now,
        }
    }

    #[inline]
    pub fn bonus(self, now: i64) -> i32 {
        let score = decay_score(self.score, self.last_used, now) as u64;
        if score == 0 {
            return 0;
        }
        ((USAGE_MAX_BONUS * score + (score + USAGE_BASELINE) / 2) / (score + USAGE_BASELINE)) as i32
    }
}

fn decay_factors() -> &'static [u32; DECAY_STEPS] {
    static FACTORS: OnceLock<[u32; DECAY_STEPS]> = OnceLock::new();
    FACTORS.get_or_init(|| {
        std::array::from_fn(|index| {
            (f64::exp2(-(index as f64) / DECAY_STEPS as f64) * USAGE_SCALE as f64).round() as u32
        })
    })
}

fn decay_score(score: u32, last_used: i64, now: i64) -> u32 {
    if score == 0 || last_used <= 0 {
        return 0;
    }
    if now <= last_used {
        return score;
    }
    let age = now - last_used;
    let whole_halves = age / USAGE_HALF_LIFE_SECONDS;
    if whole_halves >= 32 {
        return 0;
    }
    let remainder = age % USAGE_HALF_LIFE_SECONDS;
    let factor_index = (remainder as usize * DECAY_STEPS) / USAGE_HALF_LIFE_SECONDS as usize;
    let factor = decay_factors()[factor_index] as u64;
    let scaled = (score as u64 * factor + (USAGE_SCALE as u64 / 2)) / USAGE_SCALE as u64;
    (scaled >> whole_halves) as u32
}

fn decay_score_exact(score: u32, last_used: i64, now: i64) -> u32 {
    if score == 0 || last_used <= 0 {
        return 0;
    }
    if now <= last_used {
        return score;
    }
    let age = now - last_used;
    if age / USAGE_HALF_LIFE_SECONDS >= 32 {
        return 0;
    }
    let factor = f64::exp2(-(age as f64) / USAGE_HALF_LIFE_SECONDS as f64);
    (score as f64 * factor).round().min(USAGE_MAX_SCORE as f64) as u32
}

#[derive(Clone, Debug)]
pub struct MatchItem {
    pub text: String,
    pub score_offset: i32,
    pub usage: Usage,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MatchResult {
    pub index: usize,
    pub score: i32,
    pub exact: bool,
}

fn result_order(left: &MatchResult, right: &MatchResult) -> Ordering {
    right
        .score
        .cmp(&left.score)
        .then_with(|| right.exact.cmp(&left.exact))
        .then_with(|| left.index.cmp(&right.index))
}

#[inline]
pub fn match_query(
    query: &fuzzy::Query,
    text: &str,
    score_offset: i32,
    usage: Usage,
    now: i64,
    index: usize,
) -> Option<MatchResult> {
    query.score(text).map(|matched| MatchResult {
        index,
        score: matched.score + score_offset + usage.bonus(now),
        exact: matched.exact,
    })
}

pub fn rank_matches(mut results: Vec<MatchResult>, limit: Option<usize>) -> Vec<MatchResult> {
    if let Some(limit) = limit {
        if limit == 0 {
            return Vec::new();
        }
        if results.len() > limit {
            results.select_nth_unstable_by(limit, result_order);
            results.truncate(limit);
        }
    }
    results.sort_by(result_order);
    results
}

pub fn fuzzy_match(
    query: &str,
    items: &[MatchItem],
    now: i64,
    limit: Option<usize>,
) -> Vec<MatchResult> {
    let query = fuzzy::Query::new(query);
    let typo = (limit != Some(0)).then(|| query.typo()).flatten();
    let mut results = Vec::new();
    if let Some(typo) = &typo {
        let mut matcher = typo.matcher();
        for (index, item) in items.iter().enumerate() {
            let (strict, repaired) = matcher.score_both(&item.text);
            if let Some(matched) = strict {
                results.push(MatchResult {
                    index,
                    score: matched.score + item.score_offset + item.usage.bonus(now),
                    exact: matched.exact,
                });
            } else if let Some(matched) = repaired {
                results.push(MatchResult {
                    index,
                    score: matched.score + item.score_offset + item.usage.bonus(now),
                    exact: false,
                });
            }
        }
    } else {
        results.extend(items.iter().enumerate().filter_map(|(index, item)| {
            match_query(
                &query,
                &item.text,
                item.score_offset,
                item.usage,
                now,
                index,
            )
        }));
    }
    rank_matches(results, limit)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/cmp/mod_test.rs"
    ));
}
