use super::data::{Node, Source};
use super::matching::Matcher;
use super::model::*;
use super::stamps::{Stamps, Summary};
use super::state::State;
use super::storage::{IndexedSequence, IndexedValue, Map};
use std::borrow::Cow;
use std::collections::{HashMap, HashSet};
use std::sync::Arc;

pub(crate) type MatchedChildren = Map<NodeId, IndexedSequence<NodeId>>;

#[derive(Clone, Debug)]
pub struct Row {
    pub id: NodeId,
    pub(crate) label: Arc<str>,
    pub(crate) label_payload: Option<Arc<super::memory::Payload>>,
    pub(crate) text: Option<super::text::Text>,
    pub chain: Option<Arc<[NodeId]>>,
    pub depth: usize,
    pub parent: Option<NodeId>,
    pub source_ancestor: Option<NodeId>,
    pub last_child: Option<NodeId>,
    pub last_descendant: NodeId,
    pub connector_last: bool,
}

impl PartialEq for Row {
    fn eq(&self, other: &Self) -> bool {
        self.same_layout(other)
            && self.connector_last == other.connector_last
            && Arc::ptr_eq(&self.label, &other.label)
            && match (&self.text, &other.text) {
                (None, None) => true,
                (Some(a), Some(b)) => a.same_version(b),
                _ => false,
            }
    }
}
impl Eq for Row {}

impl IndexedValue for Row {
    fn ids(&self) -> &[NodeId] {
        self.chain
            .as_deref()
            .unwrap_or_else(|| std::slice::from_ref(&self.id))
    }
}

impl Row {
    pub fn folded_ids(&self) -> &[NodeId] {
        self.ids()
    }

    pub(crate) fn same_layout(&self, other: &Self) -> bool {
        self.id == other.id
            && self.chain == other.chain
            && self.depth == other.depth
            && self.parent == other.parent
            && self.source_ancestor == other.source_ancestor
            && self.last_child == other.last_child
            && self.last_descendant == other.last_descendant
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Direction {
    Parent,
    LastChildOrSibling,
}

/** A half-open row interval ending at a path node's connector, at its display depth. */
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GuideSegment {
    pub first: usize,
    pub last: usize,
    pub depth: usize,
}

#[derive(Clone, Debug)]
pub struct RowInfo {
    pub row: Row,
    pub label: String,
    pub marked: bool,
    pub full: bool,
    pub pending: bool,
    pub expanded: bool,
    pub can_expand: bool,
    pub icon: Option<Arc<str>>,
    pub highlight: Option<Arc<str>>,
    pub right_text: Option<Arc<str>>,
    pub load_state: LoadState,
    pub error: Option<Error>,
    pub matches: Vec<(usize, usize)>,
}

pub struct Snapshot {
    pub id: u64,
    pub commit_revision: Revision,
    pub layout_revision: Revision,
    pub(crate) text_revision: Revision,
    pub summary: Summary,
    pub last_root: Option<NodeId>,
    pub needed_children: Arc<[NodeId]>,
    pub visited_nodes: usize,
    pub queries: Arc<[super::query::QueryInfo]>,
    pub(crate) source: Arc<Source>,
    pub(crate) state: State,
    pub(crate) rows: IndexedSequence<Row>,
    pub(crate) previous: Option<u64>,
    pub(crate) replaced_rows: usize,
    pub(crate) text_nodes: Arc<[NodeId]>,
    pub(crate) matched_children: MatchedChildren,
    pub(crate) text_roots: Map<NodeId, ()>,
    matcher: Option<Matcher>,
}

pub(crate) struct Inherited<'a> {
    source: &'a Source,
    stamps: &'a Stamps,
    values: HashMap<NodeId, u32>,
}

impl<'a> Inherited<'a> {
    pub(crate) fn new(source: &'a Source, stamps: &'a Stamps) -> Self {
        Self {
            source,
            stamps,
            values: HashMap::new(),
        }
    }

    pub(crate) fn get(&mut self, id: NodeId) -> Result<u32> {
        if let Some(value) = self.values.get(&id) {
            return Ok(*value);
        }
        let mut path = Vec::new();
        let mut current = Some(id);
        let mut value = self.stamps.clear;
        while let Some(node) = current {
            if let Some(cached) = self.values.get(&node) {
                value = *cached;
                break;
            }
            let data = self.source.node(node).ok_or_else(|| Error::missing(node))?;
            path.push(node);
            current = data.parent;
        }
        for node in path.into_iter().rev() {
            value = value.max(self.stamps.marks(node).subtree);
            self.values.insert(node, value);
        }
        Ok(value)
    }
}

pub(crate) fn selection_kind(
    source: &Source,
    state: &State,
    id: NodeId,
    inherited: u32,
) -> Result<u8> {
    if inherited.max(state.selection.marks(id).own) & 1 == 0 {
        return Ok(0);
    }
    let summary = state
        .summaries
        .lookup(source, &state.selection, id, inherited)?
        .ok_or_else(|| Error::invalid("frame selection summary was not prepared"))?;
    Ok(if summary.summary.full { 2 } else { 1 })
}

pub(crate) fn compression_child(
    node: &Node,
    display: &DisplayOptions,
    matched: &MatchedChildren,
) -> Option<NodeId> {
    if !node.data.can_expand || !node.data.foldable {
        return None;
    }
    // Ordinary filters compact their retained topology; selected-only preserves source branches.
    if !display.selected_only && (!display.pattern.is_empty() || display.filter.is_some()) {
        let children = matched.get(&node.id)?;
        return (children.len() == 1).then(|| *children.get(0).expect("single matched child"));
    }
    (node.child_count() == 1).then(|| node.child_at(0).expect("single source child"))
}

pub(crate) fn sorted(
    source: &Source,
    mut ids: Vec<NodeId>,
    options: &DisplayOptions,
) -> Vec<NodeId> {
    if options.sort == Sort::Source && !options.branches_first {
        if options.mode == Mode::List
            && let Some(filter) = &options.filter
        {
            ids.sort_by_key(|id| filter.get(id).copied().unwrap_or(usize::MAX));
        }
        return ids;
    }
    let mut keys: Vec<_> = ids
        .iter()
        .map(|id| {
            let node = source.node(*id).expect("validated source child");
            (
                *id,
                options.branches_first && !node.data.can_expand,
                (options.sort == Sort::Name).then(|| node.data.label.to_ascii_lowercase()),
                node.data.score,
            )
        })
        .collect();
    keys.sort_by(|a, b| {
        a.1.cmp(&b.1).then_with(|| match options.sort {
            Sort::Source if options.mode == Mode::List => {
                options
                    .filter
                    .as_ref()
                    .map_or(std::cmp::Ordering::Equal, |filter| {
                        filter
                            .get(&a.0)
                            .copied()
                            .unwrap_or(usize::MAX)
                            .cmp(&filter.get(&b.0).copied().unwrap_or(usize::MAX))
                    })
            }
            Sort::Source => std::cmp::Ordering::Equal,
            Sort::Name => a.2.cmp(&b.2).then_with(|| a.0.cmp(&b.0)),
            Sort::Score => b.3.total_cmp(&a.3).then_with(|| a.0.cmp(&b.0)),
        })
    });
    ids.clear();
    ids.extend(keys.into_iter().map(|key| key.0));
    ids
}

fn hidden(source: &Source, state: &State, id: NodeId) -> bool {
    !state.display.show_hidden
        && !state.display.selected_only
        && source.node(id).is_some_and(|node| node.data.hidden)
}

fn matching_label<'a>(node: &'a Node, state: &State) -> Cow<'a, str> {
    if node.data.can_expand
        && state.display.mode == Mode::List
        && !state.display.branch_suffix.is_empty()
    {
        Cow::Owned(format!(
            "{}{}",
            node.data.label, state.display.branch_suffix
        ))
    } else {
        Cow::Borrowed(&node.data.label)
    }
}

