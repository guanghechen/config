use super::LuaFrame;
use crate::ux::treeview::*;
use mlua::prelude::*;
use std::collections::{BTreeMap, HashSet};
use std::sync::Arc;

pub(super) fn invalid(error: impl std::fmt::Display) -> Error {
    Error::invalid(error.to_string())
}

pub(super) fn table(value: LuaValue) -> Result<LuaTable> {
    match value {
        LuaValue::Table(table) => Ok(table),
        _ => Err(Error::invalid("expected a table")),
    }
}

pub(super) fn get<T: FromLua>(table: &LuaTable, key: &str) -> Result<T> {
    table.raw_get(key).map_err(invalid)
}

pub(super) fn integer(value: LuaValue) -> Result<usize> {
    match value {
        LuaValue::Integer(value) if value >= 0 => usize::try_from(value).map_err(invalid),
        LuaValue::Number(value)
            if value.is_finite()
                && value >= 0.0
                && value.fract() == 0.0
                && value <= 9_007_199_254_740_991.0 =>
        {
            Ok(value as usize)
        }
        _ => Err(Error::invalid("expected an exact nonnegative integer")),
    }
}

pub(super) fn boolean(value: LuaValue) -> Result<bool> {
    match value {
        LuaValue::Boolean(value) => Ok(value),
        _ => Err(Error::invalid("expected a boolean")),
    }
}

fn option_bool(table: &LuaTable, key: &str) -> Result<Option<bool>> {
    match get(table, key)? {
        LuaValue::Nil => Ok(None),
        value => boolean(value).map(Some),
    }
}

pub(super) fn string(value: LuaValue) -> Result<Arc<str>> {
    match value {
        LuaValue::String(value) if value.as_bytes().len() <= 64 * 1024 * 1024 => value
            .to_str()
            .map(|text| Arc::<str>::from(text.as_ref()))
            .map_err(invalid),
        _ => Err(Error::invalid("expected a UTF-8 string")),
    }
}

pub(super) fn token(value: LuaValue, prefix: char) -> Result<u64> {
    let LuaValue::String(value) = value else {
        return Err(Error::invalid("expected an opaque token"));
    };
    if value.as_bytes().len() != 17 {
        return Err(Error::invalid("expected an opaque token"));
    }
    let text = value.to_str().map_err(invalid)?;
    if text.len() != 17
        || !text.starts_with(prefix)
        || !text.as_bytes()[1..].iter().all(u8::is_ascii_hexdigit)
    {
        return Err(Error::invalid(
            "expected an opaque identity or revision token",
        ));
    }
    u64::from_str_radix(&text[1..], 16).map_err(invalid)
}

pub(super) fn array_len(table: &LuaTable) -> Result<usize> {
    let len = table.raw_len();
    if len > 200_000 {
        return Err(Error::limit("array input capacity exceeded"));
    }
    let mut count = 0;
    for entry in table.clone().pairs::<LuaValue, LuaValue>() {
        let (key, _) = entry.map_err(invalid)?;
        let index = integer(key)?;
        if index == 0 || index > len {
            return Err(Error::invalid("expected a dense 1-based array"));
        }
        count += 1;
    }
    if count != len {
        return Err(Error::invalid("expected a dense 1-based array"));
    }
    Ok(len)
}

