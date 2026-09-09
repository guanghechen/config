use std::borrow::Cow;

use mlua::prelude::*;
use yoz_git::encoding::{self, Unicode};
use yoz_git::staging::{self, Eol, HunkRange, Intersection, Span};

use super::integer;

// Nil without an error delegates a legacy codec to Lua; invalid Unicode must not fall back.
fn decode_unicode(
    lua: &Lua,
    (bytes, encoding): (LuaString, LuaString),
) -> LuaResult<(Option<LuaString>, bool, Option<&'static str>)> {
    let Some(encoding) = Unicode::parse(&encoding.as_bytes()) else {
        return Ok((None, false, None));
    };
    match encoding.decode(&bytes.as_bytes()) {
        Ok(decoded) => {
            let text = if !decoded.bomb && matches!(decoded.text, Cow::Borrowed(_)) {
                bytes.clone()
            } else {
                lua.create_string(decoded.text.as_ref())?
            };
            Ok((Some(text), decoded.bomb, None))
        }
        Err(err) => Ok((None, false, Some(err))),
    }
}

fn encode_unicode(
    lua: &Lua,
    (text, encoding, bomb): (LuaString, LuaString, bool),
) -> LuaResult<(Option<LuaString>, Option<&'static str>)> {
    let Some(encoding) = Unicode::parse(&encoding.as_bytes()) else {
        return Ok((None, None));
    };
    match encoding.encode(&text.as_bytes(), bomb) {
        Ok(Cow::Borrowed(_)) => Ok((Some(text.clone()), None)),
        Ok(Cow::Owned(bytes)) => Ok((Some(lua.create_string(bytes)?), None)),
        Err(err) => Ok((None, Some(err))),
    }
}

fn span(node: &LuaTable) -> LuaResult<Span> {
    Span::new(
        usize::try_from(integer(node.get("start")?)?).map_err(LuaError::external)?,
        usize::try_from(integer(node.get("count")?)?).map_err(LuaError::external)?,
        node.get("no_nl_at_eof")?,
    )
    .map_err(LuaError::external)
}

fn hunk_range(hunk: &LuaTable) -> LuaResult<HunkRange> {
    Ok(HunkRange {
        removed: span(&hunk.get::<LuaTable>("removed")?)?,
        added: span(&hunk.get::<LuaTable>("added")?)?,
    })
}

fn node_table(lua: &Lua, source: &LuaTable, span: Span, offset: usize) -> LuaResult<LuaTable> {
    let source_lines = source.get::<LuaTable>("lines")?;
    if offset + span.count() > source_lines.raw_len() {
        return Err(LuaError::external("Git hunk span exceeds its lines"));
    }
    let lines = lua.create_table_with_capacity(span.count(), 0)?;
    for index in 0..span.count() {
        lines.raw_push(source_lines.raw_get::<LuaString>(offset + index + 1)?)?;
    }
    let result = lua.create_table_with_capacity(0, 4)?;
    result.set("start", span.start())?;
    result.set("count", span.count())?;
    result.set("no_nl_at_eof", span.no_nl_at_eof())?;
    result.set("lines", lines)?;
    Ok(result)
}

fn hunk_table(
    lua: &Lua,
    range: HunkRange,
    removed: &LuaTable,
    removed_offset: usize,
    added: &LuaTable,
    added_offset: usize,
) -> LuaResult<LuaTable> {
    let result = lua.create_table_with_capacity(0, 5)?;
    result.set("type", range.kind())?;
    result.set("head", range.head())?;
    result.set("vend", range.added.last())?;
    result.set(
        "removed",
        node_table(lua, removed, range.removed, removed_offset)?,
    )?;
    result.set("added", node_table(lua, added, range.added, added_offset)?)?;
    Ok(result)
}

fn intersected(lua: &Lua, source: &LuaTable, selection: Intersection) -> LuaResult<LuaTable> {
    hunk_table(
        lua,
        selection.range,
        &source.get("removed")?,
        selection.removed_offset,
        &source.get("added")?,
        selection.added_offset,
    )
}

fn inverted(lua: &Lua, source: &LuaTable, range: HunkRange) -> LuaResult<LuaTable> {
    hunk_table(
        lua,
        range,
        &source.get("added")?,
        0,
        &source.get("removed")?,
        0,
    )
}

struct Document {
    text: LuaString,
    eol: Eol,
    lines: PackedLines,
}

