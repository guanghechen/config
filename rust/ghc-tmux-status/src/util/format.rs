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
    use super::sanitize_option_text;

    #[test]
    fn sanitize_option_text_replaces_separators_and_bounds_length() {
        assert_eq!(sanitize_option_text("a\tb\nc\rd"), "a b c d");
        assert_eq!(sanitize_option_text(&"x".repeat(300)).len(), 240);
    }
}
