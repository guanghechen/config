use super::*;

#[inline]
fn score_typo_ascii(query: &[u8], wildcard: Option<usize>, candidate: &[u8]) -> Option<Score> {
    let mut candidate_index = 0usize;
    let mut previous_match: Option<usize> = None;
    let mut total = 0i32;
    let mut prefix = true;

    for (query_index, &query_byte) in query.iter().enumerate() {
        let mut matched_index = None;
        while candidate_index < candidate.len() {
            if wildcard == Some(query_index)
                || candidate[candidate_index].eq_ignore_ascii_case(&query_byte)
            {
                matched_index = Some(candidate_index);
                break;
            }
            candidate_index += 1;
        }

        let matched_index = matched_index?;
        let matched = candidate[matched_index];
        prefix &= matched_index == query_index;
        total += MATCH_BONUS;
        if wildcard != Some(query_index) && matched == query_byte {
            total += CASE_BONUS;
        }
        if is_ascii_boundary(candidate, matched_index) {
            total += BOUNDARY_BONUS;
        }
        if let Some(previous) = previous_match {
            let skipped = matched_index - previous - 1;
            if skipped == 0 {
                total += CONSECUTIVE_BONUS;
            } else {
                total -= skipped.min(MAX_GAP_PENALTY) as i32;
            }
        } else if matched_index > 0 {
            total -= matched_index.min(MAX_LEADING_PENALTY) as i32;
        }

        previous_match = Some(matched_index);
        candidate_index = matched_index + 1;
    }

    let tail = candidate.len().saturating_sub(query.len());
    total -= tail.min(MAX_TAIL_PENALTY) as i32;
    if prefix {
        total += PREFIX_BONUS;
    }
    if candidate.len() == query.len() && prefix {
        total += WHOLE_WORD_BONUS;
    }

    Some(Score {
        score: total - TYPO_PENALTY,
        exact: false,
    })
}

#[inline]
fn score_typo_char_slice(
    query: &[QueryChar],
    wildcard: Option<usize>,
    candidate: &[char],
) -> Option<Score> {
    score_typo_chars_from_prefix(
        query,
        wildcard,
        candidate,
        0,
        CharScoreState {
            candidate_index: 0,
            total: 0,
            prefix: true,
        },
    )
}

#[test]
fn t_supports_unicode_subsequences() {
    let matched = score("你界", "你好世界").unwrap();
    assert!(matched.score > 0);
    assert!(!matched.exact);
}

#[test]
fn t_rejects_missing_characters() {
    assert_eq!(score("xyz", "example"), None);
}

#[test]
fn t_prefers_prefixes() {
    assert!(score("cmp", "completion").unwrap().score > score("cmp", "create_map").unwrap().score);
}

#[test]
fn t_prefers_shorter_prefix_tails() {
    assert!(score("fun", "fund").unwrap().score > score("fun", "function").unwrap().score);
}

#[test]
fn t_prefers_tighter_gaps() {
    assert!(score("abc", "a_bc").unwrap().score > score("abc", "a___bc").unwrap().score);
}

#[test]
fn t_scores_equal_character_gaps_independently_of_utf8_width() {
    assert_eq!(
        score("ab", "axb").unwrap().score,
        score("ab", "a你b").unwrap().score
    );
}

#[test]
fn t_supports_streaming_unicode_case_folding() {
    assert!(score("Σ", "σigma").is_some());
}

#[test]
fn t_projects_strict_match_byte_ranges() {
    let candidates = [
        "Completion".to_owned(),
        "你好世界".to_owned(),
        "ÄpfelBeta".to_owned(),
        "other".to_owned(),
    ];

    assert_eq!(
        matched_ranges("cmp", &candidates[..1]),
        vec![vec![0, 1, 2, 4]]
    );
    assert_eq!(
        matched_ranges("你界", &candidates[1..2]),
        vec![vec![0, 3, 9, 12]]
    );
    assert_eq!(
        matched_ranges("äb", &candidates[2..3]),
        vec![vec![0, 2, 6, 7]]
    );
    assert_eq!(
        matched_ranges("xyz", &candidates[3..]),
        vec![Vec::<usize>::new()]
    );
    assert_eq!(
        matched_ranges("", &candidates[..1]),
        vec![Vec::<usize>::new()]
    );
}