fn validate_input(value: &LuaValue, byte_limit: usize) -> Result<()> {
    fn walk(
        value: &LuaValue,
        depth: usize,
        active: &mut HashSet<usize>,
        bytes: &mut usize,
        count: &mut usize,
        byte_limit: usize,
    ) -> Result<()> {
        *count += 1;
        *bytes = bytes.saturating_add(32);
        if depth > 36 || *count > 2_000_000 || *bytes > byte_limit {
            return Err(Error::limit("Lua input capacity exceeded"));
        }
        match value {
            LuaValue::String(value) => {
                *bytes = bytes.saturating_add(value.as_bytes().len());
            }
            LuaValue::Number(value) if !value.is_finite() => {
                return Err(Error::invalid("numbers must be finite"));
            }
            LuaValue::Table(table) => {
                let pointer = table.to_pointer() as usize;
                if !active.insert(pointer) {
                    return Err(Error::invalid("cyclic input table"));
                }
                for entry in table.clone().pairs::<LuaValue, LuaValue>() {
                    let (key, value) = entry.map_err(invalid)?;
                    walk(&key, depth + 1, active, bytes, count, byte_limit)?;
                    walk(&value, depth + 1, active, bytes, count, byte_limit)?;
                }
                active.remove(&pointer);
            }
            _ => {}
        }
        if *bytes > byte_limit {
            return Err(Error::limit("Lua input byte capacity exceeded"));
        }
        Ok(())
    }
    walk(
        value,
        0,
        &mut HashSet::new(),
        &mut 0usize,
        &mut 0usize,
        byte_limit,
    )
}

pub(super) fn node(value: LuaValue) -> Result<NodeId> {
    token(value, 'n').map(NodeId)
}
pub(super) fn revision(value: LuaValue) -> Result<Revision> {
    token(value, 'r').map(Revision)
}

pub(super) fn ids(value: LuaValue) -> Result<Arc<[NodeId]>> {
    let table = table(value)?;
    let count = array_len(&table)?;
    (1..=count)
        .map(|index| node(table.raw_get(index).map_err(invalid)?))
        .collect()
}

pub(super) fn reference(value: LuaValue) -> Result<NodeRef> {
    match value {
        LuaValue::String(value) => Ok(NodeRef::Key(string(LuaValue::String(value))?)),
        LuaValue::Table(value) => Ok(NodeRef::Id(node(get(&value, "id")?)?)),
        _ => Err(Error::invalid(
            "node reference must be a provider key or {id=NodeId}",
        )),
    }
}

fn optional_reference(value: LuaValue) -> Result<Option<NodeRef>> {
    match value {
        LuaValue::Nil | LuaValue::Boolean(false) => Ok(None),
        value => reference(value).map(Some),
    }
}

fn target_reference(table: &LuaTable) -> Result<NodeRef> {
    match get(table, "id")? {
        LuaValue::Nil => reference(get(table, "node")?),
        value => node(value).map(NodeRef::Id),
    }
}

fn optional_text(value: LuaValue) -> Result<Option<Option<Arc<str>>>> {
    match value {
        LuaValue::Nil => Ok(None),
        LuaValue::Boolean(false) => Ok(Some(None)),
        value => string(value).map(|text| Some(Some(text))),
    }
}

fn completeness(value: LuaValue) -> Result<Option<Completeness>> {
    if matches!(value, LuaValue::Nil | LuaValue::Boolean(false)) {
        return Ok(None);
    }
    match string(value)?.as_ref() {
        "unknown" => Ok(Some(Completeness::Unknown)),
        "partial" => Ok(Some(Completeness::Partial)),
        "complete" => Ok(Some(Completeness::Complete)),
        _ => Err(Error::invalid("unknown children completeness")),
    }
}

struct Decoder {
    bytes: usize,
    entries: usize,
    active: HashSet<usize>,
}

