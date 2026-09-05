use super::is_absolute::is_absolute;
use super::normalize::{normalize, normalize_borrowed, normalize_joined};
use std::borrow::Cow;

pub fn resolve(from: &str, to: &str, keep_tailing_slash: bool) -> String {
    if is_absolute(to) {
        return normalize(to, keep_tailing_slash);
    }

    normalize_joined(from, to, keep_tailing_slash)
}

pub(crate) fn resolve_borrowed<'a>(from: &str, to: &'a str) -> Cow<'a, str> {
    if is_absolute(to) {
        normalize_borrowed(to)
    } else {
        Cow::Owned(normalize_joined(from, to, false))
    }
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/resolve_test.rs"
    ));
}
