use crate::types::IMatchLocation;

pub fn get_locations(text: &str, offsets: &[usize]) -> Vec<IMatchLocation> {
    let mut locations: Vec<IMatchLocation> = Vec::with_capacity(offsets.len());

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

            locations.push(IMatchLocation {
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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/string/get_locations_test.rs"
    ));
}