// mlua's auxiliary reference stack is bounded. Retain bytes, not one Lua handle per line.
struct PackedLines {
    bytes: Vec<u8>,
    offsets: Vec<usize>,
}

impl PackedLines {
    fn new(byte_capacity: usize, line_capacity: usize) -> Self {
        let mut offsets = Vec::with_capacity(line_capacity + 1);
        offsets.push(0);
        Self {
            bytes: Vec::with_capacity(byte_capacity),
            offsets,
        }
    }

    fn append(
        &mut self,
        table: LuaTable,
        offset: usize,
        count: usize,
    ) -> LuaResult<std::ops::Range<usize>> {
        let end = offset
            .checked_add(count)
            .filter(|end| *end <= table.raw_len())
            .ok_or_else(|| LuaError::external("Git hunk span exceeds its lines"))?;
        let start = self.offsets.len() - 1;
        for index in offset..end {
            self.bytes
                .extend_from_slice(&table.raw_get::<LuaString>(index + 1)?.as_bytes());
            self.offsets.push(self.bytes.len());
        }
        Ok(start..self.offsets.len() - 1)
    }

    fn lines(&self) -> Vec<&[u8]> {
        self.offsets
            .windows(2)
            .map(|range| &self.bytes[range[0]..range[1]])
            .collect()
    }
}

impl Document {
    fn read(table: LuaTable) -> LuaResult<Self> {
        let text: LuaString = table.get("text")?;
        let eol =
            Eol::parse(&table.get::<LuaString>("eol")?.as_bytes()).map_err(LuaError::external)?;
        let source: LuaTable = table.get("lines")?;
        let count = source.raw_len();
        let mut lines = PackedLines::new(text.as_bytes().len(), count);
        lines.append(source, 0, count)?;
        Ok(Self { text, eol, lines })
    }
}

fn document_info(table: LuaTable) -> LuaResult<staging::DocumentInfo> {
    let text: LuaString = table.get("text")?;
    let eol = Eol::parse(&table.get::<LuaString>("eol")?.as_bytes()).map_err(LuaError::external)?;
    let lines: LuaTable = table.get("lines")?;
    let count = lines.raw_len();
    let last_empty = count > 0 && lines.raw_get::<LuaString>(count)?.as_bytes().is_empty();
    Ok(staging::DocumentInfo::new(
        &text.as_bytes(),
        eol,
        count,
        last_empty,
    ))
}

fn rebuild(
    lua: &Lua,
    original: LuaTable,
    modified: LuaTable,
    ranges: Vec<(HunkRange, std::ops::Range<usize>)>,
    added: PackedLines,
) -> LuaResult<LuaString> {
    if ranges.is_empty() {
        return original.get("text");
    }
    let original = Document::read(original)?;
    let modified = document_info(modified)?;
    let original_lines = original.lines.lines();
    let added_lines = added.lines();
    let changes: Vec<_> = ranges
        .into_iter()
        .map(|(range, lines)| staging::LineChange {
            range,
            added_lines: &added_lines[lines],
        })
        .collect();
    let text = staging::apply_line_changes(
        &staging::Document {
            text: &original.text.as_bytes(),
            eol: original.eol,
            lines: &original_lines,
        },
        modified,
        &changes,
    )
    .map_err(LuaError::external)?;
    lua.create_string(text)
}

fn apply_line_changes(
    lua: &Lua,
    (original, modified, hunks): (LuaTable, LuaTable, LuaTable),
) -> LuaResult<LuaString> {
    let mut ranges = Vec::with_capacity(hunks.raw_len());
    let mut added = PackedLines::new(0, 0);
    for hunk in hunks.sequence_values::<LuaTable>() {
        let hunk = hunk?;
        let source: LuaTable = hunk.get::<LuaTable>("added")?.get("lines")?;
        let count = source.raw_len();
        let lines = added.append(source, 0, count)?;
        ranges.push((hunk_range(&hunk)?, lines));
    }
    rebuild(lua, original, modified, ranges, added)
}

