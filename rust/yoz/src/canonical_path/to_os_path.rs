use std::borrow::Cow;

#[inline]
pub fn to_os_path(filepath: &str) -> Cow<'_, str> {
    to_separator(filepath, std::path::MAIN_SEPARATOR)
}

#[inline]
fn to_separator(filepath: &str, separator: char) -> Cow<'_, str> {
    if separator == '/' || !filepath.as_bytes().contains(&b'/') {
        return Cow::Borrowed(filepath);
    }

    let mut buffer = [0; 4];
    Cow::Owned(filepath.replace('/', separator.encode_utf8(&mut buffer)))
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/canonical_path/to_os_path_test.rs"
    ));
}
