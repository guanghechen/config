use std::cmp;

fn utf8_char_width(byte: u8) -> usize {
    match byte {
        0x00..=0x7F => 1,
        0xC2..=0xDF => 2,
        0xE0..=0xEF => 3,
        0xF0..=0xF4 => 4,
        _ => 1,
    }
}

pub fn compute_line_offsets(bytes: &[u8]) -> Vec<usize> {
    let mut offsets = Vec::new();
    offsets.push(0);

    let mut index = 0;
    while index < bytes.len() {
        let byte = bytes[index];
        if byte == b'\r' {
            if index + 1 < bytes.len() && bytes[index + 1] == b'\n' {
                offsets.push(index + 2);
                index += 2;
                continue;
            }
            offsets.push(index + 1);
            index += 1;
            continue;
        }

        if byte == b'\n' {
            offsets.push(index + 1);
        }
        index += 1;
    }

    if offsets.last().copied() != Some(bytes.len()) {
        offsets.push(bytes.len());
    }

    offsets
}

pub fn locate_line(offsets: &[usize], position: usize) -> usize {
    if offsets.is_empty() {
        return 1;
    }

    let raw = match offsets.binary_search(&position) {
        Ok(idx) => idx + 1,
        Err(idx) => idx,
    };

    cmp::min(cmp::max(raw, 1), offsets.len().saturating_sub(1))
}

pub fn build_preview_string(
    bytes: &[u8],
    highlight_start: usize,
    highlight_end_inclusive: usize,
) -> (String, u32, u32) {
    if bytes.is_empty() {
        return (String::new(), 0, 0);
    }

    let mut preview = String::with_capacity(bytes.len());
    let mut mapping = vec![0u32; bytes.len()];
    let mut index = 0;

    while index < bytes.len() {
        let repr_start = preview.len() as u32;
        let byte = bytes[index];

        if byte == b'\r' && index + 1 < bytes.len() && bytes[index + 1] == b'\n' {
            preview.push('↲');
            mapping[index] = repr_start;
            mapping[index + 1] = repr_start;
            index += 2;
            continue;
        }

        if byte == b'\n' {
            preview.push('↲');
            mapping[index] = repr_start;
            index += 1;
            continue;
        }

        if byte == b'\r' {
            preview.push('↲');
            mapping[index] = repr_start;
            index += 1;
            continue;
        }

        let width = cmp::min(utf8_char_width(byte), bytes.len() - index).max(1);
        let slice = &bytes[index..index + width];
        if let Ok(text) = std::str::from_utf8(slice) {
            preview.push_str(text);
            for offset in 0..width {
                mapping[index + offset] = repr_start;
            }
            index += width;
        } else {
            preview.push('�');
            mapping[index] = repr_start;
            index += 1;
        }
    }

    let clamp = |idx: usize| -> usize {
        if idx >= bytes.len() {
            bytes.len().saturating_sub(1)
        } else {
            idx
        }
    };

    let sx = mapping[clamp(highlight_start)];
    let sy = mapping[clamp(highlight_end_inclusive)];
    (preview, sx, sy)
}
