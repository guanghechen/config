//! Unit tests: fzf's own vectors (`algo_test.go`, `pattern_test.go`, v0.74.5, MIT) and properties of the
//! corpus that fzf's tests do not cover.

use super::algo::{self, Scratch, Text};
use super::class::{
    BONUS_BOUNDARY, BONUS_CAMEL123, BONUS_CONSECUTIVE, BONUS_FIRST_CHAR_MULTIPLIER, BONUS_NON_WORD,
    SCORE_GAP_EXTENSION, SCORE_GAP_START, SCORE_MATCH, Scheme, classes,
};
use super::corpus::{Corpus, Query};
use super::matcher::{self, Options};
use super::pattern::{CaseMode, TermKind, parse};

const MATCH: i32 = SCORE_MATCH as i32;
const GAP_START: i32 = SCORE_GAP_START as i32;
const GAP_EXTENSION: i32 = SCORE_GAP_EXTENSION as i32;
const BOUNDARY: i32 = BONUS_BOUNDARY as i32;
const NON_WORD: i32 = BONUS_NON_WORD as i32;
const CAMEL: i32 = BONUS_CAMEL123 as i32;
const CONSECUTIVE: i32 = BONUS_CONSECUTIVE as i32;
const FIRST: i32 = BONUS_FIRST_CHAR_MULTIPLIER as i32;
/** The default scheme, as fzf's algorithm tests run with `Init("default")`. */
const WHITE: i32 = BONUS_BOUNDARY as i32 + 2;
const DELIMITER: i32 = BONUS_BOUNDARY as i32 + 1;

#[derive(Clone, Copy, Debug)]
enum Algo {
    V1,
    V2,
    Exact,
    Prefix,
    Suffix,
    Equal,
}

fn chars(input: &str) -> Vec<char> {
    input.chars().collect()
}

/// fzf's `assertMatch`: positions, when present, decide start and end.
#[allow(clippy::too_many_arguments)]
fn assert_match(
    algo: Algo,
    case_sensitive: bool,
    forward: bool,
    input: &str,
    pattern: &str,
    start: i64,
    end: i64,
    score: i32,
) {
    let pattern = chars(&if case_sensitive {
        pattern.to_owned()
    } else {
        pattern.to_lowercase()
    });
    let input_chars = chars(input);
    let text = if input.is_ascii() {
        Text::Bytes(input.as_bytes())
    } else {
        Text::Chars(&input_chars)
    };
    let classes = classes(Scheme::Default);
    let mut scratch = Scratch::default();
    let result = match algo {
        Algo::V1 => algo::fuzzy_v1(
            classes,
            case_sensitive,
            forward,
            text,
            &pattern,
            Some(&mut scratch.positions),
        ),
        Algo::V2 => algo::fuzzy_v2(
            classes,
            case_sensitive,
            forward,
            text,
            &pattern,
            true,
            &mut scratch,
            false,
        ),
        Algo::Exact => algo::exact(classes, case_sensitive, forward, false, text, &pattern),
        Algo::Prefix => algo::prefix(classes, case_sensitive, text, &pattern),
        Algo::Suffix => algo::suffix(classes, case_sensitive, text, &pattern),
        Algo::Equal => algo::equal(classes, case_sensitive, text, &pattern),
    };
    let fuzzy = matches!(algo, Algo::V1 | Algo::V2);
    let (actual_start, actual_end, actual_score) = match result {
        None => (-1, -1, 0),
        Some(found) if fuzzy && !scratch.positions.is_empty() => {
            let positions = &mut scratch.positions;
            positions.sort_unstable();
            assert_eq!(
                positions[0], found.start,
                "a traced start is the first position"
            );
            (
                positions[0] as i64,
                *positions.last().unwrap() as i64 + 1,
                found.score,
            )
        }
        Some(found) => (found.start as i64, found.end as i64, found.score),
    };
    assert_eq!(
        (actual_start, actual_end, actual_score),
        (start, end, score),
        "{algo:?} case_sensitive={case_sensitive} forward={forward} {input:?} / {pattern:?}",
        pattern = pattern.iter().collect::<String>()
    );
}

