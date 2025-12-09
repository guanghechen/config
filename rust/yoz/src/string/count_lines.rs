pub fn count_lines(text: &str) -> u32 {
    text.lines().count() as u32
}

#[cfg(test)]
mod tests {
    use super::count_lines;

    #[test]
    fn t_counts_lines() {
        let text = "one\ntwo\nthree";
        assert_eq!(count_lines(text), 3);
    }
}
