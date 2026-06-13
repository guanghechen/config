pub fn format_percent_min_width_2(percent: f64) -> String {
    format!("{:>2}", percent.round() as u64)
}

#[cfg(test)]
mod tests {
    use super::format_percent_min_width_2;

    #[test]
    fn formats_percent_with_at_least_two_digits() {
        assert_eq!(format_percent_min_width_2(5.0), " 5");
        assert_eq!(format_percent_min_width_2(12.0), "12");
        assert_eq!(format_percent_min_width_2(100.0), "100");
    }
}
