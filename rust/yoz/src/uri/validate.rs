use super::parse::parse;

pub fn validate(uri: &str) -> bool {
    parse(uri).is_some()
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/validate_test.rs"
    ));
}
