use super::data::{Node, Source};
use super::memory::{Charge, Payload};
use super::model::{Error, ListText, Mode, NodeId, Result, Root, Sort};
use super::projection::{Row, Snapshot};
use super::state::State;
use super::storage::{IndexedSequence, Map};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::sync::Arc;

/** Rows reuse their label; only nodes with descendants retain an own shared path. */
#[derive(Clone, Debug)]
pub(crate) struct Text {
    prefix: Option<Arc<TextPath>>,
    path: Option<Arc<TextPath>>,
}

impl Text {
    pub fn bytes(&self, label: &str) -> usize {
        self.prefix.as_ref().map_or(label.len(), |prefix| {
            prefix.bytes.saturating_add(1).saturating_add(label.len())
        })
    }

    pub fn single_label(&self) -> bool {
        self.prefix.is_none()
    }

    pub fn append<'a>(&'a self, label: &str, output: &mut String, scratch: &mut Vec<&'a str>) {
        if let Some(prefix) = &self.prefix {
            prefix.append(output, scratch);
            output.push('/');
        }
        output.push_str(label);
    }

    pub fn same_version(&self, other: &Self) -> bool {
        [&self.prefix, &self.path]
            .into_iter()
            .zip([&other.prefix, &other.path])
            .all(|(a, b)| match (a, b) {
                (None, None) => true,
                (Some(a), Some(b)) => Arc::ptr_eq(a, b),
                _ => false,
            })
    }

    pub fn same_prefix(&self, other: &Self, equality: &mut Equality) -> bool {
        match (&self.prefix, &other.prefix) {
            (None, None) => true,
            (Some(a), Some(b)) => equality.same_text(a, b),
            _ => false,
        }
    }
}

/** A shared label prefix; complete path strings exist only during bounded export. */
pub(crate) struct TextPath {
    id: NodeId,
    label: Arc<str>,
    parent: Option<Arc<TextPath>>,
    bytes: usize,
    _charge: Charge,
    _label: Arc<Payload>,
}

impl std::fmt::Debug for TextPath {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("TextPath")
            .field("id", &self.id)
            .field("bytes", &self.bytes)
            .finish()
    }
}

impl Drop for TextPath {
    fn drop(&mut self) {
        let mut parent = self.parent.take();
        while let Some(value) = parent {
            match Arc::try_unwrap(value) {
                Ok(mut value) => parent = value.parent.take(),
                Err(_) => break,
            }
        }
    }
}

impl TextPath {
    fn new(id: NodeId, label: Arc<str>, parent: Option<Arc<Self>>) -> Result<Arc<Self>> {
        let bytes = parent
            .as_ref()
            .map_or(Some(label.len()), |parent| {
                parent.bytes.checked_add(1)?.checked_add(label.len())
            })
            .ok_or_else(|| Error::limit("ancestry text size overflow"))?;
        Ok(Arc::new(Self {
            id,
            _label: Payload::text(label.clone()),
            label,
            parent,
            bytes,
            _charge: Charge::new(std::mem::size_of::<Self>() + 16),
        }))
    }

    pub fn append<'a>(&'a self, output: &mut String, labels: &mut Vec<&'a str>) {
        labels.clear();
        let mut current = Some(self);
        while let Some(path) = current {
            labels.push(path.label.as_ref());
            current = path.parent.as_deref();
        }
        for (index, label) in labels.iter().rev().enumerate() {
            if index != 0 {
                output.push('/');
            }
            output.push_str(label);
        }
    }
}

/** Compare one fixed pair of frame prefix trees, visiting each pair of prefixes once. */
#[derive(Default)]
pub(crate) struct Equality(HashMap<(NodeId, NodeId), bool>);

impl Equality {
    pub fn same_text(&mut self, left: &Arc<TextPath>, right: &Arc<TextPath>) -> bool {
        let mut left = left;
        let mut right = right;
        let mut pending = Vec::new();
        let equal = loop {
            if Arc::ptr_eq(left, right) {
                break true;
            }
            let key = (left.id, right.id);
            if let Some(equal) = self.0.get(&key) {
                break *equal;
            }
            pending.push(key);
            if left.bytes != right.bytes || left.label != right.label {
                break false;
            }
            match (&left.parent, &right.parent) {
                (Some(a), Some(b)) => {
                    left = a;
                    right = b;
                }
                (None, None) => break true,
                _ => break false,
            }
        };
        for key in pending {
            self.0.insert(key, equal);
        }
        equal
    }
}

pub(crate) struct Builder<'a> {
    source: &'a Source,
    root: &'a Root,
    stops: &'a Map<NodeId, ()>,
    previous: Option<&'a Snapshot>,
    paths: HashMap<NodeId, Arc<TextPath>>,
}

