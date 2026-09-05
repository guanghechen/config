use super::normalize::normalize_joined;

pub fn join(from: &str, to: &str, keep_tailing_slash: bool) -> String {
    normalize_joined(from, to, keep_tailing_slash)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/join_test.rs"
    ));
}
