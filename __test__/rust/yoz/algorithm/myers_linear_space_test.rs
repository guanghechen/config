// Archived tests for the disabled myers_linear_space implementation.
// Keep disabled until the implementation is restored.

// #[cfg(test)]
// mod tests {
//     use super::*;
//
//     fn test_case(left: &str, right: &str, expected: usize) {
//         let left_chars: Vec<char> = left.chars().collect();
//         let right_chars: Vec<char> = right.chars().collect();
//         let points: Vec<(usize, usize)> = lcs_myers(&left_chars, &right_chars);
//         let mut x0: usize = 0;
//         let mut y0: usize = 0;
//         for &(x, y) in &points {
//             assert!(x0 <= x);
//             assert!(y0 <= y);
//             x0 = x + 1;
//             y0 = y + 1;
//         }
//
//         let mut left_common: Vec<char> = vec![];
//         let mut right_common: Vec<char> = vec![];
//         for &(x, y) in &points {
//             left_common.push(left_chars[x]);
//             right_common.push(right_chars[y]);
//         }
//
//         assert_eq!(left_common.len(), expected);
//         assert_eq!(right_common.len(), expected);
//         assert_eq!(left_common, right_common);
//     }
//
//     #[test]
//     fn test_same_ascii() {
//         test_case("hello, world!", "hello, world!", 13);
//         test_case(
//             "f8d1d155-d14e-433f-88e1-07b54f184740",
//             "a00322f7-256e-46fe-ae91-8de835c57778",
//             12,
//         );
//         test_case("abcde", "ace", 3);
//         test_case("ace", "abcde", 3);
//         test_case("abc", "abc", 3);
//         test_case("abc", "abce", 3);
//         test_case("", "abce", 0);
//         test_case("abce", "", 0);
//         test_case("", "", 0);
//         test_case("abeep boop", "beep boob blah", 8);
//     }
//
//     #[test]
//     fn test_same_unicode() {
//         test_case("你好，中国!", "你好，中国!", 6);
//     }
// }
