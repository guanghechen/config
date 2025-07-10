use nvim_tools::oxi::string;

#[test]
fn test_calc_linewidths() {
    let text = "abc\ndef\nghi";
    let widths = string::calc_linewidths(text.to_string());
    assert_eq!(widths, vec![3, 3, 3]);

    let widths = string::calc_linewidths(text.to_string());
    assert_eq!(widths, vec![3, 3, 3]);
}
