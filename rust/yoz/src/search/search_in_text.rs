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
    use super::*;

    #[test]
    fn t_search_literal_case_insensitive() {
        let text = "Hello World\nhello world\nHELLO WORLD";
        let result = search_in_text("hello", text, false, false, false).unwrap();
        assert_eq!(result.matches.len(), 3);
        assert_eq!(result.matches[0].lx, 1);
        assert_eq!(result.matches[1].lx, 2);
        assert_eq!(result.matches[2].lx, 3);
    }

    #[test]
    fn t_search_regex_valid() {
        let text = "foo123\nbar456\nfoo789";
        let result = search_in_text(r"foo\d+", text, false, true, true).unwrap();
        assert_eq!(result.matches.len(), 2);
        assert_eq!(result.matches[0].lx, 1);
        assert_eq!(result.matches[1].lx, 3);
    }

    #[test]
    fn t_search_fuzzy_match() {
        let text = "hello world";
        let result = search_in_text("hw", text, true, false, false).unwrap();
        assert!(!result.matches.is_empty());
    }

    #[test]
    fn t_search_preview_metadata() {
        let text = "foo bar baz\nqux quux";
        let result = search_in_text("bar baz\nqux", text, false, false, true).unwrap();

        assert_eq!(result.matches.len(), 1);
        let m = &result.matches[0];
        assert_eq!(m.lx, 1);
        assert_eq!(m.ly, 2);
        assert_eq!(m.cx, 4);
        assert_eq!(m.cy, 2);
        assert_eq!(m.ox, 4);
        assert_eq!(m.oy, 14);
        assert_eq!(m.s, "foo bar baz↲qux quux");
        assert_eq!(m.sx, 4);
        assert_eq!(m.sy, 16);
    }
}
