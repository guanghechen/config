use super::count_lines;

#[test]
fn t_counts_lines() {
    let text = "one\ntwo\nthree";
    assert_eq!(count_lines(text), 3);
}
