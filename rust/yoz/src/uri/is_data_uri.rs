pub fn is_data_uri(src: &str) -> bool {
    src.starts_with("data:")
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/is_data_uri_test.rs"
    ));
}
