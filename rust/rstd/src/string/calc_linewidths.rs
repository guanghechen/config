pub fn calc_linewidths(text: &str) -> Vec<u32> {
    text.lines().map(|line| line.len() as u32).collect()
}

#[cfg(test)]
mod tests {
    use super::calc_linewidths;

    #[test]
    fn test_computes_per_line_widths() {
        let text = "abc\ndef\nghi";
        let widths = calc_linewidths(text);
        assert_eq!(widths, vec![3, 3, 3]);
    }
}
