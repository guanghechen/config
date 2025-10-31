pub fn parse_lines(text: &str, lwidths: Option<&[u32]>) -> Vec<String> {
    match lwidths {
        Some(widths) if !widths.is_empty() => {
            let mut lines = Vec::with_capacity(widths.len());
            let mut offset = 0usize;
            let text_len = text.len();

            for &width in widths {
                let width = width as usize;
                let end = offset.saturating_add(width).min(text_len);

                if offset >= text_len {
                    lines.push(String::new());
                } else if let Some(slice) = text.get(offset..end) {
                    lines.push(slice.to_string());
                } else {
                    lines.push(text[offset..].to_string());
                }

                offset = end.saturating_add(1);
            }

            lines
        }
        _ => text.split('\n').map(|line| line.to_string()).collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::parse_lines;

    #[test]
    fn test_parse_lines_with_widths() {
        let text = "foo\nbar\nbaz";
        let lines = parse_lines(text, Some(&[3, 3, 3]));
        assert_eq!(lines, vec!["foo", "bar", "baz"]);
    }

    #[test]
    fn test_parse_lines_without_widths() {
        let text = "foo\nbar\nbaz";
        let lines = parse_lines(text, None);
        assert_eq!(lines, vec!["foo", "bar", "baz"]);
    }
}
