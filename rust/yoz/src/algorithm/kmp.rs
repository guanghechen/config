/// Compute the KMP failure function for `pattern`.
pub fn calc_fails<T: PartialEq>(pattern: &[T], fails: &mut [usize]) {
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
pub fn find_all_matched_points<T: PartialEq>(
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
            calc_fails(pattern, &mut local_fails);
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
pub fn find_first_matched_point<T: PartialEq>(
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
            calc_fails(pattern, &mut local_fails);
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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/algorithm/kmp_test.rs"
    ));
}
