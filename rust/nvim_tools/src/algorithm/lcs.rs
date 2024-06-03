use crate::algorithm::kmp::find_first_matched_point;

pub fn lcs<T: PartialEq>(left: &[T], right: &[T]) -> Vec<(usize, usize)> {
    let n1: usize = left.len();
    let n2: usize = right.len();

    if n1 == 0 || n2 == 0 {
        return vec![];
    }

    // Optmize for same string or prefix samed string.
    // if n1 <= n2 then
    //     let match_point = find_first_matched_point(&left, &right);
    //     match match_point {
    //     Some(p) ->
    // }
    // end

    let common_n: usize = if n1 < n2 { n1 } else { n2 };
    {
        let mut flag: bool = true;
        for i in 0..common_n {
            if left[i] != right[i] {
                flag = false;
                break;
            }
        }
        if flag {
            return Vec::from([(n1 - 1, n1 - 1)]);
        }
    }

    let mut dp: Vec<Vec<usize>> = vec![vec![0; n2]; n1];
    dp[0][0] = if left[0] == right[0] { 1 } else { 0 };
    for i in 1..n1 {
        dp[i][0] = dp[i - 1][0] | if left[i] == right[i] { 1 } else { 0 };
    }

    #[allow(clippy::needless_range_loop)]
    for j in 1..n2 {
        dp[0][j] = dp[0][j - 1] | if left[0] == right[j] { 1 } else { 0 };
    }

    for i in 1..n1 {
        #[allow(clippy::needless_range_loop)]
        for j in 1..n2 {
            dp[i][j] = if left[i] == right[j] {
                dp[i - 1][j - 1] + 1
            } else if dp[i][j - 1] < dp[i - 1][j] {
                dp[i - 1][j]
            } else {
                dp[i][j - 1]
            };
        }
    }

    let result_size: usize = dp[n1 - 1][n2 - 1];
    if result_size == 0 {
        return vec![];
    }

    let mut pairs: Vec<(usize, usize)> = vec![(0, 0); result_size];
    {
        let mut i: usize = n1 - 1;
        let mut j: usize = n2 - 1;
        let mut len: usize = result_size;
        while len > 0 {
            while i > 0 && dp[i][j] == len {
                i -= 1;
            }
            while j > 0 && dp[i][j] == len {
                j -= 1;
            }
            pairs[len - 1] = (i, j);

            i -= 1;
            j -= 1;
            len -= 1;
        }
    }
    pairs
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_same_ascii() {
        let left: Vec<char> = "hello, world!".chars().collect();
        let right: Vec<char> = "hello, world!".chars().collect();
        let result = lcs(&left, &right);
        assert_eq!(result, vec![(left.len() - 1, right.len() - 1)]);
    }

    #[test]
    fn test_same_unicode() {
        let left: Vec<char> = "你好，中国!".chars().collect();
        let right: Vec<char> = "你好，中国!".chars().collect();
        let result = lcs(&left, &right);
        assert_eq!(result, vec![(left.len() - 1, right.len() - 1)]);
    }
}
