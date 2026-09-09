pub mod algorithm;
pub mod canonical_path;
pub mod cmp;
pub mod dict;
pub mod find;
pub mod r#fn;
pub mod fs;
pub mod path;
pub mod replace;
pub mod search;
pub mod string;
pub mod types;
pub mod uri;

use mlua::FromLua;
use mlua::FromLuaMulti;
use mlua::Function;
use mlua::IntoLua;
use mlua::IntoLuaMulti;
use mlua::MultiValue as LuaMultiValue;
use mlua::Value as LuaValue;
use mlua::prelude::*;
use std::cmp::Ordering;
use std::collections::{HashMap, HashSet};

#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
use std::cell::RefCell;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
use std::rc::Rc;

use crate::dict::search::SearchResultKind;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
use yoz_im as im;

#[inline]
fn f<A, R, F>(lua: &Lua, func: F) -> LuaResult<Function>
where
    A: FromLuaMulti,
    R: IntoLuaMulti,
    F: Fn(&Lua, A) -> LuaResult<R> + Send + 'static,
{
    lua.create_function(func)
}

fn fn_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        ("uuid", f(lua, |_, ()| Ok(r#fn::uuid()))?),
        ("md5", f(lua, |_, input: String| Ok(r#fn::md5(&input)))?),
    ])
}

#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
fn im_module(lua: &Lua) -> LuaResult<LuaTable> {
    let state = Rc::new(RefCell::new(im::Backend::default()));

    #[cfg(target_os = "linux")]
    let setup_state = Rc::clone(&state);
    #[cfg(target_os = "linux")]
    let setup = lua.create_function(move |lua, params: LuaTable| -> LuaResult<LuaMultiValue> {
        let executable = params.get::<String>("executable")?;
        let result = setup_state
            .try_borrow_mut()
            .map_err(|_| {
                LuaError::RuntimeError("IM state is already borrowed".to_owned())
            })?
            .setup(&executable);
        match result {
            Ok(()) => Ok(LuaMultiValue::from_vec(vec![
                true.into_lua(lua)?,
                LuaValue::Nil,
            ])),
            Err(error) => Ok(LuaMultiValue::from_vec(vec![
                LuaValue::Nil,
                error.into_lua(lua)?,
            ])),
        }
    })?;

    let capture_state = Rc::clone(&state);
    let capture = lua.create_function(move |lua, ()| -> LuaResult<LuaMultiValue> {
        let result = capture_state
            .try_borrow_mut()
            .map_err(|_| {
                LuaError::RuntimeError("IM state is already borrowed".to_owned())
            })?
            .capture();
        match result {
            Ok(source_id) => Ok(LuaMultiValue::from_vec(vec![
                source_id.into_lua(lua)?,
                LuaValue::Nil,
            ])),
            Err(error) => Ok(LuaMultiValue::from_vec(vec![
                LuaValue::Nil,
                error.into_lua(lua)?,
            ])),
        }
    })?;

    let capture_and_select_state = Rc::clone(&state);
    let capture_and_select_english =
        lua.create_function(move |lua, ()| -> LuaResult<LuaMultiValue> {
            let result = capture_and_select_state
                .try_borrow_mut()
                .map_err(|_| {
                    LuaError::RuntimeError("IM state is already borrowed".to_owned())
                })?
                .capture_and_select_english();
            match result {
                Ok(snapshot) => Ok(LuaMultiValue::from_vec(vec![
                    snapshot.into_lua(lua)?,
                    true.into_lua(lua)?,
                    LuaValue::Nil,
                ])),
                Err(im::CaptureAndSelectError::Capture(error)) => {
                    Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        false.into_lua(lua)?,
                        error.into_lua(lua)?,
                    ]))
                }
                Err(im::CaptureAndSelectError::Select { snapshot, error }) => {
                    Ok(LuaMultiValue::from_vec(vec![
                        snapshot.into_lua(lua)?,
                        false.into_lua(lua)?,
                        error.into_lua(lua)?,
                    ]))
                }
            }
        })?;

    let restore_state = Rc::clone(&state);
    let restore = lua.create_function(
        move |lua, source_id: String| -> LuaResult<LuaMultiValue> {
            let result = restore_state
                .try_borrow_mut()
                .map_err(|_| {
                    LuaError::RuntimeError("IM state is already borrowed".to_owned())
                })?
                .restore(&source_id);
            match result {
                Ok(()) => Ok(LuaMultiValue::from_vec(vec![
                    true.into_lua(lua)?,
                    LuaValue::Nil,
                ])),
                Err(error) => Ok(LuaMultiValue::from_vec(vec![
                    LuaValue::Nil,
                    error.into_lua(lua)?,
                ])),
            }
        },
    )?;

    let is_english_state = Rc::clone(&state);
    let is_english = lua.create_function(move |_, source_id: String| -> LuaResult<bool> {
        let is_english = is_english_state
            .try_borrow_mut()
            .map_err(|_| {
                LuaError::RuntimeError("IM state is already borrowed".to_owned())
            })?
            .is_english(&source_id);
        Ok(is_english)
    })?;

    let exports = lua.create_table()?;
    #[cfg(target_os = "linux")]
    exports.set("setup", setup)?;
    exports.set("capture", capture)?;
    exports.set("capture_and_select_english", capture_and_select_english)?;
    exports.set("restore", restore)?;
    exports.set("is_english", is_english)?;
    Ok(exports)
}

fn dict_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([(
        "search",
        f(lua, |lua, params: LuaValue| {
            let options = crate::types::IDictSearchOptions::from_lua(params, lua)?;
            let results = crate::dict::search::search(&options);
            let table = lua.create_table_with_capacity(results.len(), 0)?;
            for (idx, result) in results.into_iter().enumerate() {
                let entry = lua.create_table()?;
                let kind = match result.kind {
                    SearchResultKind::Scalar => "scalar",
                    SearchResultKind::Segment => "segment",
                };
                entry.set("type", kind)?;
                entry.set("indexes", result.indexes)?;
                table.set(idx + 1, entry)?;
            }
            Ok(LuaValue::Table(table))
        })?,
    )])
}

