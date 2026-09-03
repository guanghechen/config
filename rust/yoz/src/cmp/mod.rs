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
    use super::*;

    #[test]
    fn t_orders_prefix_and_consecutive_matches_first() {
        let items = vec![
            MatchItem {
                text: "buffer".to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            },
            MatchItem {
                text: "BufEnter".to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            },
            MatchItem {
                text: "build_future".to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            },
        ];

        let results = fuzzy_match("buf", &items, 1_000_000, None);
        assert_eq!(results.len(), 3);
        assert_eq!(results[0].index, 0);
        assert!(results[0].exact);
        assert_eq!(results[1].index, 1);
    }

    #[test]
    fn t_applies_score_offsets() {
        let items = vec![
            MatchItem {
                text: "alpha".to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            },
            MatchItem {
                text: "alphabet".to_owned(),
                score_offset: 100,
                usage: Usage::default(),
            },
        ];

        let results = fuzzy_match("alpha", &items, 1_000_000, None);
        assert_eq!(results[0].index, 1);
    }

    #[test]
    fn t_frecency_decays_old_usage() {
        let now = 10_000_000;
        let items = vec![
            MatchItem {
                text: "alpha".to_owned(),
                score_offset: 0,
                usage: Usage::from_count(2, now - 60),
            },
            MatchItem {
                text: "alpha".to_owned(),
                score_offset: 0,
                usage: Usage::from_count(64, now - 35 * 24 * 60 * 60),
            },
        ];

        let results = fuzzy_match("alpha", &items, now, None);
        assert_eq!(results[0].index, 0);
    }

    #[test]
    fn t_limits_after_complete_ranking() {
        let items = (0..1000)
            .map(|index| MatchItem {
                text: format!("item-{index:04}"),
                score_offset: 0,
                usage: Usage::default(),
            })
            .collect::<Vec<_>>();
        let results = fuzzy_match("item", &items, 1_000_000, Some(5));
        assert_eq!(results.len(), 5);
        assert_eq!(results[0].index, 0);
    }

    #[test]
    fn t_typo_fallback_recalls_repaired_candidates() {
        let items = ["print", "printf", "println", "paint", "priority_queue"]
            .into_iter()
            .map(|text| MatchItem {
                text: text.to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            })
            .collect::<Vec<_>>();
        let results = fuzzy_match("pritn", &items, 1_000_000, Some(200));

        assert_eq!(results[0].index, 0);
        assert!(results.iter().any(|result| result.index == 1));
        assert!(results.iter().any(|result| result.index == 2));
    }

    #[test]
    fn t_typo_fallback_preserves_top_k_consistency() {
        let items = ["p_r_i_t_n", "print"]
            .into_iter()
            .map(|text| MatchItem {
                text: text.to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            })
            .collect::<Vec<_>>();
        let full = fuzzy_match("pritn", &items, 1_000_000, Some(200));
        let top = fuzzy_match("pritn", &items, 1_000_000, Some(1));

        assert_eq!(top, full[..1]);
        assert_eq!(top[0].index, 1);
    }

    #[test]
    fn t_dense_strict_results_do_not_suppress_a_better_typo() {
        let mut items = (0..32)
            .map(|index| MatchItem {
                text: format!("p_r_i_t_n_{index:02}"),
                score_offset: 0,
                usage: Usage::default(),
            })
            .collect::<Vec<_>>();
        items.push(MatchItem {
            text: "print".to_owned(),
            score_offset: 0,
            usage: Usage::default(),
        });
        let results = fuzzy_match("pritn", &items, 1_000_000, Some(200));

        assert_eq!(results[0].index, 32);
    }

    #[test]
    fn t_prefix_match_keeps_competing_typo_repairs() {
        let items = ["pritn_value", "print"]
            .into_iter()
            .map(|text| MatchItem {
                text: text.to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            })
            .collect::<Vec<_>>();
        let results = fuzzy_match("pritn", &items, 1_000_000, Some(200));

        assert_eq!(results.len(), 2);
        assert_eq!(results[0].index, 0);
        assert_eq!(results[1].index, 1);
    }

    #[test]
    fn t_orders_strict_one_and_two_typo_prefixes() {
        let items = ["complxtjon_value", "complxtion", "completion"]
            .into_iter()
            .map(|text| MatchItem {
                text: text.to_owned(),
                score_offset: 0,
                usage: Usage::default(),
            })
            .collect::<Vec<_>>();
        let results = fuzzy_match("complxtjon", &items, 1_000_000, Some(200));

        assert_eq!(
            results
                .iter()
                .map(|result| result.index)
                .collect::<Vec<_>>(),
            vec![0, 1, 2]
        );
    }

    #[test]
    fn t_usage_records_decayed_frequency() {
        let now = 10_000_000;
        let once = Usage::default().record(now);
        let twice = once.record(now);
        let after_half_life = twice.decayed(now + USAGE_HALF_LIFE_SECONDS);

        assert!((once.score() - 1.0).abs() < 0.0001);
        assert!((twice.score() - 2.0).abs() < 0.0001);
        assert!((after_half_life.score() - 1.0).abs() < 0.0001);
        assert!(twice.bonus(now) > once.bonus(now));
    }

    #[test]
    fn t_short_interval_snapshots_preserve_total_decay() {
        let start = 10_000_000;
        let interval = 30 * 60;
        let steps = 400;
        let initial = Usage::from_count(4, start);
        let mut stepped = initial;
        for step in 1..=steps {
            stepped = stepped.decayed(start + step * interval);
        }
        let direct = initial.decayed(start + steps * interval);

        assert!((stepped.score() - direct.score()).abs() < 0.001);
        assert!(stepped.score() < 2.0);
    }

    #[test]
    fn t_short_interval_record_consumes_elapsed_decay() {
        let start = 10_000_000;
        let recorded = Usage::from_count(4, start).record(start + 30 * 60);
        assert!(recorded.score() < 5.0);
        assert!(recorded.score() > 4.9);
    }
}
