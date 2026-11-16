use super::document::Document;
use super::language::{self, Class, Kind, Token};

fn lines(text: &str) -> Vec<Box<[u8]>> {
    text.split('\n')
        .map(|line| Box::from(line.as_bytes()))
        .collect()
}

fn parse(language: &str, text: &str) -> Document {
    let mut document = Document::new(language::language(language).expect("known language"), 4);
    document.edit(0, 0, lines(text));
    document.settle();
    document
}

#[derive(Clone, Copy, Debug)]
struct Item {
    row: usize,
    col: usize,
    kind: Kind,
    token: &'static Token,
    height: Option<u32>,
}

impl Item {
    fn text(&self) -> &'static str {
        if self.kind == Kind::Closing && !self.token.close.is_empty() {
            self.token.close
        } else {
            self.token.open
        }
    }

    fn before(&self, row: usize, col: usize) -> bool {
        self.row < row || (self.row == row && self.col < col)
    }
}

fn items(document: &Document) -> Vec<Item> {
    (0..document.line_count())
        .flat_map(|row| {
            document
                .row_tokens(row)
                .into_iter()
                .map(move |(col, kind, token, height)| Item {
                    row,
                    col,
                    kind,
                    token,
                    height,
                })
        })
        .collect()
}

/// Rows of (column, text, height).
fn rows(document: &Document) -> Vec<Vec<(usize, &'static str, Option<u32>)>> {
    let mut rows = vec![Vec::new(); document.line_count()];
    for item in items(document) {
        rows[item.row].push((item.col, item.text(), item.height));
    }
    rows
}

#[test]
fn t_tokens_follow_blink_states() {
    assert_eq!(
        rows(&parse("c", "{\n}")),
        vec![vec![(0, "{", Some(0))], vec![(0, "}", Some(0))]]
    );
    assert_eq!(
        rows(&parse("c", "// comment {}\n}")),
        vec![vec![(0, "//", None)], vec![(0, "}", None)]]
    );
    assert_eq!(
        rows(&parse("c", "/* comment {} */\n}")),
        vec![
            vec![(0, "/*", Some(0)), (14, "*/", Some(0))],
            vec![(0, "}", None)]
        ]
    );
    // An escaped `%` does not start a comment.
    assert_eq!(
        rows(&parse("latex", "test 90\\% ( and b )\n%abc")),
        vec![
            vec![(10, "(", Some(0)), (18, ")", Some(0))],
            vec![(0, "%", None)]
        ]
    );
    // Strings join the stack; an escaped quote stays inside; paired backslashes escape nothing.
    assert_eq!(
        rows(&parse("javascript", "( \"a)\" )\n\"a\\\"b\"\n\"a\\\\\" ]")),
        vec![
            vec![
                (0, "(", Some(0)),
                (2, "\"", Some(1)),
                (5, "\"", Some(1)),
                (7, ")", Some(0))
            ],
            vec![(0, "\"", Some(0)), (5, "\"", Some(0))],
            vec![(0, "\"", Some(0)), (4, "\"", Some(0)), (6, "]", None)],
        ]
    );
    // A string, a line comment and an inline span end with their line.
    assert_eq!(
        rows(&parse("javascript", "\"open (\n)")),
        vec![vec![(0, "\"", None)], vec![(0, ")", None)]]
    );
}

#[test]
fn t_character_literals_close_one_or_two_bytes_later() {
    // `'{'` hides its brace; a lifetime is no literal.
    assert_eq!(
        rows(&parse("rust", "let c = '{';\nfn f<'a>(x: &'a str) {}")),
        vec![
            vec![(8, "'", Some(0)), (10, "'", Some(0))],
            vec![
                (8, "(", Some(0)),
                (19, ")", Some(0)),
                (21, "{", Some(0)),
                (22, "}", Some(0))
            ],
        ]
    );
    // `'x'` closes two bytes later; so does `'\''`, at the escaped quote.
    assert_eq!(
        rows(&parse("c", "'x' '\\''")),
        vec![vec![
            (0, "'", Some(0)),
            (2, "'", Some(0)),
            (4, "'", Some(0)),
            (6, "'", Some(0))
        ]]
    );
}