fn cmp_count(value: &LuaValue) -> u32 {
    match value {
        LuaValue::Integer(value) => (*value).clamp(0, u32::MAX as i64) as u32,
        LuaValue::Number(value) if value.is_finite() => {
            value.floor().clamp(0.0, u32::MAX as f64) as u32
        }
        _ => 0,
    }
}

fn cmp_score(value: &LuaValue) -> Option<f64> {
    match value {
        LuaValue::Integer(value) => Some(*value as f64),
        LuaValue::Number(value) if value.is_finite() => Some(*value),
        _ => None,
    }
}

fn cmp_timestamp(value: &LuaValue) -> i64 {
    match value {
        LuaValue::Integer(value) => *value,
        LuaValue::Number(value) if value.is_finite() => value.floor() as i64,
        _ => 0,
    }
}

fn cmp_usage(value: LuaValue) -> LuaResult<cmp::Usage> {
    if let LuaValue::Table(value) = value {
        let last_used = value.get::<LuaValue>("last_used")?;
        let last_used = cmp_timestamp(&last_used);
        let score = value.get::<LuaValue>("score")?;
        if let Some(score) = cmp_score(&score) {
            return Ok(cmp::Usage::from_score(score, last_used));
        }
        let count = value.get::<LuaValue>("count")?;
        return Ok(cmp::Usage::from_count(cmp_count(&count), last_used));
    }
    Ok(cmp::Usage::from_count(cmp_count(&value), 0))
}

fn cmp_item_usage(value: &LuaTable) -> LuaResult<cmp::Usage> {
    let last_used = cmp_timestamp(&value.get::<LuaValue>("last_used")?);
    let score = value.get::<LuaValue>("usage_score")?;
    if let Some(score) = cmp_score(&score) {
        return Ok(cmp::Usage::from_score(score, last_used));
    }
    let use_count = value.get::<LuaValue>("use_count")?;
    Ok(cmp::Usage::from_count(cmp_count(&use_count), last_used))
}

fn cmp_usage_map(usage: LuaTable) -> LuaResult<HashMap<String, cmp::Usage>> {
    let mut usage_by_key = HashMap::new();
    for pair in usage.pairs::<LuaString, LuaValue>() {
        let (key, value) = pair?;
        usage_by_key.insert(key.to_str()?.to_owned(), cmp_usage(value)?);
    }
    Ok(usage_by_key)
}

struct CmpUsage {
    values: HashMap<String, cmp::Usage>,
}

fn cmp_usage_table(lua: &Lua, usage: cmp::Usage) -> LuaResult<LuaTable> {
    let value = lua.create_table()?;
    value.set("score", usage.score())?;
    value.set("last_used", usage.last_used)?;
    Ok(value)
}

impl LuaUserData for CmpUsage {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method_mut(
            "set",
            |_, usage, (key, value): (String, LuaValue)| -> LuaResult<()> {
                usage.values.insert(key, cmp_usage(value)?);
                Ok(())
            },
        );
        methods.add_method_mut(
            "record",
            |_, usage, (key, now): (String, Option<i64>)| -> LuaResult<()> {
                let now = cmp_now(now);
                let updated = usage
                    .values
                    .get(&key)
                    .copied()
                    .unwrap_or_default()
                    .record(now);
                usage.values.insert(key, updated);
                Ok(())
            },
        );
        methods.add_method_mut(
            "snapshot",
            |lua, usage, now: Option<i64>| -> LuaResult<LuaTable> {
                let now = cmp_now(now);
                usage.values.retain(|_, value| {
                    let decayed = value.decayed(now);
                    if decayed.bonus(now) == 0 {
                        return false;
                    }
                    *value = decayed;
                    true
                });
                let output = lua.create_table_with_capacity(0, usage.values.len())?;
                for (key, value) in &usage.values {
                    output.set(key.as_str(), cmp_usage_table(lua, *value)?)?;
                }
                Ok(output)
            },
        );
    }
}

fn cmp_with_usage<T>(
    usage: LuaValue,
    callback: impl FnOnce(&HashMap<String, cmp::Usage>) -> LuaResult<T>,
) -> LuaResult<T> {
    match usage {
        LuaValue::Nil => callback(&HashMap::new()),
        LuaValue::Table(usage) => callback(&cmp_usage_map(usage)?),
        LuaValue::UserData(usage) => callback(&usage.borrow::<CmpUsage>()?.values),
        value => Err(LuaError::FromLuaConversionError {
            from: value.type_name(),
            to: "completion usage".to_owned(),
            message: Some("expected a table, usage index, or nil".to_owned()),
        }),
    }
}

fn cmp_now(now: Option<i64>) -> i64 {
    now.unwrap_or_else(|| {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |duration| duration.as_secs() as i64)
    })
}

fn cmp_results_table(lua: &Lua, results: Vec<cmp::MatchResult>) -> LuaResult<LuaTable> {
    let output = lua.create_table_with_capacity(results.len(), 0)?;
    for (output_index, result) in results.into_iter().enumerate() {
        let item = lua.create_table()?;
        item.set("index", result.index + 1)?;
        item.set("score", result.score)?;
        item.set("exact", result.exact)?;
        output.set(output_index + 1, item)?;
    }
    Ok(output)
}

fn cmp_indices_table(lua: &Lua, results: Vec<cmp::MatchResult>) -> LuaResult<LuaTable> {
    let output = lua.create_table_with_capacity(results.len(), 0)?;
    for (output_index, result) in results.into_iter().enumerate() {
        output.set(output_index + 1, result.index + 1)?;
    }
    Ok(output)
}

