use super::*;
use mlua::prelude::*;
use std::collections::HashMap;

pub(super) fn token(prefix: char, value: u64) -> String {
    format!("{prefix}{value:016x}")
}
pub(super) fn node(id: NodeId) -> String {
    token('n', id.value())
}

pub(super) fn error(lua: &Lua, error: &Error) -> LuaResult<LuaTable> {
    let table = lua.create_table()?;
    table.set("code", error.code.as_str())?;
    table.set("message", error.message.as_ref())?;
    table.set("node", error.node.map(node))?;
    Ok(table)
}

pub(super) fn revisions(lua: &Lua, revisions: Revisions) -> LuaResult<LuaTable> {
    let table = lua.create_table()?;
    table.set("commit", token('r', revisions.commit.value()))?;
    table.set("data", token('r', revisions.data.value()))?;
    table.set(
        "state",
        revisions.state.map(|revision| token('r', revision.value())),
    )?;
    table.set(
        "selection",
        revisions
            .selection
            .map(|revision| token('r', revision.value())),
    )?;
    Ok(table)
}

fn summary(lua: &Lua, summary: Summary) -> LuaResult<LuaTable> {
    let table = lua.create_table()?;
    table.set("full", summary.full)?;
    table.set("known_roots", summary.known_roots)?;
    table.set("known_self_only", summary.known_self_only)?;
    table.set("pending", summary.pending)?;
    table.set("is_empty", summary.is_empty())?;
    Ok(table)
}

pub(super) fn value(lua: &Lua, value: &Value) -> LuaResult<LuaValue> {
    match value {
        Value::Null => Ok(LuaValue::LightUserData(LuaLightUserData(
            std::ptr::null_mut(),
        ))),
        Value::Boolean(value) => value.into_lua(lua),
        Value::Integer(value) => value.into_lua(lua),
        Value::Number(value) => value.into_lua(lua),
        Value::String(value) => value.as_ref().into_lua(lua),
        Value::Bytes(value) => lua.create_string(value.as_ref())?.into_lua(lua),
        Value::Array(values) => {
            let result = lua.create_table_with_capacity(values.len(), 0)?;
            for (index, item) in values.iter().enumerate() {
                result.raw_set(index + 1, self::value(lua, item)?)?;
            }
            result.into_lua(lua)
        }
        Value::Object(fields) => self::fields(lua, fields)?.into_lua(lua),
    }
}

pub(super) fn fields(lua: &Lua, fields: &Fields) -> LuaResult<LuaTable> {
    let table = lua.create_table_with_capacity(0, fields.len())?;
    for (key, item) in fields.iter() {
        table.raw_set(key.as_str(), value(lua, item)?)?;
    }
    Ok(table)
}

pub(super) fn query(lua: &Lua, info: &QueryInfo) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    result.set("session", token('q', info.session.0))?;
    result.set("provider", token('p', info.provider.0))?;
    result.set("generation", token('r', info.generation))?;
    result.set(
        "result_generation",
        info.result_generation.map(|value| token('r', value)),
    )?;
    result.set("pattern", info.input.pattern.as_ref())?;
    result.set("load_state", info.load_state.as_str())?;
    result.set("completeness", info.completeness.as_str())?;
    result.set(
        "error",
        info.error.as_ref().map(|err| error(lua, err)).transpose()?,
    )?;
    Ok(result)
}

pub(super) fn query_result(
    lua: &Lua,
    scope: DataScope,
    origin: &QueryResult,
) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    result.set("session", token('q', origin.session.0))?;
    result.set("generation", token('r', origin.generation))?;
    result.set("pattern", origin.input.pattern.as_ref())?;
    result.set("completeness", origin.completeness.as_str())?;
    let root = lua.create_table()?;
    root.set(
        "kind",
        match scope {
            DataScope::Forest => "forest",
            DataScope::Children(_) => "children",
            DataScope::Descendants(_) => "descendants",
        },
    )?;
    root.set("node", scope.anchor().map(node))?;
    result.set("scope", root)?;
    Ok(result)
}