impl Decoder {
    fn charge(&mut self, bytes: usize) -> Result<()> {
        self.bytes = self
            .bytes
            .checked_add(bytes)
            .ok_or_else(|| Error::limit("Lua payload size overflow"))?;
        self.entries += 1;
        if self.bytes > 64 * 1024 * 1024 || self.entries > 1_000_000 {
            return Err(Error::limit("Lua payload capacity exceeded"));
        }
        Ok(())
    }
    fn value(&mut self, value: LuaValue, depth: usize) -> Result<Value> {
        if depth > 32 {
            return Err(Error::limit("Lua payload nesting exceeds 32"));
        }
        self.charge(16)?;
        Ok(match value {
            LuaValue::Nil => Value::Null,
            LuaValue::LightUserData(value) if value.0.is_null() => Value::Null,
            LuaValue::Boolean(value) => Value::Boolean(value),
            LuaValue::Integer(value) => Value::Integer(value),
            LuaValue::Number(value) if value.is_finite() => Value::Number(value),
            LuaValue::String(value) => {
                self.charge(value.as_bytes().len())?;
                match value.to_str() {
                    Ok(text) => Value::String(text.as_ref().into()),
                    Err(_) => Value::Bytes(value.as_bytes().as_ref().into()),
                }
            }
            LuaValue::Table(table) => {
                let pointer = table.to_pointer() as usize;
                if !self.active.insert(pointer) {
                    return Err(Error::invalid("cyclic Lua payload"));
                }
                let value = if table.raw_len() != 0 {
                    let len = table.raw_len();
                    self.charge(len.saturating_mul(16))?;
                    let mut values = Vec::with_capacity(len);
                    for index in 1..=len {
                        values.push(self.value(table.raw_get(index).map_err(invalid)?, depth + 1)?);
                    }
                    for pair in table.clone().pairs::<LuaValue, LuaValue>() {
                        let (key, _) = pair.map_err(invalid)?;
                        let index = integer(key)?;
                        if index == 0 || index > len {
                            return Err(Error::invalid("payload array has non-array keys"));
                        }
                    }
                    Value::Array(values.into())
                } else {
                    let mut fields = BTreeMap::new();
                    for pair in table.clone().pairs::<LuaValue, LuaValue>() {
                        let (key, value) = pair.map_err(invalid)?;
                        let key = string(key)?;
                        self.charge(key.len())?;
                        fields.insert(key.to_string(), self.value(value, depth + 1)?);
                    }
                    Value::Object(Arc::new(fields))
                };
                self.active.remove(&pointer);
                value
            }
            _ => {
                return Err(Error::invalid(
                    "payload must contain owned scalar, string, array, or object values",
                ));
            }
        })
    }
    fn fields(&mut self, value: LuaValue) -> Result<Fields> {
        if matches!(value, LuaValue::Nil | LuaValue::Boolean(false)) {
            return Ok(super::super::model::empty_fields());
        }
        match self.value(value, 0)? {
            Value::Object(fields) => Ok(fields),
            _ => Err(Error::invalid("fields must be a string-keyed object")),
        }
    }
}

fn data(table: &LuaTable, decoder: &mut Decoder) -> Result<NodeData> {
    let label = string(get(table, "label")?)?;
    decoder.charge(label.len())?;
    let data = NodeData {
        label,
        can_expand: option_bool(table, "can_expand")?.unwrap_or(false),
        foldable: option_bool(table, "foldable")?.unwrap_or(false),
        hidden: option_bool(table, "hidden")?.unwrap_or(false),
        score: get::<Option<f64>>(table, "score")?.unwrap_or(0.0),
        icon: optional_text(get(table, "icon")?)?.flatten(),
        highlight: optional_text(get(table, "highlight")?)?.flatten(),
        right_text: optional_text(get(table, "right_text")?)?.flatten(),
        fields: decoder.fields(get(table, "fields")?)?,
    };
    data.validate()?;
    Ok(data)
}

pub(super) fn records(value: LuaValue) -> Result<Vec<Record>> {
    records_bounded(value, 64 * 1024 * 1024)
}

