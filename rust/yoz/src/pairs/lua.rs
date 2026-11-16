//! Lua bindings: `yoz.pairs.language(filetype)` names the language a filetype parses with, and
//! `yoz.pairs.new(language, tab_width)` returns a document that a buffer's line edits keep in sync. Rows and columns
//! are zero-based; columns are bytes.

use super::document::{Document, End};
use super::language::{self, Class, Kind};
use mlua::prelude::*;
use std::cell::RefCell;

struct LuaDocument(RefCell<Document>);

impl LuaDocument {
    /// The document with settled pairs, for a query.
    fn settled(&self) -> std::cell::Ref<'_, Document> {
        self.0.borrow_mut().settle();
        self.0.borrow()
    }
}

fn read_lines(lines: &LuaTable) -> LuaResult<Vec<Box<[u8]>>> {
    let mut texts = Vec::with_capacity(lines.raw_len());
    for line in lines.sequence_values::<LuaString>() {
        texts.push(Box::from(&*line?.as_bytes()));
    }
    Ok(texts)
}

/// Both ends of a pair as six values: row, column and length of the opening, then of the closing.
fn pair_values(lua: &Lua, pair: Option<(End, End)>) -> LuaResult<LuaMultiValue> {
    match pair {
        None => LuaNil.into_lua_multi(lua),
        Some(((open_row, open_col, open_len), (close_row, close_col, close_len))) => (
            open_row, open_col, open_len, close_row, close_col, close_len,
        )
            .into_lua_multi(lua),
    }
}

fn position_values(lua: &Lua, position: Option<(usize, usize)>) -> LuaResult<LuaMultiValue> {
    match position {
        None => LuaNil.into_lua_multi(lua),
        Some((row, col)) => (row, col).into_lua_multi(lua),
    }
}

fn class_name(class: Class) -> &'static str {
    match class {
        Class::Delimiter => "delimiter",
        Class::String => "string",
        Class::BlockString => "block_string",
        Class::LineComment => "line_comment",
        Class::BlockComment => "block_comment",
        Class::InlineSpan => "inline_span",
        Class::BlockSpan => "block_span",
    }
}

impl LuaUserData for LuaDocument {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method(
            "edit",
            |_, this, (first, old_end, lines): (usize, usize, LuaTable)| {
                let lines = read_lines(&lines)?;
                Ok(this.0.borrow_mut().edit(first, old_end, lines))
            },
        );
        methods.add_method("set_tab_width", |_, this, tab_width: u8| {
            Ok(this.0.borrow_mut().set_tab_width(tab_width))
        });
        methods.add_method("revision", |_, this, ()| Ok(this.0.borrow().revision()));
        methods.add_method("line_count", |_, this, ()| Ok(this.0.borrow().line_count()));
        methods.add_method(
            "highlights",
            |lua,
             this,
             (first_row, first_col, last_row, last_col): (usize, usize, usize, usize)| {
                let document = this.settled();
                let mut values: Vec<i64> = Vec::new();
                for (row, col, end_col, height) in
                    document.highlights((first_row, first_col), (last_row, last_col))
                {
                    values.extend([
                        row as i64,
                        col as i64,
                        end_col as i64,
                        height.map_or(-1, i64::from),
                    ]);
                }
                lua.create_sequence_from(values)
            },
        );
        methods.add_method("inside", |_, this, (row, col): (usize, usize)| {
            Ok(this.0.borrow().inside(row, col).map(class_name))
        });
        methods.add_method("match_pair", |lua, this, (row, col): (usize, usize)| {
            pair_values(lua, this.settled().match_pair(row, col))
        });
        methods.add_method(
            "surrounding_pair",
            |lua, this, (row, col): (usize, usize)| {
                pair_values(lua, this.settled().surrounding_pair(row, col))
            },
        );
        for (name, wanted) in [
            ("unmatched_closing_after", Kind::Closing),
            ("unmatched_opening_before", Kind::Opening),
        ] {
            methods.add_method(
                name,
                move |lua, this, (open, close, row, col): (String, String, usize, usize)| {
                    position_values(
                        lua,
                        this.settled().unmatched(&open, &close, row, col, wanted),
                    )
                },
            );
        }
        methods.add_method("tokens", |lua, this, row: usize| {
            let document = this.settled();
            let out = lua.create_table()?;
            for (col, kind, token, height) in document.row_tokens(row) {
                let item = lua.create_table()?;
                item.set("col", col)?;
                item.set(
                    "kind",
                    match kind {
                        Kind::Opening => "opening",
                        Kind::Closing => "closing",
                        Kind::NonPair => "non_pair",
                    },
                )?;
                item.set("class", class_name(token.class))?;
                item.set("open", token.open)?;
                if !token.close.is_empty() {
                    item.set("close", token.close)?;
                }
                if !token.span.is_empty() {
                    item.set("span", token.span)?;
                }
                item.set("height", height)?;
                out.raw_push(item)?;
            }
            Ok(out)
        });
    }
}

pub(crate) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    exports.set(
        "language",
        lua.create_function(|_, filetype: String| Ok(language::language_name(&filetype)))?,
    )?;
    exports.set(
        "new",
        lua.create_function(|_, (name, tab_width): (String, u8)| {
            let language = language::language(&name)
                .ok_or_else(|| LuaError::runtime(format!("unknown pairs language: {name}")))?;
            Ok(LuaDocument(RefCell::new(Document::new(
                language, tab_width,
            ))))
        })?,
    )?;
    Ok(exports)
}