fn apply_selection(
    lua: &Lua,
    (original, modified, hunks, top, bot, mode): (
        LuaTable,
        LuaTable,
        LuaTable,
        LuaValue,
        LuaValue,
        LuaString,
    ),
) -> LuaResult<Option<LuaString>> {
    use staging::Selection;
    let (top, bot) = (integer(top)?, integer(bot)?);
    let mode = match mode.as_bytes().as_ref() {
        b"stage" => Selection::Stage,
        b"stage_partial" => Selection::StagePartial,
        b"unstage" => Selection::Unstage,
        b"reset" => Selection::Reset,
        _ => return Err(LuaError::external("Invalid Git staging selection")),
    };
    let mut hunk_ranges = Vec::new();
    for hunk in hunks.sequence_values::<LuaTable>() {
        let range = hunk_range(&hunk?)?;
        hunk_ranges.push(range);
        // Cursor staging uses the first touched hunk; do not marshal the ignored suffix.
        if mode == Selection::Stage && range.touches(top, bot) {
            break;
        }
    }
    let Some(selected) = staging::select_hunks(&hunk_ranges, top, bot, mode) else {
        return Ok(None);
    };
    let mut ranges = Vec::with_capacity(selected.len());
    let mut added = PackedLines::new(0, 0);
    let side = if mode == Selection::Unstage {
        "removed"
    } else {
        "added"
    };
    for selection in selected {
        let source: LuaTable = hunks
            .raw_get::<LuaTable>(selection.index + 1)?
            .get::<LuaTable>(side)?
            .get("lines")?;
        let source_range = hunk_ranges[selection.index];
        let source_count = if mode == Selection::Unstage {
            source_range.removed.count()
        } else {
            source_range.added.count()
        };
        if source.raw_len() != source_count {
            return Err(LuaError::external(
                "Git hunk line count does not match its span",
            ));
        }
        let lines = added.append(
            source,
            selection.added_offset,
            selection.range.added.count(),
        )?;
        ranges.push((selection.range, lines));
    }
    let (original, modified) = if mode == Selection::Unstage {
        (modified, original)
    } else {
        (original, modified)
    };
    rebuild(lua, original, modified, ranges, added).map(Some)
}

pub(super) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    result.set(
        "normalize_encoding",
        lua.create_function(|lua, name: Option<LuaString>| {
            let Some(name) = name else {
                return lua.create_string("utf-8");
            };
            lua.create_string(encoding::normalize(&name.as_bytes()).as_ref())
        })?,
    )?;
    result.set("decode_unicode", lua.create_function(decode_unicode)?)?;
    result.set("encode_unicode", lua.create_function(encode_unicode)?)?;
    result.set("apply_selection", lua.create_function(apply_selection)?)?;
    result.set(
        "from_text",
        lua.create_function(|lua, (text, default_eol): (LuaString, Option<LuaString>)| {
            let eol = default_eol
                .map(|eol| Eol::parse(&eol.as_bytes()))
                .transpose()
                .map_err(LuaError::external)?
                .unwrap_or(Eol::Lf);
            let document = staging::from_text(&text.as_bytes(), eol);
            let result = lua.create_table_with_capacity(0, 3)?;
            result.set("text", lua.create_string(&document.text)?)?;
            result.set("eol", lua.create_string(document.eol.bytes())?)?;
            let lines = lua.create_table()?;
            for line in document.lines() {
                lines.raw_push(lua.create_string(line)?)?;
            }
            result.set("lines", lines)?;
            Ok(result)
        })?,
    )?;
    result.set(
        "apply_line_changes",
        lua.create_function(apply_line_changes)?,
    )?;
    result.set(
        "modified_range",
        lua.create_function(|_, hunk: LuaTable| Ok(hunk_range(&hunk)?.modified_range()))?,
    )?;
    result.set(
        "touches",
        lua.create_function(|_, (hunk, top, bot): (LuaTable, LuaValue, LuaValue)| {
            Ok(hunk_range(&hunk)?.touches(integer(top)?, integer(bot)?))
        })?,
    )?;
    result.set(
        "intersect",
        lua.create_function(|lua, (hunk, top, bot): (LuaTable, LuaValue, LuaValue)| {
            hunk_range(&hunk)?
                .intersect(integer(top)?, integer(bot)?)
                .map(|selection| intersected(lua, &hunk, selection))
                .transpose()
        })?,
    )?;
    result.set(
        "invert",
        lua.create_function(|lua, hunk: LuaTable| {
            inverted(lua, &hunk, hunk_range(&hunk)?.invert())
        })?,
    )?;
    result.set(
        "less",
        lua.create_function(|_, (left, right): (LuaTable, LuaTable)| {
            Ok(hunk_range(&left)?.sort_key() < hunk_range(&right)?.sort_key())
        })?,
    )?;
    Ok(result)
}