fn list_label(
    node: &Node,
    state: &State,
    previous: Option<&Snapshot>,
) -> (Arc<str>, Option<Arc<super::memory::Payload>>) {
    match matching_label(node, state) {
        Cow::Borrowed(_) => (node.data.label.clone(), None),
        Cow::Owned(text) => {
            let label = previous
                .and_then(|frame| frame.rows.lookup(node.id))
                .filter(|row| row.label.as_ref() == text)
                .map_or_else(|| Arc::<str>::from(text), |row| row.label.clone());
            let payload = super::memory::Payload::text(label.clone());
            (label, Some(payload))
        }
    }
}

fn retained(
    source: &Source,
    state: &State,
    roots: &[NodeId],
    matcher: Option<&Matcher>,
    matched_children: &mut MatchedChildren,
) -> Result<Option<HashSet<NodeId>>> {
    *matched_children = Map::default();
    if matcher.is_none() && state.display.filter.is_none() && !state.display.selected_only {
        return Ok(None);
    }
    struct Scan<'a> {
        node: &'a Node,
        child: usize,
        direct: bool,
        descendant: Vec<NodeId>,
    }
    let mut keep = Vec::new();
    let mut counts = Vec::new();
    let mut visited = 0;
    let mut inherited = Inherited::new(source, &state.selection);
    let mut stack = Vec::<Scan<'_>>::new();
    for &root in roots {
        if hidden(source, state, root) {
            continue;
        }
        let mut enter = Some(root);
        loop {
            if let Some(id) = enter.take() {
                visited += 1;
                let node = source.node(id).ok_or_else(|| Error::missing(id))?;
                let selected = if state.display.selected_only {
                    let value = inherited.get(id)?;
                    let summary = state
                        .summaries
                        .lookup(source, &state.selection, id, value)?
                        .ok_or_else(|| Error::invalid("selection summary missing"))?;
                    !summary.summary.is_empty()
                } else {
                    true
                };
                let direct = selected
                    && state
                        .display
                        .filter
                        .as_ref()
                        .is_none_or(|filter| filter.contains_key(&id))
                    && matcher.is_none_or(|matcher| matcher.is_match(&matching_label(node, state)));
                stack.push(Scan {
                    node,
                    child: 0,
                    direct,
                    descendant: Vec::new(),
                });
            }
            let descend = state.display.mode != Mode::List
                || state
                    .display
                    .list_depth
                    .is_none_or(|limit| stack.len() <= limit);
            let Some(frame) = stack.last_mut() else { break };
            if let Some(child) = descend.then(|| frame.node.child_at(frame.child)).flatten() {
                frame.child += 1;
                if !hidden(source, state, child) {
                    enter = Some(child);
                }
                continue;
            }
            let frame = stack.pop().expect("finished filter node");
            let connected = frame.direct || !frame.descendant.is_empty();
            if frame.node.data.can_expand {
                counts.push((frame.node.id, IndexedSequence::from_vec(frame.descendant)?));
            }
            if frame.direct
                || (connected
                    && (state.display.mode == Mode::Tree
                        || (state.display.selected_only && state.display.filter.is_none())))
            {
                keep.push(frame.node.id);
            }
            if let Some(parent) = stack.last_mut()
                && connected
            {
                parent.descendant.push(frame.node.id);
            }
        }
    }
    counts.sort_unstable_by_key(|(id, _)| *id);
    *matched_children = Map::from_sorted(counts);
    Ok((keep.len() != visited).then(|| keep.into_iter().collect()))
}

struct Group {
    ids: Vec<NodeId>,
    next: usize,
    parent: Option<usize>,
    depth: usize,
}

impl Snapshot {
    pub(crate) fn build(
        source: Arc<Source>,
        state: &mut State,
        previous: Option<&Snapshot>,
        reuse_layout: bool,
        text_nodes: Arc<[NodeId]>,
        commit_revision: Revision,
    ) -> Result<Self> {
        Self::build_inner(
            source,
            state,
            previous,
            reuse_layout,
            text_nodes,
            commit_revision,
            None,
        )
    }