fn cmp_rank_with_sort_text(
    mut results: Vec<cmp::MatchResult>,
    sort_texts: &[LuaString],
    limit: Option<usize>,
) -> Vec<cmp::MatchResult> {
    let compare = |left: &cmp::MatchResult, right: &cmp::MatchResult| {
        right
            .score
            .cmp(&left.score)
            .then_with(|| right.exact.cmp(&left.exact))
            .then_with(|| {
                let left = sort_texts.get(left.index).map(LuaString::as_bytes);
                let right = sort_texts.get(right.index).map(LuaString::as_bytes);
                match (left, right) {
                    (Some(left), Some(right)) => left.cmp(&right),
                    (Some(_), None) => Ordering::Greater,
                    (None, Some(_)) => Ordering::Less,
                    (None, None) => Ordering::Equal,
                }
            })
            .then_with(|| left.index.cmp(&right.index))
    };
    if let Some(limit) = limit {
        if limit == 0 {
            return Vec::new();
        }
        if results.len() > limit {
            results.select_nth_unstable_by(limit, compare);
            results.truncate(limit);
        }
    }
    results.sort_by(compare);
    results
}

struct CmpMatcherItem {
    text: String,
    proximity_key: String,
    usage_key: Option<String>,
    score_offset: i32,
    usage: cmp::Usage,
}

struct CmpMatcher {
    items: Vec<CmpMatcherItem>,
}

enum CmpIndexSort {
    None,
    Text,
    Values(Vec<String>),
}

struct CmpIndex {
    items: Vec<CmpMatcherItem>,
    sort: CmpIndexSort,
}

#[inline]
fn cmp_match_cached_items(
    query: &cmp::fuzzy::Query,
    items: &[CmpMatcherItem],
    usage_by_key: &HashMap<String, cmp::Usage>,
    nearby_words: &HashSet<String>,
    now: i64,
    limit: Option<usize>,
) -> Vec<cmp::MatchResult> {
    let mut results = Vec::new();
    let typo = (limit != Some(0)).then(|| query.typo()).flatten();
    if let Some(typo) = &typo {
        let mut matcher = typo.matcher();
        for (index, item) in items.iter().enumerate() {
            let usage = item
                .usage_key
                .as_ref()
                .and_then(|key| usage_by_key.get(key))
                .copied()
                .unwrap_or(item.usage);
            let proximity_bonus = i32::from(nearby_words.contains(&item.proximity_key)) * 2;
            let (strict, repaired) = matcher.score_both(&item.text);
            if let Some(matched) = strict {
                results.push(cmp::MatchResult {
                    index,
                    score: matched.score + item.score_offset + usage.bonus(now) + proximity_bonus,
                    exact: matched.exact,
                });
            } else if let Some(matched) = repaired {
                results.push(cmp::MatchResult {
                    index,
                    score: matched.score + item.score_offset + usage.bonus(now) + proximity_bonus,
                    exact: false,
                });
            }
        }
    } else {
        for (index, item) in items.iter().enumerate() {
            let usage = item
                .usage_key
                .as_ref()
                .and_then(|key| usage_by_key.get(key))
                .copied()
                .unwrap_or(item.usage);
            if let Some(mut result) =
                cmp::match_query(query, &item.text, item.score_offset, usage, now, index)
            {
                if nearby_words.contains(&item.proximity_key) {
                    result.score += 2;
                }
                results.push(result);
            }
        }
    }
    results
}

type CmpRankArgs = (
    String,
    LuaTable,
    LuaValue,
    Option<LuaTable>,
    LuaValue,
    LuaValue,
    Option<i64>,
    Option<usize>,
);

#[inline]
fn cmp_rank_usage(
    usage_by_key: &HashMap<String, cmp::Usage>,
    usage_keys: Option<&LuaTable>,
    lua_index: usize,
) -> LuaResult<cmp::Usage> {
    if usage_by_key.is_empty() {
        return Ok(cmp::Usage::default());
    }
    Ok(usage_keys
        .map(|keys| keys.raw_get::<Option<LuaString>>(lua_index))
        .transpose()?
        .flatten()
        .as_ref()
        .and_then(|key| key.to_str().ok())
        .and_then(|key| usage_by_key.get(key.as_ref()))
        .copied()
        .unwrap_or_default())
}

#[inline]
fn cmp_rank_score_offset(
    constant: Option<i32>,
    values: Option<&LuaTable>,
    lua_index: usize,
) -> i32 {
    constant.unwrap_or_else(|| {
        values
            .expect("score offset table")
            .raw_get(lua_index)
            .unwrap_or(0)
    })
}

impl LuaUserData for CmpMatcher {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method(
            "match",
            |lua,
             matcher,
             (query, usage, now, limit): (
                String,
                LuaValue,
                Option<i64>,
                Option<usize>,
            )| {
                let now = cmp_now(now);
                cmp_with_usage(usage, |usage_by_key| {
                    let query = cmp::fuzzy::Query::new(&query);
                    let results = cmp_match_cached_items(
                        &query,
                        &matcher.items,
                        usage_by_key,
                        &HashSet::new(),
                        now,
                        limit,
                    );
                    cmp_results_table(lua, cmp::rank_matches(results, limit))
                })
            },
        );
    }
}

