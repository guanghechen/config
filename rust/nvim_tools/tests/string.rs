use nvim_tools::util::string;

#[test]
fn test_get_line_widths() {
    let widths = string::get_line_widths("abc\ndef\nghi");
    assert_eq!(widths, vec![3, 3, 3]);

    let widths = string::get_line_widths("abc\ndef\nghi\n");
    assert_eq!(widths, vec![3, 3, 3]);
}
