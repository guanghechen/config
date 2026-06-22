pub fn format_percent_width_2(percent: f64) -> String {
    let value = percent.round().clamp(0.0, 100.0) as u64;
    format!("{value:>2}")
}

#[cfg(test)]
mod tests {
    use super::format_percent_width_2;

    #[test]
    fn formats_percent_right_aligned_width_2() {
        assert_eq!(format_percent_width_2(5.0), " 5");
        assert_eq!(format_percent_width_2(12.0), "12");
        assert_eq!(format_percent_width_2(100.0), "100");
        assert_eq!(format_percent_width_2(-3.0), " 0");
        assert_eq!(format_percent_width_2(250.0), "100");
    }
}