#[test]
fn t_block_tokens_cross_lines_and_patterns_keep_their_order() {
    // Lua: `--[[` wins over `--`; brackets inside comments and long strings are ignored.
    assert_eq!(
        rows(&parse("lua", "--[[ (\n]] )\nx = [[ { ]] -- (")),
        vec![
            vec![(0, "--[[", Some(0))],
            vec![(0, "]]", Some(0)), (3, ")", None)],
            vec![(4, "[[", Some(0)), (9, "]]", Some(0)), (12, "--", None)],
        ]
    );
    // Latex lists `$` before `$$`, so `$$` reads as two single-dollar strings.
    assert_eq!(
        rows(&parse("latex", "$$ x $$")),
        vec![vec![
            (0, "$", Some(0)),
            (1, "$", Some(0)),
            (5, "$", Some(0)),
            (6, "$", Some(0))
        ]]
    );
    // Markdown's `bold` is `**` only.
    assert_eq!(
        rows(&parse("markdown", "*a* **b** `c`")),
        vec![vec![(4, "**", Some(0)), (7, "**", Some(0))]]
    );
    // Zig's `\\` comment never applies: backslashes are escapes first.
    assert_eq!(rows(&parse("zig", "\\\\ (")), vec![vec![(3, "(", None)]]);
}

