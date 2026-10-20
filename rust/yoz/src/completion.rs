//! Completion snapshots, native ranking and Lua bindings.

use mlua::prelude::*;
use mlua::{UserData, UserDataMethods};

pub(crate) mod fuzzy;
mod history;
mod rank;

use fuzzy::Matcher;
use history::{Entry, History};
use rank::Snapshot;

impl UserData for Matcher {
    fn add_methods<M: UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("query", |_, matcher, query: String| {
            Ok(matcher.query(&query))
        });
        methods.add_method("query_packed", |lua, matcher, query: String| {
            if matcher.len() > u32::MAX as usize {
                return Err(LuaError::runtime("completion candidate count exceeds u32"));
            }
            lua.create_string(matcher.query_packed(&query))
        });
    }
}

impl UserData for Snapshot {}

fn parse_history(data: Option<LuaTable>) -> LuaResult<History> {
    let mut history = History::default();
    let Some(data) = data else { return Ok(history) };
    history.max_timestamps = data.get::<Option<usize>>("MAX_TIMESTAMPS")?.unwrap_or(10);
    if history.max_timestamps == 0 || history.max_timestamps > i32::MAX as usize / 10 {
        return Err(LuaError::runtime(
            "invalid completion history timestamp limit",
        ));
    }
    if let Some(items) = data.get::<Option<LuaTable>>("items")? {
        for pair in items.pairs::<String, LuaTable>() {
            let (key, item) = pair?;
            let key = history::parse_key(&key)
                .ok_or_else(|| LuaError::runtime("invalid completion history key"))?;
            let timestamps: Vec<i64> = item.get("timestamps")?;
            if timestamps.is_empty() {
                continue;
            }
            let index: usize = item.get("idx")?;
            if timestamps.len() > history.max_timestamps || index == 0 || index > timestamps.len() {
                return Err(LuaError::runtime(
                    "invalid completion history timestamp ring",
                ));
            }
            history
                .entries
                .insert(key, Entry::new(timestamps, index - 1));
        }
    }
    Ok(history)
}

fn dump_history(lua: &Lua, history: &History) -> LuaResult<LuaTable> {
    let data = lua.create_table()?;
    let items = lua.create_table_with_capacity(0, history.entries.len())?;
    for (key, entry) in &history.entries {
        let item = lua.create_table()?;
        item.set(
            "timestamps",
            lua.create_sequence_from(entry.timestamps.iter().copied())?,
        )?;
        item.set("idx", entry.index + 1)?;
        items.set(history::format_key(key), item)?;
    }
    data.set("MAX_TIMESTAMPS", history.max_timestamps)?;
    data.set("items", items)?;
    Ok(data)
}

impl UserData for History {
    fn add_methods<M: UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut("access", |_, history, key: LuaString| {
            history.access(history::key(&key.as_bytes()), history::now());
            Ok(())
        });
        methods.add_method_mut("score", |_, history, key: LuaString| {
            Ok(history.score(&history::key(&key.as_bytes()), history::now()))
        });
        methods.add_method("dump", |lua, history, ()| dump_history(lua, history));
        methods.add_method_mut("load", |_, history, data: LuaTable| {
            *history = parse_history(Some(data))?;
            Ok(())
        });
    }
}