impl<'a> Builder<'a> {
    pub fn new(
        source: &'a Source,
        root: &'a Root,
        stops: &'a Map<NodeId, ()>,
        previous: Option<&'a Snapshot>,
    ) -> Self {
        Self {
            source,
            root,
            stops,
            previous,
            paths: HashMap::new(),
        }
    }

    fn previous(&self, id: NodeId) -> Option<Arc<TextPath>> {
        let previous = self.previous?;
        previous
            .position(id)
            .and_then(|at| previous.row(at))
            .and_then(|row| row.text.as_ref()?.path.clone())
    }

    pub fn text(&mut self, node: &Node) -> Result<Text> {
        let id = node.id;
        if node.child_count() != 0 {
            let path = self.get(id, self.previous(id))?;
            return Ok(Text {
                prefix: path.parent.clone(),
                path: Some(path),
            });
        }
        let parent = node.parent.filter(|parent| {
            self.stops.get(&id).is_none()
                && !matches!(self.root, Root::ChildrenOf(root) if root == parent)
        });
        let prefix = parent
            .map(|parent| {
                if let Some(path) = self.paths.get(&parent) {
                    return Ok(path.clone());
                }
                let old = self
                    .previous
                    .and_then(|frame| frame.position(id).and_then(|at| frame.row(at)))
                    .and_then(|row| row.text.as_ref());
                self.get(
                    parent,
                    old.and_then(|text| text.prefix.clone())
                        .filter(|path| path.id == parent),
                )
            })
            .transpose()?;
        Ok(Text { prefix, path: None })
    }

    fn get(&mut self, id: NodeId, previous: Option<Arc<TextPath>>) -> Result<Arc<TextPath>> {
        if let Some(path) = self.paths.get(&id) {
            return Ok(path.clone());
        }
        let mut pending = Vec::new();
        let mut current = id;
        let mut old = previous.or_else(|| self.previous(current));
        let mut parent = loop {
            if let Some(path) = self.paths.get(&current) {
                break Some(path.clone());
            }
            let node = self
                .source
                .node(current)
                .ok_or_else(|| Error::missing(current))?;
            let next = node.parent.filter(|parent| {
                self.stops.get(&current).is_none()
                    && !matches!(self.root, Root::ChildrenOf(root) if root == parent)
            });
            pending.push((current, node.data.label.clone(), old.clone()));
            let Some(next) = next else {
                break None;
            };
            old = old
                .as_ref()
                .and_then(|path| path.parent.as_ref())
                .filter(|path| path.id == next)
                .cloned()
                .or_else(|| self.previous(next));
            current = next;
        };
        for (id, label, old) in pending.into_iter().rev() {
            let reusable = old.filter(|old| {
                old.label == label
                    && match (&old.parent, &parent) {
                        (None, None) => true,
                        (Some(a), Some(b)) => Arc::ptr_eq(a, b),
                        _ => false,
                    }
            });
            let path = match reusable {
                Some(path) => path,
                None => TextPath::new(id, label, parent)?,
            };
            self.paths.insert(id, path.clone());
            parent = Some(path);
        }
        parent.ok_or_else(|| Error::missing(id))
    }
}

fn in_scope(
    source: &Source,
    root: &Root,
    stops: &Map<NodeId, ()>,
    cache: &mut HashMap<NodeId, bool>,
    node: NodeId,
) -> bool {
    if *root == Root::ChildrenOf(node) {
        return false;
    }
    let mut current = Some(node);
    let mut path = Vec::new();
    let included = loop {
        let Some(id) = current else { break false };
        if *root == Root::ChildrenOf(id) || stops.get(&id).is_some() {
            break true;
        }
        if let Some(included) = cache.get(&id) {
            break *included;
        }
        path.push(id);
        current = source.node(id).and_then(|node| node.parent);
    };
    for id in path {
        cache.insert(id, included);
    }
    included
}

