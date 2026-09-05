use super::parse_comma_list;

#[test]
fn t_splits_and_trims_segments() {
    let items = parse_comma_list("foo, bar , ,baz,,");
    assert_eq!(items, vec!["foo", "bar", "baz"]);
}
