//! Eight-column DP updates with the same Unicode characters, edit budget and scores as the scalar path.

use super::{CASE_BONUS, CASE_FLAG, Candidate, Scratch, TYPO_COST, UNREACHABLE};
use std::arch::x86_64::*;

/** The horizontal gap recurrence is a prefix maximum after adding column indexes:
 * `current[j] = max(point[k] + k, k <= j) - j`. Each vector performs that scan
 * within its two halves, joins the halves, and carries the preceding column.
 *
 * # Safety
 * The caller must check AVX2 support. Every vector covers eight existing candidate
 * columns, and each DP plane has an extra leading column. The first transposition
 * block uses a shifted in-bounds load and masks its nonexistent first predecessor.
 */
#[target_feature(enable = "avx2")]
pub(super) unsafe fn typo_score(
    candidate: &Candidate,
    needle: &[char],
    casing: &[u8],
    errors: usize,
    scratch: &mut Scratch,
) -> Option<i32> {
    let width = candidate.chars.len() + 1;
    let size = width * (errors + 1);
    let (previous, before_previous, current) = (
        &mut scratch.typo_previous,
        &mut scratch.typo_before_previous,
        &mut scratch.typo_current,
    );
    previous.resize(size, UNREACHABLE);
    before_previous.resize(size, UNREACHABLE);
    current.resize(size, UNREACHABLE);
    previous.fill(UNREACHABLE);
    before_previous.fill(UNREACHABLE);
    previous[..width].fill(0);

    unsafe {
        let unreachable = _mm256_set1_epi32(UNREACHABLE);
        let reward = _mm256_set1_epi32(16);
        let case_mask = _mm256_set1_epi32(i32::from(CASE_FLAG));
        let boundary_mask = _mm256_set1_epi32(i32::from(!CASE_FLAG));
        let case_bonus = _mm256_set1_epi32(i32::from(CASE_BONUS));
        let typo_cost = _mm256_set1_epi32(TYPO_COST);
        let substitution_cost = _mm256_set1_epi32(TYPO_COST - 16);
        let transposition_cost = _mm256_set1_epi32(TYPO_COST - 32);
        let lanes = _mm256_setr_epi32(0, 1, 2, 3, 4, 5, 6, 7);
        let shifted_lanes = _mm256_setr_epi32(0, 0, 1, 2, 3, 4, 5, 6);
        let left_last_lane = _mm256_set1_epi32(3);

        for i in 1..=needle.len() {
            current.fill(UNREACHABLE);
            let ch = _mm256_set1_epi32(needle[i - 1] as i32);
            let query_case = _mm256_set1_epi32(i32::from(casing[i - 1]));
            let previous_ch = _mm256_set1_epi32(if i >= 2 { needle[i - 2] as i32 } else { 0 });
            for e in 0..=errors.min(i) {
                if e == i {
                    current[e * width] = -(i as i32) * TYPO_COST;
                }
                let mut j = 1;
                while j + 7 < width {
                    let index = e * width + j;
                    let chars = _mm256_loadu_si256(candidate.chars.as_ptr().add(j - 1).cast());
                    let flags = _mm256_cvtepu8_epi32(_mm_loadl_epi64(
                        candidate.bonuses.as_ptr().add(j - 1).cast(),
                    ));
                    let bonus = _mm256_add_epi32(
                        _mm256_and_si256(flags, boundary_mask),
                        _mm256_and_si256(
                            _mm256_cmpeq_epi32(_mm256_and_si256(flags, case_mask), query_case),
                            case_bonus,
                        ),
                    );
                    let diagonal = _mm256_loadu_si256(previous.as_ptr().add(index - 1).cast());
                    let exact = _mm256_add_epi32(diagonal, _mm256_add_epi32(reward, bonus));
                    let mut point =
                        _mm256_blendv_epi8(unreachable, exact, _mm256_cmpeq_epi32(chars, ch));
                    if e > 0 {
                        let deletion =
                            _mm256_loadu_si256(previous.as_ptr().add(index - width).cast());
                        let substitution =
                            _mm256_loadu_si256(previous.as_ptr().add(index - width - 1).cast());
                        point = _mm256_max_epi32(point, _mm256_sub_epi32(deletion, typo_cost));
                        point = _mm256_max_epi32(
                            point,
                            _mm256_sub_epi32(substitution, substitution_cost),
                        );
                        if i >= 2 {
                            let (left_chars, preceding) = if j == 1 {
                                let row = _mm256_loadu_si256(
                                    before_previous.as_ptr().add((e - 1) * width).cast(),
                                );
                                (
                                    _mm256_permutevar8x32_epi32(chars, shifted_lanes),
                                    _mm256_permutevar8x32_epi32(row, shifted_lanes),
                                )
                            } else {
                                (
                                    _mm256_loadu_si256(candidate.chars.as_ptr().add(j - 2).cast()),
                                    _mm256_loadu_si256(
                                        before_previous.as_ptr().add(index - width - 2).cast(),
                                    ),
                                )
                            };
                            let mut mask = _mm256_and_si256(
                                _mm256_cmpeq_epi32(left_chars, ch),
                                _mm256_cmpeq_epi32(chars, previous_ch),
                            );
                            if j == 1 {
                                mask = _mm256_blend_epi32(mask, _mm256_setzero_si256(), 1);
                            }
                            point = _mm256_max_epi32(
                                point,
                                _mm256_blendv_epi8(
                                    unreachable,
                                    _mm256_sub_epi32(preceding, transposition_cost),
                                    mask,
                                ),
                            );
                        }
                    }

                    let positions = _mm256_add_epi32(lanes, _mm256_set1_epi32(j as i32));
                    let carry = _mm256_set1_epi32(current[index - 1] + j as i32 - 1);
                    let mut maxima = _mm256_max_epi32(_mm256_add_epi32(point, positions), carry);
                    maxima = _mm256_max_epi32(
                        maxima,
                        _mm256_blend_epi32(_mm256_slli_si256(maxima, 4), unreachable, 0x11),
                    );
                    maxima = _mm256_max_epi32(
                        maxima,
                        _mm256_blend_epi32(_mm256_slli_si256(maxima, 8), unreachable, 0x33),
                    );
                    maxima = _mm256_max_epi32(
                        maxima,
                        _mm256_blend_epi32(
                            unreachable,
                            _mm256_permutevar8x32_epi32(maxima, left_last_lane),
                            0xf0,
                        ),
                    );
                    _mm256_storeu_si256(
                        current.as_mut_ptr().add(index).cast(),
                        _mm256_sub_epi32(maxima, positions),
                    );
                    j += 8;
                }
                while j < width {
                    let index = e * width + j;
                    let mut score = current[index - 1] - 1;
                    if needle[i - 1] == candidate.chars[j - 1] {
                        score = score.max(
                            previous[index - 1]
                                + 16
                                + i32::from(candidate.bonus(j - 1, casing[i - 1])),
                        );
                    }
                    if e > 0 {
                        score = score.max(previous[index - width] - TYPO_COST);
                        score = score.max(previous[index - width - 1] + 16 - TYPO_COST);
                        if i >= 2
                            && j >= 2
                            && needle[i - 1] == candidate.chars[j - 2]
                            && needle[i - 2] == candidate.chars[j - 1]
                        {
                            score = score.max(before_previous[index - width - 2] + 32 - TYPO_COST);
                        }
                    }
                    current[index] = score;
                    j += 1;
                }
            }
            std::mem::swap(before_previous, previous);
            std::mem::swap(previous, current);
        }
    }
    let score = *previous.iter().max()?;
    (score > UNREACHABLE / 2).then_some(score)
}
