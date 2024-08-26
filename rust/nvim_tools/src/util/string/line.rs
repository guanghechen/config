pub fn get_line_widths(text: &str) -> Vec<u32> {
    let mut lwidths: Vec<u32> = vec![];
    for line in text.lines() {
        lwidths.push(line.len() as u32);
    }
    lwidths
}