#[test]
fn t_fzf_fuzzy_match() {
    for algo in [Algo::V1, Algo::V2] {
        for forward in [true, false] {
            let t = |cs, input, pattern, start, end, score| {
                assert_match(algo, cs, forward, input, pattern, start, end, score)
            };
            t(
                false,
                "fooBarbaz1",
                "oBZ",
                2,
                9,
                MATCH * 3 + CAMEL + GAP_START + GAP_EXTENSION * 3,
            );
            t(
                false,
                "foo bar baz",
                "fbb",
                0,
                9,
                MATCH * 3 + WHITE * FIRST + WHITE * 2 + 2 * GAP_START + 4 * GAP_EXTENSION,
            );
            t(
                false,
                "/AutomatorDocument.icns",
                "rdoc",
                9,
                13,
                MATCH * 4 + CAMEL + CONSECUTIVE * 2,
            );
            t(
                false,
                "/man1/zshcompctl.1",
                "zshc",
                6,
                10,
                MATCH * 4 + DELIMITER * FIRST + DELIMITER * 3,
            );
            t(
                false,
                "/.oh-my-zsh/cache",
                "zshc",
                8,
                13,
                MATCH * 4 + BOUNDARY * FIRST + BOUNDARY * 2 + GAP_START + DELIMITER,
            );
            t(
                false,
                ".vimrc",
                ".vimrc",
                0,
                6,
                MATCH * 6 + WHITE * (FIRST + 5),
            );
            t(
                false,
                "/.vimrc",
                ".vimrc",
                1,
                7,
                MATCH * 6 + DELIMITER * (FIRST + 5),
            );
            t(
                false,
                "a.vimrc",
                ".vimrc",
                1,
                7,
                MATCH * 6 + BOUNDARY * (FIRST + 5),
            );
            t(
                false,
                "ab0123 456",
                "12356",
                3,
                10,
                MATCH * 5 + CONSECUTIVE * 3 + GAP_START + GAP_EXTENSION,
            );
            t(
                false,
                "abc123 456",
                "12356",
                3,
                10,
                MATCH * 5 + CAMEL * FIRST + CAMEL * 2 + CONSECUTIVE + GAP_START + GAP_EXTENSION,
            );
            t(
                false,
                "foo/bar/baz",
                "fbb",
                0,
                9,
                MATCH * 3 + WHITE * FIRST + DELIMITER * 2 + 2 * GAP_START + 4 * GAP_EXTENSION,
            );
            t(
                false,
                "fooBarBaz",
                "fbb",
                0,
                7,
                MATCH * 3 + WHITE * FIRST + CAMEL * 2 + 2 * GAP_START + 2 * GAP_EXTENSION,
            );
            t(
                false,
                "foo barbaz",
                "fbb",
                0,
                8,
                MATCH * 3 + WHITE * FIRST + WHITE + GAP_START * 2 + GAP_EXTENSION * 3,
            );
            t(
                false,
                "fooBar Baz",
                "foob",
                0,
                4,
                MATCH * 4 + WHITE * FIRST + WHITE * 3,
            );
            t(
                false,
                "xFoo-Bar Baz",
                "foo-b",
                1,
                6,
                MATCH * 5 + CAMEL * FIRST + CAMEL * 2 + NON_WORD + BOUNDARY,
            );

            t(
                true,
                "fooBarbaz",
                "oBz",
                2,
                9,
                MATCH * 3 + CAMEL + GAP_START + GAP_EXTENSION * 3,
            );
            t(
                true,
                "Foo/Bar/Baz",
                "FBB",
                0,
                9,
                MATCH * 3 + WHITE * FIRST + DELIMITER * 2 + GAP_START * 2 + GAP_EXTENSION * 4,
            );
            t(
                true,
                "FooBarBaz",
                "FBB",
                0,
                7,
                MATCH * 3 + WHITE * FIRST + CAMEL * 2 + GAP_START * 2 + GAP_EXTENSION * 2,
            );
            t(
                true,
                "FooBar Baz",
                "FooB",
                0,
                4,
                MATCH * 4 + WHITE * FIRST + WHITE * 2 + CAMEL.max(WHITE),
            );
            t(true, "foo-bar", "o-ba", 2, 6, MATCH * 4 + BOUNDARY * 3);

            t(true, "fooBarbaz", "oBZ", -1, -1, 0);
            t(true, "Foo Bar Baz", "fbb", -1, -1, 0);
            t(true, "fooBarbaz", "fooBarbazz", -1, -1, 0);
        }
    }
}