pub(super) fn records_bounded(value: LuaValue, byte_limit: usize) -> Result<Vec<Record>> {
    validate_input(&value, byte_limit)?;
    let input = table(value)?;
    let mut decoder = Decoder {
        bytes: 0,
        entries: 0,
        active: HashSet::new(),
    };
    if let Some(keys) = get::<Option<LuaTable>>(&input, "keys")? {
        let count = array_len(&keys)?;
        let names = [
            "labels",
            "parents",
            "can_expand",
            "foldable",
            "hidden",
            "scores",
            "icons",
            "highlights",
            "right_texts",
            "fields",
            "completeness",
        ];
        let columns: Vec<_> = names
            .iter()
            .map(|name| get::<Option<LuaTable>>(&input, name))
            .collect::<Result<_>>()?;
        let parent_keys: Option<LuaTable> = get(&input, "parent_keys")?;
        if parent_keys
            .as_ref()
            .map(array_len)
            .transpose()?
            .is_some_and(|len| len != count)
        {
            return Err(Error::invalid("parent key column has a different length"));
        }
        if parent_keys.is_some() && columns[1].is_some() {
            return Err(Error::invalid("provide either parents or parent_keys"));
        }
        if columns[0].is_none() {
            return Err(Error::invalid("record columns require labels"));
        }
        for column in columns.iter().flatten() {
            if array_len(column)? != count {
                return Err(Error::invalid("record columns have unequal lengths"));
            }
        }
        let mut names = Vec::with_capacity(count);
        for at in 1..=count {
            let key = string(keys.raw_get(at).map_err(invalid)?)?;
            decoder.charge(key.len())?;
            names.push(key);
        }
        let mut records = Vec::with_capacity(count);
        for at in 1..=count {
            let value = |index: usize| -> Result<LuaValue> {
                columns[index]
                    .as_ref()
                    .map(|column| column.raw_get(at).map_err(invalid))
                    .unwrap_or(Ok(LuaValue::Nil))
            };
            let label = string(value(0)?)?;
            decoder.charge(label.len())?;
            let parent = if let Some(parent_keys) = &parent_keys {
                optional_reference(parent_keys.raw_get(at).map_err(invalid)?)?
            } else {
                match value(1)? {
                    LuaValue::Nil => None,
                    value => {
                        let index = integer(value)?;
                        if index > count || index == at {
                            return Err(Error::invalid("invalid parent column index"));
                        }
                        index
                            .checked_sub(1)
                            .map(|index| NodeRef::Key(names[index].clone()))
                    }
                }
            };
            let optional_bool = |index| -> Result<bool> {
                match value(index)? {
                    LuaValue::Nil => Ok(false),
                    value => boolean(value),
                }
            };
            let score = match value(5)? {
                LuaValue::Nil => 0.0,
                LuaValue::Number(value) => value,
                LuaValue::Integer(value) => value as f64,
                _ => return Err(Error::invalid("scores must be numbers")),
            };
            let data = NodeData {
                label,
                can_expand: optional_bool(2)?,
                foldable: optional_bool(3)?,
                hidden: optional_bool(4)?,
                score,
                icon: optional_text(value(6)?)?.flatten(),
                highlight: optional_text(value(7)?)?.flatten(),
                right_text: optional_text(value(8)?)?.flatten(),
                fields: decoder.fields(value(9)?)?,
            };
            data.validate()?;
            records.push(Record {
                key: names[at - 1].clone(),
                parent,
                data,
                completeness: completeness(value(10)?)?,
            });
        }
        return Ok(records);
    }
    let count = array_len(&input)?;
    let mut records = Vec::with_capacity(count);
    for at in 1..=count {
        let row: LuaTable = input.raw_get(at).map_err(invalid)?;
        let key = string(get(&row, "key")?)?;
        decoder.charge(key.len())?;
        records.push(Record {
            key,
            parent: optional_reference(get(&row, "parent")?)?,
            data: data(&row, &mut decoder)?,
            completeness: completeness(get(&row, "completeness")?)?,
        });
    }
    Ok(records)
}