#[test]
fn t_supports_one_typo_variants() {
    let transposed = Query::new("pritn").typo().unwrap();
    assert_eq!(transposed.max_edits, 1);
    assert!(transposed.score("print").is_some());

    let substituted = Query::new("pront").typo().unwrap();
    assert!(substituted.score("print").is_some());

    let extra = Query::new("priint").typo().unwrap();
    assert!(extra.score("print").is_some());

    let multiple = Query::new("prxyt").typo().unwrap();
    assert!(multiple.score("print").is_none());

    let unicode = Query::new("你好界世").typo().unwrap();
    assert!(unicode.score("你好世界").is_some());
}

#[test]
fn t_supports_two_typo_prefix_repairs() {
    for (query, candidate) in [
        ("complxtjon", "completion"),
        ("xycdefgh", "abcdefgh"),
        ("compxletionx", "completion"),
        ("abcedfghxj", "abcdefghij"),
        ("bacdfegh", "abcdefgh"),
        ("baabacaa", "baacbaa"),
        ("你坏世界和战未来", "你好世界和平未来"),
        ("甲乙丙丁戊己庚辛", "甲乙丙己丁庚辛"),
    ] {
        let typo = Query::new(query).typo().unwrap();
        assert_eq!(typo.max_edits, 2, "{query}");
        let repaired = typo
            .score(candidate)
            .unwrap_or_else(|| panic!("{query} -> {candidate}"));
        assert!(!repaired.exact, "{query}");
    }

    let typo = Query::new("xycdefgh").typo().unwrap();
    let (strict, repaired) = typo.matcher().score_both("abcdefgh");
    assert!(strict.is_none());
    assert!(repaired.is_some());
}

#[test]
fn t_long_queries_keep_prefix_repairs_without_widening_fuzzy_scratch() {
    let candidate = "abcdefghijklmnopqrstuvwxyz0123456789ABCD";
    let query = "abcdefghijxlmnopqrstuvwxyz0123456789AxCD";
    let typo = Query::new(query).typo().unwrap();

    assert_eq!(typo.max_edits, 2);
    assert!(!typo.fuzzy_repairs);
    assert!(typo.score(candidate).is_some());
}

#[test]
fn t_short_queries_do_not_receive_a_second_typo() {
    let typo = Query::new("abcxefy").typo().unwrap();
    assert_eq!(typo.max_edits, 1);
    assert!(typo.score("abcdefg").is_none());
}

fn reference_prefix_distance(query: &[u8], candidate: &[u8]) -> usize {
    let mut rows = [[u8::MAX; 9]; 9];
    for (index, row) in rows.iter_mut().enumerate().take(query.len() + 1) {
        row[0] = index as u8;
    }
    for query_len in 1..=query.len() {
        for candidate_len in 1..=candidate.len() {
            let mut cost = rows[query_len - 1][candidate_len].saturating_add(1);
            cost = cost.min(
                rows[query_len - 1][candidate_len - 1].saturating_add(u8::from(
                    query[query_len - 1] != candidate[candidate_len - 1],
                )),
            );
            if query_len >= 2
                && candidate_len >= 2
                && query[query_len - 1] == candidate[candidate_len - 2]
                && query[query_len - 2] == candidate[candidate_len - 1]
            {
                cost = cost.min(rows[query_len - 2][candidate_len - 2].saturating_add(1));
            }
            rows[query_len][candidate_len] = cost;
        }
    }
    usize::from(rows[query.len()][candidate.len()])
}

fn binary_word(value: usize, len: usize) -> Vec<u8> {
    (0..len)
        .map(|index| {
            if value & (1 << index) == 0 {
                b'a'
            } else {
                b'b'
            }
        })
        .collect()
}