#[test]
fn t_fzf_fuzzy_match_backward() {
    assert_match(
        Algo::V1,
        false,
        true,
        "foobar fb",
        "fb",
        0,
        4,
        MATCH * 2 + WHITE * FIRST + GAP_START + GAP_EXTENSION,
    );
    assert_match(
        Algo::V1,
        false,
        false,
        "foobar fb",
        "fb",
        7,
        9,
        MATCH * 2 + WHITE * FIRST + WHITE,
    );
}

#[test]
fn t_fzf_exact_match() {
    for forward in [true, false] {
        let t = |cs, input, pattern, start, end, score| {
            assert_match(Algo::Exact, cs, forward, input, pattern, start, end, score)
        };
        t(true, "fooBarbaz", "oBA", -1, -1, 0);
        t(true, "fooBarbaz", "fooBarbazz", -1, -1, 0);
        t(
            false,
            "fooBarbaz",
            "oBA",
            2,
            5,
            MATCH * 3 + CAMEL + CONSECUTIVE,
        );
        t(
            false,
            "/AutomatorDocument.icns",
            "rdoc",
            9,
            13,
            MATCH * 4 + CAMEL + CONSECUTIVE * 2,
        );
        t(
            false,
            "/man1/zshcompctl.1",
            "zshc",
            6,
            10,
            MATCH * 4 + DELIMITER * (FIRST + 3),
        );
        t(
            false,
            "/.oh-my-zsh/cache",
            "zsh/c",
            8,
            13,
            MATCH * 5 + BOUNDARY * (FIRST + 3) + DELIMITER,
        );
    }
    assert_match(
        Algo::Exact,
        false,
        true,
        "foobar foob",
        "oo",
        1,
        3,
        MATCH * 2 + CONSECUTIVE,
    );
    assert_match(
        Algo::Exact,
        false,
        false,
        "foobar foob",
        "oo",
        8,
        10,
        MATCH * 2 + CONSECUTIVE,
    );
}

#[test]
fn t_fzf_prefix_suffix_match() {
    let prefix = MATCH * 3 + WHITE * FIRST + WHITE * 2;
    for forward in [true, false] {
        let p = |cs, input, pattern, start, end, score| {
            assert_match(Algo::Prefix, cs, forward, input, pattern, start, end, score)
        };
        p(true, "fooBarbaz", "Foo", -1, -1, 0);
        p(false, "fooBarBaz", "baz", -1, -1, 0);
        p(false, "fooBarbaz", "Foo", 0, 3, prefix);
        p(false, "foOBarBaZ", "foo", 0, 3, prefix);
        p(false, "f-oBarbaz", "f-o", 0, 3, prefix);
        p(false, " fooBar", "foo", 1, 4, prefix);
        p(false, " fooBar", " fo", 0, 3, prefix);
        p(false, "     fo", "foo", -1, -1, 0);

        let s = |cs, input, pattern, start, end, score| {
            assert_match(Algo::Suffix, cs, forward, input, pattern, start, end, score)
        };
        s(true, "fooBarbaz", "Baz", -1, -1, 0);
        s(false, "fooBarbaz", "Foo", -1, -1, 0);
        s(false, "fooBarbaz", "baz", 6, 9, MATCH * 3 + CONSECUTIVE * 2);
        s(
            false,
            "fooBarBaZ",
            "baz",
            6,
            9,
            (MATCH + CAMEL) * 3 + CAMEL * (FIRST - 1),
        );
        s(
            false,
            "fooBarbaz ",
            "baz",
            6,
            9,
            MATCH * 3 + CONSECUTIVE * 2,
        );
        s(
            false,
            "fooBarbaz ",
            "baz ",
            6,
            10,
            MATCH * 4 + CONSECUTIVE * 2 + WHITE,
        );
    }
}