fn patch(table: &LuaTable, decoder: &mut Decoder) -> Result<NodePatch> {
    Ok(NodePatch {
        label: get::<Option<LuaString>>(table, "label")?
            .map(|value| string(LuaValue::String(value)))
            .transpose()?,
        can_expand: option_bool(table, "can_expand")?,
        foldable: option_bool(table, "foldable")?,
        hidden: option_bool(table, "hidden")?,
        score: get(table, "score")?,
        icon: optional_text(get(table, "icon")?)?,
        highlight: optional_text(get(table, "highlight")?)?,
        right_text: optional_text(get(table, "right_text")?)?,
        fields: match get(table, "fields")? {
            LuaValue::Nil => None,
            value => Some(decoder.fields(value)?),
        },
        completeness: completeness(get(table, "completeness")?)?,
    })
}

fn position(value: LuaValue) -> Result<Position> {
    match value {
        LuaValue::Nil => Ok(Position::Last),
        LuaValue::String(value) => match value.to_str().map_err(invalid)?.as_ref() {
            "first" => Ok(Position::First),
            "last" => Ok(Position::Last),
            _ => Err(Error::invalid("unknown insertion position")),
        },
        LuaValue::Table(value) => {
            let before: LuaValue = get(&value, "before")?;
            if !matches!(before, LuaValue::Nil) {
                return reference(before).map(Position::Before);
            }
            reference(get(&value, "after")?).map(Position::After)
        }
        _ => Err(Error::invalid("invalid insertion position")),
    }
}

pub(super) fn batch(value: LuaValue) -> Result<Batch> {
    validate_input(&value, 64 * 1024 * 1024)?;
    let input = table(value)?;
    let base_revision = revision(get(&input, "base_revision")?)?;
    let items: LuaTable = get(&input, "operations")?;
    let count = array_len(&items)?;
    let mut decoder = Decoder {
        bytes: 0,
        entries: 0,
        active: HashSet::new(),
    };
    let mut operations = Vec::with_capacity(count);
    for index in 1..=count {
        let item: LuaTable = items.raw_get(index).map_err(invalid)?;
        let kind = string(get(&item, "kind")?)?;
        operations.push(match kind.as_ref() {
            "insert" => {
                let key = string(get(&item, "key")?)?;
                decoder.charge(key.len())?;
                let data = data(&item, &mut decoder)?;
                let completeness =
                    completeness(get(&item, "completeness")?)?.unwrap_or(if data.can_expand {
                        Completeness::Unknown
                    } else {
                        Completeness::Complete
                    });
                Operation::Insert {
                    key,
                    parent: optional_reference(get(&item, "parent")?)?,
                    position: position(get(&item, "position")?)?,
                    data,
                    completeness,
                }
            }
            "update" => Operation::Update {
                node: target_reference(&item)?,
                patch: patch(&item, &mut decoder)?,
            },
            "reparent" => Operation::Reparent {
                node: target_reference(&item)?,
                parent: optional_reference(get(&item, "parent")?)?,
                position: position(get(&item, "position")?)?,
            },
            "remove" => Operation::Remove {
                node: target_reference(&item)?,
            },
            "reorder" => {
                let children: LuaTable = get(&item, "children")?;
                let count = array_len(&children)?;
                Operation::Reorder {
                    parent: optional_reference(get(&item, "parent")?)?,
                    children: (1..=count)
                        .map(|at| reference(children.raw_get(at).map_err(invalid)?))
                        .collect::<Result<_>>()?,
                }
            }
            _ => return Err(Error::invalid("unknown tree update operation")),
        });
    }
    Ok(Batch {
        base_revision,
        operations,
    })
}

pub(super) fn scope(value: LuaValue) -> Result<DataScope> {
    if matches!(value, LuaValue::Nil) {
        return Ok(DataScope::Forest);
    }
    let value = table(value)?;
    match string(get(&value, "kind")?)?.as_ref() {
        "forest" => Ok(DataScope::Forest),
        "children" => node(get(&value, "node")?).map(DataScope::Children),
        "descendants" => node(get(&value, "node")?).map(DataScope::Descendants),
        _ => Err(Error::invalid("unknown provider scope")),
    }
}

