pub fn calc_linewidths(text: &str) -> Vec<u32> {
    text.lines().map(|line| line.len() as u32).collect()
}

pub fn count_lines(text: &str) -> u32 {
    text.lines().count() as u32
}

pub fn parse_comma_list(input: &str) -> Vec<String> {
    input
        .split(',')
        .map(|segment| segment.trim())
        .filter(|segment| !segment.is_empty())
        .map(|segment| segment.to_string())
        .collect()
}