impl LuaUserData for CmpIndex {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method(
            "rank",
            |lua,
             index,
             (query, usage, now, limit, nearby_words): (
                String,
                LuaValue,
                Option<i64>,
                Option<usize>,
                Option<LuaTable>,
            )| {
                let now = cmp_now(now);
                cmp_with_usage(usage, |usage_by_key| {
                    let query = cmp::fuzzy::Query::new(&query);
                    let nearby_words = nearby_words
                        .as_ref()
                        .map(|values| {
                            values
                                .sequence_values::<LuaString>()
                                .map(|value| value.and_then(|value| Ok(value.to_str()?.to_owned())))
                                .collect::<LuaResult<HashSet<_>>>()
                        })
                        .transpose()?
                        .unwrap_or_default();
                    let results = cmp_match_cached_items(
                        &query,
                        &index.items,
                        usage_by_key,
                        &nearby_words,
                        now,
                        limit,
                    );

                    let results = match &index.sort {
                        CmpIndexSort::None => cmp::rank_matches(results, limit),
                        CmpIndexSort::Text => {
                            cmp_rank_with_owned_sort_text(results, &index.items, None, limit)
                        }
                        CmpIndexSort::Values(values) => cmp_rank_with_owned_sort_text(
                            results,
                            &index.items,
                            Some(values),
                            limit,
                        ),
                    };
                    cmp_indices_table(lua, results)
                })
            },
        );
    }
}

fn cmp_rank_with_owned_sort_text(
    mut results: Vec<cmp::MatchResult>,
    items: &[CmpMatcherItem],
    sort_texts: Option<&[String]>,
    limit: Option<usize>,
) -> Vec<cmp::MatchResult> {
    let compare = |left: &cmp::MatchResult, right: &cmp::MatchResult| {
        let left_sort = sort_texts
            .and_then(|values| values.get(left.index).map(String::as_bytes))
            .or_else(|| items.get(left.index).map(|item| item.text.as_bytes()));
        let right_sort = sort_texts
            .and_then(|values| values.get(right.index).map(String::as_bytes))
            .or_else(|| items.get(right.index).map(|item| item.text.as_bytes()));
        right
            .score
            .cmp(&left.score)
            .then_with(|| right.exact.cmp(&left.exact))
            .then_with(|| match (left_sort, right_sort) {
                (Some(left), Some(right)) => left.cmp(right),
                (Some(_), None) => Ordering::Greater,
                (None, Some(_)) => Ordering::Less,
                (None, None) => Ordering::Equal,
            })
            .then_with(|| left.index.cmp(&right.index))
    };
    if let Some(limit) = limit {
        if limit == 0 {
            return Vec::new();
        }
        if results.len() > limit {
            results.select_nth_unstable_by(limit, compare);
            results.truncate(limit);
        }
    }
    results.sort_by(compare);
    results
}

