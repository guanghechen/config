use nvim_tools::util::string;

#[test]
fn test_calc_linewidths() {
    let text = "abc\ndef\nghi";
    let widths = string::calc_linewidths(text);
    assert_eq!(widths, vec![3, 3, 3]);

    let widths = string::calc_linewidths(text);
    assert_eq!(widths, vec![3, 3, 3]);
}