fn prepare_snapshot(data: LuaTable) -> LuaResult<Snapshot> {
    /* Column arrays keep the Lua payload opaque and avoid per-candidate string-key
     * lookups, nested table handles and repeated filetype decoding. */
    let labels: LuaTable = data.get("labels")?;
    let filters: LuaTable = data.get("filters")?;
    let sort_texts: LuaTable = data.get("sort_texts")?;
    let ids: LuaTable = data.get("ids")?;
    let frecency_keys: LuaTable = data.get("frecency_keys")?;
    let offsets: LuaTable = data.get("offsets")?;
    let deprecated: LuaTable = data.get("deprecated")?;
    let regions: Vec<usize> = data.get("regions")?;
    let filetypes: Vec<String> = data.get("filetypes")?;
    let count = labels.raw_len();
    if regions.len() != count
        || [
            &filters,
            &sort_texts,
            &ids,
            &frecency_keys,
            &offsets,
            &deprecated,
        ]
        .iter()
        .any(|column| column.raw_len() != count)
    {
        return Err(LuaError::runtime(
            "completion metadata columns differ in length",
        ));
    }
    let mut candidates = Vec::with_capacity(count);
    for (index, region) in regions.into_iter().enumerate() {
        let region = region
            .checked_sub(1)
            .filter(|region| *region < filetypes.len())
            .ok_or_else(|| LuaError::runtime("invalid completion region"))?;
        let position = index + 1;
        let label: String = labels.raw_get(position)?;
        let filter: LuaString = filters.raw_get(position)?;
        let (has_sort_text, sort_text) = match sort_texts.raw_get::<LuaValue>(position)? {
            LuaValue::Boolean(false) => (false, None),
            LuaValue::String(text) => {
                let text = text.to_str()?;
                (true, (text.as_ref() != label).then(|| text.to_string()))
            }
            _ => {
                return Err(LuaError::runtime(
                    "completion sort text must be a string or false",
                ));
            }
        };
        let key: LuaString = frecency_keys.raw_get(position)?;
        let offset: f64 = offsets.raw_get(position)?;
        if !offset.is_finite() {
            return Err(LuaError::runtime("completion score offset must be finite"));
        }
        candidates.push(rank::Candidate {
            fuzzy: fuzzy::Candidate::new(&filter.to_str()?),
            id: rank::Identity::new(&ids.raw_get::<LuaString>(position)?.as_bytes()),
            sort_text,
            has_sort_text,
            label,
            history_key: history::candidate_key(&filetypes[region], &key.as_bytes()),
            offset,
            deprecated: deprecated.raw_get(position)?,
            region,
        });
    }
    Ok(Snapshot {
        candidates,
        regions: filetypes.len(),
    })
}

fn rank_snapshots(
    lua: &Lua,
    requests: LuaTable,
    nearby: LuaString,
    history: Option<LuaAnyUserData>,
) -> LuaResult<(LuaTable, LuaTable, LuaTable)> {
    let mut specs = Vec::with_capacity(requests.raw_len());
    for request in requests.sequence_values::<LuaTable>() {
        let request = request?;
        specs.push((
            request.get::<LuaAnyUserData>("snapshot")?,
            request.get::<String>("query")?,
            request.get::<Vec<bool>>("eligible")?,
        ));
    }
    let snapshots = specs
        .iter()
        .map(|spec| spec.0.borrow::<Snapshot>())
        .collect::<LuaResult<Vec<_>>>()?;
    let mut native_requests = Vec::with_capacity(specs.len());
    for (snapshot, (_, query, eligible)) in snapshots.iter().zip(&specs) {
        if snapshot.regions != eligible.len() {
            return Err(LuaError::runtime(
                "completion eligibility mask does not match its snapshot",
            ));
        }
        native_requests.push(rank::Request {
            snapshot,
            query,
            eligible,
        });
    }
    let mut history = history
        .map(|value| value.borrow_mut::<History>())
        .transpose()?;
    let ranked = rank::query(
        &native_requests,
        &nearby.as_bytes(),
        history.as_deref_mut(),
        history::now(),
    );
    let groups = lua.create_table_with_capacity(ranked.len(), 0)?;
    let indexes = lua.create_table_with_capacity(ranked.len(), 0)?;
    let scores = lua.create_table_with_capacity(ranked.len(), 0)?;
    for (position, item) in ranked.into_iter().enumerate() {
        groups.raw_set(position + 1, item.request)?;
        indexes.raw_set(position + 1, item.index)?;
        scores.raw_set(position + 1, item.score)?;
    }
    Ok((groups, indexes, scores))
}

pub fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set(
        "match_ranges",
        lua.create_function(|_, (query, text): (String, String)| {
            Ok(fuzzy::match_ranges(&query, &text))
        })?,
    )?;
    module.set(
        "new",
        lua.create_function(|_, labels: Vec<String>| Ok(Matcher::new(&labels)))?,
    )?;
    module.set(
        "new_snapshot",
        lua.create_function(|_, data: LuaTable| prepare_snapshot(data))?,
    )?;
    module.set(
        "new_history",
        lua.create_function(|_, data: Option<LuaTable>| parse_history(data))?,
    )?;
    module.set(
        "rank",
        lua.create_function(
            |lua, (requests, nearby, history): (LuaTable, LuaString, Option<LuaAnyUserData>)| {
                rank_snapshots(lua, requests, nearby, history)
            },
        )?,
    )?;
    Ok(module)
}
