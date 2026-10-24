use regex::{Regex, RegexBuilder};
use std::borrow::Cow;
use std::cell::RefCell;

thread_local! {
    /* Previews and replaces run once per match or file with one pattern, and a case-insensitive pattern takes
     * tens of microseconds to compile. */
    static LAST: RefCell<Option<(String, bool, bool, Regex)>> = const { RefCell::new(None) };
}

/** The pattern as buffer search and replace match it: a regex, or else the literal text;
case-insensitive unless asked, with `.` also matching line breaks. Matches are ranges of the
searched text itself, never of a case-folded copy, and an empty literal matches nothing. */
pub(crate) fn matcher(
    pattern: &str,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<Regex, String> {
    LAST.with_borrow_mut(|last| {
        if let Some((cached, regex, case_sensitive, compiled)) = last
            && cached == pattern
            && *regex == flag_regex
            && *case_sensitive == flag_case_sensitive
        {
            return Ok(compiled.clone());
        }
        let compiled = compile(pattern, flag_regex, flag_case_sensitive)?;
        *last = Some((
            pattern.to_owned(),
            flag_regex,
            flag_case_sensitive,
            compiled.clone(),
        ));
        Ok(compiled)
    })
}

fn compile(pattern: &str, flag_regex: bool, flag_case_sensitive: bool) -> Result<Regex, String> {
    let pattern = if flag_regex {
        Cow::Borrowed(pattern)
    } else if pattern.is_empty() {
        /* An empty class never matches. */
        Cow::Borrowed(r"[^\s\S]")
    } else {
        Cow::Owned(regex::escape(pattern))
    };
    RegexBuilder::new(&pattern)
        .case_insensitive(!flag_case_sensitive)
        .dot_matches_new_line(true)
        .build()
        .map_err(|error| format!("Invalid regex pattern: {error}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn find(pattern: &str, regex: bool, case_sensitive: bool, text: &str) -> Vec<(usize, usize)> {
        matcher(pattern, regex, case_sensitive)
            .unwrap()
            .find_iter(text)
            .map(|found| (found.start(), found.end()))
            .collect()
    }

    #[test]
    fn t_matcher_ranges_are_in_the_searched_text() {
        /* "İ" lowercases to three bytes; a case-folded copy would shift every later range. */
        assert_eq!(find("A", false, false, "İab"), [(2, 3)]);
        assert_eq!(find("a.b", false, true, "axb a.b"), [(4, 7)]);
        assert_eq!(find("", false, false, "text"), []);
    }

    #[test]
    fn t_matcher_keeps_patterns_and_flags_apart() {
        /* Each call changes one part of the key of the call before it. */
        assert_eq!(find("f.o", true, false, "Fxo"), [(0, 3)]);
        assert_eq!(find("f.o", false, false, "Fxo F.o"), [(4, 7)]);
        assert_eq!(find("f.o", false, true, "F.o f.o"), [(4, 7)]);
        assert_eq!(find("F.O", false, true, "F.o F.O"), [(4, 7)]);
    }

    #[test]
    fn t_matcher_regex_follows_the_search_flags() {
        assert_eq!(find("foo", true, false, "Foo foo"), [(0, 3), (4, 7)]);
        assert_eq!(find("foo", true, true, "Foo foo"), [(4, 7)]);
        assert_eq!(find("a.b", true, true, "a\nb"), [(0, 3)]);
    }
}
