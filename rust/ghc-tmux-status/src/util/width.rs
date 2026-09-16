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
    /*
     * Includes Unicode 17 East_Asian_Width W/F ranges. Keep the existing
     * conservative CJK and emoji block reserves for status-length ceilings.
     * Source: https://www.unicode.org/Public/17.0.0/ucd/EastAsianWidth.txt
     */
    matches!(
        character as u32,
        0x1100..=0x115F
            | 0x231A..=0x231B
            | 0x2329..=0x232A
            | 0x23E9..=0x23EC
            | 0x23F0
            | 0x23F3
            | 0x25FD..=0x25FE
            | 0x2614..=0x2615
            | 0x2630..=0x2637
            | 0x2648..=0x2653
            | 0x267F
            | 0x268A..=0x268F
            | 0x2693
            | 0x26A1
            | 0x26AA..=0x26AB
            | 0x26BD..=0x26BE
            | 0x26C4..=0x26C5
            | 0x26CE
            | 0x26D4
            | 0x26EA
            | 0x26F2..=0x26F3
            | 0x26F5
            | 0x26FA
            | 0x26FD
            | 0x2705
            | 0x270A..=0x270B
            | 0x2728
            | 0x274C
            | 0x274E
            | 0x2753..=0x2755
            | 0x2757
            | 0x2795..=0x2797
            | 0x27B0
            | 0x27BF
            | 0x2B1B..=0x2B1C
            | 0x2B50
            | 0x2B55
            | 0x2E80..=0xA4CF
            | 0xA960..=0xA97C
            | 0xAC00..=0xD7A3
            | 0xF900..=0xFAFF
            | 0xFE10..=0xFE19
            | 0xFE30..=0xFE6F
            | 0xFF00..=0xFF60
            | 0xFFE0..=0xFFE6
            | 0x16FE0..=0x16FE4
            | 0x16FF0..=0x16FF6
            | 0x17000..=0x18CD5
            | 0x18CFF..=0x18D1E
            | 0x18D80..=0x18DF2
            | 0x1AFF0..=0x1AFF3
            | 0x1AFF5..=0x1AFFB
            | 0x1AFFD..=0x1AFFE
            | 0x1B000..=0x1B122
            | 0x1B132
            | 0x1B150..=0x1B152
            | 0x1B155
            | 0x1B164..=0x1B167
            | 0x1B170..=0x1B2FB
            | 0x1D300..=0x1D356
            | 0x1D360..=0x1D376
            | 0x1F004
            | 0x1F0CF
            | 0x1F18E
            | 0x1F191..=0x1F19A
            | 0x1F200..=0x1F202
            | 0x1F210..=0x1F23B
            | 0x1F240..=0x1F248
            | 0x1F250..=0x1F251
            | 0x1F260..=0x1F265
            | 0x1F300..=0x1FAFF
            | 0x20000..=0x2FFFD
            | 0x30000..=0x3FFFD
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

    #[test]
    fn supplementary_cjk_is_double_width() {
        assert_eq!(display_width("𠮷野家"), 6);
        assert_eq!(display_width("\u{20000}\u{30000}\u{31350}"), 6);
    }

    #[test]
    fn wide_symbols_and_supplementary_kana_use_two_cells() {
        assert_eq!(display_width("⌚✅ꥠ𛀁"), 8);
    }

    #[test]
    fn ambiguous_and_private_use_icons_stay_single_width() {
        assert_eq!(display_width("¤"), 3);
    }
}
