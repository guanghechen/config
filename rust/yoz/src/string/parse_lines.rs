/** The lines of `text`, each as many bytes long as its width in `lwidths`, the lengths
`calc_linewidths` measures; without widths, `text` split at line feeds. */
pub fn parse_lines(text: &str, lwidths: Option<&[u32]>) -> Vec<String> {
    match lwidths {
        Some(widths) if !widths.is_empty() => {
            let mut lines = Vec::with_capacity(widths.len());
            let mut offset = 0usize;
            let text_len = text.len();
            let bytes = text.as_bytes();

            for &width in widths {
                let width = width as usize;

                if offset >= text_len {
                    lines.push(String::new());
                    continue;
                }

                if width == 0 {
                    lines.push(String::new());
                } else {
                    /* A width that ends inside a character keeps the character whole. */
                    let end = text.ceil_char_boundary((offset + width).min(text_len));
                    lines.push(text[offset..end].to_string());
                    offset = end;
                }

                if offset < text_len && bytes[offset] == b'\r' {
                    offset += 1;
                }
                if offset < text_len && bytes[offset] == b'\n' {
                    offset += 1;
                }
            }

            lines
        }
        _ => text.split('\n').map(|line| line.to_string()).collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::parse_lines;
    use crate::string::calc_linewidths;

    #[test]
    fn t_parse_lines_with_multibyte_widths() {
        /* `calc_linewidths` measures bytes: "İ" takes two and each CJK character three. */
        let text = "İab a\n中文\nend";
        let lines = parse_lines(text, Some(&calc_linewidths(text)));
        assert_eq!(lines, vec!["İab a", "中文", "end"]);
    }

    #[test]
    fn t_parse_lines_keeps_characters_whole() {
        let lines = parse_lines("中文", Some(&[1, 1]));
        assert_eq!(lines, vec!["中", "文"]);
    }

    #[test]
    fn t_parse_lines_with_widths() {
        let text = "foo\nbar\nbaz";
        let lines = parse_lines(text, Some(&[3, 3, 3]));
        assert_eq!(lines, vec!["foo", "bar", "baz"]);
    }

    #[test]
    fn t_parse_lines_without_widths() {
        let text = "foo\nbar\nbaz";
        let lines = parse_lines(text, None);
        assert_eq!(lines, vec!["foo", "bar", "baz"]);
    }

    #[test]
    fn t_parse_lines_with_widths_without_newlines() {
        let text = "abcdef";
        let lines = parse_lines(text, Some(&[2, 2, 2]));
        assert_eq!(lines, vec!["ab", "cd", "ef"]);
    }

    #[test]
    fn t_parse_lines_with_crlf_widths() {
        let text = "foo\r\nbar";
        let lines = parse_lines(text, Some(&[3, 3]));
        assert_eq!(lines, vec!["foo", "bar"]);
    }
}
