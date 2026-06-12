pub fn display_width(text: &str) -> usize {
    text.chars().map(char_width).sum()
}

fn char_width(character: char) -> usize {
    if character == '\u{0000}' {
        return 0;
    }
    if character.is_control() {
        return 0;
    }
    if is_wide(character) { 2 } else { 1 }
}

fn is_wide(character: char) -> bool {
    matches!(
        character as u32,
        0x1100..=0x115F
            | 0x2329..=0x232A
            | 0x2E80..=0xA4CF
            | 0xAC00..=0xD7A3
            | 0xF900..=0xFAFF
            | 0xFE10..=0xFE19
            | 0xFE30..=0xFE6F
            | 0xFF00..=0xFF60
            | 0xFFE0..=0xFFE6
            | 0x1F300..=0x1FAFF
    )
}

#[cfg(test)]
mod tests {
    use super::display_width;

    #[test]
    fn ascii_is_single_width() {
        assert_eq!(display_width("abc"), 3);
    }

    #[test]
    fn cjk_is_double_width() {
        assert_eq!(display_width("你好"), 4);
    }
}