pub(super) fn effect(lua: &Lua, effect: &Effect) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    match effect {
        Effect::NeedChildren {
            token: read,
            sequence,
        } => {
            result.set("kind", "NeedChildren")?;
            result.set("token", LuaRead(*read))?;
            result.set("node", node(read.node))?;
            result.set("sequence", token('r', *sequence))?;
            result.set("first", *sequence == 1)?;
            result.set("work", token('w', read.work))?;
        }
        Effect::CancelChildren { token: read } => {
            result.set("kind", "CancelChildren")?;
            result.set("token", LuaRead(*read))?;
            result.set("work", token('w', read.work))?;
        }
        Effect::Query {
            token: query,
            input,
            sequence,
        } => {
            result.set("kind", "Query")?;
            result.set("token", LuaQueryToken(*query))?;
            result.set("session", token('q', query.session.0))?;
            result.set("work", token('w', query.work))?;
            result.set("sequence", token('r', *sequence))?;
            result.set("pattern", input.pattern.as_ref())?;
            result.set("first", *sequence == 1)?;
            result.set("options", fields(lua, &input.options)?)?;
        }
        Effect::CancelQuery { token: query } => {
            result.set("kind", "CancelQuery")?;
            result.set("token", LuaQueryToken(*query))?;
            result.set("work", token('w', query.work))?;
        }
        Effect::TaskFailed { lock, error: err } => {
            result.set("kind", "TaskFailed")?;
            result.set("lock", token('l', lock.0))?;
            result.set("error", error(lua, err)?)?;
        }
        Effect::RootUnavailable { state, node: id } => {
            result.set("kind", "RootUnavailable")?;
            result.set("state", token('s', *state))?;
            result.set("node", node(*id))?;
        }
        Effect::NodeInvalidated { nodes } => {
            result.set("kind", "NodeInvalidated")?;
            result.set("nodes", LuaIds(nodes.clone()))?;
        }
        Effect::ViewChanged { state } => {
            result.set("kind", "ViewChanged")?;
            result.set("state", token('s', *state))?;
        }
        Effect::SelectionPending { state, nodes } => {
            result.set("kind", "SelectionPending")?;
            result.set("state", token('s', *state))?;
            result.set("nodes", LuaIds(nodes.clone()))?;
        }
    }
    Ok(result)
}

fn sources(lua: &Lua, result: &LuaTable, sources: &SelectionSources) -> LuaResult<()> {
    result.set("summary", summary(lua, sources.summary)?)?;
    result.set("subtree_roots", LuaIds(sources.subtree_roots.clone()))?;
    result.set("self_only_nodes", LuaIds(sources.self_only_nodes.clone()))?;
    result.set("needed_children", LuaIds(sources.needed_children.clone()))?;
    Ok(())
}

pub(super) fn reply(lua: &Lua, reply: &Reply) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    match reply {
        Reply::Applied {
            revisions: revs,
            effects,
        } => {
            result.set("kind", "Applied")?;
            result.set("revisions", revisions(lua, *revs)?)?;
            let output = lua.create_table_with_capacity(effects.len(), 0)?;
            for (index, item) in effects.iter().enumerate() {
                output.raw_set(index + 1, effect(lua, item)?)?;
            }
            result.set("effects", output)?;
        }
        Reply::NoChange => result.set("kind", "NoChange")?,
        Reply::Rejected { error: err } => {
            result.set("kind", "Rejected")?;
            result.set("error", error(lua, err)?)?;
        }
        Reply::Locked {
            revisions: revs,
            token: lock,
        } => {
            result.set("kind", "Locked")?;
            result.set("revisions", revisions(lua, *revs)?)?;
            result.set("token", token('l', lock.0))?;
        }
        Reply::Inspected {
            revisions: revs,
            sources: source,
        } => {
            result.set("kind", "Inspected")?;
            result.set("revisions", revisions(lua, *revs)?)?;
            sources(lua, &result, source)?;
        }
        Reply::Ready {
            revisions: revs,
            sources: source,
            cleanup,
            source: snapshot,
        } => {
            result.set("kind", "Ready")?;
            result.set("revisions", revisions(lua, *revs)?)?;
            sources(lua, &result, source)?;
            result.set("cleanup", token('c', cleanup.0))?;
            result.set("source", LuaSource(snapshot.clone()))?;
        }
        Reply::Pending {
            revisions: revs,
            sources: source,
        } => {
            result.set("kind", "Pending")?;
            result.set("revisions", revisions(lua, *revs)?)?;
            sources(lua, &result, source)?;
        }
    }
    Ok(result)
}

