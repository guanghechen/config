use super::parse::parse;

pub fn pathname(uri: &str) -> Option<String> {
    parse(uri).map(|parts| parts.path.to_string())
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/pathname_test.rs"
    ));
}
