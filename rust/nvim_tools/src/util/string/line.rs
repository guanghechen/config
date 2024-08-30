use crate::types::r#match::MatchLocation;

pub fn get_line_widths(text: &str) -> Vec<u32> {
    let mut lwidths: Vec<u32> = vec![];
    for line in text.lines() {
        lwidths.push(line.len() as u32);
    }
    lwidths
}

pub fn get_locations(text: &str, offsets: &[usize]) -> Vec<MatchLocation> {
    let mut locations: Vec<MatchLocation> = vec![];

    let n: usize = offsets.len();
    let mut k: usize = 0;
    let mut offset: usize = 0;
    for (lnum, line) in text.lines().enumerate() {
        if k == n {
            break;
        }

        let next_offset: usize = offset + line.len() + 1;
        while k < n {
            let p: usize = offsets[k];
            if p >= next_offset {
                break;
            }

            locations.push(MatchLocation {
                offset: p,
                lnum: lnum + 1,
                col: p - offset,
            });

            k += 1;
        }
        offset = next_offset;
    }

    locations
}
