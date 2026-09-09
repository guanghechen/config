use mlua::prelude::*;
use yoz_git::staging::{HunkRange, Span};
use yoz_git::word_diff;

use super::integer;

fn span(row: &LuaTable, offset: usize) -> LuaResult<Span> {
    Span::new(
        usize::try_from(integer(row.raw_get(offset)?)?).map_err(LuaError::external)?,
        usize::try_from(integer(row.raw_get(offset + 1)?)?).map_err(LuaError::external)?,
        None,
    )
    .map_err(LuaError::external)
}

fn finish(
    lua: &Lua,
    (old, new, raw): (LuaString, LuaString, Option<LuaTable>),
) -> LuaResult<LuaTable> {
    let raw = raw
        .map(|raw| {
            raw.sequence_values::<LuaTable>()
                .map(|row| {
                    let row = row?;
                    Ok(HunkRange {
                        removed: span(&row, 1)?,
                        added: span(&row, 3)?,
                    })
                })
                .collect::<LuaResult<Vec<_>>>()
        })
        .transpose()?;
    let changes = word_diff::finish(&old.as_bytes(), &new.as_bytes(), raw.as_deref());
    let result = lua.create_table_with_capacity(changes.len(), 0)?;
    for change in changes {
        result.raw_push(lua.create_table_from([
            ("old_start", change.old_start),
            ("old_end", change.old_end),
            ("new_start", change.new_start),
            ("new_end", change.new_end),
        ])?)?;
    }
    Ok(result)
}

pub(super) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    result.set(
        "inputs",
        lua.create_function(|lua, (old, new): (LuaString, LuaString)| {
            Ok((
                lua.create_string(word_diff::bytes_as_lines(&old.as_bytes()))?,
                lua.create_string(word_diff::bytes_as_lines(&new.as_bytes()))?,
            ))
        })?,
    )?;
    result.set("finish", lua.create_function(finish)?)?;
    Ok(result)
}
