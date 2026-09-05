use super::calc_linewidths;

#[test]
fn t_computes_per_line_widths() {
    let text = "abc\ndef\nghi";
    let widths = calc_linewidths(text);
    assert_eq!(widths, vec![3, 3, 3]);
}
