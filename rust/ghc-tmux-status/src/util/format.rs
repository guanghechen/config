pub fn format_percent_width_2(percent: f64) -> String {
    let value = percent.round().clamp(0.0, 100.0) as u64;
    format!("{value:>2}")
}

pub fn sanitize_option_text(value: &str) -> String {
    const MAX_ERROR_LEN: usize = 240;
    let sanitized = value
        .chars()
        .map(|character| match character {
            '\t' | '\n' | '\r' => ' ',
            _ => character,
        })
        .collect::<String>();
    sanitized.chars().take(MAX_ERROR_LEN).collect()
}

#[cfg(test)]
mod tests {
    use super::{format_percent_width_2, sanitize_option_text};

    #[test]
    fn formats_percent_right_aligned_width_2() {
        assert_eq!(format_percent_width_2(5.0), " 5");
        assert_eq!(format_percent_width_2(12.0), "12");
        assert_eq!(format_percent_width_2(100.0), "100");
        assert_eq!(format_percent_width_2(-3.0), " 0");
        assert_eq!(format_percent_width_2(250.0), "100");
    }

    #[test]
    fn sanitize_option_text_replaces_separators_and_bounds_length() {
        assert_eq!(sanitize_option_text("a\tb\nc\rd"), "a b c d");
        assert_eq!(sanitize_option_text(&"x".repeat(300)).len(), 240);
    }
}