#[test]
fn t_fzf_empty_pattern() {
    for forward in [true, false] {
        assert_match(Algo::V1, true, forward, "foobar", "", 0, 0, 0);
        assert_match(Algo::V2, true, forward, "foobar", "", 0, 0, 0);
        assert_match(Algo::Exact, true, forward, "foobar", "", 0, 0, 0);
        assert_match(Algo::Prefix, true, forward, "foobar", "", 0, 0, 0);
        assert_match(Algo::Suffix, true, forward, "foobar", "", 6, 6, 0);
    }
}

#[test]
fn t_fzf_equal_match() {
    let pattern = parse("^AbC$", true, CaseMode::Smart);
    let term = &pattern.sets[0][0];
    assert_eq!(term.kind, TermKind::Equal);
    for (input, expected) in [
        ("ABC", None),
        ("AbC", Some((0, 3))),
        ("AbC  ", Some((0, 3))),
        (" AbC ", Some((1, 4))),
        ("  AbC", Some((2, 5))),
    ] {
        let found = algo::equal(
            classes(Scheme::Default),
            term.case_sensitive,
            Text::Bytes(input.as_bytes()),
            &term.text,
        );
        assert_eq!(
            found.map(|found| (found.start, found.end)),
            expected,
            "{input:?}"
        );
    }
    assert_match(
        Algo::Equal,
        false,
        true,
        "Danco",
        "danco",
        0,
        5,
        (MATCH + WHITE) * 5 + (FIRST - 1) * WHITE,
    );
}

#[test]
fn t_fzf_long_string() {
    let mut bytes = vec![b'x'; u16::MAX as usize * 2];
    bytes[u16::MAX as usize] = b'z';
    let input = String::from_utf8(bytes).unwrap();
    let start = u16::MAX as i64;
    assert_match(
        Algo::V2,
        true,
        true,
        &input,
        "zx",
        start,
        start + 2,
        MATCH * 2 + CONSECUTIVE,
    );
}

#[test]
fn t_fzf_positions_with_reused_scratch() {
    let classes = classes(Scheme::Default);
    let pattern = chars("co/");
    let target = "core_color/view/server.txt";
    let positions = |scratch: &mut Scratch| {
        algo::fuzzy_v2(
            classes,
            false,
            true,
            Text::Bytes(target.as_bytes()),
            &pattern,
            true,
            scratch,
            true,
        )
        .unwrap();
        scratch.positions.clone()
    };
    let fresh = positions(&mut Scratch::default());
    let mut scratch = Scratch::default();
    let dirty = "completion/keybinding/client/handler/writer_index.txt";
    algo::fuzzy_v2(
        classes,
        false,
        true,
        Text::Bytes(dirty.as_bytes()),
        &pattern,
        true,
        &mut scratch,
        true,
    );
    assert_eq!(fresh, positions(&mut scratch));
}

/// fzf checks its fast paths against the general path the same way, with test hooks that disable them.
#[test]
fn t_fast_paths_agree_with_the_general_path() {
    let alphabet = b"aAbB/_-. 1xyz";
    let mut random = Lcg(5);
    for _ in 0..20_000 {
        let text: Vec<u8> = (0..random.next(40))
            .map(|_| alphabet[random.next(alphabet.len())])
            .collect();
        let pattern: Vec<u8> = (0..1 + random.next(2))
            .map(|_| b"abAB/_ .1"[random.next(9)])
            .collect();
        for scheme in [Scheme::Default, Scheme::Path] {
            let classes = classes(scheme);
            for (case_sensitive, forward, with_pos) in
                (0..8).map(|bits| (bits & 1 == 0, bits & 2 == 0, bits & 4 == 0))
            {
                let pattern: Vec<u8> = if case_sensitive {
                    pattern.clone()
                } else {
                    pattern.to_ascii_lowercase()
                };
                let chars: Vec<char> = pattern.iter().map(|&byte| byte as char).collect();
                let expected = algo::fuzzy_index(Text::Bytes(&text), &chars, case_sensitive)
                    .and_then(|(min, max)| {
                        let mut scratch = Scratch::default();
                        let mut t = text[min..max].to_vec();
                        let found = algo::general(
                            classes,
                            case_sensitive,
                            forward,
                            &mut t,
                            &pattern,
                            min,
                            with_pos,
                            &mut scratch,
                        );
                        scratch.positions.sort_unstable();
                        found.map(|found| (found, scratch.positions))
                    });
                let mut scratch = Scratch::default();
                let actual = if pattern.len() == 1 {
                    algo::single(
                        classes,
                        case_sensitive,
                        forward,
                        &text,
                        pattern[0],
                        with_pos,
                        &mut scratch,
                    )
                } else {
                    algo::fuzzy_index(Text::Bytes(&text), &chars, case_sensitive).and_then(
                        |(min, max)| {
                            let pair = (pattern[0], pattern[1]);
                            algo::two(
                                classes,
                                case_sensitive,
                                forward,
                                &text,
                                pair,
                                min,
                                max,
                                with_pos,
                                &mut scratch,
                            )
                        },
                    )
                };
                scratch.positions.sort_unstable();
                let actual = actual.map(|found| (found, scratch.positions));
                assert_eq!(
                    actual,
                    expected,
                    "{scheme:?} case_sensitive={case_sensitive} forward={forward} with_pos={with_pos} {:?} / {:?}",
                    String::from_utf8_lossy(&text),
                    String::from_utf8_lossy(&pattern)
                );
            }
        }
    }
}

