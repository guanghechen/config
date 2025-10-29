/// Compute the KMP failure function for `pattern`.
pub fn kmp_calc_fails<T: PartialEq>(pattern: &[T], fails: &mut [usize]) {
    if pattern.is_empty() || fails.len() < pattern.len() + 1 {
        return;
    }

    fails[0] = 0;
    fails[1] = 0;
    let n = pattern.len();
    for i in 1..n {
        let mut j: usize = fails[i];
        while j > 0 && pattern[i] != pattern[j] {
            j = fails[j];
        }
        fails[i + 1] = if pattern[i] == pattern[j] { j + 1 } else { 0 };
    }
}

/// Find all match offsets using KMP. Returns start indices for each match.
pub fn kmp_find_all_matched_points<T: PartialEq>(
    text: &[T],
    pattern: &[T],
    fails: Option<&Vec<usize>>,
) -> Vec<usize> {
    let n_pattern: usize = pattern.len();
    if n_pattern == 0 {
        return vec![];
    }

    let mut local_fails;
    let fails: &Vec<usize> = match fails {
        Some(f) => f,
        None => {
            local_fails = vec![0; n_pattern + 1];
            kmp_calc_fails(pattern, &mut local_fails);
            &local_fails
        }
    };

    let mut result: Vec<usize> = Vec::new();
    let mut j: usize = 0;

    #[allow(clippy::needless_range_loop)]
    for i in 0..text.len() {
        while j > 0 && pattern[j] != text[i] {
            j = fails[j];
        }

        if pattern[j] == text[i] {
            j += 1;
        }

        if j == n_pattern {
            result.push(i + 1 - n_pattern);
            j = 0;
        }
    }

    result
}

/// Find the first match offset using KMP. Returns the start index if found.
pub fn kmp_find_first_matched_point<T: PartialEq>(
    text: &[T],
    pattern: &[T],
    fails: Option<&Vec<usize>>,
) -> Option<usize> {
    let n_pattern: usize = pattern.len();
    if n_pattern == 0 {
        return Some(0);
    }

    let mut local_fails;
    let fails: &Vec<usize> = match fails {
        Some(f) => f,
        None => {
            local_fails = vec![0; n_pattern + 1];
            kmp_calc_fails(pattern, &mut local_fails);
            &local_fails
        }
    };

    let mut j: usize = 0;
    let mut remaining: usize = n_pattern + 1;

    #[allow(clippy::needless_range_loop)]
    for i in 0..text.len() {
        while j > 0 && pattern[j] != text[i] {
            j = fails[j];
        }

        if pattern[j] == text[i] {
            j += 1;
            remaining -= 1;
        }

        if j == n_pattern {
            return Some(i + 1 - n_pattern);
        }

        if i + remaining > text.len() {
            break;
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn find_all_matched_points_basic() {
        let text: Vec<char> = "hello, world!".repeat(4).chars().collect();
        let pattern: Vec<char> = "hello, world!".chars().collect();
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [0, 13, 26, 39]);

        let text: Vec<char> = "wawhello, world!h".repeat(4).chars().collect();
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [3, 20, 37, 54]);
    }

    #[test]
    fn find_all_handles_empty_pattern() {
        let text: Vec<u8> = b"hello".to_vec();
        let pattern: Vec<u8> = vec![];
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn find_all_handles_empty_text() {
        let text: Vec<u8> = vec![];
        let pattern: Vec<u8> = b"test".to_vec();
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn find_all_pattern_longer_than_text() {
        let text: Vec<u8> = b"hi".to_vec();
        let pattern: Vec<u8> = b"hello world".to_vec();
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn find_all_single_char() {
        let text: Vec<u8> = b"aabaabaab".to_vec();
        let pattern: Vec<u8> = b"a".to_vec();
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [0, 1, 3, 4, 6, 7]);
    }

    #[test]
    fn find_all_overlapping_matches() {
        let text: Vec<u8> = b"aaaa".to_vec();
        let pattern: Vec<u8> = b"aa".to_vec();
        let result = kmp_find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [0, 2]);
    }

    #[test]
    fn find_first_matched_point() {
        let text: Vec<u8> = b"hello world hello".to_vec();
        let pattern: Vec<u8> = b"hello".to_vec();
        let result = kmp_find_first_matched_point(&text, &pattern, None);
        assert_eq!(result, Some(0));
    }

    #[test]
    fn find_first_no_match() {
        let text: Vec<u8> = b"hello world".to_vec();
        let pattern: Vec<u8> = b"rust".to_vec();
        let result = kmp_find_first_matched_point(&text, &pattern, None);
        assert_eq!(result, None);
    }

    #[test]
    fn calc_fails_produces_prefix_table() {
        let pattern: Vec<u8> = b"abcabc".to_vec();
        let mut fails = vec![0; pattern.len() + 1];
        kmp_calc_fails(&pattern, &mut fails);
        assert_eq!(fails, [0, 0, 0, 0, 1, 2, 3]);
    }

    #[test]
    fn find_all_with_precomputed_fails() {
        let text: Vec<u8> = b"hello hello hello".to_vec();
        let pattern: Vec<u8> = b"hello".to_vec();
        let mut fails = vec![0; pattern.len() + 1];
        kmp_calc_fails(&pattern, &mut fails);

        let result = kmp_find_all_matched_points(&text, &pattern, Some(&fails));
        assert_eq!(result, [0, 6, 12]);
    }

    #[test]
    fn find_all_handles_utf8_bytes() {
        let text = "Hello, 世界!";
        let pattern = "世界";
        let result = kmp_find_all_matched_points(text.as_bytes(), pattern.as_bytes(), None);
        assert_eq!(result.len(), 1);
    }
}
