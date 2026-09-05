pub fn calc_linewidths(text: &str) -> Vec<u32> {
    text.lines().map(|line| line.len() as u32).collect()
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/string/calc_linewidths_test.rs"
    ));
}
