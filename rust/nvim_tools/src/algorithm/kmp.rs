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
    pattern: &[T],
    text: &[T],
    fails: Option<&Vec<usize>>,
) -> Vec<usize> {
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

    let mut result: Vec<usize> = Vec::new();
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
            result.push(i + 1 - n_pattern);
            j = 0;
            k = n_pattern + 1;
        }

        if i + k > n_text {
            break;
        }
    }

    result
}

pub fn find_first_matched_point<T: PartialEq>(
    pattern: &[T],
    text: &[T],
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
        let left: Vec<char> = "hello, world!".chars().collect();
        let right: Vec<char> = "hello, world!".repeat(4).chars().collect();
        let result = find_all_matched_points(&left, &right, None);
        assert_eq!(result, [0, 13, 26, 39]);

        let right: Vec<char> = "wawhello, world!h".repeat(4).chars().collect();
        let result = find_all_matched_points(&left, &right, None);
        assert_eq!(result, [3, 20, 37, 54]);
    }
}