    pub(crate) fn rebuild(
        source: Arc<Source>,
        state: &mut State,
        previous: &Snapshot,
        dirty: &super::engine::Invalidation,
        commit: Revision,
    ) -> Result<Self> {
        if dirty.layout && (state.display.selected_only || state.display.compress) {
            state.summary(&source)?;
        }
        let local = if dirty.layout {
            super::incremental::project(&source, state, previous, dirty)?
        } else {
            None
        };
        Self::build_inner(
            source,
            state,
            Some(previous),
            !dirty.layout,
            dirty.text.iter().copied().collect(),
            commit,
            local,
        )
    }

    fn build_inner(
        source: Arc<Source>,
        state: &mut State,
        previous: Option<&Snapshot>,
        reuse_layout: bool,
        text_nodes: Arc<[NodeId]>,
        commit_revision: Revision,
        local: Option<super::incremental::LayoutUpdate>,
    ) -> Result<Self> {
        if state.display.pattern.len() > 4096 {
            return Err(Error::limit("filter pattern exceeds 4096 bytes"));
        }
        if !state.display.branch_suffix.is_empty()
            && (state.display.mode != Mode::List
                || state.display.list_text != ListText::Label
                || state.display.branch_suffix.len() > 32
                || state.display.branch_suffix.chars().any(char::is_control))
        {
            return Err(Error::invalid(
                "branch suffixes require List label text and at most 32 display bytes",
            ));
        }
        if let Some(label) = &state.display.context_label {
            if state.display.mode != Mode::List
                || state.display.list_text != ListText::Label
                || !matches!(state.root, Root::ChildrenOf(_))
                || label.len() > 4096
                || label.chars().any(char::is_control)
            {
                return Err(Error::invalid(
                    "context labels require a ChildrenOf List with label text",
                ));
            }
        }
        let summary = state.summary(&source)?;
        let matcher = if state.display.pattern.is_empty() {
            None
        } else if let Some(previous) = previous.filter(|previous| {
            previous.state.display.pattern == state.display.pattern
                && previous.state.display.case_sensitive == state.display.case_sensitive
                && previous.state.display.fuzzy == state.display.fuzzy
                && previous.state.display.regex == state.display.regex
        }) {
            previous.matcher.clone()
        } else {
            Some(Matcher::new(&state.display)?)
        };
        let reuse = previous.filter(|frame| {
            reuse_layout && frame.state.display == state.display && frame.state.root == state.root
        });
        let text_roots = if state.display.mode == Mode::List
            && state.display.list_text == ListText::Ancestry
            && matches!(state.root, Root::Forest(_))
        {
            /* Display and metadata updates may rebuild rows without changing parentage. */
            match previous.filter(|frame| {
                frame.ancestry_text()
                    && frame.state.root == state.root
                    && frame.source.ancestry_revision == source.ancestry_revision
            }) {
                Some(frame) => frame.text_roots.clone(),
                None => {
                    let mut roots = state.display_roots(&source);
                    roots.sort_unstable();
                    Map::from_sorted(roots.into_iter().map(|id| (id, ())).collect())
                }
            }
        } else {
            Map::default()
        };
        let mut matched_children =
            previous.map_or_else(Map::default, |frame| frame.matched_children.clone());
        let (mut rows, last_root, needed, visited_nodes, same_layout, replaced_rows) =
            if let Some(local) = local {
                matched_children = local.matched_children;
                (
                    local.rows,
                    local.last_root,
                    local.needed,
                    local.visited,
                    local.same,
                    0,
                )
            } else if let Some(frame) = reuse {
                (
                    frame.rows.clone(),
                    frame.last_root,
                    frame.needed_children.clone(),
                    0,
                    true,
                    0,
                )
            } else {
                let roots = state.display_roots(&source);
                let keep = retained(
                    &source,
                    state,
                    &roots,
                    matcher.as_ref(),
                    &mut matched_children,
                )?;
                let allowed = |id: &NodeId| {
                    !hidden(&source, state, *id)
                        && keep.as_ref().is_none_or(|keep| keep.contains(id))
                };
                let mut rows = Vec::<Row>::new();
                let mut needed = Vec::new();
                let mut visited = 0;
                let mut last_root = None;
                let mut selection = Inherited::new(&source, &state.selection);
                let mut expansion = Inherited::new(&source, &state.expansion);
                if state.display.mode == Mode::List {
                    if let (Root::ChildrenOf(id), Some(label)) =
                        (&state.root, &state.display.context_label)
                        && source.contains(*id)
                        && state
                            .display
                            .filter
                            .as_ref()
                            .is_none_or(|filter| filter.contains_key(id))
                        && matcher
                            .as_ref()
                            .is_none_or(|matcher| matcher.is_match(label))
                    {
                        rows.push(Row {
                            id: *id,
                            label: label.clone(),
                            label_payload: Some(super::memory::Payload::text(label.clone())),
                            text: None,
                            chain: None,
                            depth: 0,
                            parent: None,
                            source_ancestor: None,
                            last_child: None,
                            last_descendant: *id,
                            connector_last: true,
                        });
                    }
                    let mut groups = vec![Group {
                        ids: roots.clone(),
                        next: 0,
                        parent: None,
                        depth: 0,
                    }];
                    let mut candidates = Vec::new();
                    while let Some(group) = groups.last_mut() {
                        let Some(&id) = group.ids.get(group.next) else {
                            groups.pop();
                            continue;
                        };
                        group.next += 1;
                        if hidden(&source, state, id) {
                            continue;
                        }
                        let node = source.node(id).ok_or_else(|| Error::missing(id))?;
                        let depth = group.depth;
                        let descend = state.display.list_depth.is_none_or(|limit| depth < limit);
                        visited += 1;
                        if allowed(&id) {
                            candidates.push(id);
                        }
                        if descend
                            && node.data.can_expand
                            && node.completeness != Completeness::Complete
                        {
                            needed.push(id);
                        }
                        if descend && node.child_count() != 0 {
                            groups.push(Group {
                                ids: node.children().collect(),
                                next: 0,
                                parent: None,
                                depth: depth + 1,
                            });
                        }
                    }
                    let candidates = sorted(&source, candidates, &state.display);
                    let visible: HashSet<_> = candidates.iter().copied().collect();
                    let mut ancestors = HashMap::<NodeId, Option<NodeId>>::new();
                    let mut text = (state.display.list_text == ListText::Ancestry).then(|| {
                        super::text::Builder::new(&source, &state.root, &text_roots, previous)
                    });
                    for id in candidates {
                        let mut path = Vec::new();
                        let node = source.node(id).expect("projected node");
                        let mut parent = node.parent;
                        while let Some(current) = parent {
                            if visible.contains(&current) {
                                break;
                            }
                            if let Some(cached) = ancestors.get(&current) {
                                parent = *cached;
                                break;
                            }
                            path.push(current);
                            parent = source.node(current).and_then(|node| node.parent);
                        }
                        for current in path {
                            ancestors.insert(current, parent);
                        }
                        let (label, label_payload) = list_label(node, state, previous);
                        rows.push(Row {
                            id,
                            label,
                            label_payload,
                            text: text.as_mut().map(|text| text.text(node)).transpose()?,
                            chain: None,
                            depth: 0,
                            parent: None,
                            source_ancestor: parent,
                            last_child: None,
                            last_descendant: id,
                            connector_last: true,
                        });
                    }
                    last_root = rows.last().map(|row| row.id);
                } else {
                    let top = match state.root {
                        Root::Forest(_) => roots.clone(),
                        Root::ChildrenOf(_) => sorted(&source, roots.clone(), &state.display),
                    };
                    let top: Vec<_> = top.into_iter().filter(&allowed).collect();
                    let mut groups = vec![Group {
                        ids: top,
                        next: 0,
                        parent: None,
                        depth: 0,
                    }];
                    while let Some(group) = groups.last_mut() {
                        let Some(&outer) = group.ids.get(group.next) else {
                            let finished = groups.pop().expect("finished group");
                            if let Some(parent) = finished.parent {
                                rows[parent].last_descendant =
                                    rows.last().expect("parent row exists").id;
                            }
                            continue;
                        };
                        group.next += 1;
                        let parent = group.parent;
                        let depth = group.depth;
                        let visible_last = group.next == group.ids.len();
                        let mut id = outer;
                        let mut chain = Vec::new();
                        visited += 1;
                        if state.display.compress {
                            loop {
                                let node = source.node(id).ok_or_else(|| Error::missing(id))?;
                                let Some(child) =
                                    compression_child(node, &state.display, &matched_children)
                                else {
                                    break;
                                };
                                if expansion.get(id)?.max(state.expansion.marks(id).own) & 1 == 0 {
                                    break;
                                }
                                let child_node =
                                    source.node(child).ok_or_else(|| Error::missing(child))?;
                                if !allowed(&child)
                                    || !child_node.data.can_expand
                                    || !child_node.data.foldable
                                {
                                    break;
                                }
                                if selection_kind(&source, state, id, selection.get(id)?)?
                                    != selection_kind(&source, state, child, selection.get(child)?)?
                                {
                                    break;
                                }
                                if chain.is_empty() {
                                    chain.push(id);
                                }
                                if node.completeness != Completeness::Complete {
                                    needed.push(id);
                                }
                                chain.push(child);
                                id = child;
                                visited += 1;
                            }
                        }
                        let connector_last = if state.display.selected_only {
                            if parent.is_none() {
                                roots.last() == Some(&outer)
                            } else {
                                let source_parent = source.node(outer).and_then(|node| node.parent);
                                let siblings = source.child_sequence(source_parent)?;
                                siblings.get(siblings.len().saturating_sub(1)) == Some(&outer)
                            }
                        } else {
                            visible_last
                        };
                        let row_index = rows.len();
                        let parent_id = parent.map(|parent| rows[parent].id);
                        if let Some(parent) = parent {
                            rows[parent].last_child = Some(id);
                        } else {
                            last_root = Some(id);
                        }
                        let node = source.node(id).ok_or_else(|| Error::missing(id))?;
                        rows.push(Row {
                            id,
                            label: node.data.label.clone(),
                            label_payload: None,
                            text: None,
                            chain: (!chain.is_empty()).then(|| chain.into()),
                            depth,
                            parent: parent_id,
                            source_ancestor: parent_id,
                            last_child: None,
                            last_descendant: id,
                            connector_last,
                        });
                        let expanded = node.data.can_expand
                            && expansion.get(id)?.max(state.expansion.marks(id).own) & 1 != 0;
                        if expanded {
                            if node.completeness != Completeness::Complete {
                                needed.push(id);
                            }
                            let children = sorted(
                                &source,
                                node.children().filter(&allowed).collect(),
                                &state.display,
                            );
                            if !children.is_empty() {
                                groups.push(Group {
                                    ids: children,
                                    next: 0,
                                    parent: Some(row_index),
                                    depth: depth + 1,
                                });
                            }
                        }
                    }
                }
                if let Root::ChildrenOf(root) = state.root
                    && source.node(root).is_some_and(|node| {
                        node.data.can_expand && node.completeness != Completeness::Complete
                    })
                {
                    needed.push(root);
                }
                let same = previous.is_some_and(|previous| {
                    previous.state.root == state.root
                        && previous.state.display.mode == state.display.mode
                        && previous.rows.len() == rows.len()
                        && previous
                            .rows
                            .iter()
                            .zip(&rows)
                            .all(|(a, b)| a.same_layout(b))
                });
                let (indexed, replaced) = match previous {
                    Some(previous) => previous.rows.reconcile(rows)?,
                    None => {
                        let count = rows.len();
                        (IndexedSequence::from_vec(rows)?, count)
                    }
                };
                (indexed, last_root, needed.into(), visited, same, replaced)
            };
        /* Keep cached text tied to this source's allocation, including equal-text
        updates. Sharing a superseded label alone would outlive its payload charge. */
        let mut updated = HashSet::new();
        for id in text_nodes.iter() {
            /* Newly projected identities already use this source's label allocation. */
            if previous.is_none_or(|old| !old.source.contains(*id)) {
                continue;
            }
            let Some(at) = rows.position(id) else {
                continue;
            };
            if !updated.insert(at) {
                continue;
            }
            let row = rows.get(at).expect("changed text row");
            if state.display.context_label.is_some() && state.root == Root::ChildrenOf(row.id) {
                continue;
            }
            let (label, payload) = list_label(
                source.node(row.id).expect("projected node"),
                state,
                previous,
            );
            if !Arc::ptr_eq(&row.label, &label) {
                let mut row = row.clone();
                row.label = label;
                row.label_payload = payload;
                rows.splice(at, at + 1, vec![row])?;
            }
        }
        let (text_nodes, ancestry_changed) =
            super::text::apply(&source, state, previous, &mut rows, text_nodes, &text_roots)?;
        let old_cursor = state
            .cursor
            .or_else(|| previous.and_then(|frame| frame.state.cursor));
        let cursor = old_cursor
            .filter(|id| rows.position(id).is_some())
            .or_else(|| {
                let mut current = old_cursor;
                while let Some(id) = current {
                    current = source.node(id).and_then(|node| node.parent).or_else(|| {
                        previous
                            .and_then(|frame| frame.source.node(id))
                            .and_then(|node| node.parent)
                    });
                    if current.is_some_and(|id| rows.position(&id).is_some()) {
                        return current;
                    }
                }
                None
            })
            .or_else(|| {
                let position = previous
                    .and_then(|frame| old_cursor.and_then(|id| frame.rows.position(&id)))
                    .unwrap_or(0);
                rows.get(position.min(rows.len().saturating_sub(1)))
                    .map(|row| row.id)
            });
        state.cursor = cursor;
        let layout_revision = match previous {
            Some(previous) if same_layout => previous.layout_revision,
            Some(previous) => previous.layout_revision.next()?,
            None => Revision(1),
        };
        let text_revision = match previous {
            Some(previous) => {
                let changed = !same_layout
                    || ancestry_changed
                    || previous.state.display.context_label != state.display.context_label
                    || previous.state.display.branch_suffix != state.display.branch_suffix
                    || text_nodes.iter().any(|id| {
                        /* Expandability changes derived List text even when the source label is unchanged. */
                        let suffix = !state.display.branch_suffix.is_empty();
                        (rows.position(id).is_some() || previous.position(*id).is_some())
                            && previous
                                .source
                                .node(*id)
                                .map(|node| (&node.data.label, suffix && node.data.can_expand))
                                != source
                                    .node(*id)
                                    .map(|node| (&node.data.label, suffix && node.data.can_expand))
                    });
                if changed {
                    previous.text_revision.next()?
                } else {
                    previous.text_revision
                }
            }
            None => Revision(1),
        };
        Ok(Self {
            id: identity()?,
            commit_revision,
            layout_revision,
            text_revision,
            summary,
            last_root,
            needed_children: needed,
            visited_nodes,
            queries: Arc::new([]),
            source,
            state: state.clone(),
            rows,
            previous: previous.map(|frame| frame.id),
            replaced_rows,
            text_nodes,
            matched_children,
            text_roots,
            matcher,
        })
    }