#[test]
fn t_byte_search_finds_first_and_last_occurrences() {
    let mut random = Lcg(9);
    for _ in 0..5000 {
        let text: Vec<u8> = (0..random.next(40))
            .map(|_| b"aAbB/xyz"[random.next(8)])
            .collect();
        for (byte, case_sensitive) in [(b'a', false), (b'a', true), (b'A', true), (b'/', false)] {
            let matches = |&value: &u8| {
                value == byte || !case_sensitive && value.to_ascii_lowercase() == byte
            };
            let pattern = [byte as char];
            let expected = text.iter().position(matches).map(|first| {
                let last = text.iter().rposition(matches).unwrap();
                (first.saturating_sub(1), last + 1)
            });
            assert_eq!(
                algo::fuzzy_index(Text::Bytes(&text), &pattern, case_sensitive),
                expected,
                "{text:?} {byte}"
            );
        }
    }
}

#[test]
fn t_fzf_parse_terms_extended() {
    let pattern = parse(
        "aaa 'bbb ^ccc ddd$ !eee !'fff !^ggg !hhh$ | ^iii$ ^xxx | 'yyy | zzz$ | !ZZZ |",
        true,
        CaseMode::Smart,
    );
    let kinds: Vec<Vec<(TermKind, bool)>> = pattern
        .sets
        .iter()
        .map(|set| set.iter().map(|term| (term.kind, term.inverse)).collect())
        .collect();
    use TermKind::*;
    assert_eq!(
        kinds,
        vec![
            vec![(Fuzzy, false)],
            vec![(Exact, false)],
            vec![(Prefix, false)],
            vec![(Suffix, false)],
            vec![(Exact, true)],
            vec![(Fuzzy, true)],
            vec![(Prefix, true)],
            vec![(Suffix, true), (Equal, false)],
            vec![
                (Prefix, false),
                (Exact, false),
                (Suffix, false),
                (Exact, true)
            ],
        ]
    );
    assert!(pattern.sets[..8].iter().all(|set| set[0].text.len() == 3));
    assert!(pattern.sets[8][3].case_sensitive);
}

#[test]
fn t_fzf_parse_terms_extended_exact() {
    let pattern = parse(
        "aaa 'bbb ^ccc ddd$ !eee !'fff !^ggg !hhh$",
        false,
        CaseMode::Smart,
    );
    use TermKind::*;
    let kinds: Vec<(TermKind, bool)> = pattern
        .sets
        .iter()
        .map(|set| (set[0].kind, set[0].inverse))
        .collect();
    assert_eq!(
        kinds,
        vec![
            (Exact, false),
            (Fuzzy, false),
            (Prefix, false),
            (Suffix, false),
            (Exact, true),
            (Fuzzy, true),
            (Prefix, true),
            (Suffix, true)
        ]
    );
    assert!(pattern.sets.iter().all(|set| set[0].text.len() == 3));
}

