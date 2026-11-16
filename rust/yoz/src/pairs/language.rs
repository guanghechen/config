//! Static language definitions, compiled into the ordered match arms of blink.pairs' `define_matcher!`.
//!
//! The definitions and the arm order reproduce blink.pairs v0.5.0 (`src/parser/languages`, `matcher/src`; MIT
//! License, Copyright (c) 2025 Liam Dyer). Its span sections are maps keyed by name, so a later span of the same name
//! replaced an earlier one: markdown's `bold` is `**` only. Raw strings differ on purpose: blink.pairs let a backslash
//! hide their closing and had neither Rust's `r"` nor C#'s `"""`.

use std::sync::OnceLock;

/** Role of a token occurrence in the pairing pass. */
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Kind {
    Opening,
    Closing,
    NonPair,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Class {
    Delimiter,
    String,
    BlockString,
    LineComment,
    BlockComment,
    InlineSpan,
    BlockSpan,
}

/** A distinct token of a language. Occurrences pair when they share the token. */
#[derive(Debug, PartialEq, Eq)]
pub(crate) struct Token {
    pub(crate) class: Class,
    pub(crate) open: &'static str,
    /** Empty for strings and line comments, whose closing text is the opening text. */
    pub(crate) close: &'static str,
    /** Name of a span; empty otherwise. */
    pub(crate) span: &'static str,
}

impl Token {
    /// Byte length of an occurrence of `kind`.
    pub(crate) fn len(&self, kind: Kind) -> usize {
        match kind {
            Kind::Closing if !self.close.is_empty() => self.close.len(),
            _ => self.open.len(),
        }
    }
}

/** Tokenizer state carried between tokens; the payload is the token that entered the state. */
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum State {
    Normal,
    InString(u8),
    InBlockString(u8),
    InLineComment,
    InBlockComment(u8),
    InInlineSpan(u8),
    InBlockSpan(u8),
}

impl State {
    /// The state a line passes to the next one: strings, line comments and inline spans end at the line break.
    pub(crate) fn carried(self) -> State {
        match self {
            State::InString(_) | State::InLineComment | State::InInlineSpan(_) => State::Normal,
            state => state,
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum Action {
    /** Records an occurrence of `kind`, skips the rest of the pattern and enters `next`. */
    Emit { kind: Kind, token: u8, next: State },
    /** A character literal, closed by the same quote one or two bytes later, which it skips to. */
    Char { token: u8 },
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct Arm {
    /** The state the arm applies in. */
    pub(crate) state: State,
    pub(crate) pattern: &'static [u8],
    /** The arm does not apply to a token right after an unpaired backslash. */
    pub(crate) unescaped: bool,
    pub(crate) action: Action,
}

pub(crate) struct Language {
    pub(crate) name: &'static str,
    pub(crate) tokens: Vec<Token>,
    /** Arms in match order, indexed by the first pattern byte. */
    pub(crate) arms_by_byte: Vec<Vec<Arm>>,
    /** Bytes the tokenizer stops at: every pattern byte, plus `\` for escapes. */
    pub(crate) candidate: [bool; 256],
}

struct Definition {
    name: &'static str,
    delimiters: &'static [(&'static str, &'static str)],
    line_comments: &'static [&'static str],
    block_comments: &'static [(&'static str, &'static str)],
    strings: &'static [&'static str],
    chars: &'static [&'static str],
    block_strings: &'static [(&'static str, &'static str)],
    /** Block strings without escapes: a backslash does not hide their closing. */
    raw_strings: &'static [(&'static str, &'static str)],
    inline_spans: &'static [(&'static str, &'static str, &'static str)],
    block_spans: &'static [(&'static str, &'static str, &'static str)],
}

const BRACKETS: &[(&str, &str)] = &[("(", ")"), ("[", "]"), ("{", "}")];

const fn code(name: &'static str) -> Definition {
    Definition {
        name,
        delimiters: BRACKETS,
        line_comments: &[],
        block_comments: &[],
        strings: &[],
        chars: &[],
        block_strings: &[],
        raw_strings: &[],
        inline_spans: &[],
        block_spans: &[],
    }
}

