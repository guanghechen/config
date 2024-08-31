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