pub(crate) fn apply(
    source: &Source,
    state: &State,
    previous: Option<&Snapshot>,
    rows: &mut IndexedSequence<Row>,
    nodes: Arc<[NodeId]>,
    stops: &Map<NodeId, ()>,
) -> Result<(Arc<[NodeId]>, bool)> {
    let ancestry =
        state.display.mode == Mode::List && state.display.list_text == ListText::Ancestry;
    let was_ancestry = previous.is_some_and(Snapshot::ancestry_text);
    if !ancestry {
        return if was_ancestry {
            Ok((rows.iter().map(|row| row.id).collect(), true))
        } else {
            Ok((nodes, false))
        };
    }
    let mut positions = BTreeSet::new();
    let spans = previous.map_or_else(Vec::new, |old| old.rows.shared_spans(rows));
    let mut next = 0;
    for (_, start, len) in spans.into_iter().chain(std::iter::once((0, rows.len(), 0))) {
        for (offset, row) in rows.iter_from(next).take(start - next).enumerate() {
            if row.text.is_none() {
                positions.insert(next + offset);
            }
        }
        next = start + len;
    }
    if let Some(old) = previous {
        /* Initializing a row says nothing about whether its descendants were covered. */
        let mut covered = HashSet::new();
        let mut visited = HashSet::new();
        let mut scope = HashMap::new();
        let ordered = state.display.sort == Sort::Source && !state.display.branches_first;
        /* New leaves are initialized by projection or the missing-text pass above;
         * they have no descendants whose existing text needs invalidation. */
        let mut dirty: Vec<_> = nodes
            .iter()
            .copied()
            .filter(|id| {
                old.source.contains(*id)
                    || source.node(*id).is_none_or(|node| node.child_count() != 0)
            })
            .collect();
        if ordered {
            /* Rank lookup walks persistent indexes; compute it once per dirty node. */
            dirty.sort_by_cached_key(|id| rows.position(id));
        }
        for id in dirty {
            let before = old.source.node(id);
            let after = source.node(id);
            if before
                .zip(after)
                .is_some_and(|(a, b)| a.data.label == b.data.label && a.parent == b.parent)
            {
                continue;
            }
            let at = rows.position(&id);
            if let Some(at) = at
                && ordered
            {
                if covered.contains(&at) {
                    continue;
                }
                /* Source-order List descendants form a contiguous range whose nearest
                 * visible ancestor has already been visited. Do not rewalk source paths. */
                let mut descendants = HashSet::from([id]);
                for (offset, row) in rows.iter_from(at).enumerate() {
                    if offset != 0
                        && row
                            .source_ancestor
                            .is_none_or(|parent| !descendants.contains(&parent))
                    {
                        break;
                    }
                    descendants.insert(row.id);
                    positions.insert(at + offset);
                    covered.insert(at + offset);
                }
                continue;
            }
            /* A missing row can be filtered out or outside this frame's text scope.
             * Only the former needs descendant traversal. Share ancestor lookups across
             * the batch, including when all changed ancestors are filtered out. */
            if at.is_none()
                && (state.display.pattern.is_empty()
                    || !in_scope(source, &state.root, stops, &mut scope, id))
            {
                continue;
            }
            let mut pending = vec![id];
            while let Some(id) = pending.pop() {
                if !visited.insert(id) {
                    continue;
                }
                if let Some(at) = rows.position(&id) {
                    positions.insert(at);
                    covered.insert(at);
                }
                if let Some(node) = source.node(id) {
                    pending.extend(node.children());
                }
            }
        }
    }
    if positions.is_empty() {
        if previous.is_some() && !was_ancestry {
            return Ok((rows.iter().map(|row| row.id).collect(), true));
        }
        return Ok((nodes, false));
    }
    let mut builder = Builder::new(source, &state.root, stops, previous);
    let mut equality = Equality::default();
    let mut changed = nodes.iter().copied().collect::<HashSet<_>>();
    let mut text_changed = !was_ancestry;
    let mut replacement = Vec::new();
    let mut start = None;
    for at in positions {
        let row = rows.get(at).expect("ancestry row");
        let text = builder.text(source.node(row.id).ok_or_else(|| Error::missing(row.id))?)?;
        if row.text.as_ref().is_some_and(|old| old.same_version(&text)) {
            continue;
        }
        let old = previous
            .and_then(|old| old.position(row.id).and_then(|at| old.row(at)))
            .and_then(|row| row.text.as_ref());
        if old.is_none_or(|old| !old.same_prefix(&text, &mut equality)) {
            changed.insert(row.id);
            text_changed = true;
        }
        let mut row = row.clone();
        row.text = Some(text);
        if let Some(first) = start
            && first + replacement.len() != at
        {
            rows.splice(
                first,
                first + replacement.len(),
                std::mem::take(&mut replacement),
            )?;
            start = None;
        }
        start.get_or_insert(at);
        replacement.push(row);
    }
    if let Some(start) = start {
        rows.splice(start, start + replacement.len(), replacement)?;
    }
    Ok((changed.into_iter().collect(), text_changed))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_deep_shared_text_has_linear_storage_and_iterative_release() {
        let budget = super::super::memory::Budget::new(16 * 1024 * 1024);
        let _guard = budget.enter();
        let label: Arc<str> = "x".into();
        let mut path = None;
        for id in 1..=10_000 {
            path = Some(TextPath::new(NodeId(id), label.clone(), path).unwrap());
        }
        let path = path.unwrap();
        assert_eq!(path.bytes, 19_999);
        assert!(budget.used() < 2 * 1024 * 1024);
        let mut output = String::new();
        path.append(&mut output, &mut Vec::new());
        assert_eq!(output.len(), 19_999);
        assert!(output.starts_with("x/x/x/"));
        drop(path);
        assert_eq!(budget.used(), 0);
    }
}
