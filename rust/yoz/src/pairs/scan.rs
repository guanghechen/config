//! Line tokenizer: the per-token state machine of blink.pairs' `parse`, run over the bytes of one line.

use super::language::{Action, Kind, Language, State};

/** Height of an occurrence that pairing left unmatched, or has not paired yet. */
pub(crate) const NONE: u32 = u32::MAX;

/** A token occurrence: its byte column, token and role, and the height pairing gives it. */
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Tok {
    pub(crate) col: u32,
    /** Stack depth of its pair, or [`NONE`]. */
    pub(crate) height: u32,
    pub(crate) token: u8,
    pub(crate) kind: Kind,
}

/// Appends the occurrences of `line` scanned from `state` to `out` and returns the state at the end of the line,
/// before the line break resets it (see [`State::carried`]).
///
/// blink.pairs' tokenizer only sees candidate bytes: pattern bytes and `\`. Escapes pair backslashes on the line; an
/// arm that ignores escaped tokens does not apply right after an unpaired backslash. A pattern matches adjacent
/// bytes and consumes them. A character literal closes at the same quote one or two bytes later and consumes the
/// bytes up to it.
pub(crate) fn scan_line(
    language: &Language,
    line: &[u8],
    mut state: State,
    out: &mut Vec<Tok>,
) -> State {
    let mut escaped_col: Option<usize> = None;
    let mut col = 0;
    while col < line.len() {
        let byte = line[col];
        if !language.candidate[usize::from(byte)] {
            col += 1;
            continue;
        }
        if byte == b'\\' {
            escaped_col = if escaped_col.is_some_and(|escaped| escaped + 1 == col) {
                None
            } else {
                Some(col)
            };
            col += 1;
            continue;
        }
        let escaped = escaped_col.is_some_and(|escaped| escaped + 1 == col);
        let mut resume = col + 1;
        for arm in &language.arms_by_byte[usize::from(byte)] {
            if arm.state != state || (arm.unescaped && escaped) {
                continue;
            }
            let (token, close) = match arm.action {
                Action::Emit { kind, token, next } => {
                    if !line[col..].starts_with(arm.pattern) {
                        continue;
                    }
                    out.push(Tok {
                        col: col as u32,
                        height: NONE,
                        token,
                        kind,
                    });
                    resume = col + arm.pattern.len();
                    state = next;
                    break;
                }
                Action::Char { token } => {
                    let Some(close) = [col + 1, col + 2]
                        .into_iter()
                        .find(|&at| line.get(at) == Some(&byte))
                    else {
                        continue;
                    };
                    (token, close)
                }
            };
            for (col, kind) in [(col, Kind::Opening), (close, Kind::Closing)] {
                out.push(Tok {
                    col: col as u32,
                    height: NONE,
                    token,
                    kind,
                });
            }
            resume = close + 1;
            state = State::Normal;
            break;
        }
        col = resume;
    }
    state
}

/// Leading whitespace width with tabs `tab_width` wide, saturating at 255 and rounded down to a multiple of
/// `tab_width`, as indent rematching compares it; 0 for a blank line, which owns no tokens.
pub(crate) fn indent(line: &[u8], tab_width: u8) -> u8 {
    let mut width: u8 = 0;
    for &byte in line {
        match byte {
            b' ' => width = width.saturating_add(1),
            b'\t' => width = width.saturating_add(tab_width),
            _ => return width / tab_width * tab_width,
        }
    }
    0
}