#[test]
fn t_fzf_parse_terms_empty() {
    assert!(parse("' ^ !' !^", true, CaseMode::Smart).sets.is_empty());
}

#[test]
fn t_fzf_case_sensitivity() {
    let term = |query: &str, case| {
        let pattern = parse(query, true, case);
        let term = &pattern.sets[0][0];
        (term.text.iter().collect::<String>(), term.case_sensitive)
    };
    assert_eq!(term("abc", CaseMode::Smart), ("abc".into(), false));
    assert_eq!(term("Abc", CaseMode::Smart), ("Abc".into(), true));
    assert_eq!(term("abc", CaseMode::Ignore), ("abc".into(), false));
    assert_eq!(term("Abc", CaseMode::Ignore), ("abc".into(), false));
    assert_eq!(term("abc", CaseMode::Respect), ("abc".into(), true));
    assert_eq!(term("Abc", CaseMode::Respect), ("Abc".into(), true));
}

#[test]
fn t_fzf_cacheable() {
    let cacheable = |fuzzy, query| parse(query, fuzzy, CaseMode::Smart).cacheable;
    assert!(cacheable(true, "foo bar"));
    assert!(!cacheable(true, "foo 'bar"));
    assert!(!cacheable(true, "foo !bar"));
    assert!(cacheable(false, "foo bar"));
    assert!(!cacheable(false, "foo 'bar"));
    assert!(cacheable(false, "foo '"));
    assert!(!cacheable(false, "foo !bar"));
    assert!(!cacheable(true, "foo | bar baz"));
    assert!(cacheable(true, "foo\\ bar"));
}

#[test]
fn t_fzf_cache_key() {
    let key = |fuzzy, query| parse(query, fuzzy, CaseMode::Smart).key;
    assert_eq!(key(true, "foo bar"), "foo\tbar");
    assert_eq!(key(true, "foo | bar baz"), "baz");
    assert_eq!(key(true, "foo !bar ^baz"), "foo\tbaz");
    assert_eq!(key(false, "foo 'bar ^baz"), "foo");
    assert_eq!(key(true, "core |"), "core");
    assert_eq!(key(true, "foo\\ bar"), "foo bar");
}

#[test]
fn t_fzf_extended_match_or_and_inverse() {
    let classes = classes(Scheme::Default);
    let options = Options {
        forward: true,
        with_pos: true,
        fallback: true,
    };
    let matches = |query: &str, item: &str| {
        let pattern = parse(query, true, CaseMode::Smart);
        matcher::match_item(
            classes,
            &pattern,
            Text::Bytes(item.as_bytes()),
            &options,
            &mut Scratch::default(),
            None,
        )
    };
    // The first matching term of a set gives its score.
    assert!(matches("zzz | abc", "xabcx").is_some());
    assert!(matches("zzz | qqq", "xabcx").is_none());
    // An inverse term matches when its text is absent, scoring nothing.
    assert_eq!(matches("!qqq", "xabcx").unwrap().score, 0);
    assert!(matches("!abc", "xabcx").is_none());
    // Every set must match, scores add up.
    let both = matches("ab cx", "xabcx").unwrap().score;
    assert_eq!(
        both,
        matches("ab", "xabcx").unwrap().score + matches("cx", "xabcx").unwrap().score
    );
    assert!(matches("ab zz", "xabcx").is_none());
}

/// A deterministic generator, so property tests are reproducible.
struct Lcg(u64);

impl Lcg {
    fn next(&mut self, bound: usize) -> usize {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        ((self.0 >> 33) as usize) % bound
    }
}

fn sample_corpus(count: usize, seed: u64) -> Vec<String> {
    let words = [
        "src", "main", "core", "config", "parser", "render", "Server", "client", "index",
        "handler", "util", "列表", "café",
    ];
    let extensions = [".rs", ".lua", ".md", ".go", ""];
    let mut random = Lcg(seed);
    (0..count)
        .map(|_| {
            let depth = 1 + random.next(4);
            let mut path: Vec<String> = (0..depth)
                .map(|_| {
                    let mut word = words[random.next(words.len())].to_owned();
                    if random.next(4) == 0 {
                        word = format!("{word}_{}", words[random.next(words.len())]);
                    }
                    word
                })
                .collect();
            let last = path.pop().unwrap();
            path.push(format!(
                "{last}{}",
                extensions[random.next(extensions.len())]
            ));
            path.join("/")
        })
        .collect()
}

