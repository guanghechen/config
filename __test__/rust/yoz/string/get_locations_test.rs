use super::get_locations;

#[test]
fn t_maps_offsets_to_line_meta() {
    let text = "foo\nbar\nbaz";
    let offsets = vec![0, 4, 8];
    let locations = get_locations(text, &offsets);
    assert_eq!(locations.len(), 3);
    assert_eq!(locations[0].lnum, 1);
    assert_eq!(locations[1].lnum, 2);
    assert_eq!(locations[2].lnum, 3);
}
