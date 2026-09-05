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
                    let mut end = offset;
                    let mut consumed = 0usize;
                    let mut iter = text[offset..].char_indices();
                    while consumed < width {
                        match iter.next() {
                            Some((relative_idx, ch)) => {
                                end = offset + relative_idx + ch.len_utf8();
                                consumed += 1;
                            }
                            None => {
                                end = text_len;
                                break;
                            }
                        }
                    }
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
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/string/parse_lines_test.rs"
    ));
}
