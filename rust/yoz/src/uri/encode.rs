pub fn encode(src: &str) -> String {
    let mut result = String::with_capacity(src.len() * 3);

    for byte in src.bytes() {
        if is_unreserved(byte) {
            result.push(byte as char);
        } else {
            result.push('%');
            result.push(HEX_DIGITS[(byte >> 4) as usize] as char);
            result.push(HEX_DIGITS[(byte & 0x0F) as usize] as char);
        }
    }

    result
}

const HEX_DIGITS: &[u8; 16] = b"0123456789ABCDEF";

fn is_unreserved(b: u8) -> bool {
    matches!(b, b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~')
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/encode_test.rs"
    ));
}