    pub fn source(&self) -> &Source {
        &self.source
    }

    pub(crate) fn matches_node(&self, id: NodeId, label: &str) -> bool {
        self.state
            .display
            .filter
            .as_ref()
            .is_none_or(|filter| filter.contains_key(&id))
            && self
                .matcher
                .as_ref()
                .is_none_or(|matcher| matcher.is_match(label))
    }

    pub(crate) fn unchanged_match(
        &self,
        display: &DisplayOptions,
        before: &str,
        after: &str,
    ) -> bool {
        self.state.display.pattern == display.pattern
            && display.branch_suffix.is_empty()
            && self.state.display.case_sensitive == display.case_sensitive
            && self.state.display.fuzzy == display.fuzzy
            && self.state.display.regex == display.regex
            && self
                .matcher
                .as_ref()
                .is_none_or(|matcher| matcher.is_match(before) == matcher.is_match(after))
    }
    pub fn state_id(&self) -> u64 {
        self.state.id
    }
    pub fn state_revision(&self) -> Revision {
        self.state.revision
    }
    pub fn selection_revision(&self) -> Revision {
        self.state.selection_revision
    }
    pub fn mode(&self) -> Mode {
        self.state.display.mode
    }

    pub(crate) fn ancestry_text(&self) -> bool {
        self.mode() == Mode::List && self.state.display.list_text == ListText::Ancestry
    }
    pub fn root(&self) -> &Root {
        &self.state.root
    }
    pub fn cursor(&self) -> Option<NodeId> {
        self.state.cursor
    }
    pub fn len(&self) -> usize {
        self.rows.len()
    }
    pub fn is_empty(&self) -> bool {
        self.rows.is_empty()
    }
    pub fn row(&self, index: usize) -> Option<&Row> {
        self.rows.get(index)
    }
    pub fn position(&self, id: NodeId) -> Option<usize> {
        self.rows.position(&id)
    }