pub(super) fn outcome(lua: &Lua, outcome: Outcome) -> LuaResult<LuaValue> {
    match outcome {
        Outcome::Reply(value) => reply(lua, &value)?.into_lua(lua),
        Outcome::State(value) => LuaState(value).into_lua(lua),
        Outcome::Provider(value) => LuaProvider(value).into_lua(lua),
        Outcome::Query(value) => LuaQuery(value).into_lua(lua),
        Outcome::Plan(value) => LuaPlan(value).into_lua(lua),
        Outcome::TaskUpdate(value) => token('u', value.0).into_lua(lua),
    }
}

pub(super) fn header(lua: &Lua, frame: &Snapshot) -> LuaResult<LuaTable> {
    let result = lua.create_table()?;
    result.set("frame_id", token('f', frame.id))?;
    result.set("state_id", token('s', frame.state_id()))?;
    result.set("data_id", token('d', frame.state.data_identity))?;
    result.set(
        "data_revision",
        token('r', frame.source().revision().value()),
    )?;
    result.set("state_revision", token('r', frame.state_revision().value()))?;
    result.set(
        "selection_revision",
        token('r', frame.selection_revision().value()),
    )?;
    result.set("commit_revision", token('r', frame.commit_revision.value()))?;
    result.set("layout_revision", token('r', frame.layout_revision.value()))?;
    result.set("row_count", frame.len())?;
    result.set(
        "mode",
        if frame.mode() == Mode::Tree {
            "tree"
        } else {
            "list"
        },
    )?;
    result.set("cursor", frame.cursor().map(node))?;
    result.set(
        "cursor_row",
        frame
            .cursor()
            .and_then(|id| frame.position(id))
            .map(|row| row + 1),
    )?;
    result.set("summary", summary(lua, frame.summary)?)?;
    result.set("needed_children", LuaIds(frame.needed_children.clone()))?;
    result.set("visited_nodes", frame.visited_nodes)?;
    let root = lua.create_table()?;
    match frame.root() {
        Root::ChildrenOf(id) => {
            root.set("kind", "children_of")?;
            root.set("node", node(*id))?;
        }
        Root::Forest(ids) => {
            root.set("kind", "forest")?;
            root.set("nodes", LuaIds(ids.clone()))?;
        }
    }
    result.set("root", root)?;
    let queries = lua.create_table()?;
    for (index, item) in frame.queries.iter().enumerate() {
        queries.raw_set(index + 1, query(lua, item)?)?;
    }
    result.set("queries", queries)?;
    Ok(result)
}

pub(super) fn detail(lua: &Lua, source: &Source, id: NodeId) -> LuaResult<Option<LuaTable>> {
    let Some(item) = source.node(id) else {
        return Ok(None);
    };
    let result = lua.create_table()?;
    result.set("id", node(id))?;
    result.set("key", item.key.as_ref())?;
    result.set("parent", item.parent.map(node))?;
    result.set("label", item.data.label.as_ref())?;
    result.set("can_expand", item.data.can_expand)?;
    result.set("foldable", item.data.foldable)?;
    result.set("hidden", item.data.hidden)?;
    result.set("score", item.data.score)?;
    result.set("icon", item.data.icon.as_deref())?;
    result.set("highlight", item.data.highlight.as_deref())?;
    result.set("right_text", item.data.right_text.as_deref())?;
    result.set("fields", fields(lua, &item.data.fields)?)?;
    result.set("completeness", item.completeness.as_str())?;
    result.set("load_state", item.load_state.as_str())?;
    result.set(
        "error",
        item.error.as_ref().map(|err| error(lua, err)).transpose()?,
    )?;
    result.set("child_count", item.child_count())?;
    Ok(Some(result))
}