#[test]
fn t_raw_strings_have_no_escapes() {
    // A backslash hides no raw string's closing, unlike a regular string's.
    assert_eq!(
        rows(&parse("rust", r##"f(r"C:\", r#"\"#, "\"")"##)),
        vec![vec![
            (1, "(", Some(0)),
            (2, "r\"", Some(1)),
            (7, "\"", Some(1)),
            (10, "r#\"", Some(1)),
            (14, "\"#", Some(1)),
            (18, "\"", Some(1)),
            (21, "\"", Some(1)),
            (22, ")", Some(0))
        ]]
    );
    for (language, text, closing) in [
        ("lua", r"x = [[C:\]] .. f(y)", (9, "]]")),
        ("go", r"x := `C:\`; f(y)", (9, "`")),
        ("cpp", r#"R"(C:\)" f(y)"#, (6, ")\"")),
        ("csharp", r#"@"C:\" f(y)"#, (5, "\"")),
        ("csharp", r#""""C:\(""" f(y)"#, (7, "\"\"\"")),
    ] {
        let rows = rows(&parse(language, text));
        assert_eq!(rows[0][1], (closing.0, closing.1, Some(0)), "{language}");
        assert!(
            rows[0][2..].iter().all(|token| token.2 == Some(0)),
            "{language}: {rows:?}"
        );
    }
}

#[test]
fn t_inside_tells_the_string_comment_or_span_of_a_position() {
    let document = parse("lua", "f(\"a(\", 'b') -- c\nx = [[\nd(]] .. y");
    for (row, col, class) in [
        (0, 1, None),
        (0, 2, None),
        (0, 3, Some(Class::String)),
        (0, 5, Some(Class::String)),
        (0, 6, None),
        (0, 9, Some(Class::String)),
        (0, 14, None),
        (0, 15, Some(Class::LineComment)),
        (1, 6, Some(Class::BlockString)),
        (2, 0, Some(Class::BlockString)),
        (2, 2, Some(Class::BlockString)),
        (2, 3, None),
        (2, 4, None),
    ] {
        assert_eq!(document.inside(row, col), class, "{row}:{col}");
    }
    // A character literal is a string; past the last row is code.
    let document = parse("rust", "let c = '(';");
    assert_eq!(document.inside(0, 9), Some(Class::String));
    assert_eq!(document.inside(1, 0), None);
}

#[test]
fn t_skipped_openings_are_unmatched_and_indent_rematching_moves_them() {
    assert_eq!(
        rows(&parse("c", "( [ )")),
        vec![vec![(0, "(", Some(0)), (2, "[", None), (4, ")", Some(0))]]
    );
    // The stack pairs the inner `{`; indentation shows the outer one is the open one.
    assert_eq!(
        rows(&parse("rust", "fn a() {\n    if x {\n}")),
        vec![
            vec![(4, "(", Some(0)), (5, ")", Some(0)), (7, "{", Some(0))],
            vec![(9, "{", None)],
            vec![(0, "}", Some(0))],
        ]
    );
}

#[test]
fn t_indent_rematching_stops_past_256_unmatched_openings() {
    // The outer `{` takes the closing by indent while 256 openings are unmatched, itself included; one more and the
    // stack pass's pairs stand.
    let outer = |strays: usize| {
        let text = format!("fn a() {{\n    if x {{\n}}\n{}", "(".repeat(strays));
        rows(&parse("rust", &text))[0][2]
    };
    assert_eq!(outer(255), (7, "{", Some(0)));
    assert_eq!(outer(256), (7, "{", None));
}

#[test]
fn t_pair_ends_measure_their_own_text() {
    // Rematching moves `r#"a"#` apart, so its opening pairs with the next opening at its height: three bytes long.
    let document = parse(
        "rust",
        r##"f(x, {
    if y {
}
); g(r#"a"#);
let s = r#"b"#;"##,
    );
    assert_eq!(document.match_pair(3, 5), Some(((3, 5, 3), (4, 8, 3))));
}

// The queries below follow blink.pairs' scans over every token; the document answers them with partner links and
// skips. Random documents compare the two.

fn naive_match_at(items: &[Item], row: usize, col: usize) -> Option<usize> {
    items.iter().position(|item| {
        item.row == row && (item.col..item.col + item.token.len(item.kind)).contains(&col)
    })
}

fn naive_match_pair(items: &[Item], index: usize) -> Option<(usize, usize)> {
    let item = items[index];
    if item.token.class == Class::Delimiter && item.height.is_none() {
        return None;
    }
    let same = |other: &Item| std::ptr::eq(other.token, item.token) && other.height == item.height;
    match item.kind {
        Kind::Opening => (index + 1..items.len())
            .find(|&other| same(&items[other]))
            .map(|other| (index, other)),
        Kind::Closing => (0..index)
            .rev()
            .find(|&other| same(&items[other]))
            .map(|other| (other, index)),
        Kind::NonPair => None,
    }
}

fn naive_surrounding(items: &[Item], row: usize, col: usize) -> Option<(usize, usize)> {
    if let Some(index) = naive_match_at(items, row, col) {
        return naive_match_pair(items, index);
    }
    (0..items.len())
        .rev()
        .filter(|&index| items[index].before(row, col))
        .find(|&index| {
            items[index].kind == Kind::Opening
                && naive_match_pair(items, index)
                    .is_some_and(|(_, close)| !items[close].before(row, col + 1))
        })
        .and_then(|index| naive_match_pair(items, index))
}

fn naive_height_at(items: &[Item], row: usize, col: usize) -> u32 {
    let step = |count: &mut u32, item: &Item| {
        if item.token.class == Class::Delimiter {
            match item.kind {
                Kind::Opening => *count = count.saturating_add(1),
                Kind::Closing => *count = count.saturating_sub(1),
                Kind::NonPair => {}
            }
        }
    };
    let mut count = 0;
    for item in items.iter().filter(|item| !item.before(row, col)) {
        if let Some(height) = item.height {
            return (height + u32::from(item.kind == Kind::Closing)).saturating_sub(count);
        }
        step(&mut count, item);
    }
    count = 0;
    for item in items.iter().rev().filter(|item| item.before(row, col)) {
        if let Some(height) = item.height {
            return (height + u32::from(item.kind == Kind::Opening)).saturating_sub(count);
        }
        step(&mut count, item);
    }
    0
}

fn naive_unmatched(
    items: &[Item],
    open: &str,
    close: &str,
    row: usize,
    col: usize,
    forward: bool,
) -> Option<(usize, usize)> {
    let target = |item: &Item| {
        item.token.class == Class::Delimiter && item.token.open == open && item.token.close == close
    };
    let (lower, upper) = if forward {
        (Kind::Closing, Kind::Opening)
    } else {
        (Kind::Opening, Kind::Closing)
    };
    let mut lowest = naive_height_at(items, row, col);
    let mut current = lowest;
    let ordered: Vec<&Item> = if forward {
        items.iter().filter(|item| !item.before(row, col)).collect()
    } else {
        items
            .iter()
            .rev()
            .filter(|item| item.before(row, col))
            .collect()
    };
    for item in ordered
        .into_iter()
        .filter(|item| item.token.class == Class::Delimiter)
    {
        if let Some(height) = item.height {
            if height < lowest {
                if item.kind == lower && target(item) {
                    lowest = height;
                } else {
                    return None;
                }
            }
            current = height + u32::from(item.kind == upper);
        }
        if item.kind == lower && target(item) && item.height.is_none() && current == lowest {
            return Some((item.row, item.col));
        }
    }
    None
}

/** A deterministic xorshift generator. */
struct Random(u64);

impl Random {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }

    fn below(&mut self, bound: usize) -> usize {
        (self.next() % bound as u64) as usize
    }

    fn pick<'a>(&mut self, values: &[&'a str]) -> &'a str {
        values[self.below(values.len())]
    }
}

#[rustfmt::skip]
const FRAGMENTS: &[(&str, &[&str])] = &[
    ("lua", &["(", ")", "[", "]", "{", "}", "\"", "'", "--", "--[[", "]]", "[[", "\\", " ", "x", "foo"]),
    ("rust", &["(", ")", "[", "]", "{", "}", "\"", "'", "r\"", "r#\"", "\"#", "//", "/*", "*/", "\\", " ", "x", "'a"]),
    ("c", &["(", ")", "[", "]", "{", "}", "\"", "'", "//", "/*", "*/", "\\", " ", "x"]),
    ("python", &["(", ")", "[", "]", "{", "}", "\"", "'", "\"\"\"", "'''", "#", "\\", " ", "x"]),
    ("javascript", &["(", ")", "[", "]", "{", "}", "\"", "'", "`", "//", "/*", "*/", "\\", " ", "x"]),
    ("markdown", &["$", "$$", "_", "**", "~~", "```", "*", "(", ")", "\\", " ", "x"]),
    ("latex", &["(", ")", "[", "]", "{", "}", "$", "$$", "%", "\\", "'", "\"", " ", "x"]),
    ("sql", &["(", ")", "\"", "'", "$$", "`", "--", "#", "/*", "*/", " ", "x"]),
    ("ruby", &["(", ")", "{", "}", "=begin", "end", "#", "\"", "'", " ", "x"]),
    ("cpp", &["(", ")", "{", "}", "R\"(", ")\"", "\"", "'", "//", " ", "x"]),
];

fn random_line(random: &mut Random, fragments: &[&str]) -> String {
    let mut line = String::new();
    for _ in 0..random.below(3) {
        line.push_str(if random.below(3) == 0 { "\t" } else { "    " });
    }
    for _ in 0..random.below(10) {
        line.push_str(random.pick(fragments));
    }
    line
}

fn random_text(random: &mut Random, fragments: &[&str], count: usize) -> Vec<String> {
    (0..count).map(|_| random_line(random, fragments)).collect()
}

#[test]
fn t_queries_answer_like_full_scans() {
    let mut random = Random(0x9e37_79b9_7f4a_7c15);
    for &(language, fragments) in FRAGMENTS {
        for _ in 0..60 {
            let count = 1 + random.below(14);
            let text = random_text(&mut random, fragments, count).join("\n");
            let document = parse(language, &text);
            let items = items(&document);
            let end = |item: Item| (item.row, item.col, item.token.len(item.kind));
            let at = |pair: Option<(usize, usize)>| {
                pair.map(|(open, close)| (end(items[open]), end(items[close])))
            };
            let text_lines: Vec<&str> = text.split('\n').collect();
            for (row, line) in text_lines.iter().enumerate() {
                for col in 0..=line.len() + 1 {
                    let pair = naive_match_at(&items, row, col)
                        .and_then(|index| naive_match_pair(&items, index));
                    assert_eq!(
                        document.match_pair(row, col),
                        at(pair),
                        "match_pair {language} {row}:{col}\n{text}"
                    );
                    assert_eq!(
                        document.surrounding_pair(row, col),
                        at(naive_surrounding(&items, row, col)),
                        "surrounding {language} {row}:{col}\n{text}"
                    );
                    for (open, close) in [("(", ")"), ("[", "]"), ("{", "}")] {
                        assert_eq!(
                            document.unmatched(open, close, row, col, Kind::Closing),
                            naive_unmatched(&items, open, close, row, col, true),
                            "closing after {language} {open} {row}:{col}\n{text}"
                        );
                        assert_eq!(
                            document.unmatched(open, close, row, col, Kind::Opening),
                            naive_unmatched(&items, open, close, row, col, false),
                            "opening before {language} {open} {row}:{col}\n{text}"
                        );
                    }
                }
            }
        }
    }
}

#[test]
fn t_incremental_edits_match_a_full_parse() {
    let mut random = Random(0x2545_f491_4f6c_dd1d);
    for &(language, fragments) in FRAGMENTS {
        for _ in 0..40 {
            let count = 1 + random.below(12);
            let mut text = random_text(&mut random, fragments, count);
            let mut document = parse(language, &text.join("\n"));
            for _ in 0..12 {
                let first = random.below(text.len() + 1);
                let old_end = first + random.below(text.len() - first + 1);
                let replacement = if random.below(3) == 0 {
                    // Retype one line with a fragment more or less, as typing does.
                    let mut line = text.get(first).cloned().unwrap_or_default();
                    let cut = random.below(line.len() + 1);
                    if random.below(2) == 0 {
                        line.insert_str(cut, random.pick(fragments));
                    } else {
                        line.truncate(cut);
                    }
                    vec![line]
                } else {
                    let count = random.below(4);
                    random_text(&mut random, fragments, count)
                };
                let old_end = if replacement.len() == 1 && old_end == first && first < text.len() {
                    first + 1
                } else {
                    old_end
                };
                // A buffer always keeps a line: emptying it leaves one empty line.
                let replacement = if text.len() - (old_end - first) + replacement.len() == 0 {
                    vec![String::new()]
                } else {
                    replacement
                };
                text.splice(first..old_end, replacement.clone());
                document.edit(
                    first,
                    old_end,
                    replacement
                        .iter()
                        .map(|line| Box::from(line.as_bytes()))
                        .collect(),
                );
                // Edits may pile up before a query settles them, as Insert mode's two edits for a typed pair do.
                if random.below(2) == 0 {
                    continue;
                }
                document.settle();
                let full = parse(language, &text.join("\n"));
                assert_eq!(
                    rows(&document),
                    rows(&full),
                    "{language} after editing {first}..{old_end}\n{}",
                    text.join("\n")
                );
                for (row, line) in text.iter().enumerate() {
                    for col in 0..=line.len() {
                        assert_eq!(
                            document.surrounding_pair(row, col),
                            full.surrounding_pair(row, col)
                        );
                        assert_eq!(document.inside(row, col), full.inside(row, col));
                    }
                }
            }
        }
    }
}