    /** Find a visible terminal node without exporting skipped branch rows or their metadata. */
    pub fn adjacent_leaf(&self, index: Option<usize>, forward: bool) -> Option<usize> {
        if index.is_some_and(|index| index >= self.len()) {
            return None;
        }
        let leaf = |row: &Row| {
            !self
                .source
                .node(row.id)
                .expect("projected node")
                .data
                .can_expand
        };
        if forward {
            let first = index.map_or(0, |index| index + 1);
            self.rows
                .iter_from(first)
                .position(leaf)
                .map(|offset| first + offset)
        } else {
            (0..index.unwrap_or(self.len()))
                .rev()
                .find(|&at| leaf(self.row(at).expect("projected row")))
        }
    }

    /** Prove that row reads are reusable across cursor-only publications, without visiting rows. */
    pub fn same_rows(&self, other: &Self) -> bool {
        self.state.id == other.state.id
            && Arc::ptr_eq(&self.source, &other.source)
            && self.rows.same_version(&other.rows)
            && self.state.root == other.state.root
            && self.state.display == other.state.display
            && self.state.selection.clear == other.state.selection.clear
            && self
                .state
                .selection
                .nodes
                .same_version(&other.state.selection.nodes)
            && self.state.expansion.clear == other.state.expansion.clear
            && self
                .state
                .expansion
                .nodes
                .same_version(&other.state.expansion.nodes)
    }

