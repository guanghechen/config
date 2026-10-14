//! Sixteen-column DP for bounded labels; character comparisons remain full Unicode u32 values.

use super::{CASE_BONUS, CASE_FLAG, Candidate, Scratch};
use std::arch::x86_64::*;

const UNREACHABLE: i16 = -16384;
const TYPO_COST: i16 = 80;

#[inline]
#[target_feature(enable = "avx2")]
fn matches(first: __m256i, second: __m256i, ch: __m256i) -> __m256i {
    let packed = _mm256_packs_epi32(
        _mm256_cmpeq_epi32(first, ch),
        _mm256_cmpeq_epi32(second, ch),
    );
    _mm256_permute4x64_epi64(packed, 0xd8)
}

#[inline]
#[target_feature(enable = "avx2")]
fn shift_column(value: __m256i) -> __m256i {
    let bridge = _mm256_permute2x128_si256(value, value, 0x08);
    _mm256_or_si256(_mm256_slli_si256(value, 2), _mm256_srli_si256(bridge, 14))
}

/** Uses the same prefix-max recurrence as the i32 kernel, with sixteen score lanes.
 *
 * # Safety
 * AVX2 is required; labels must contain at most 4096 lowercase characters, queries
 * at most 128, and the edit budget at most two. Real scores are between -4256 and
 * 5120, and adding column indexes stays within i16. Unreachable states cannot
 * reach the -8192 validity threshold even after 128 maximum character rewards.
 * Vector loads cover sixteen existing columns; row zero is handled explicitly.
 */
