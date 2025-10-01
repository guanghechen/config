pub fn calc_fails<T: PartialEq>(pattern: &[T], fails: &mut [usize]) {
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

pub fn find_all_matched_points<T: PartialEq>(
    text: &[T],
    pattern: &[T],
    fails: Option<&Vec<usize>>,
) -> Vec<usize> {
    let n_text: usize = text.len();
    let n_pattern: usize = pattern.len();

    // Return empty result for empty pattern
    if n_pattern == 0 {
        return vec![];
    }

    let mut local_fails;
    let fails: &Vec<usize> = match fails {
        Some(f) => f,
        None => {
            local_fails = vec![0; n_pattern + 1];
            calc_fails(pattern, &mut local_fails);
            &local_fails
        }
    };

    let mut result: Vec<usize> = Vec::new();
    let mut j: usize = 0;

    #[allow(clippy::needless_range_loop)]
    for i in 0..n_text {
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

pub fn find_first_matched_point<T: PartialEq>(
    text: &[T],
    pattern: &[T],
    fails: Option<&Vec<usize>>,
) -> Option<usize> {
    let n_pattern: usize = pattern.len();
    let n_text: usize = text.len();

    let mut local_fails;
    let fails: &Vec<usize> = match fails {
        Some(f) => f,
        None => {
            local_fails = vec![0; n_pattern + 1];
            calc_fails(pattern, &mut local_fails);
            &local_fails
        }
    };

    let mut j: usize = 0;
    let mut k: usize = n_pattern + 1;

    #[allow(clippy::needless_range_loop)]
    for i in 0..n_text {
        while j > 0 && pattern[j] != text[i] {
            j = fails[j];
        }

        if pattern[j] == text[i] {
            j += 1;
            k -= 1;
        }

        if j == n_pattern {
            return Some(i + 1 - n_pattern);
        }

        if i + k > n_text {
            break;
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_all_matched_points() {
        let text: Vec<char> = "hello, world!".repeat(4).chars().collect();
        let pattern: Vec<char> = "hello, world!".chars().collect();
        let result = find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [0, 13, 26, 39]);

        let text: Vec<char> = "wawhello, world!h".repeat(4).chars().collect();
        let result = find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [3, 20, 37, 54]);
    }

    #[test]
    fn test_find_all_empty_pattern() {
        let text: Vec<u8> = b"hello".to_vec();
        let pattern: Vec<u8> = vec![];
        let result = find_all_matched_points(&text, &pattern, None);
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn test_find_all_empty_text() {
        let text: Vec<u8> = vec![];
        let pattern: Vec<u8> = b"test".to_vec();
        let result = find_all_matched_points(&text, &pattern, None);
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn test_find_all_pattern_longer_than_text() {
        let text: Vec<u8> = b"hi".to_vec();
        let pattern: Vec<u8> = b"hello world".to_vec();
        let result = find_all_matched_points(&text, &pattern, None);
        assert_eq!(result.len(), 0);
    }

    #[test]
    fn test_find_all_single_char() {
        let text: Vec<u8> = b"aabaabaab".to_vec();
        let pattern: Vec<u8> = b"a".to_vec();
        let result = find_all_matched_points(&text, &pattern, None);
        assert_eq!(result, [0, 1, 3, 4, 6, 7]);
    }

    #[test]
    fn test_find_all_overlapping() {
        let text: Vec<u8> = b"aaaa".to_vec();
        let pattern: Vec<u8> = b"aa".to_vec();
        let result = find_all_matched_points(&text, &pattern, None);
        // KMP finds non-overlapping matches by default
        assert_eq!(result, [0, 2]);
    }

    #[test]
    fn test_find_first_matched() {
        let text: Vec<u8> = b"hello world hello".to_vec();
        let pattern: Vec<u8> = b"hello".to_vec();
        let result = find_first_matched_point(&text, &pattern, None);
        assert_eq!(result, Some(0));
    }

    #[test]
    fn test_find_first_no_match() {
        let text: Vec<u8> = b"hello world".to_vec();
        let pattern: Vec<u8> = b"rust".to_vec();
        let result = find_first_matched_point(&text, &pattern, None);
        assert_eq!(result, None);
    }

    #[test]
    fn test_calc_fails() {
        let pattern: Vec<u8> = b"abcabc".to_vec();
        let mut fails = vec![0; pattern.len() + 1];
        calc_fails(&pattern, &mut fails);
        assert_eq!(fails, [0, 0, 0, 0, 1, 2, 3]);
    }

    #[test]
    fn test_find_all_with_precomputed_fails() {
        let text: Vec<u8> = b"hello hello hello".to_vec();
        let pattern: Vec<u8> = b"hello".to_vec();
        let mut fails = vec![0; pattern.len() + 1];
        calc_fails(&pattern, &mut fails);

        let result = find_all_matched_points(&text, &pattern, Some(&fails));
        assert_eq!(result, [0, 6, 12]);
    }

    #[test]
    fn test_find_all_bytes() {
        let text = "Hello, 世界!";
        let pattern = "世界";
        let result = find_all_matched_points(text.as_bytes(), pattern.as_bytes(), None);
        assert_eq!(result.len(), 1);
    }
}