fn query(pattern: &str, rank: bool) -> Query<'_> {
    Query {
        pattern,
        fuzzy: true,
        case: CaseMode::Smart,
        rank,
        weight: 0,
        threads: 1,
    }
}

#[test]
fn t_corpus_narrowing_matches_a_full_scan() {
    let items = sample_corpus(3000, 7);
    for scheme in [Scheme::Path, Scheme::Default] {
        let mut typed = Corpus::new(scheme);
        typed.append(&items).unwrap();
        let typing = [
            "s", "sr", "src", "src/", "src/c", "src/co", "src/con", "c", "co", "cor", "core", "|",
            "core |", "| core", "core !md", "core |", "^src", "src co", "rc o", "Src", "src\\ ",
            "s c",
        ];
        for pattern in typing {
            let mut fresh = Corpus::new(scheme);
            fresh.append(&items).unwrap();
            let expected = fresh.query(&query(pattern, true));
            let narrowed = typed.query(&query(pattern, true));
            assert_eq!(narrowed.indices, expected.indices, "{scheme:?} {pattern}");
            assert_eq!(narrowed.scores, expected.scores, "{scheme:?} {pattern}");
        }
        // Extending a query only ever examines the previous matches.
        let before = typed.query(&query("ser", true)).indices.len();
        assert!(typed.query(&query("serv", true)).examined <= before);
    }
}

#[test]
fn t_corpus_membership_agrees_with_scoring() {
    let items = sample_corpus(2000, 11);
    let mut corpus = Corpus::new(Scheme::Path);
    corpus.append(&items).unwrap();
    for pattern in [
        "c",
        "cr",
        "Srv",
        "rs$",
        "^src",
        "'core",
        "!md",
        "cli | ser",
        "ma co",
        "列",
        "caf",
        "zzz",
    ] {
        let mut ranked = corpus.query(&query(pattern, true)).indices;
        ranked.sort_unstable();
        assert_eq!(
            corpus.query(&query(pattern, false)).indices,
            ranked,
            "{pattern}"
        );
    }
}

#[test]
fn t_corpus_threads_match_one_thread() {
    let items = sample_corpus(40_000, 3);
    let mut corpus = Corpus::new(Scheme::Path);
    corpus.append(&items).unwrap();
    for pattern in ["s", "cfg", "src core", "ha.rs$"] {
        let single = corpus.query(&Query {
            threads: 1,
            ..query(pattern, true)
        });
        let many = corpus.query(&Query {
            threads: 6,
            ..query(pattern, true)
        });
        assert_eq!(single.indices, many.indices, "{pattern}");
        assert_eq!(single.scores, many.scores, "{pattern}");
    }
}

#[test]
fn t_corpus_ranks_by_score_then_pathname_length_and_index() {
    let mut corpus = Corpus::new(Scheme::Path);
    corpus
        .append(&[
            "a/b/foo.lua",
            "foo/bar.lua",
            "x/foo.lua",
            "xx/foo.lua",
            "foo.lua",
        ])
        .unwrap();
    let ranked = corpus.query(&query("foo", true));
    let order: Vec<&str> = ranked
        .indices
        .iter()
        .map(|&index| corpus.text(index as usize))
        .collect();
    // Equal scores: matches in the basename first, then shorter items, then item order.
    assert_eq!(
        order,
        vec![
            "foo.lua",
            "x/foo.lua",
            "xx/foo.lua",
            "a/b/foo.lua",
            "foo/bar.lua"
        ]
    );
}