    /** Only visible ancestors are visited; an offscreen parent terminates the clipped path. */
    pub fn guide_path(&self, index: usize, start: usize, end: usize) -> Result<Vec<GuideSegment>> {
        if start > end || end > self.len() {
            return Err(Error::invalid("guide viewport is outside this frame"));
        }
        if end - start > 512 {
            return Err(Error::limit("guide viewport requires at most 512 rows"));
        }
        let mut segments = Vec::new();
        if self.mode() != Mode::Tree || !(start..end).contains(&index) {
            return Ok(segments);
        }
        let mut at = index;
        loop {
            let row = self.row(at).expect("visible guide path node");
            let parent = row.parent.and_then(|id| self.position(id));
            let first = parent.map_or_else(
                || match self.root() {
                    Root::ChildrenOf(_) => 0,
                    Root::Forest(_) => at,
                },
                |parent| parent + 1,
            );
            segments.push(GuideSegment {
                first: first.max(start),
                last: at + 1,
                depth: row.depth,
            });
            match parent {
                Some(parent) if parent >= start => at = parent,
                _ => break,
            }
        }
        segments.reverse();
        Ok(segments)
    }

    pub fn navigate(&self, index: usize, direction: Direction) -> Option<usize> {
        if self.mode() == Mode::List {
            return None;
        }
        let row = self.row(index)?;
        let id = match direction {
            Direction::Parent => row.parent?,
            Direction::LastChildOrSibling => row
                .last_child
                .or_else(|| {
                    row.parent
                        .and_then(|parent| self.rows.lookup(parent))
                        .and_then(|parent| parent.last_child)
                })
                .or(self.last_root)?,
        };
        self.position(id)
    }

    pub fn first_child(&self, index: usize) -> Option<usize> {
        let row = self.row(index)?;
        self.row(index + 1)
            .filter(|child| child.parent == Some(row.id))
            .map(|_| index + 1)
    }

    pub fn next_sibling(&self, index: usize) -> Option<usize> {
        let row = self.row(index)?;
        let next = self.position(row.last_descendant)? + 1;
        self.row(next)
            .filter(|next| next.parent == row.parent)
            .map(|_| next)
    }

    /// Selected identities from this frame; visible reads preserve display order.
    pub fn marked_nodes(&self, visible_only: bool) -> Result<Arc<[NodeId]>> {
        if self.summary.is_empty() {
            return Ok(Arc::from([]));
        }
        let mut inherited = Inherited::new(&self.source, &self.state.selection);
        let mut selected = Vec::new();
        let mut visit = |id| -> Result<()> {
            if inherited.get(id)?.max(self.state.selection.marks(id).own) & 1 != 0 {
                selected.push(id);
            }
            Ok(())
        };
        if visible_only {
            for row in self.rows.iter() {
                visit(row.id)?;
            }
        } else {
            for (id, _) in self.source.nodes.iter() {
                visit(*id)?;
            }
        }
        Ok(selected.into())
    }

