#![allow(non_snake_case)]
#![allow(clippy::too_many_arguments)]

use std::{cmp::PartialEq, collections::HashMap};

pub fn lcs_myers<T>(left: &[T], right: &[T]) -> Vec<(usize, usize)>
where
    T: PartialEq,
{
    let N1: usize = left.len();
    let N2: usize = right.len();
    if N1 == 0 || N2 == 0 {
        return Vec::new();
    }

    let fx0: usize = internals::fast_forward(left, right, 0, 0);
    if fx0 == N1 || fx0 == N2 {
        return (0..fx0).map(|i| (i, i)).collect();
    }

    let mut parents: HashMap<usize, i8> = HashMap::new();
    let mut diagonals: Vec<usize> = vec![0; N1 + N2 + 1];
    diagonals[0] = fx0;

    let minimal_step: usize =
        internals::find_minimal_step(&mut diagonals, &mut parents, left, right);
    let count = (N1 + N2 - minimal_step) / 2;
    let mut answers: Vec<(usize, usize)> = vec![(0, 0); count];
    let mut x: usize = N1;
    let mut y: usize = N2;
    let mut i = count;
    while x > 0 && y > 0 {
        let p: usize = y * N1 + x;
        let dir: Option<i8> = parents.get(&p).copied();
        match dir {
            Some(-1) => x -= 1,
            Some(1) => y -= 1,
            _ => {
                i -= 1;
                x -= 1;
                y -= 1;
                answers[i] = (x, y);
            }
        }
    }
    answers
}

mod internals {
    use std::{cmp::PartialEq, collections::HashMap};

    pub fn find_minimal_step<T>(
        diagonals: &mut [usize],
        parents: &mut HashMap<usize, i8>,
        left: &[T],
        right: &[T],
    ) -> usize
    where
        T: PartialEq,
    {
        let N1: usize = left.len();
        let N2: usize = right.len();
        let K: isize = N1 as isize - N2 as isize;
        let L: usize = N1 + N2 + 1;

        for step in 1..L {
            let parity: isize = (step & 1) as isize;
            let kl: isize = -(step.min(N2) as isize);
            let kr: isize = step.min(N1) as isize;

            if step <= N1 {
                let fk: isize = step as isize;
                let fkid: usize = step;
                diagonals[fkid] = fast_forward(left, right, fk, step);
            }

            if step <= N2 {
                let fk: isize = -(step as isize);
                let fkid: usize = L - step;
                diagonals[fkid] = fast_forward(left, right, fk, 0);
            }

            for k in (parity..=-kl).step_by(2) {
                let x: usize = forward(diagonals, parents, left, right, kl, kr, -k);
                if -k == K && x == N1 {
                    return step;
                }
            }

            for k in (parity..=kr).step_by(2) {
                let x: usize = forward(diagonals, parents, left, right, kl, kr, k);
                if k == K && x == N1 {
                    return step;
                }
            }
        }
        unreachable!()
    }

    pub fn fast_forward<T>(left: &[T], right: &[T], k: isize, x0: usize) -> usize
    where
        T: PartialEq,
    {
        let N1: usize = left.len();
        let N2: usize = right.len();
        let mut x: usize = x0;
        let mut y: usize = (x as isize - k) as usize;
        while x < N1 && y < N2 && left[x] == right[y] {
            x += 1;
            y += 1;
        }
        x
    }

    pub fn forward<T>(
        diagonals: &mut [usize],
        parents: &mut HashMap<usize, i8>,
        left: &[T],
        right: &[T],
        kl: isize,
        kr: isize,
        k: isize,
    ) -> usize
    where
        T: PartialEq,
    {
        let N1: usize = left.len();
        let N2: usize = right.len();
        let L: usize = N1 + N2 + 1;

        let kid: usize = if k < 0 {
            (k + L as isize) as usize
        } else {
            k as usize
        };

        let mut x = diagonals[kid];
        if x < N1 {
            if k > kl {
                let kl: isize = k - 1;
                let klid: usize = if kl < 0 {
                    (kl + L as isize) as usize
                } else {
                    kl as usize
                };
                let xl: usize = diagonals[klid];
                if x <= xl && xl < N1 {
                    x = xl + 1;
                    let y: usize = (x as isize - k) as usize;
                    let p: usize = y * N1 + x;
                    parents.insert(p, -1);
                }
            }

            if k < kr {
                let kr = k + 1;
                let krid: usize = if kr < 0 {
                    (kr + L as isize) as usize
                } else {
                    kr as usize
                };
                let xr = diagonals[krid];
                if x < xr {
                    x = xr;
                    let y: usize = (x as isize - k) as usize;
                    let p: usize = y * N1 + x;
                    parents.insert(p, 1);
                }
            }

            x = fast_forward(left, right, k, x);
            diagonals[kid] = x;
        }
        x
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_case(left: &str, right: &str, expected: usize) {
        let left_chars: Vec<char> = left.chars().collect();
        let right_chars: Vec<char> = right.chars().collect();
        let points: Vec<(usize, usize)> = lcs_myers(&left_chars, &right_chars);
        let mut x0: usize = 0;
        let mut y0: usize = 0;
        for &(x, y) in &points {
            assert!(x0 <= x);
            assert!(y0 <= y);
            x0 = x + 1;
            y0 = y + 1;
        }

        let mut left_common: Vec<char> = vec![];
        let mut right_common: Vec<char> = vec![];
        for &(x, y) in &points {
            left_common.push(left_chars[x]);
            right_common.push(right_chars[y]);
        }

        assert_eq!(left_common.len(), expected);
        assert_eq!(right_common.len(), expected);
        assert_eq!(left_common, right_common);
    }

    #[test]
    fn test_same_ascii() {
        test_case("hello, world!", "hello, world!", 13);
        test_case(
            "f8d1d155-d14e-433f-88e1-07b54f184740",
            "a00322f7-256e-46fe-ae91-8de835c57778",
            12,
        );
        test_case("abcde", "ace", 3);
        test_case("ace", "abcde", 3);
        test_case("abc", "abc", 3);
        test_case("abc", "abce", 3);
        test_case("", "abce", 0);
        test_case("abce", "", 0);
        test_case("", "", 0);
        test_case("abeep boop", "beep boob blah", 8);
    }

    #[test]
    fn test_same_unicode() {
        test_case("你好，中国!", "你好，中国!", 6);
    }
}
