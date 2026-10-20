//! Lua bindings: `yoz.fuzzy.new_corpus` returns a corpus kept on the native side; each query returns a
//! result handle that reads its order, highlights and Treeview filter without rebuilding Lua tables.

use super::{CaseMode, Corpus, Query, Ranked, Scheme};
use crate::ux::treeview::lua::{LuaIds, LuaSource};
use crate::ux::treeview::{NodeId, Source};
use mlua::prelude::*;
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;
use std::sync::Arc;

/** Keys a single `keys` read returns at most. */
const SLICE_LIMIT: usize = 1 << 20;

/// Treeview node ids of every item, resolved against one source.
struct Bound {
    identity: u64,
    revision: u64,
    /** Ids of item `i` are `ids[offsets[i]..offsets[i + 1]]`; keys missing from the source are skipped. */
    ids: Vec<NodeId>,
    offsets: Vec<u32>,
}

struct Shared {
    corpus: Corpus,
    /** Treeview keys per item: the item's node, then nodes shown with it. */
    keys: Vec<Box<[Arc<str>]>>,
    /** Item index by first key, built on the first lookup. */
    lookup: Option<HashMap<Arc<str>, u32>>,
    bound: Option<Bound>,
}

impl Shared {
    fn bind(&mut self, source: &Source) -> &Bound {
        let (identity, revision) = (source.identity, source.revision().value());
        if !self
            .bound
            .as_ref()
            .is_some_and(|bound| bound.identity == identity && bound.revision == revision)
        {
            let mut ids = Vec::with_capacity(self.keys.len());
            let mut offsets = Vec::with_capacity(self.keys.len() + 1);
            offsets.push(0);
            for keys in &self.keys {
                ids.extend(keys.iter().filter_map(|key| source.keys.get(key).copied()));
                offsets.push(ids.len() as u32);
            }
            self.bound = Some(Bound {
                identity,
                revision,
                ids,
                offsets,
            });
        }
        self.bound.as_ref().expect("bound corpus")
    }

    fn index_of(&mut self, key: &str) -> Option<usize> {
        let keys = &self.keys;
        let lookup = self.lookup.get_or_insert_with(|| {
            let mut lookup = HashMap::with_capacity(keys.len());
            for (index, keys) in keys.iter().enumerate() {
                lookup.entry(keys[0].clone()).or_insert(index as u32);
            }
            lookup
        });
        lookup.get(key).map(|&index| index as usize)
    }
}

pub(crate) struct LuaCorpus(Rc<RefCell<Shared>>);

/// Node ids for one source identity and revision.
type CachedIds = (u64, u64, Arc<[NodeId]>);

struct LuaRanked {
    shared: Rc<RefCell<Shared>>,
    ranked: Ranked,
    /** Membership by item index, built on the first lookup. */
    members: RefCell<Option<Vec<bool>>>,
    ids: RefCell<Option<CachedIds>>,
}

fn text(value: LuaValue) -> LuaResult<String> {
    match value {
        LuaValue::String(value) => Ok(String::from_utf8_lossy(&value.as_bytes()).into_owned()),
        _ => Err(LuaError::runtime("fuzzy corpus items must be strings")),
    }
}

fn keys(value: LuaValue) -> LuaResult<Box<[Arc<str>]>> {
    let keys: Box<[Arc<str>]> = match value {
        LuaValue::String(_) => Box::new([Arc::from(text(value)?)]),
        LuaValue::Table(table) => table
            .sequence_values::<LuaValue>()
            .map(|key| Ok(Arc::from(text(key?)?)))
            .collect::<LuaResult<_>>()?,
        _ => Box::new([]),
    };
    if keys.is_empty() {
        return Err(LuaError::runtime(
            "fuzzy corpus keys must be strings or nonempty arrays of strings",
        ));
    }
    Ok(keys)
}

fn scheme(options: &Option<LuaTable>) -> LuaResult<Scheme> {
    let name = match options {
        Some(options) => options.get::<Option<String>>("scheme")?,
        None => None,
    };
    match name.as_deref() {
        None | Some("default") => Ok(Scheme::Default),
        Some("path") => Ok(Scheme::Path),
        Some(name) => Err(LuaError::runtime(format!("unknown fuzzy scheme: {name}"))),
    }
}

fn case(name: Option<String>) -> LuaResult<CaseMode> {
    match name.as_deref() {
        None | Some("smart") => Ok(CaseMode::Smart),
        Some("respect") => Ok(CaseMode::Respect),
        Some("ignore") => Ok(CaseMode::Ignore),
        Some(name) => Err(LuaError::runtime(format!(
            "unknown fuzzy case mode: {name}"
        ))),
    }
}

