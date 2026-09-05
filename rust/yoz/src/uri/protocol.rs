use super::parse::parse;

pub fn protocol(uri: &str) -> Option<String> {
    parse(uri).map(|parts| parts.protocol.to_string())
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/uri/protocol_test.rs"
    ));
}
