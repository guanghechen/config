pub fn format_percent_width_3(percent: f64) -> String {
    let value = percent.round().clamp(0.0, 100.0) as u64;
    format!("{value:>3}")
}

#[cfg(test)]
mod tests {
    use super::format_percent_width_3;

    #[test]
    fn formats_percent_right_aligned_width_3() {
        assert_eq!(format_percent_width_3(5.0), "  5");
        assert_eq!(format_percent_width_3(12.0), " 12");
        assert_eq!(format_percent_width_3(100.0), "100");
        assert_eq!(format_percent_width_3(-3.0), "  0");
        assert_eq!(format_percent_width_3(250.0), "100");
    }
}