#[target_feature(enable = "avx2")]
pub(super) unsafe fn typo_score(
    candidate: &Candidate,
    needle: &[char],
    casing: &[u8],
    errors: usize,
    scratch: &mut Scratch,
) -> Option<i32> {
    debug_assert!(candidate.chars.len() <= 4096 && needle.len() <= 128 && errors <= 2);
    let width = candidate.chars.len() + 1;
    let size = width * (errors + 1);
    let (previous, before_previous, current) = (
        &mut scratch.typo16_previous,
        &mut scratch.typo16_before_previous,
        &mut scratch.typo16_current,
    );
    previous.resize(size, UNREACHABLE);
    before_previous.resize(size, UNREACHABLE);
    current.resize(size, UNREACHABLE);
    previous.fill(UNREACHABLE);
    before_previous.fill(UNREACHABLE);
    previous[..width].fill(0);

    unsafe {
        let unreachable = _mm256_set1_epi16(UNREACHABLE);
        let reward = _mm256_set1_epi16(16);
        let case_mask = _mm256_set1_epi16(i16::from(CASE_FLAG));
        let boundary_mask = _mm256_set1_epi16(i16::from(!CASE_FLAG));
        let case_bonus = _mm256_set1_epi16(i16::from(CASE_BONUS));
        let typo_cost = _mm256_set1_epi16(TYPO_COST);
        let substitution_cost = _mm256_set1_epi16(TYPO_COST - 16);
        let transposition_cost = _mm256_set1_epi16(TYPO_COST - 32);
        let lanes = _mm256_setr_epi16(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
        let repeat_last = _mm256_setr_epi8(
            14, 15, 14, 15, 14, 15, 14, 15, 14, 15, 14, 15, 14, 15, 14, 15, 14, 15, 14, 15, 14, 15,
            14, 15, 14, 15, 14, 15, 14, 15, 14, 15,
        );
        for i in 1..=needle.len() {
            current.fill(UNREACHABLE);
            let ch = _mm256_set1_epi32(needle[i - 1] as i32);
            let query_case = _mm256_set1_epi16(i16::from(casing[i - 1]));
            let previous_ch = _mm256_set1_epi32(if i >= 2 { needle[i - 2] as i32 } else { 0 });
            for e in 0..=errors.min(i) {
                if e == i {
                    current[e * width] = -(i as i16) * TYPO_COST;
                }
                let mut j = 1;
                while j + 15 < width {
                    let index = e * width + j;
                    let first = _mm256_loadu_si256(candidate.chars.as_ptr().add(j - 1).cast());
                    let second = _mm256_loadu_si256(candidate.chars.as_ptr().add(j + 7).cast());
                    let equal = matches(first, second, ch);
                    let flags = _mm256_cvtepu8_epi16(_mm_loadu_si128(
                        candidate.bonuses.as_ptr().add(j - 1).cast(),
                    ));
                    let bonus = _mm256_add_epi16(
                        _mm256_and_si256(flags, boundary_mask),
                        _mm256_and_si256(
                            _mm256_cmpeq_epi16(_mm256_and_si256(flags, case_mask), query_case),
                            case_bonus,
                        ),
                    );
                    let diagonal = _mm256_loadu_si256(previous.as_ptr().add(index - 1).cast());
                    let exact = _mm256_add_epi16(diagonal, _mm256_add_epi16(reward, bonus));
                    let mut point = _mm256_blendv_epi8(unreachable, exact, equal);
                    if e > 0 {
                        let deletion =
                            _mm256_loadu_si256(previous.as_ptr().add(index - width).cast());
                        let substitution =
                            _mm256_loadu_si256(previous.as_ptr().add(index - width - 1).cast());
                        point = _mm256_max_epi16(point, _mm256_sub_epi16(deletion, typo_cost));
                        point = _mm256_max_epi16(
                            point,
                            _mm256_sub_epi16(substitution, substitution_cost),
                        );
                        if i >= 2 {
                            let mut left_equal = shift_column(equal);
                            let preceding = if j == 1 {
                                shift_column(_mm256_loadu_si256(
                                    before_previous.as_ptr().add((e - 1) * width).cast(),
                                ))
                            } else {
                                if candidate.chars[j - 2] == needle[i - 1] {
                                    left_equal = _mm256_insert_epi16(left_equal, -1, 0);
                                }
                                _mm256_loadu_si256(
                                    before_previous.as_ptr().add(index - width - 2).cast(),
                                )
                            };
                            let mask =
                                _mm256_and_si256(left_equal, matches(first, second, previous_ch));
                            point = _mm256_max_epi16(
                                point,
                                _mm256_blendv_epi8(
                                    unreachable,
                                    _mm256_sub_epi16(preceding, transposition_cost),
                                    mask,
                                ),
                            );
                        }
                    }
                    let positions = _mm256_add_epi16(lanes, _mm256_set1_epi16(j as i16));
                    let carry = _mm256_set1_epi16(current[index - 1] + j as i16 - 1);
                    let mut maxima = _mm256_max_epi16(_mm256_add_epi16(point, positions), carry);
                    maxima = _mm256_max_epi16(
                        maxima,
                        _mm256_blend_epi16(_mm256_slli_si256(maxima, 2), unreachable, 0x01),
                    );
                    maxima = _mm256_max_epi16(
                        maxima,
                        _mm256_blend_epi16(_mm256_slli_si256(maxima, 4), unreachable, 0x03),
                    );
                    maxima = _mm256_max_epi16(
                        maxima,
                        _mm256_blend_epi16(_mm256_slli_si256(maxima, 8), unreachable, 0x0f),
                    );
                    let last = _mm256_shuffle_epi8(maxima, repeat_last);
                    let left = _mm256_permute2x128_si256(last, last, 0x00);
                    maxima = _mm256_max_epi16(maxima, _mm256_blend_epi32(unreachable, left, 0xf0));
                    _mm256_storeu_si256(
                        current.as_mut_ptr().add(index).cast(),
                        _mm256_sub_epi16(maxima, positions),
                    );
                    j += 16;
                }
                while j < width {
                    let index = e * width + j;
                    let mut score = current[index - 1] - 1;
                    if needle[i - 1] == candidate.chars[j - 1] {
                        score = score.max(
                            previous[index - 1]
                                + 16
                                + i16::from(candidate.bonus(j - 1, casing[i - 1])),
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
    (score > UNREACHABLE / 2).then_some(i32::from(score))
}
