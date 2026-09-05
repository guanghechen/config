use super::*;

#[test]
fn t_find_all_matched_points_basic() {
    let text: Vec<char> = "hello, world!".repeat(4).chars().collect();
    let pattern: Vec<char> = "hello, world!".chars().collect();
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result, [0, 13, 26, 39]);

    let text: Vec<char> = "wawhello, world!h".repeat(4).chars().collect();
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result, [3, 20, 37, 54]);
}

#[test]
fn t_find_all_handles_empty_pattern() {
    let text: Vec<u8> = b"hello".to_vec();
    let pattern: Vec<u8> = vec![];
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result.len(), 0);
}

#[test]
fn t_find_all_handles_empty_text() {
    let text: Vec<u8> = vec![];
    let pattern: Vec<u8> = b"test".to_vec();
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result.len(), 0);
}

#[test]
fn t_find_all_pattern_longer_than_text() {
    let text: Vec<u8> = b"hi".to_vec();
    let pattern: Vec<u8> = b"hello world".to_vec();
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result.len(), 0);
}

#[test]
fn t_find_all_single_char() {
    let text: Vec<u8> = b"aabaabaab".to_vec();
    let pattern: Vec<u8> = b"a".to_vec();
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result, [0, 1, 3, 4, 6, 7]);
}

#[test]
fn t_find_all_overlapping_matches() {
    let text: Vec<u8> = b"aaaa".to_vec();
    let pattern: Vec<u8> = b"aa".to_vec();
    let result = find_all_matched_points(&text, &pattern, None);
    assert_eq!(result, [0, 2]);
}

#[test]
fn t_find_first_matched_point() {
    let text: Vec<u8> = b"hello world hello".to_vec();
    let pattern: Vec<u8> = b"hello".to_vec();
    let result = find_first_matched_point(&text, &pattern, None);
    assert_eq!(result, Some(0));
}

#[test]
fn t_find_first_no_match() {
    let text: Vec<u8> = b"hello world".to_vec();
    let pattern: Vec<u8> = b"rust".to_vec();
    let result = find_first_matched_point(&text, &pattern, None);
    assert_eq!(result, None);
}

#[test]
fn t_calc_fails_produces_prefix_table() {
    let pattern: Vec<u8> = b"abcabc".to_vec();
    let mut fails = vec![0; pattern.len() + 1];
    calc_fails(&pattern, &mut fails);
    assert_eq!(fails, [0, 0, 0, 0, 1, 2, 3]);
}

#[test]
fn t_find_all_with_precomputed_fails() {
    let text: Vec<u8> = b"hello hello hello".to_vec();
    let pattern: Vec<u8> = b"hello".to_vec();
    let mut fails = vec![0; pattern.len() + 1];
    calc_fails(&pattern, &mut fails);

    let result = find_all_matched_points(&text, &pattern, Some(&fails));
    assert_eq!(result, [0, 6, 12]);
}

#[test]
fn t_find_all_handles_utf8_bytes() {
    let text = "Hello, 世界!";
    let pattern = "世界";
    let result = find_all_matched_points(text.as_bytes(), pattern.as_bytes(), None);
    assert_eq!(result.len(), 1);
}
