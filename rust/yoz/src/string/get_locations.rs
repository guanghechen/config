use crate::types::IMatchLocation;

/** The 1-based line, 0-based byte column and at most 200 bytes of line text for each of the
ascending `offsets`. */
pub fn get_locations(text: &str, offsets: &[usize]) -> Vec<IMatchLocation> {
    let mut locations: Vec<IMatchLocation> = Vec::with_capacity(offsets.len());

    let n: usize = offsets.len();
    let mut k: usize = 0;
    let mut pos: usize = 0;
    for (lnum, raw) in text.split_inclusive('\n').enumerate() {
        if k == n {
            break;
        }

        /* A line spans its line break, two bytes in CRLF files; the last line also takes the
         * offset just past it. */
        let next_pos: usize = pos + raw.len() + usize::from(!raw.ends_with('\n'));
        let line: &str = raw.strip_suffix('\n').unwrap_or(raw);
        let line: &str = line.strip_suffix('\r').unwrap_or(line);
        let line: &str = &line[..line.floor_char_boundary(200)];
        while k < n {
            let offset: usize = offsets[k];
            if offset >= next_pos {
                break;
            }

            locations.push(IMatchLocation {
                offset,
                lnum: lnum + 1,
                col: offset - pos,
                line: line.to_string(),
            });

            k += 1;
        }
        pos = next_pos;
    }

    locations
}

#[cfg(test)]
mod tests {
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

    #[test]
    fn t_maps_offsets_in_crlf_text() {
        /* Each "\r\n" takes two bytes; the offset just past the last line still maps to it. */
        let text = "ab\r\ncd\r\nef";
        let locations = get_locations(text, &[1, 4, 8, 10]);
        let mapped: Vec<(usize, usize, &str)> = locations
            .iter()
            .map(|location| (location.lnum, location.col, location.line.as_str()))
            .collect();
        assert_eq!(
            mapped,
            vec![(1, 1, "ab"), (2, 0, "cd"), (3, 0, "ef"), (3, 2, "ef")]
        );
    }

    #[test]
    fn t_truncates_long_lines_at_char_boundaries() {
        /* Byte 200 falls inside the 67th three-byte character. */
        let line = "中".repeat(67);
        let text = format!("{line}\nnext");
        let locations = get_locations(&text, &[3, line.len() + 1]);
        assert_eq!(locations[0].line, "中".repeat(66));
        let next = &locations[1];
        assert_eq!((next.lnum, next.col, next.line.as_str()), (2, 0, "next"));
    }
}