#[rustfmt::skip]
const DEFINITIONS: &[Definition] = &[
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], chars: &["'"], strings: &["\""], ..code("c") },
    Definition { line_comments: &[";"], strings: &["\""], ..code("clojure") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], chars: &["'"], strings: &["\""], raw_strings: &[("R\"(", ")\"")], ..code("cpp") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], chars: &["'"], strings: &["\""], raw_strings: &[("@\"", "\""), ("\"\"\"", "\"\"\"")], ..code("csharp") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\"", "'"], block_strings: &[("\"\"\"", "\"\"\""), ("'''", "'''")], ..code("dart") },
    Definition { line_comments: &["#"], strings: &["\""], block_strings: &[("\"\"\"", "\"\"\"")], ..code("elixir") },
    Definition { line_comments: &["%"], strings: &["\""], ..code("erlang") },
    Definition { line_comments: &["//"], block_comments: &[("(*", "*)")], strings: &["\""], block_strings: &[("\"\"\"", "\"\"\"")], ..code("fsharp") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\""], raw_strings: &[("`", "`")], ..code("go") },
    Definition { line_comments: &["--"], block_comments: &[("{-", "-}")], strings: &["\""], ..code("haskell") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], chars: &["'"], strings: &["\""], ..code("haxe") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], chars: &["'"], strings: &["\""], block_strings: &[("\"\"\"", "\"\"\"")], ..code("java") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\"", "'"], block_strings: &[("`", "`")], ..code("javascript") },
    Definition { delimiters: &[("[", "]"), ("{", "}")], line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\""], ..code("json") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\""], block_strings: &[("\"\"\"", "\"\"\"")], ..code("kotlin") },
    Definition { line_comments: &["%"], strings: &["\""], chars: &["'"], block_strings: &[("$", "$"), ("$$", "$$")], ..code("latex") },
    Definition { line_comments: &["--"], block_comments: &[("/-", "-/")], strings: &["\""], ..code("lean") },
    Definition { line_comments: &["--"], block_comments: &[("--[[", "]]")], strings: &["\"", "'"], raw_strings: &[("[[", "]]")], ..code("lua") },
    Definition {
        delimiters: &[],
        inline_spans: &[("math", "$", "$"), ("italic", "_", "_"), ("bold", "**", "**"), ("strikethrough", "~~", "~~")],
        block_spans: &[("math", "$$", "$$"), ("code", "```", "```")],
        ..code("markdown")
    },
    Definition { line_comments: &["#"], block_comments: &[("/*", "*/")], strings: &["\""], block_strings: &[("''", "''")], ..code("nix") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\""], ..code("objc") },
    Definition { block_comments: &[("(*", "*)")], strings: &["\""], ..code("ocaml") },
    Definition { line_comments: &["#"], strings: &["\"", "'"], ..code("perl") },
    Definition { line_comments: &["//", "#"], block_comments: &[("/*", "*/")], strings: &["\"", "'"], ..code("php") },
    Definition { line_comments: &["#"], strings: &["\"", "'"], block_strings: &[("\"\"\"", "\"\"\""), ("'''", "'''")], ..code("python") },
    Definition { line_comments: &["#"], strings: &["\"", "'"], ..code("r") },
    Definition { line_comments: &["#"], block_comments: &[("=begin", "end")], strings: &["\"", "'"], ..code("ruby") },
    Definition {
        line_comments: &["//"],
        block_comments: &[("/*", "*/")],
        chars: &["'"],
        block_strings: &[("\"", "\"")],
        raw_strings: &[("r\"", "\""), ("r#\"", "\"#"), ("r##\"", "\"##"), ("r###\"", "\"###")],
        ..code("rust")
    },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\""], block_strings: &[("\"\"\"", "\"\"\"")], ..code("scala") },
    Definition { line_comments: &[";"], strings: &["\""], ..code("scheme") },
    Definition { line_comments: &["#"], strings: &["\"", "'"], ..code("shell") },
    Definition { line_comments: &["--", "#"], block_comments: &[("/*", "*/")], strings: &["\"", "'", "$$", "`"], ..code("sql") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\"", "'"], block_strings: &[("\"\"\"", "\"\"\"")], ..code("swift") },
    Definition { line_comments: &["#"], strings: &["\"", "'"], block_strings: &[("\"\"\"", "\"\"\"")], ..code("toml") },
    Definition { line_comments: &["//"], block_comments: &[("/*", "*/")], strings: &["\""], ..code("typst") },
    code("vim"),
    // blink.pairs reads `\\` as a Zig line comment, but its tokenizer consumes backslashes as escapes first.
    Definition { line_comments: &["//", "\\\\"], strings: &["\""], ..code("zig") },
];