/// The packed radix-sorted ranking against a direct reading of fzf's `buildResult` and comparison sort.
#[test]
fn t_corpus_ranking_matches_a_reference_sort() {
    let items = sample_corpus(6000, 21);
    let mut corpus = Corpus::new(Scheme::Path);
    corpus.append(&items).unwrap();
    let classes = classes(Scheme::Path);
    let options = Options {
        forward: false,
        with_pos: true,
        fallback: true,
    };
    for pattern_text in [
        "c",
        "co",
        "cfg",
        "src core",
        "Ser",
        "rs$",
        "'main",
        "ha.lua | cl.go",
        "列表",
        "!md cor",
    ] {
        let pattern = parse(pattern_text, true, CaseMode::Smart);
        let mut expected: Vec<(i32, u16, u16, u32)> = Vec::new();
        for (index, item) in items.iter().enumerate() {
            let chars = chars(item);
            let text = if item.is_ascii() {
                Text::Bytes(item.as_bytes())
            } else {
                Text::Chars(&chars)
            };
            let Some(found) = matcher::match_item(
                classes,
                &pattern,
                text,
                &options,
                &mut Scratch::default(),
                None,
            ) else {
                continue;
            };
            let last_delimiter = chars
                .iter()
                .rposition(|&char| char == '/' || char == '\\')
                .map_or(-1, |at| at as i64);
            let pathname = match found.begin {
                Some(begin) if last_delimiter <= begin as i64 => {
                    (begin as i64 - last_delimiter).min(255) as u16
                }
                _ => 255,
            };
            expected.push((found.score, pathname, text.trim_len() as u16, index as u32));
        }
        expected.sort_by(|left, right| {
            right
                .0
                .cmp(&left.0)
                .then(left.1.cmp(&right.1))
                .then(left.2.cmp(&right.2))
                .then(left.3.cmp(&right.3))
        });
        let ranked = corpus.query(&query(pattern_text, true));
        let order: Vec<u32> = expected.iter().map(|hit| hit.3).collect();
        assert!(!order.is_empty(), "{pattern_text}");
        assert_eq!(ranked.indices, order, "{pattern_text}");
        assert_eq!(
            ranked.scores,
            expected.iter().map(|hit| hit.0).collect::<Vec<_>>(),
            "{pattern_text}"
        );
    }
}

#[test]
fn t_corpus_weights_reorder_close_scores() {
    let mut corpus = Corpus::new(Scheme::Path);
    corpus.append(&["lib/foo.lua", "src/foo.lua"]).unwrap();
    corpus.set_weights(&[0, 100]).unwrap();
    let weighted = Query {
        weight: 32,
        ..query("foo", true)
    };
    assert_eq!(corpus.query(&weighted).indices, vec![1, 0]);
    assert_eq!(corpus.query(&query("foo", true)).indices, vec![0, 1]);
    assert!(corpus.set_weights(&[1]).is_err());
}

#[test]
fn t_corpus_positions_are_byte_ranges() {
    let mut corpus = Corpus::new(Scheme::Path);
    corpus
        .append(&["文档/café_core.rs", "src/core.rs"])
        .unwrap();
    let ranked = corpus.query(&query("cfcore", true));
    assert_eq!(ranked.indices, vec![0]);
    let ranges = corpus.positions(0, &ranked);
    let text = corpus.text(0);
    let highlighted: String = ranges
        .iter()
        .map(|&(start, end)| &text[start..end])
        .collect();
    assert_eq!(highlighted, "cfcore");
    assert_eq!(corpus.positions(1, &ranked), Vec::<(usize, usize)>::new());
}

#[test]
fn t_corpus_empty_pattern_lists_every_item() {
    let mut corpus = Corpus::new(Scheme::Default);
    corpus.append(&["b", "a", "c"]).unwrap();
    corpus.set_weights(&[0, 100, 50]).unwrap();
    assert_eq!(corpus.query(&query("  ", true)).indices, vec![0, 1, 2]);
    assert_eq!(
        corpus
            .query(&Query {
                weight: 10,
                ..query("", true)
            })
            .indices,
        vec![1, 2, 0]
    );
    // Without match scores, raw weights order the items even where the weighted bonus rounds to a tie.
    corpus.set_weights(&[3, 4, 3]).unwrap();
    let weighted = Query {
        weight: 10,
        ..query("", true)
    };
    assert_eq!(corpus.query(&weighted).indices, vec![1, 0, 2]);
    assert_eq!(
        corpus
            .query(&Query {
                weight: 10,
                ..query("!zzz", true)
            })
            .indices,
        vec![1, 0, 2]
    );
}