pub(super) fn root(value: LuaValue) -> Result<Root> {
    let value = table(value)?;
    match string(get(&value, "kind")?)?.as_ref() {
        "children_of" => node(get(&value, "node")?).map(Root::ChildrenOf),
        "forest" => ids(get(&value, "nodes")?).map(Root::Forest),
        _ => Err(Error::invalid("unknown display root")),
    }
}

pub(super) fn display(value: LuaValue) -> Result<DisplayOptions> {
    if matches!(value, LuaValue::Nil) {
        return Ok(DisplayOptions::default());
    }
    let value = table(value)?;
    let mode = match get::<Option<String>>(&value, "mode")?
        .as_deref()
        .unwrap_or("tree")
    {
        "tree" => Mode::Tree,
        "list" => Mode::List,
        _ => return Err(Error::invalid("unknown display mode")),
    };
    let sort = match get::<Option<String>>(&value, "sort")?
        .as_deref()
        .unwrap_or("source")
    {
        "source" => Sort::Source,
        "name" => Sort::Name,
        "score" => Sort::Score,
        _ => return Err(Error::invalid("unknown sort")),
    };
    Ok(DisplayOptions {
        mode,
        sort,
        pattern: get::<Option<String>>(&value, "pattern")?
            .unwrap_or_default()
            .into(),
        case_sensitive: option_bool(&value, "case_sensitive")?.unwrap_or(false),
        show_hidden: option_bool(&value, "show_hidden")?.unwrap_or(true),
        selected_only: option_bool(&value, "selected_only")?.unwrap_or(false),
        compress: option_bool(&value, "compress")?.unwrap_or(false),
        branches_first: option_bool(&value, "branches_first")?.unwrap_or(false),
    })
}

pub(super) fn frame(value: LuaValue) -> Result<Arc<Snapshot>> {
    match value {
        LuaValue::UserData(value) => value
            .borrow::<LuaFrame>()
            .map(|frame| frame.0.clone())
            .map_err(invalid),
        _ => Err(Error::invalid("expected a native frame")),
    }
}

pub(super) fn context(value: LuaValue) -> Result<Context> {
    if matches!(value, LuaValue::Nil) {
        return Ok(Context::default());
    }
    let value = table(value)?;
    Ok(Context {
        expected_state: match get(&value, "expected_state")? {
            LuaValue::Nil => None,
            value => Some(revision(value)?),
        },
        frame: match get(&value, "frame")? {
            LuaValue::Nil => None,
            value => Some(frame(value)?),
        },
    })
}

fn targets(input: &LuaTable) -> Result<Targets> {
    let range: Option<LuaTable> = get(input, "range")?;
    if let Some(range) = range {
        let first = integer(get(&range, "first")?)?;
        let last = integer(get(&range, "last")?)?;
        if first == 0 {
            return Err(Error::invalid("Lua row input is 1-based"));
        }
        Ok(Targets::Range {
            frame: frame(get(&range, "frame")?)?,
            start: first - 1,
            end: last,
        })
    } else {
        ids(get(input, "nodes")?).map(Targets::Nodes)
    }
}

pub(super) fn direction(value: LuaValue) -> Result<Direction> {
    match string(value)?.as_ref() {
        "parent" => Ok(Direction::Parent),
        "last_child_or_sibling" => Ok(Direction::LastChildOrSibling),
        _ => Err(Error::invalid("unknown structural direction")),
    }
}