fn cmp_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from(
        [
            (
                "keyword_range",
                f(
                    lua,
                    |_, (line, cursor_col, include_suffix): (String, usize, Option<bool>)| {
                        Ok(cmp::keyword::range(
                            &line,
                            cursor_col,
                            include_suffix.unwrap_or(false),
                        ))
                    },
                )?,
            ),
            (
                "matched_ranges",
                f(lua, |_, (query, labels): (String, Vec<String>)| {
                    Ok(cmp::fuzzy::matched_ranges(&query, &labels))
                })?,
            ),
            (
                "matcher",
                f(lua, |lua, values: LuaTable| {
                    let mut items = Vec::with_capacity(values.raw_len());
                    for value in values.sequence_values::<LuaTable>() {
                        let value = value?;
                        let text: String = value.get("text")?;
                        items.push(CmpMatcherItem {
                            proximity_key: value
                                .get::<Option<String>>("proximity_key")?
                                .unwrap_or_else(|| text.clone()),
                            text,
                            usage_key: value.get("usage_key")?,
                            score_offset: value.get("score_offset").unwrap_or(0),
                            usage: cmp_item_usage(&value)?,
                        });
                    }
                    lua.create_userdata(CmpMatcher { items })
                })?,
            ),
            (
                "index",
                f(
                    lua,
                    |lua,
                     (texts, score_offsets, usage_keys, sort_texts, proximity_keys): (
                        LuaTable,
                        LuaValue,
                        Option<LuaTable>,
                        LuaValue,
                        Option<LuaTable>,
                    )| {
                        let constant_score_offset = match &score_offsets {
                            LuaValue::Integer(value) => Some(i32::try_from(*value).map_err(|_| {
                                LuaError::external("completion score offset exceeds i32")
                            })?),
                            LuaValue::Nil => Some(0),
                            LuaValue::Table(_) => None,
                            value => {
                                return Err(LuaError::FromLuaConversionError {
                                    from: value.type_name(),
                                    to: "completion score offsets".to_owned(),
                                    message: Some("expected an integer, table, or nil".to_owned()),
                                });
                            }
                        };
                        let score_offset_values = score_offsets.as_table();
                        let mut items = Vec::with_capacity(texts.raw_len());
                        for (index, text) in texts.sequence_values::<LuaString>().enumerate() {
                            let lua_index = index + 1;
                            let text = text?.to_str()?.to_owned();
                            let proximity_key = proximity_keys
                                .as_ref()
                                .map(|keys| keys.raw_get::<Option<LuaString>>(lua_index))
                                .transpose()?
                                .flatten()
                                .map(|value| value.to_str().map(|value| value.to_owned()))
                                .transpose()?
                                .unwrap_or_else(|| text.clone());
                            items.push(CmpMatcherItem {
                                text,
                                proximity_key,
                                usage_key: usage_keys
                                    .as_ref()
                                    .map(|keys| keys.raw_get(lua_index))
                                    .transpose()?
                                    .flatten(),
                                score_offset: if let Some(value) = constant_score_offset {
                                    value
                                } else {
                                    score_offset_values
                                        .expect("score offset table")
                                        .raw_get(lua_index)
                                        .unwrap_or(0)
                                },
                                usage: cmp::Usage::default(),
                            });
                        }

                        let sort = if sort_texts == LuaValue::Boolean(true) {
                            CmpIndexSort::Text
                        } else if let LuaValue::Table(values) = sort_texts {
                            let values = values
                                .sequence_values::<LuaString>()
                                .map(|value| value.and_then(|value| Ok(value.to_str()?.to_owned())))
                                .collect::<LuaResult<Vec<_>>>()?;
                            if values.len() != items.len() {
                                return Err(LuaError::external(
                                    "completion sort text count does not match item count",
                                ));
                            }
                            CmpIndexSort::Values(values)
                        } else if sort_texts.is_nil() || sort_texts == LuaValue::Boolean(false) {
                            CmpIndexSort::None
                        } else {
                            return Err(LuaError::FromLuaConversionError {
                                from: sort_texts.type_name(),
                                to: "completion sort texts".to_owned(),
                                message: Some("expected a table, true, or nil".to_owned()),
                            });
                        };
                        lua.create_userdata(CmpIndex { items, sort })
                    },
                )?,
            ),
            (
                "usage",
                f(lua, |lua, values: LuaTable| {
                    lua.create_userdata(CmpUsage {
                        values: cmp_usage_map(values)?,
                    })
                })?,
            ),
            (
                "fuzzy_match",
                f(
                    lua,
                    |lua,
                     (query, values, now, limit): (
                        String,
                        LuaTable,
                        Option<i64>,
                        Option<usize>,
                    )| {
                        let now = cmp_now(now);
                        let query = cmp::fuzzy::Query::new(&query);
                        let mut results = Vec::new();
                        let typo = (limit != Some(0)).then(|| query.typo()).flatten();
                        if let Some(typo) = &typo {
                            let mut matcher = typo.matcher();
                            for (index, value) in values.sequence_values::<LuaTable>().enumerate() {
                                let value = value?;
                                let text = value.get::<LuaString>("text")?;
                                let score_offset = value.get("score_offset").unwrap_or(0);
                                let usage = cmp_item_usage(&value)?;
                                let (strict, repaired) = matcher.score_both(text.to_str()?.as_ref());
                                if let Some(matched) = strict {
                                    results.push(cmp::MatchResult {
                                        index,
                                        score: matched.score + score_offset + usage.bonus(now),
                                        exact: matched.exact,
                                    });
                                } else if let Some(matched) = repaired {
                                    results.push(cmp::MatchResult {
                                        index,
                                        score: matched.score + score_offset + usage.bonus(now),
                                        exact: false,
                                    });
                                }
                            }
                        } else {
                            for (index, value) in values.sequence_values::<LuaTable>().enumerate() {
                                let value = value?;
                                let text = value.get::<LuaString>("text")?;
                                if let Some(result) = cmp::match_query(
                                    &query,
                                    text.to_str()?.as_ref(),
                                    value.get("score_offset").unwrap_or(0),
                                    cmp_item_usage(&value)?,
                                    now,
                                    index,
                                ) {
                                    results.push(result);
                                }
                            }
                        }
                        cmp_results_table(lua, cmp::rank_matches(results, limit))
                    },
                )?,
            ),
            (
                "rank",
                f(
                    lua,
                    |lua,
                     (query, texts, score_offsets, usage_keys, sort_texts, usage, now, limit): CmpRankArgs| {
                        let now = cmp_now(now);
                        cmp_with_usage(usage, |usage_by_key| {
                            let query = cmp::fuzzy::Query::new(&query);
                            let mut results = Vec::new();
                            let typo = (limit != Some(0)).then(|| query.typo()).flatten();
                            let mut matcher = typo.as_ref().map(|typo| typo.matcher());
                            let constant_score_offset = match &score_offsets {
                                LuaValue::Integer(value) => Some(
                                    i32::try_from(*value)
                                        .map_err(|_| LuaError::external("completion score offset exceeds i32"))?,
                                ),
                                LuaValue::Nil => Some(0),
                                LuaValue::Table(_) => None,
                                value => {
                                    return Err(LuaError::FromLuaConversionError {
                                        from: value.type_name(),
                                        to: "completion score offsets".to_owned(),
                                        message: Some("expected an integer, table, or nil".to_owned()),
                                    });
                                }
                            };
                            let score_offset_values = score_offsets.as_table();
                            let mut text_sort_values = matches!(sort_texts, LuaValue::Boolean(true))
                                .then(|| Vec::with_capacity(texts.raw_len()));
                            for (index, text) in texts.sequence_values::<LuaString>().enumerate() {
                                let text = text?;
                                let lua_index = index + 1;
                                let usage = cmp_rank_usage(usage_by_key, usage_keys.as_ref(), lua_index)?;
                                let score_offset = cmp_rank_score_offset(
                                    constant_score_offset,
                                    score_offset_values,
                                    lua_index,
                                );
                                if let Some(matcher) = &mut matcher {
                                    let (strict, repaired) =
                                        matcher.score_both(text.to_str()?.as_ref());
                                    if let Some(matched) = strict {
                                        results.push(cmp::MatchResult {
                                            index,
                                            score: matched.score + score_offset + usage.bonus(now),
                                            exact: matched.exact,
                                        });
                                    } else if let Some(matched) = repaired {
                                        results.push(cmp::MatchResult {
                                            index,
                                            score: matched.score + score_offset + usage.bonus(now),
                                            exact: false,
                                        });
                                    }
                                } else if let Some(result) = cmp::match_query(
                                    &query,
                                    text.to_str()?.as_ref(),
                                    score_offset,
                                    usage,
                                    now,
                                    index,
                                ) {
                                    results.push(result);
                                }
                                if let Some(sort_values) = &mut text_sort_values {
                                    sort_values.push(text);
                                }
                            }
                            let results = if let Some(sort_texts) = text_sort_values {
                                cmp_rank_with_sort_text(results, &sort_texts, limit)
                            } else if let LuaValue::Table(sort_texts) = sort_texts {
                                let sort_texts = sort_texts
                                    .sequence_values::<LuaString>()
                                    .collect::<LuaResult<Vec<_>>>()?;
                                cmp_rank_with_sort_text(results, &sort_texts, limit)
                            } else if sort_texts.is_nil() || sort_texts == LuaValue::Boolean(false) {
                                cmp::rank_matches(results, limit)
                            } else {
                                return Err(LuaError::FromLuaConversionError {
                                    from: sort_texts.type_name(),
                                    to: "completion sort texts".to_owned(),
                                    message: Some("expected a table, true, or nil".to_owned()),
                                });
                            };
                            cmp_results_table(lua, results)
                        })
                    },
                )?,
            ),
            (
                "words",
                f(lua, |_, (value, limit): (String, Option<usize>)| {
                    Ok(cmp::word::collect(&value, limit.unwrap_or(1000)))
                })?,
            ),
        ],
    )
}

