use super::normalize;

#[inline]
pub fn from_os_path(os_path: &str, keep_tailing_slash: bool) -> String {
    normalize(os_path, keep_tailing_slash)
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/from_os_path_test.rs"
    ));
}