    pub fn rows(&self, start: usize, end: usize) -> Result<Vec<RowInfo>> {
        if start > end || end > self.len() {
            return Err(Error::invalid("row range is outside this frame"));
        }
        if end - start > 512 {
            return Err(Error::limit("viewport reads require at most 512 rows"));
        }
        let mut remaining_bytes = 1024 * 1024;
        let mut remaining_matches = 8192;
        let mut labels = Vec::new();
        let mut selection = Inherited::new(&self.source, &self.state.selection);
        let mut expansion = Inherited::new(&self.source, &self.state.expansion);
        self.rows
            .iter_from(start)
            .take(end - start)
            .map(|row| {
                let node = self
                    .source
                    .node(row.id)
                    .ok_or_else(|| Error::missing(row.id))?;
                let mut label_bytes = 0usize;
                for id in row.folded_ids() {
                    label_bytes = label_bytes.saturating_add(
                        self.source
                            .node(*id)
                            .ok_or_else(|| Error::missing(*id))?
                            .data
                            .label
                            .len(),
                    );
                }
                label_bytes = row.text.as_ref().map_or_else(
                    || {
                        if row.chain.is_none() {
                            row.label.len()
                        } else {
                            label_bytes.saturating_add(row.folded_ids().len() - 1)
                        }
                    },
                    |text| text.bytes(&row.label),
                );
                let mut row_bytes = label_bytes.saturating_add(std::mem::size_of::<RowInfo>());
                row_bytes = row_bytes.saturating_add(std::mem::size_of_val(row.folded_ids()));
                for text in [
                    node.data.icon.as_deref(),
                    node.data.highlight.as_deref(),
                    node.data.right_text.as_deref(),
                ]
                .into_iter()
                .flatten()
                {
                    row_bytes = row_bytes.saturating_add(text.len());
                }
                if row_bytes > remaining_bytes {
                    return Err(Error::limit("viewport data exceeds 1 MiB"));
                }
                remaining_bytes -= row_bytes;
                let inherited = selection.get(row.id)?;
                let summary = self
                    .state
                    .summaries
                    .lookup(&self.source, &self.state.selection, row.id, inherited)?
                    .ok_or_else(|| Error::invalid("frame summary unavailable"))?
                    .summary;
                let label = if let Some(text) = &row.text {
                    let mut label = String::with_capacity(text.bytes(&row.label));
                    text.append(&row.label, &mut label, &mut labels);
                    label
                } else if let Some(chain) = &row.chain {
                    chain
                        .iter()
                        .map(|id| {
                            self.source
                                .node(*id)
                                .map(|node| node.data.label.as_ref())
                                .ok_or_else(|| Error::missing(*id))
                        })
                        .collect::<Result<Vec<_>>>()?
                        .join("/")
                } else {
                    row.label.to_string()
                };
                let (matched_text, match_offset) = if row.text.is_some() {
                    (
                        node.data.label.as_ref(),
                        label.len() - node.data.label.len(),
                    )
                } else {
                    (label.as_str(), 0)
                };
                let matches = self
                    .matcher
                    .as_ref()
                    .map(|matcher| {
                        matcher
                            .ranges(matched_text, remaining_matches + 1)
                            .into_iter()
                            .map(|(first, last)| (first + match_offset, last + match_offset))
                            .collect::<Vec<_>>()
                    })
                    .unwrap_or_default();
                if matches.len() > remaining_matches {
                    return Err(Error::limit("viewport matches exceed 8192"));
                }
                remaining_matches -= matches.len();
                let mut load_state = LoadState::Idle;
                let mut error = None;
                for id in row.folded_ids() {
                    let member = self.source.node(*id).ok_or_else(|| Error::missing(*id))?;
                    if member.load_state == LoadState::Error && error.is_none() {
                        error = member.error.clone().map(|mut error| {
                            error.node = Some(*id);
                            error
                        });
                        load_state = LoadState::Error;
                    } else if member.load_state == LoadState::Loading
                        && load_state == LoadState::Idle
                    {
                        load_state = LoadState::Loading;
                    }
                }
                let decoration_bytes = matches.len() * std::mem::size_of::<(usize, usize)>()
                    + error.as_ref().map_or(0, |error| error.message.len());
                if decoration_bytes > remaining_bytes {
                    return Err(Error::limit("viewport data exceeds 1 MiB"));
                }
                remaining_bytes -= decoration_bytes;
                Ok(RowInfo {
                    row: row.clone(),
                    label,
                    marked: inherited.max(self.state.selection.marks(row.id).own) & 1 != 0,
                    full: summary.full,
                    pending: summary.pending,
                    expanded: node.data.can_expand
                        && expansion
                            .get(row.id)?
                            .max(self.state.expansion.marks(row.id).own)
                            & 1
                            != 0,
                    can_expand: node.data.can_expand,
                    icon: node.data.icon.clone(),
                    highlight: node.data.highlight.clone(),
                    right_text: node.data.right_text.clone(),
                    load_state,
                    error,
                    matches,
                })
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::super::data::{NodeRef, Operation, Position};
    use super::super::state::SelectAction;
    use super::*;

    fn fixture() -> (Arc<Source>, State) {
        let mut source = Source::empty().unwrap();
        for (key, parent, branch) in [
            ("r", None, true),
            ("a", Some("r"), true),
            ("b", Some("a"), true),
            ("c", Some("b"), false),
            ("z", Some("r"), false),
        ] {
            let mut data = if branch {
                NodeData::branch(key)
            } else {
                NodeData::leaf(key)
            };
            data.foldable = branch;
            source
                .apply(
                    &Operation::Insert {
                        key: key.into(),
                        parent: parent.map(NodeRef::from),
                        position: Position::Last,
                        data,
                        completeness: Completeness::Complete,
                    },
                    Revision(1),
                    &Limits::default(),
                    None,
                )
                .unwrap();
        }
        let root = source.id("r").unwrap();
        let mut state = State::new(
            &source,
            Root::ChildrenOf(root),
            DisplayOptions {
                compress: true,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
        state
            .set_expanded(&source, &[root], true, Scope::Subtree)
            .unwrap();
        (Arc::new(source), state)
    }

    #[test]
    fn t_adjacent_leaves_follow_the_frame_order_and_skip_collapsed_branches() {
        let (source, mut state) = fixture();
        let open = Snapshot::build(
            source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            Revision(1),
        )
        .unwrap();
        assert_eq!(open.adjacent_leaf(None, true), Some(1));
        assert_eq!(open.adjacent_leaf(None, false), Some(2));
        assert_eq!(open.adjacent_leaf(Some(0), true), Some(1));
        assert_eq!(open.adjacent_leaf(Some(1), false), None);
        assert_eq!(open.adjacent_leaf(Some(2), false), Some(1));
        assert_eq!(open.adjacent_leaf(Some(2), true), None);
        assert_eq!(open.adjacent_leaf(Some(usize::MAX), false), None);
        state
            .set_expanded(&source, &[source.id("a").unwrap()], false, Scope::SelfOnly)
            .unwrap();
        let closed = Snapshot::build(
            source.clone(),
            &mut state,
            Some(&open),
            false,
            Arc::new([]),
            Revision(2),
        )
        .unwrap();
        assert_eq!(closed.adjacent_leaf(None, true), Some(1));
        assert_eq!(closed.row(1).unwrap().id, source.id("z").unwrap());
        assert_eq!(closed.adjacent_leaf(Some(1), false), None);
        assert_eq!(
            open.row(open.adjacent_leaf(None, true).unwrap())
                .unwrap()
                .id,
            source.id("c").unwrap()
        );
        state.display.mode = Mode::List;
        let list = Snapshot::build(
            source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            Revision(3),
        )
        .unwrap();
        assert_eq!(
            list.row(list.adjacent_leaf(None, true).unwrap())
                .unwrap()
                .id,
            source.id("c").unwrap()
        );
        state.root = Root::Forest(Arc::new([]));
        let empty =
            Snapshot::build(source, &mut state, None, false, Arc::new([]), Revision(4)).unwrap();
        assert_eq!(empty.adjacent_leaf(None, true), None);
        assert_eq!(empty.adjacent_leaf(None, false), None);
    }

    #[test]
    fn list_branch_suffix_is_matched_rendered_and_accounted_without_changing_source_labels() {
        let (source, mut state) = fixture();
        state.display = DisplayOptions {
            mode: Mode::List,
            list_depth: Some(0),
            branch_suffix: "/".into(),
            pattern: "^a/$".into(),
            regex: true,
            ..DisplayOptions::default()
        };
        let first = Snapshot::build(
            source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            Revision(1),
        )
        .unwrap();
        assert_eq!(first.len(), 1);
        let row = &first.rows(0, 1).unwrap()[0];
        assert_eq!(row.label, "a/");
        assert_eq!(row.matches, [(0, 2)]);
        assert!(row.row.label_payload.is_some());
        assert_eq!(
            source
                .node(source.id("a").unwrap())
                .unwrap()
                .data
                .label
                .as_ref(),
            "a"
        );
        state.display.pattern = "".into();
        state.display.branch_suffix = "中/".into();
        let before = Snapshot::build(
            source.clone(),
            &mut state,
            Some(&first),
            false,
            Arc::new([]),
            Revision(2),
        )
        .unwrap();
        state.display.branch_suffix = "".into();
        let after = Snapshot::build(
            source,
            &mut state,
            Some(&before),
            false,
            Arc::new([]),
            Revision(3),
        )
        .unwrap();
        let context = super::super::render::RenderContext::default();
        let plan = super::super::render::RenderPlan::new(
            Some(Arc::new(before)),
            Arc::new(after),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        assert_eq!(plan.lines(0, 2, 1024).unwrap().0, ["  a", "  z"]);
        assert_eq!(plan.work.written_rows, 1);
    }

    #[test]
    fn bounded_list_filters_only_its_scope_and_keeps_context_identity() {
        let (source, mut state) = fixture();
        state.display = DisplayOptions {
            mode: Mode::List,
            list_depth: Some(0),
            context_label: Some("../".into()),
            ..DisplayOptions::default()
        };
        let build = |state: &mut State, before: Option<&Snapshot>| {
            Snapshot::build(
                source.clone(),
                state,
                before,
                false,
                Arc::new([]),
                Revision(1),
            )
            .unwrap()
        };
        let frame = build(&mut state, None);
        assert_eq!(
            frame
                .rows(0, frame.len())
                .unwrap()
                .iter()
                .map(|row| row.label.as_str())
                .collect::<Vec<_>>(),
            ["../", "a", "z"]
        );
        assert_eq!(frame.row(0).unwrap().id, source.id("r").unwrap());
        assert!(state.demands_children(&source, source.id("r").unwrap()));
        assert!(!state.demands_children(&source, source.id("a").unwrap()));
        assert_eq!(frame.visited_nodes, 2);
        state.display.pattern = "c".into();
        assert_eq!(build(&mut state, Some(&frame)).len(), 0);
        state.display.pattern = "../".into();
        let filtered = build(&mut state, Some(&frame));
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered.rows(0, 1).unwrap()[0].matches, [(0, 3)]);
        state.display.pattern = "".into();
        state.display.context_label = Some("up".into());
        let changed = build(&mut state, Some(&frame));
        let context = super::super::render::RenderContext::default();
        let plan = super::super::render::RenderPlan::new(
            Some(Arc::new(frame)),
            Arc::new(changed),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        assert_eq!(plan.lines(0, 1, 1024).unwrap().0, ["  up"]);
        assert!(plan.work.written_rows > 0);
    }

    #[test]
    fn t_folded_navigation_uses_visible_parents_and_direct_children() {
        let (source, mut state) = fixture();
        let frame = Snapshot::build(
            source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            Revision(1),
        )
        .unwrap();
        assert_eq!(
            frame
                .rows(0, frame.len())
                .unwrap()
                .iter()
                .map(|row| row.label.as_str())
                .collect::<Vec<_>>(),
            ["a/b", "c", "z"]
        );
        assert_eq!(frame.position(source.id("a").unwrap()), Some(0));
        assert_eq!(frame.navigate(0, Direction::LastChildOrSibling), Some(1));
        assert_eq!(frame.navigate(1, Direction::Parent), Some(0));
        assert_eq!(frame.navigate(2, Direction::LastChildOrSibling), Some(2));
        assert_eq!(frame.first_child(0), Some(1));
        assert_eq!(frame.next_sibling(0), Some(2));
    }

    #[test]
    fn t_list_filters_existing_descendants_and_sorts_across_parents() {
        let (source, mut state) = fixture();
        state.display.mode = Mode::List;
        state.display.pattern = "c".into();
        let frame = Snapshot::build(
            source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            Revision(1),
        )
        .unwrap();
        assert_eq!(frame.len(), 1);
        assert_eq!(frame.row(0).unwrap().id, source.id("c").unwrap());
        assert_eq!(frame.navigate(0, Direction::Parent), None);
        state.display.mode = Mode::Tree;
        let frame = Snapshot::build(
            source.clone(),
            &mut state,
            Some(&frame),
            false,
            Arc::new([]),
            Revision(2),
        )
        .unwrap();
        assert_eq!(
            frame
                .rows(0, frame.len())
                .unwrap()
                .iter()
                .map(|row| row.label.as_str())
                .collect::<Vec<_>>(),
            ["a/b", "c"]
        );
    }

    #[test]
    fn t_selection_boundaries_split_chains_and_old_frames_keep_their_mapping() {
        let (source, mut state) = fixture();
        let old = Snapshot::build(
            source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            Revision(1),
        )
        .unwrap();
        state
            .select(
                &source,
                &[source.id("b").unwrap()],
                SelectAction::Select,
                Scope::Subtree,
            )
            .unwrap();
        let new = Snapshot::build(
            source.clone(),
            &mut state,
            Some(&old),
            false,
            Arc::new([]),
            Revision(2),
        )
        .unwrap();
        assert_eq!(old.len(), 3);
        assert_eq!(new.len(), 4);
        assert!(new.layout_revision > old.layout_revision);
        assert!(!old.rows(0, 1).unwrap()[0].marked);
        assert!(new.rows(1, 2).unwrap()[0].full);
    }
}