fn string_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "calc_linewidths",
            f(lua, |_, text: String| Ok(string::calc_linewidths(&text)))?,
        ),
        (
            "count_lines",
            f(lua, |_, text: String| Ok(string::count_lines(&text)))?,
        ),
        (
            "parse_comma_list",
            f(lua, |_, text: String| Ok(string::parse_comma_list(&text)))?,
        ),
        (
            "get_locations",
            f(lua, |_, (text, offsets): (String, Vec<usize>)| {
                Ok(string::get_locations(&text, &offsets))
            })?,
        ),
        (
            "parse_lines",
            f(lua, |lua, (text, widths): (String, Option<Vec<u32>>)| {
                let lines = string::parse_lines(&text, widths.as_deref());
                lines.into_lua(lua)
            })?,
        ),
    ])
}

fn set_path_cwd(cwd: &str) {
    path::set_cwd(cwd);
    canonical_path::set_cwd(cwd);
}

#[inline]
fn canonical_to_os_path(lua: &Lua, filepath: LuaString) -> LuaResult<LuaString> {
    #[cfg(not(windows))]
    {
        let _ = lua;
        Ok(filepath)
    }

    #[cfg(windows)]
    {
        if !filepath.as_bytes().contains(&b'/') {
            return Ok(filepath);
        }

        let filepath = filepath.to_str()?;
        lua.create_string(canonical_path::to_os_path(filepath.as_ref()).as_bytes())
    }
}

#[inline]
fn canonical_from_os_path(
    lua: &Lua,
    (os_path, keep_tailing_slash): (LuaString, bool),
) -> LuaResult<LuaString> {
    {
        let value = os_path.to_str()?;
        let normalized = canonical_path::from_os_path(value.as_ref(), keep_tailing_slash);
        if normalized.as_str() != value.as_ref() {
            return lua.create_string(normalized.as_bytes());
        }
    }

    Ok(os_path)
}

fn canonical_path_module(lua: &Lua) -> LuaResult<LuaTable> {
    let table = lua.create_table_from([
        (
            "basename",
            f(lua, |_, filepath: String| {
                Ok(canonical_path::basename(&filepath))
            })?,
        ),
        (
            "dirname",
            f(lua, |_, (filepath, keep_tailing_slash): (String, bool)| {
                Ok(canonical_path::dirname(&filepath, keep_tailing_slash))
            })?,
        ),
        (
            "extname",
            f(lua, |_, filepath: String| {
                Ok(canonical_path::extname(&filepath))
            })?,
        ),
        ("from_os_path", f(lua, canonical_from_os_path)?),
        (
            "is_absolute",
            f(lua, |_, filepath: String| {
                Ok(canonical_path::is_absolute(&filepath))
            })?,
        ),
        (
            "is_descendant",
            f(lua, |_, (from, to): (String, String)| {
                Ok(canonical_path::is_descendant(&from, &to))
            })?,
        ),
        (
            "is_dirpath",
            f(lua, |_, filepath: String| {
                Ok(canonical_path::is_dirpath(&filepath))
            })?,
        ),
        (
            "join",
            f(
                lua,
                |_, (from, to, keep_trailing_slash): (String, String, bool)| {
                    Ok(canonical_path::join(&from, &to, keep_trailing_slash))
                },
            )?,
        ),
        (
            "relative",
            f(
                lua,
                |_, (from, to, keep_trailing_slash): (String, String, bool)| {
                    Ok(canonical_path::relative(&from, &to, keep_trailing_slash))
                },
            )?,
        ),
        (
            "resolve",
            f(
                lua,
                |_, (from, to, keep_trailing_slash): (String, String, bool)| {
                    Ok(canonical_path::resolve(&from, &to, keep_trailing_slash))
                },
            )?,
        ),
        (
            "get_cwd",
            f(lua, |_, ()| {
                let cwd = canonical_path::get_cwd();
                Ok(cwd.as_ref().to_owned())
            })?,
        ),
        (
            "get_cwd_without_trailing",
            f(lua, |lua, ()| {
                let cwd = canonical_path::get_cwd_without_trailing();
                lua.create_string(cwd.as_bytes())
            })?,
        ),
        (
            "set_cwd",
            f(lua, |_, cwd: String| {
                set_path_cwd(&cwd);
                Ok(())
            })?,
        ),
        (
            "normalize",
            f(lua, |_, (filepath, keep_trailing_slash): (String, bool)| {
                Ok(canonical_path::normalize(&filepath, keep_trailing_slash))
            })?,
        ),
        (
            "split",
            f(
                lua,
                |lua, (filepath, keep_trailing_slash): (String, bool)| {
                    let segments = canonical_path::split(&filepath, keep_trailing_slash);
                    segments.into_lua(lua)
                },
            )?,
        ),
        ("to_os_path", f(lua, canonical_to_os_path)?),
    ])?;
    table.set("SEP", canonical_path::SEP.to_string())?;
    Ok(table)
}