impl LuaUserData for LuaCorpus {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method(
            "append",
            |_, this, (texts, keys_of): (LuaTable, LuaTable)| {
                let texts: Vec<String> = texts
                    .sequence_values::<LuaValue>()
                    .map(|value| text(value?))
                    .collect::<LuaResult<_>>()?;
                let keys_of: Vec<_> = keys_of
                    .sequence_values::<LuaValue>()
                    .map(|value| keys(value?))
                    .collect::<LuaResult<_>>()?;
                if keys_of.len() != texts.len() {
                    return Err(LuaError::runtime("fuzzy corpus keys must match the items"));
                }
                let mut shared = this.0.borrow_mut();
                shared.corpus.append(&texts).map_err(LuaError::runtime)?;
                shared.keys.extend(keys_of);
                shared.lookup = None;
                shared.bound = None;
                Ok(())
            },
        );
        methods.add_method("set_weights", |_, this, weights: LuaString| {
            this.0
                .borrow_mut()
                .corpus
                .set_weights(&weights.as_bytes())
                .map_err(LuaError::runtime)
        });
        methods.add_method("query", |_, this, options: LuaTable| {
            let pattern: String = options
                .get::<Option<String>>("pattern")?
                .unwrap_or_default();
            let query = Query {
                pattern: &pattern,
                fuzzy: options.get::<Option<bool>>("fuzzy")?.unwrap_or(true),
                case: case(options.get("case")?)?,
                rank: options.get::<Option<bool>>("rank")?.unwrap_or(true),
                weight: options
                    .get::<Option<i32>>("weight")?
                    .unwrap_or(0)
                    .clamp(0, 10_000),
                threads: 0,
            };
            let ranked = this.0.borrow_mut().corpus.query(&query);
            Ok(LuaRanked {
                shared: this.0.clone(),
                ranked,
                members: RefCell::new(None),
                ids: RefCell::new(None),
            })
        });
    }
}

impl LuaRanked {
    /// Item index of the matched item whose first key is `key`.
    fn matched(&self, key: &str) -> Option<usize> {
        let mut shared = self.shared.borrow_mut();
        let index = shared.index_of(key)?;
        let mut members = self.members.borrow_mut();
        let members = members.get_or_insert_with(|| {
            let mut members = vec![false; shared.corpus.len()];
            for &index in &self.ranked.indices {
                members[index as usize] = true;
            }
            members
        });
        members[index].then_some(index)
    }
}

impl LuaUserData for LuaRanked {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("count", |_, this, ()| Ok(this.ranked.indices.len()));
        // First keys of the matches in rank order, a 1-based inclusive range defaulting to every match.
        methods.add_method(
            "keys",
            |lua, this, (first, last): (Option<i64>, Option<i64>)| {
                let count = this.ranked.indices.len();
                let first = first.unwrap_or(1).max(1) as usize;
                let last = last.map_or(count, |last| (last.max(0) as usize).min(count));
                if last >= first && last - first + 1 > SLICE_LIMIT {
                    return Err(LuaError::runtime("fuzzy result slice is too large"));
                }
                let slice = if last >= first {
                    &this.ranked.indices[first - 1..last]
                } else {
                    &[][..]
                };
                let shared = this.shared.borrow();
                lua.create_sequence_from(
                    slice
                        .iter()
                        .map(|&index| shared.keys[index as usize][0].as_ref()),
                )
            },
        );
        methods.add_method("same", |_, this, other: LuaUserDataRef<LuaRanked>| {
            Ok(Rc::ptr_eq(&this.shared, &other.shared)
                && this.ranked.indices == other.ranked.indices)
        });
        methods.add_method("has", |_, this, key: LuaString| {
            Ok(this.matched(&key.to_str()?).is_some())
        });
        // Matched byte ranges of the item whose first key is `key`, or nil when it did not match.
        methods.add_method("highlight", |lua, this, key: LuaString| {
            let Some(index) = this.matched(&key.to_str()?) else {
                return Ok(None);
            };
            let ranges = this.shared.borrow().corpus.positions(index, &this.ranked);
            let points = lua.create_table_with_capacity(ranges.len(), 0)?;
            for (l, r) in ranges {
                let point = lua.create_table_with_capacity(0, 2)?;
                point.raw_set("l", l)?;
                point.raw_set("r", r)?;
                points.raw_push(point)?;
            }
            Ok(Some(points))
        });
        // Node ids of the matches in rank order, each item followed by the nodes shown with it.
        methods.add_method("ids", |_, this, source: LuaUserDataRef<LuaSource>| {
            let (identity, revision) = (source.0.identity, source.0.revision().value());
            if let Some((cached_identity, cached_revision, ids)) = &*this.ids.borrow()
                && *cached_identity == identity
                && *cached_revision == revision
            {
                return Ok(LuaIds(ids.clone()));
            }
            let mut shared = this.shared.borrow_mut();
            let bound = shared.bind(&source.0);
            let mut ids = Vec::with_capacity(this.ranked.indices.len());
            for &index in &this.ranked.indices {
                let index = index as usize;
                ids.extend_from_slice(
                    &bound.ids[bound.offsets[index] as usize..bound.offsets[index + 1] as usize],
                );
            }
            let ids: Arc<[NodeId]> = ids.into();
            *this.ids.borrow_mut() = Some((identity, revision, ids.clone()));
            Ok(LuaIds(ids))
        });
    }
}

pub(crate) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([(
        "new_corpus",
        lua.create_function(|_, options: Option<LuaTable>| {
            Ok(LuaCorpus(Rc::new(RefCell::new(Shared {
                corpus: Corpus::new(scheme(&options)?),
                keys: Vec::new(),
                lookup: None,
                bound: None,
            }))))
        })?,
    )])
}