pub(super) fn rows(lua: &Lua, frame: &Snapshot, start: usize, end: usize) -> LuaResult<LuaTable> {
    let batch = frame.rows(start, end).map_err(LuaError::external)?;
    let result = lua.create_table()?;
    let names = [
        "ids",
        "labels",
        "depths",
        "parents",
        "last_children",
        "last_descendants",
        "connector_last",
        "marked",
        "full",
        "pending",
        "expanded",
        "can_expand",
        "icons",
        "highlights",
        "right_texts",
        "load_states",
        "errors",
        "matches",
        "folded_ids",
        "guides",
    ];
    let columns: Vec<_> = names
        .iter()
        .map(|_| lua.create_table_with_capacity(batch.len(), 0))
        .collect::<LuaResult<_>>()?;
    struct Guide {
        depth: usize,
        previous: Option<usize>,
    }
    let mut ancestors = HashMap::<NodeId, Option<usize>>::new();
    let mut guides = Vec::<Guide>::new();
    let mut remaining_guides = 8192;
    for (offset, info) in batch.iter().enumerate() {
        let index = offset + 1;
        columns[0].raw_set(index, node(info.row.id))?;
        columns[1].raw_set(index, info.label.as_str())?;
        columns[2].raw_set(index, info.row.depth)?;
        columns[3].raw_set(
            index,
            info.row
                .parent
                .and_then(|id| frame.position(id))
                .map_or(0, |row| row + 1),
        )?;
        columns[4].raw_set(
            index,
            info.row
                .last_child
                .and_then(|id| frame.position(id))
                .map_or(0, |row| row + 1),
        )?;
        columns[5].raw_set(
            index,
            frame
                .position(info.row.last_descendant)
                .map_or(0, |row| row + 1),
        )?;
        columns[6].raw_set(index, info.row.connector_last)?;
        columns[7].raw_set(index, info.marked)?;
        columns[8].raw_set(index, info.full)?;
        columns[9].raw_set(index, info.pending)?;
        columns[10].raw_set(index, info.expanded)?;
        columns[11].raw_set(index, info.can_expand)?;
        for (column, text) in [
            (12, &info.icon),
            (13, &info.highlight),
            (14, &info.right_text),
        ] {
            columns[column].raw_set(
                index,
                text.as_ref()
                    .map(|text| lua.create_string(text.as_bytes()).map(LuaValue::String))
                    .transpose()?
                    .unwrap_or(LuaValue::Boolean(false)),
            )?;
        }
        columns[15].raw_set(index, info.load_state.as_str())?;
        columns[16].raw_set(
            index,
            info.error
                .as_ref()
                .map(|err| error(lua, err).map(LuaValue::Table))
                .transpose()?
                .unwrap_or(LuaValue::Boolean(false)),
        )?;
        let matches = lua.create_table()?;
        for (at, &(first, last)) in info.matches.iter().enumerate() {
            matches.raw_set(at + 1, lua.create_sequence_from([first, last])?)?;
        }
        columns[17].raw_set(index, matches)?;
        columns[18].raw_set(index, LuaIds(info.row.folded_ids().into()))?;
        let mut path = Vec::new();
        let mut parent = info.row.parent;
        let mut link = None;
        while let Some(id) = parent {
            if let Some(cached) = ancestors.get(&id) {
                link = *cached;
                break;
            }
            let row = frame.rows.lookup(id).expect("frame ancestor");
            path.push(row);
            parent = row.parent;
        }
        for row in path.into_iter().rev() {
            if !row.connector_last {
                if guides.len() == 8192 {
                    return Err(LuaError::external(Error::limit(
                        "viewport guides exceed 8192",
                    )));
                }
                guides.push(Guide {
                    depth: row.depth,
                    previous: link,
                });
                link = Some(guides.len() - 1);
            }
            ancestors.insert(row.id, link);
        }
        let list = lua.create_table()?;
        let mut at = 1;
        while let Some(index) = link {
            if remaining_guides == 0 {
                return Err(LuaError::external(Error::limit(
                    "viewport guides exceed 8192",
                )));
            }
            remaining_guides -= 1;
            let guide = &guides[index];
            list.raw_set(at, guide.depth)?;
            at += 1;
            link = guide.previous;
        }
        columns[19].raw_set(index, list)?;
    }
    for (name, column) in names.into_iter().zip(columns) {
        result.set(name, column)?;
    }
    result.set("first", start + 1)?;
    Ok(result)
}