#[test]
fn t_two_typo_prefix_search_matches_bounded_reference() {
    let query_len = 8;
    for query_value in 0..1 << query_len {
        let query = binary_word(query_value, query_len);
        for candidate_len in query_len - 2..=query_len {
            for candidate_value in 0..1 << candidate_len {
                let candidate = binary_word(candidate_value, candidate_len);
                let distance = (query_len - 2..=candidate_len)
                    .map(|prefix_len| reference_prefix_distance(&query, &candidate[..prefix_len]))
                    .min();
                let expected = distance.is_some_and(|distance| distance <= 2);
                let actual = score_ascii(&query, &candidate).is_some()
                    || score_typo_prefix_ascii(&query, &candidate, candidate.len()).is_some()
                    || score_two_typo_prefix_ascii(&query, &candidate).is_some();
                assert_eq!(
                    expected,
                    actual,
                    "query={:?} candidate={:?}",
                    String::from_utf8_lossy(&query),
                    String::from_utf8_lossy(&candidate)
                );
            }
        }
    }
}

#[test]
fn t_prefers_a_prefix_repair_over_weaker_typo_alignments() {
    let repaired = Query::new("aabc").typo().unwrap().score("aaacb").unwrap();

    assert!(repaired.score > 0);
    assert!(!repaired.exact);
}

#[test]
fn t_fuzzy_typo_uses_the_best_available_alignment() {
    let repaired = Query::new("a_bb")
        .typo()
        .unwrap()
        .score("__b_babb")
        .unwrap();

    assert!(repaired.score > 0);
}

#[test]
fn t_fuzzy_typo_does_not_short_circuit_on_a_lower_score() {
    let repaired = Query::new("c_c_ccab_")
        .typo()
        .unwrap()
        .score("__ccddcc_ccab_bb")
        .unwrap();

    assert_eq!(repaired.score, 114);
}

#[test]
fn t_combined_matching_preserves_strict_scores() {
    for (query, candidate) in [
        ("cdvl42", "candidate_value_00042"),
        ("候c值一", "候选candidate值一00042"),
    ] {
        let strict = Query::new(query);
        let typo = strict.typo().unwrap();
        let mut matcher = typo.matcher();
        let (combined, _) = matcher.score_both(candidate);

        assert_eq!(combined, strict.score(candidate));
    }
}

#[test]
fn t_shared_ascii_prefix_scoring_matches_full_scoring() {
    let typo = Query::new("abcdefghijklmnopqrstuvxw").typo().unwrap();
    let query = typo.ascii.as_deref().unwrap();
    let candidate = b"__a_b_c_d_e_f_g_h_i_j_k_l_m_n_o_p_q_r_s_t_u_v_w_x_candidate";
    let context = ascii_match_context(query, candidate);

    for variants in [
        &typo.swaps[..],
        &typo.substitutions[..],
        &typo.deletions[..],
    ] {
        for variant in variants {
            let variant_query = variant.ascii.as_deref().unwrap();
            let actual = (variant.edit_index <= context.matched_prefix)
                .then(|| {
                    score_typo_ascii_from_prefix(
                        variant_query,
                        variant.wildcard,
                        candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    )
                })
                .flatten();
            assert_eq!(
                actual,
                score_typo_ascii(variant_query, variant.wildcard, candidate)
            );
        }
    }
}

#[test]
fn t_shared_unicode_prefix_scoring_matches_full_scoring() {
    let typo = Query::new("你一二三四界世").typo().unwrap();
    let candidate = "__你_一_二_三_四_世_界_candidate"
        .chars()
        .collect::<Vec<_>>();
    let context = char_match_context(&typo.chars, &candidate);

    for variants in [
        &typo.swaps[..],
        &typo.substitutions[..],
        &typo.deletions[..],
    ] {
        for variant in variants {
            let actual = (variant.edit_index <= context.matched_prefix)
                .then(|| {
                    score_typo_chars_from_prefix(
                        &variant.chars,
                        variant.wildcard,
                        &candidate,
                        variant.edit_index,
                        context.prefixes[variant.edit_index],
                    )
                })
                .flatten();
            assert_eq!(
                actual,
                score_typo_char_slice(&variant.chars, variant.wildcard, &candidate)
            );
        }
    }
}

#[test]
fn t_bounds_typo_query_length() {
    assert!(Query::new("abc").typo().is_none());
    assert_eq!(Query::new("abcdefgh").typo().unwrap().max_edits, 2);
    let too_long = "a".repeat(MAX_PREFIX_TYPO_QUERY_CHARS + 1);
    assert!(Query::new(&too_long).typo().is_none());
}