fn path_module(lua: &Lua) -> LuaResult<LuaTable> {
    let table = lua.create_table_from([
        (
            "basename",
            f(lua, |_, filepath: String| Ok(path::basename(&filepath)))?,
        ),
        (
            "dirname",
            f(
                lua,
                |_, (filepath, keep_tailing_slash, sep): (String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::dirname(&filepath, keep_tailing_slash, sep))
                },
            )?,
        ),
        (
            "extname",
            f(lua, |_, filepath: String| Ok(path::extname(&filepath)))?,
        ),
        (
            "is_absolute",
            f(lua, |_, filepath: String| Ok(path::is_absolute(&filepath)))?,
        ),
        (
            "is_descendant",
            f(lua, |_, (from, to): (String, String)| {
                Ok(path::is_descendant(&from, &to))
            })?,
        ),
        (
            "is_dirpath",
            f(lua, |_, filepath: String| Ok(path::is_dirpath(&filepath)))?,
        ),
        (
            "join",
            f(
                lua,
                |_, (from, to, keep_trailing_slash, sep): (String, String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::join(&from, &to, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "relative",
            f(
                lua,
                |_, (from, to, keep_trailing_slash, sep): (String, String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::relative(&from, &to, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "resolve",
            f(
                lua,
                |_, (from, to, keep_trailing_slash, sep): (String, String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::resolve(&from, &to, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "get_cwd",
            f(lua, |_, ()| {
                let cwd = path::get_cwd();
                Ok(cwd.as_ref().to_owned())
            })?,
        ),
        (
            "set_cwd",
            f(lua, |_, cwd: String| {
                set_path_cwd(&cwd);
                Ok(())
            })?,
        ),
        (
            "normalize",
            f(
                lua,
                |_, (filepath, keep_trailing_slash, sep): (String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::normalize(&filepath, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "split",
            f(
                lua,
                |lua, (filepath, keep_trailing_slash): (String, bool)| {
                    let segments = path::split(&filepath, keep_trailing_slash);
                    segments.into_lua(lua)
                },
            )?,
        ),
        (
            "is_exist",
            f(lua, |_, input: String| Ok(path::is_exist(&input)))?,
        ),
        (
            "is_exist_directory",
            f(lua, |_, input: String| Ok(path::is_exist_directory(&input)))?,
        ),
        (
            "is_exist_file",
            f(lua, |_, input: String| Ok(path::is_exist_file(&input)))?,
        ),
        (
            "mkdirs",
            f(lua, |_, dirpath: String| {
                path::mkdirs(&dirpath).map_err(LuaError::RuntimeError)?;
                Ok(())
            })?,
        ),
        (
            "locate_nearest",
            f(
                lua,
                |_, (start_dirpath, filenames): (String, Vec<String>)| {
                    Ok(path::locate_nearest(&start_dirpath, &filenames))
                },
            )?,
        ),
    ])?;
    table.set("SEP", path::SEP.to_string())?;
    Ok(table)
}

fn fs_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "is_same_file",
            f(
                lua,
                |lua, (left, right): (String, String)| -> LuaResult<LuaMultiValue> {
                    match fs::is_same_file(&left, &right) {
                        Ok(result) => Ok(LuaMultiValue::from_vec(vec![
                            result.into_lua(lua)?,
                            LuaValue::Nil,
                        ])),
                        Err(error) => Ok(LuaMultiValue::from_vec(vec![
                            LuaValue::Nil,
                            LuaValue::String(lua.create_string(error)?),
                        ])),
                    }
                },
            )?,
        ),
        (
            "is_descendant",
            f(
                lua,
                |lua, (source, target): (String, String)| -> LuaResult<LuaMultiValue> {
                    match fs::is_descendant(&source, &target) {
                        Ok(result) => Ok(LuaMultiValue::from_vec(vec![
                            result.into_lua(lua)?,
                            LuaValue::Nil,
                        ])),
                        Err(error) => Ok(LuaMultiValue::from_vec(vec![
                            LuaValue::Nil,
                            LuaValue::String(lua.create_string(error)?),
                        ])),
                    }
                },
            )?,
        ),
        (
            "collect_files",
            f(
                lua,
                |lua, (dirpath, recursive): (String, bool)| -> LuaResult<LuaMultiValue> {
                    match fs::collect_files(&dirpath, recursive) {
                        Ok(result) => {
                            let data = result.into_lua(lua)?;
                            Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                        }
                        Err(error) => {
                            let err = error.into_lua(lua)?;
                            Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                        }
                    }
                },
            )?,
        ),
        (
            "get_filesize",
            f(lua, |lua, filepath: String| -> LuaResult<LuaMultiValue> {
                match fs::get_filesize(&filepath) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "readdir",
            f(lua, |lua, dirpath: String| -> LuaResult<LuaMultiValue> {
                match fs::readdir(&dirpath) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "move",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::IFsMoveParams::from_lua(params, lua)?;
                match fs::r#move(&params) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
    ])
}

fn replace_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "replace_file",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::replace::IReplaceFileParams::from_lua(params, lua)?;
                match crate::replace::replace_file(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_by_matches",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFileByMatchesParams::from_lua(params, lua)?;
                match crate::replace::replace_file_by_matches(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_by_matches_advance",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::replace::IReplaceFileByMatchesAdvanceParams::from_lua(
                    params, lua,
                )?;
                match crate::replace::replace_file_by_matches_advance(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                    &params.remain_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_preview",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFilePreviewParams::from_lua(params, lua)?;
                match crate::replace::replace_file_preview(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_preview_advance",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFilePreviewParams::from_lua(params, lua)?;
                match crate::replace::replace_file_preview_advance(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_preview_by_matches_advance",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFilePreviewByMatchesAdvanceParams::from_lua(
                        params, lua,
                    )?;
                match crate::replace::replace_file_preview_by_matches_advance(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceTextPreviewParams::from_lua(params, lua)?;
                match crate::replace::replace_text_preview(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview_by_matches",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::replace::IReplaceTextPreviewByMatchesParams::from_lua(
                    params, lua,
                )?;
                match crate::replace::replace_text_preview_by_matches(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview_advance",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceTextPreviewAdvanceParams::from_lua(params, lua)?;
                match crate::replace::replace_text_preview_advance(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview_by_matches_advance",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceTextPreviewByMatchesAdvanceParams::from_lua(
                        params, lua,
                    )?;
                match crate::replace::replace_text_preview_by_matches_advance(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
    ])
}

fn find_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([(
        "find_files",
        f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
            let options = find::IFindFilesOptions::from_lua(options, lua)?;
            match find::find_files(&options) {
                Ok(result) => {
                    let data = result.into_lua(lua)?;
                    Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                }
                Err(error) => {
                    let err = error.into_lua(lua)?;
                    Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                }
            }
        })?,
    )])
}

fn search_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "start_search_in_files",
            f(lua, |lua, options: LuaValue| {
                let options = search::ISearchInFilesOptions::from_lua(options, lua)?;
                let job = search::start_search_in_files(options).map_err(LuaError::external)?;
                lua.create_userdata(job)
            })?,
        ),
        (
            "search_in_files",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInFilesOptions::from_lua(options, lua)?;
                match search::search_in_files(&options) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_lines",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesOptions::from_lua(options, lua)?;
                match search::search_in_lines(
                    &options.pattern,
                    &options.lines,
                    options.flag_fuzzy,
                    options.flag_regex,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_text",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInTextOptions::from_lua(options, lua)?;
                match search::search_in_text(
                    &options.pattern,
                    &options.text,
                    options.flag_fuzzy,
                    options.flag_regex,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_lines_literal",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesLiteralOptions::from_lua(options, lua)?;
                match search::search_in_lines(
                    &options.pattern,
                    &options.lines,
                    options.flag_fuzzy,
                    false,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = LuaValue::String(lua.create_string(&error)?);
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_lines_regex",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesRegexOptions::from_lua(options, lua)?;
                match search::search_in_lines(
                    &options.pattern,
                    &options.lines,
                    false,
                    true,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = LuaValue::String(lua.create_string(&error)?);
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
    ])
}

fn uri_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "basename",
            f(lua, |_, uri: String| Ok(uri::basename(&uri)))?,
        ),
        (
            "build",
            f(
                lua,
                |_, (protocol, path, hash): (String, String, Option<String>)| {
                    Ok(uri::build(&protocol, &path, hash.as_deref()))
                },
            )?,
        ),
        (
            "decode",
            f(lua, |_, src: String| Ok(uri::decode(&src)))?,
        ),
        (
            "encode",
            f(lua, |_, src: String| Ok(uri::encode(&src)))?,
        ),
        (
            "extname",
            f(lua, |_, uri: String| Ok(uri::extname(&uri)))?,
        ),
        (
            "from_filepath",
            f(lua, |_, filepath: String| {
                Ok(uri::from_filepath(&filepath))
            })?,
        ),
        ("hash", f(lua, |_, uri: String| Ok(uri::hash(&uri)))?),
        (
            "is_data_uri",
            f(lua, |_, src: String| Ok(uri::is_data_uri(&src)))?,
        ),
        (
            "join",
            f(lua, |_, (from_uri, to_path): (String, String)| {
                Ok(uri::join(&from_uri, &to_path))
            })?,
        ),
        (
            "normalize",
            f(lua, |_, uri: String| Ok(uri::normalize(&uri)))?,
        ),
        (
            "parent",
            f(lua, |_, uri: String| Ok(uri::parent(&uri)))?,
        ),
        (
            "parse",
            f(lua, |lua, uri: String| {
                match uri::parse(&uri) {
                    Some(parts) => {
                        let table = lua.create_table()?;
                        table.set("protocol", parts.protocol)?;
                        table.set("path", parts.path)?;
                        if let Some(hash) = parts.hash {
                            table.set("hash", hash)?;
                        }
                        Ok(LuaValue::Table(table))
                    }
                    None => Ok(LuaValue::Nil),
                }
            })?,
        ),
        (
            "pathname",
            f(lua, |_, uri: String| Ok(uri::pathname(&uri)))?,
        ),
        (
            "protocol",
            f(lua, |_, uri: String| Ok(uri::protocol(&uri)))?,
        ),
        (
            "relative",
            f(lua, |_, (from_uri, to_uri): (String, String)| {
                Ok(uri::relative(&from_uri, &to_uri))
            })?,
        ),
        (
            "split",
            f(lua, |lua, path: String| {
                let segments = uri::split(&path);
                segments.into_lua(lua)
            })?,
        ),
        (
            "to_filepath",
            f(
                lua,
                |_, (uri, keep_trailing_slash): (String, Option<bool>)| {
                    Ok(uri::to_filepath(&uri, keep_trailing_slash.unwrap_or(false)))
                },
            )?,
        ),
        (
            "validate",
            f(lua, |_, uri: String| Ok(uri::validate(&uri)))?,
        ),
    ])
}

#[mlua::lua_module]
fn yoz(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    exports.set("canonical_path", canonical_path_module(lua)?)?;
    exports.set("cmp", cmp_module(lua)?)?;
    exports.set("dict", dict_module(lua)?)?;
    exports.set("string", string_module(lua)?)?;
    exports.set("fn", fn_module(lua)?)?;
    exports.set("path", path_module(lua)?)?;
    exports.set("fs", fs_module(lua)?)?;
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    exports.set("im", im_module(lua)?)?;
    #[cfg(target_os = "linux")]
    if im::is_available() {
        exports.set("im", im_module(lua)?)?;
    }
    exports.set("replace", replace_module(lua)?)?;
    exports.set("find", find_module(lua)?)?;
    exports.set("search", search_module(lua)?)?;
    exports.set("uri", uri_module(lua)?)?;
    Ok(exports)
}