/// The language blink.pairs parses a buffer of `filetype` with.
pub(crate) fn language_name(filetype: &str) -> Option<&'static str> {
    Some(match filetype {
        "typescript" | "javascript" | "typescriptreact" | "javascriptreact" => "javascript",
        "latex" | "tex" | "bib" => "latex",
        filetype => DEFINITIONS.iter().find(|def| def.name == filetype)?.name,
    })
}

/// The compiled language named `name`, as [`language_name`] returns it.
pub(crate) fn language(name: &str) -> Option<&'static Language> {
    static COMPILED: OnceLock<Vec<Language>> = OnceLock::new();
    COMPILED
        .get_or_init(|| DEFINITIONS.iter().map(compile).collect())
        .iter()
        .find(|language| language.name == name)
}

/// The arm that opens `token` from the Normal state into the state `inside` makes of it, then the arm that closes it
/// there; a closing that ignores escapes does not apply right after an unpaired backslash.
fn pair(
    arms: &mut Vec<Arm>,
    token: u8,
    open: &'static str,
    close: &'static str,
    inside: fn(u8) -> State,
    close_unescaped: bool,
) {
    let inside = inside(token);
    for (state, pattern, unescaped, kind, next) in [
        (State::Normal, open, false, Kind::Opening, inside),
        (inside, close, close_unescaped, Kind::Closing, State::Normal),
    ] {
        arms.push(Arm {
            state,
            pattern: pattern.as_bytes(),
            unescaped,
            action: Action::Emit { kind, token, next },
        });
    }
}

/// Builds the arms of `def` in the order blink.pairs' macro emits them: block comments, block strings, block spans,
/// line comments, strings, characters, inline spans, then delimiters.
fn compile(def: &Definition) -> Language {
    let mut tokens: Vec<Token> = Vec::new();
    let mut intern = |class, open, close, span| -> u8 {
        let token = Token {
            class,
            open,
            close,
            span,
        };
        let index = tokens
            .iter()
            .position(|known| *known == token)
            .unwrap_or_else(|| {
                tokens.push(token);
                tokens.len() - 1
            });
        u8::try_from(index).expect("a language has at most 256 tokens")
    };
    let mut arms: Vec<Arm> = Vec::new();
    for &(open, close) in def.block_comments {
        let token = intern(Class::BlockComment, open, close, "");
        pair(&mut arms, token, open, close, State::InBlockComment, false);
    }
    // Raw strings follow the other block strings in their place in the order.
    for (strings, close_unescaped) in [(def.block_strings, true), (def.raw_strings, false)] {
        for &(open, close) in strings {
            let token = intern(Class::BlockString, open, close, "");
            pair(
                &mut arms,
                token,
                open,
                close,
                State::InBlockString,
                close_unescaped,
            );
        }
    }
    for &(span, open, close) in def.block_spans {
        let token = intern(Class::BlockSpan, open, close, span);
        pair(&mut arms, token, open, close, State::InBlockSpan, false);
    }
    for &comment in def.line_comments {
        let token = intern(Class::LineComment, comment, "", "");
        arms.push(Arm {
            state: State::Normal,
            pattern: comment.as_bytes(),
            unescaped: true,
            action: Action::Emit {
                kind: Kind::NonPair,
                token,
                next: State::InLineComment,
            },
        });
    }
    for &delim in def.strings {
        let token = intern(Class::String, delim, "", "");
        pair(&mut arms, token, delim, delim, State::InString, true);
    }
    for &delim in def.chars {
        let token = intern(Class::String, delim, "", "");
        arms.push(Arm {
            state: State::Normal,
            pattern: delim.as_bytes(),
            unescaped: false,
            action: Action::Char { token },
        });
    }
    for &(span, open, close) in def.inline_spans {
        let token = intern(Class::InlineSpan, open, close, span);
        pair(&mut arms, token, open, close, State::InInlineSpan, false);
    }
    for &(open, close) in def.delimiters {
        let token = intern(Class::Delimiter, open, close, "");
        pair(&mut arms, token, open, close, |_| State::Normal, false);
    }

    let mut candidate = [false; 256];
    candidate[usize::from(b'\\')] = true;
    let mut arms_by_byte = vec![Vec::new(); 256];
    for arm in arms {
        for &byte in arm.pattern {
            candidate[usize::from(byte)] = true;
        }
        arms_by_byte[usize::from(arm.pattern[0])].push(arm);
    }
    Language {
        name: def.name,
        tokens,
        arms_by_byte,
        candidate,
    }
}