pub(super) fn command(value: LuaValue) -> Result<Command> {
    let input = table(value)?;
    let kind = string(get(&input, "kind")?)?;
    Ok(match kind.as_ref() {
        "set_root" => Command::SetRoot(root(get(&input, "root")?)?),
        "set_display" => Command::SetDisplay(display(get(&input, "display")?)?),
        "set_expanded" => Command::SetExpanded {
            targets: targets(&input)?,
            value: boolean(get(&input, "value")?)?,
            scope: if boolean(get(&input, "recursive")?)? {
                Scope::Subtree
            } else {
                Scope::SelfOnly
            },
        },
        "toggle_expanded" => Command::ToggleExpanded {
            node: node(get(&input, "node")?)?,
            scope: if boolean(get(&input, "recursive")?)? {
                Scope::Subtree
            } else {
                Scope::SelfOnly
            },
        },
        "select_node" | "deselect_node" | "toggle_node" => Command::Select {
            targets: targets(&input)?,
            scope: if boolean(get(&input, "recursive")?)? {
                Scope::Subtree
            } else {
                Scope::SelfOnly
            },
            action: match kind.as_ref() {
                "select_node" => SelectAction::Select,
                "deselect_node" => SelectAction::Deselect,
                _ => SelectAction::Toggle,
            },
        },
        "clear_selection" => Command::ClearSelection,
        "set_cursor" => Command::SetCursor(match get(&input, "node")? {
            LuaValue::Nil => None,
            value => Some(node(value)?),
        }),
        "navigate" => {
            let row = integer(get(&input, "row")?)?;
            if row == 0 {
                return Err(Error::invalid("Lua row input is 1-based"));
            }
            Command::Navigate {
                frame: frame(get(&input, "frame")?)?,
                row: row - 1,
                direction: direction(get(&input, "direction")?)?,
            }
        }
        "inspect_selection" => Command::InspectSelection,
        "prepare_sources" => Command::PrepareSources(LockToken(token(get(&input, "lock")?, 'l')?)),
        "unselect" => Command::Unselect {
            lock: LockToken(token(get(&input, "lock")?, 'l')?),
            cleanup: CleanupToken(token(get(&input, "cleanup")?, 'c')?),
            successful: ids(get(&input, "successful")?)?,
        },
        _ => return Err(Error::invalid("unknown treeview command")),
    })
}

pub(super) fn render_context(value: LuaValue) -> Result<RenderContext> {
    if matches!(value, LuaValue::Nil) {
        return Ok(RenderContext::default());
    }
    let value = table(value)?;
    Ok(RenderContext {
        version: match get(&value, "version")? {
            LuaValue::Nil => 1,
            value => token(value, 'r')?,
        },
        indent: match get(&value, "indent")? {
            LuaValue::Nil => 2,
            value => integer(value)?,
        },
        slots: match get(&value, "slots")? {
            LuaValue::Nil => 4,
            value => integer(value)?,
        },
        separator: get::<Option<String>>(&value, "separator")?
            .unwrap_or_else(|| "/".into())
            .into(),
    })
}

pub(super) fn query(value: LuaValue) -> Result<QueryInput> {
    validate_input(&value, 64 * 1024 * 1024)?;
    let value = table(value)?;
    let mut decoder = Decoder {
        bytes: 0,
        entries: 0,
        active: HashSet::new(),
    };
    Ok(QueryInput {
        pattern: string(get(&value, "pattern")?)?,
        options: decoder.fields(get(&value, "options")?)?,
    })
}

pub(super) fn error(value: LuaValue) -> Result<Error> {
    match value {
        LuaValue::String(value) => Ok(Error::invalid(value.to_str().map_err(invalid)?.to_string())),
        LuaValue::Table(value) => {
            let code = match get::<Option<String>>(&value, "code")?
                .as_deref()
                .unwrap_or("InvalidUpdate")
            {
                "InvalidUpdate" => ErrorCode::InvalidUpdate,
                "MissingNode" => ErrorCode::MissingNode,
                "Stale" => ErrorCode::Stale,
                "Busy" => ErrorCode::Busy,
                "Disposed" => ErrorCode::Disposed,
                "ResourceLimit" => ErrorCode::ResourceLimit,
                _ => return Err(Error::invalid("unknown error code")),
            };
            Ok(Error::new(code, string(get(&value, "message")?)?))
        }
        _ => Err(Error::invalid("expected a provider error")),
    }
}
