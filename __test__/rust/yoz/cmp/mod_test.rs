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
