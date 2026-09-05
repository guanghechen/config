use super::parse::parse;

pub fn hash(uri: &str) -> Option<String> {
    parse(uri).and_then(|parts| parts.hash.map(|h| h.to_string()))
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/hash_test.rs"
    ));
}
