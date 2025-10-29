use crate::types::MatchLocation;

pub fn get_locations(text: &str, offsets: &[usize]) -> Vec<MatchLocation> {
    let mut locations: Vec<MatchLocation> = Vec::with_capacity(offsets.len());

    let n: usize = offsets.len();
    let mut k: usize = 0;
    let mut pos: usize = 0;
    for (lnum, line) in text.lines().enumerate() {
        if k == n {
            break;
        }

        let next_pos: usize = pos + line.len() + 1;
        while k < n {
            let offset: usize = offsets[k];
            if offset >= next_pos {
                break;
            }

            locations.push(MatchLocation {
                offset,
                lnum: lnum + 1,
                col: offset - pos,
                line: line[0..line.len().min(200)].to_string(),
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
    fn maps_offsets_to_line_meta() {
        let text = "foo\nbar\nbaz";
        let offsets = vec![0, 4, 8];
        let locations = get_locations(text, &offsets);
        assert_eq!(locations.len(), 3);
        assert_eq!(locations[0].lnum, 1);
        assert_eq!(locations[1].lnum, 2);
        assert_eq!(locations[2].lnum, 3);
    }
}
