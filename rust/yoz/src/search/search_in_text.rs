use super::ISearchBuffer;
use super::search_in_lines::search_in_lines_buffer;
use crate::types::ISearchTextResult;

pub fn search_in_text(
    pattern: &str,
    text: &str,
    flag_fuzzy: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<ISearchTextResult, String> {
    let buffer = ISearchBuffer::from_text(text);
    search_in_lines_buffer(
        pattern,
        &buffer,
        flag_fuzzy,
        flag_regex,
        flag_case_sensitive,
    )
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/search/search_in_text_test.rs"
    ));
}
