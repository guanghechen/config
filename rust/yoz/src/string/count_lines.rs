pub fn count_lines(text: &str) -> u32 {
    text.lines().count() as u32
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/string/count_lines_test.rs"
    ));
}
