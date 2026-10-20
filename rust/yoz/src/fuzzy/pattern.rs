//! fzf's extended search syntax (`pattern.go`, MIT): space-separated terms that must all match, `|` between
//! alternatives, and `'`, `^`, `$`, `!` modifiers.

/// How a term with no case of its own decides case sensitivity.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CaseMode {
    /** Case-sensitive only when the term has an uppercase character. */
    Smart,
    Respect,
    Ignore,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum TermKind {
    Fuzzy,
    Exact,
    /** `'text'`: exact, with a word boundary at both ends. */
    ExactBoundary,
    Prefix,
    Suffix,
    Equal,
}

#[derive(Clone, Debug)]
pub(crate) struct Term {
    pub(crate) kind: TermKind,
    pub(crate) inverse: bool,
    /** Lowercase unless `case_sensitive`. */
    pub(crate) text: Vec<char>,
    pub(crate) case_sensitive: bool,
}

impl Term {
    /// ASCII characters an item must contain, case folded; `None` when some character is not ASCII.
    pub(crate) fn ascii_mask(&self) -> Option<u128> {
        let mut mask = 0u128;
        for &char in &self.text {
            if !char.is_ascii() {
                return None;
            }
            mask |= 1 << (char.to_ascii_lowercase() as u32);
        }
        Some(mask)
    }
}

#[derive(Clone, Debug)]
pub(crate) struct Pattern {
    /** Every set must match; within a set the first matching term counts. */
    pub(crate) sets: Vec<Vec<Term>>,
    /** Results of this query can serve later queries whose keys extend this key. */
    pub(crate) cacheable: bool,
    /** fzf leaves results unsorted when every term is inverse. */
    pub(crate) sortable: bool,
    /** Texts of the terms that bound the results, tab-separated: the key for result caches. */
    pub(crate) key: String,
}

/// Trims unescaped surrounding spaces as fzf does for extended queries.
fn trim(query: &str) -> String {
    let mut text = query.trim_start_matches(' ').to_owned();
    while text.ends_with(' ') && !text.ends_with("\\ ") {
        text.pop();
    }
    text
}

pub(crate) fn parse(query: &str, fuzzy: bool, case: CaseMode) -> Pattern {
    let source = trim(query).replace("\\ ", "\t");
    let base = if fuzzy {
        TermKind::Fuzzy
    } else {
        TermKind::Exact
    };
    let mut sets: Vec<Vec<Term>> = Vec::new();
    let mut set: Vec<Term> = Vec::new();
    let mut switch_set = false;
    let mut after_bar = false;
    for token in source.split(' ').filter(|token| !token.is_empty()) {
        let mut text = token.replace('\t', " ");
        let lower = text.to_lowercase();
        let case_sensitive = case == CaseMode::Respect || case == CaseMode::Smart && text != lower;
        if !case_sensitive {
            text = lower;
        }
        let mut kind = base;
        let mut inverse = false;

        if !set.is_empty() && !after_bar && text == "|" {
            switch_set = false;
            after_bar = true;
            continue;
        }
        after_bar = false;

        if let Some(rest) = text.strip_prefix('!') {
            inverse = true;
            kind = TermKind::Exact;
            text = rest.to_owned();
        }
        if text != "$" && text.ends_with('$') {
            kind = TermKind::Suffix;
            text.pop();
        }
        if text.len() > 2 && text.starts_with('\'') && text.ends_with('\'') {
            kind = TermKind::ExactBoundary;
            text = text[1..text.len() - 1].to_owned();
        } else if let Some(rest) = text.strip_prefix('\'') {
            // Flips exactness.
            kind = if fuzzy && !inverse {
                TermKind::Exact
            } else {
                TermKind::Fuzzy
            };
            text = rest.to_owned();
        } else if let Some(rest) = text.strip_prefix('^') {
            kind = if kind == TermKind::Suffix {
                TermKind::Equal
            } else {
                TermKind::Prefix
            };
            text = rest.to_owned();
        }

        if !text.is_empty() {
            if switch_set {
                sets.push(std::mem::take(&mut set));
            }
            set.push(Term {
                kind,
                inverse,
                text: text.chars().collect(),
                case_sensitive,
            });
            switch_set = true;
        }
    }
    if !set.is_empty() {
        sets.push(set);
    }

    let mut cacheable = true;
    let mut sortable = false;
    'sets: for set in &sets {
        for (index, term) in set.iter().enumerate() {
            if !term.inverse {
                sortable = true;
            }
            if index > 0 || term.inverse || term.kind != base {
                cacheable = false;
                if sortable {
                    break 'sets;
                }
            }
        }
    }
    let sortable = sortable || sets.is_empty();
    // fzf's `buildCacheKey`: the terms whose matches contain the pattern's, so that the results of a key's
    // prefix or suffix contain the results of the key.
    let key = sets
        .iter()
        .filter(|set| {
            set.len() == 1 && !set[0].inverse && (fuzzy || set[0].kind == TermKind::Exact)
        })
        .map(|set| set[0].text.iter().collect::<String>())
        .collect::<Vec<_>>()
        .join("\t");
    Pattern {
        sets,
        cacheable,
        sortable,
        key,
    }
}
