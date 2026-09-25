use super::data::{ChangeKind, Source};
use super::engine::Invalidation;
use super::model::*;
use super::projection::{MatchedChildren, Row, Snapshot, selection_kind, sorted};
use super::state::State;
use super::storage::IndexedSequence;
use std::collections::{HashMap, HashSet};
use std::sync::Arc;

pub(crate) struct LayoutUpdate {
    pub rows: IndexedSequence<Row>,
    pub last_root: Option<NodeId>,
    pub needed: Arc<[NodeId]>,
    pub visited: usize,
    pub same: bool,
    pub matched_children: MatchedChildren,
}

#[derive(Default)]
struct Ranks {
    nodes: HashMap<NodeId, usize>,
    blocks: HashMap<u64, usize>,
}

impl Ranks {
    fn position(&mut self, source: &Source, id: NodeId) -> usize {
        *self.nodes.entry(id).or_insert_with(|| {
            source
                .child_sequence(source.node(id).expect("ordered node").parent)
                .expect("sibling group")
                .position_cached(&id, &mut self.blocks)
                .expect("source sibling")
        })
    }
}

fn member(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    matched: &MatchedChildren,
    id: NodeId,
    subtree: bool,
) -> Result<bool> {
    let Some(node) = source.node(id) else {
        return Ok(false);
    };
    if !state.display.show_hidden && !state.display.selected_only && node.data.hidden {
        return Ok(false);
    }
    let selected = if state.display.selected_only {
        let inherited = state.selection.inherited(source, id)?;
        !state
            .summaries
            .lookup(source, &state.selection, id, inherited)?
            .ok_or_else(|| Error::invalid("selection summary unavailable"))?
            .summary
            .is_empty()
    } else {
        true
    };
    Ok((selected && previous.matches_label(&node.data.label))
        || (!state.display.pattern.is_empty()
            && (subtree || state.display.mode == Mode::Tree || state.display.selected_only)
            && matched
                .get(&id)
                .is_some_and(|children| !children.is_empty())))
}

fn visible(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    matched: &MatchedChildren,
    id: NodeId,
) -> Result<bool> {
    member(source, state, previous, matched, id, false)
}

fn source_path(
    source: &Source,
    state: &State,
    roots: &HashMap<NodeId, usize>,
    node: NodeId,
) -> Result<Option<Vec<NodeId>>> {
    let mut path = Vec::new();
    let mut current = node;
    loop {
        let Some(data) = source.node(current) else {
            return Ok(None);
        };
        if !state.display.show_hidden && !state.display.selected_only && data.data.hidden {
            return Ok(None);
        }
        path.push(current);
        if roots.contains_key(&current) {
            path.reverse();
            return Ok(Some(path));
        }
        let Some(parent) = data.parent else {
            return Ok(None);
        };
        if state.root == Root::ChildrenOf(parent) {
            path.reverse();
            return Ok(Some(path));
        }
        current = parent;
    }
}

fn visible_path(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    matched: &MatchedChildren,
    roots: &HashMap<NodeId, usize>,
    node: NodeId,
) -> Result<Option<Vec<NodeId>>> {
    let Some(path) = source_path(source, state, roots, node)? else {
        return Ok(None);
    };
    if state.display.mode == Mode::Tree {
        let mut current = node;
        for _ in 0..path.len() {
            if !visible(source, state, previous, matched, current)?
                || (current != node && !state.expanded(source, current)?)
            {
                return Ok(None);
            }
            if let Some(parent) = source.node(current).and_then(|node| node.parent) {
                current = parent;
            }
        }
    }
    Ok(Some(path))
}

fn compare_paths(
    source: &Source,
    state: &State,
    roots: &HashMap<NodeId, usize>,
    left: &[NodeId],
    right: &[NodeId],
    ranks: &mut Ranks,
) -> std::cmp::Ordering {
    use std::cmp::Ordering;
    let compare_key = |a: NodeId, b: NodeId| {
        if state.display.sort == Sort::Source && !state.display.branches_first {
            return Ordering::Equal;
        }
        let left = &source.node(a).expect("ordered node").data;
        let right = &source.node(b).expect("ordered node").data;
        (state.display.branches_first && !left.can_expand)
            .cmp(&(state.display.branches_first && !right.can_expand))
            .then_with(|| match state.display.sort {
                Sort::Source => Ordering::Equal,
                Sort::Name => left
                    .label
                    .to_ascii_lowercase()
                    .cmp(&right.label.to_ascii_lowercase())
                    .then_with(|| a.cmp(&b)),
                Sort::Score => right.score.total_cmp(&left.score).then_with(|| a.cmp(&b)),
            })
    };
    if state.display.mode == Mode::List {
        let order = compare_key(
            *left.last().expect("node path"),
            *right.last().expect("node path"),
        );
        if order != Ordering::Equal {
            return order;
        }
    }
    for (&a, &b) in left.iter().zip(right) {
        if a == b {
            continue;
        }
        if let (Some(a), Some(b)) = (roots.get(&a), roots.get(&b)) {
            return a.cmp(b);
        }
        if state.display.mode == Mode::Tree {
            let order = compare_key(a, b);
            if order != Ordering::Equal {
                return order;
            }
        }
        let left = ranks.position(source, a);
        let right = ranks.position(source, b);
        return left.cmp(&right);
    }
    left.len().cmp(&right.len())
}

fn sorted_list(state: &State) -> bool {
    state.display.mode == Mode::List
        && (state.display.sort != Sort::Source || state.display.branches_first)
}

/* Surviving rows keep their projection order. Rank search skips filtered
siblings and compares only the sort keys along the relevant paths. */
fn boundary_at(
    source: &Source,
    state: &State,
    roots: &HashMap<NodeId, usize>,
    rows: &IndexedSequence<Row>,
    path: &[NodeId],
    after: bool,
    ranks: &mut Ranks,
) -> Result<usize> {
    let direct_rank = if path.len() == 1
        && state.display.sort == Sort::Source
        && !state.display.branches_first
        && matches!(state.root, Root::ChildrenOf(root) if source.node(path[0]).is_some_and(|node| node.parent == Some(root)))
    {
        Some(ranks.position(source, path[0]))
    } else {
        None
    };
    let (mut left, mut right) = (0, rows.len());
    while left < right {
        let middle = left + (right - left) / 2;
        let row = rows.get(middle).expect("row rank");
        let id = row.folded_ids()[0];
        let single = [id];
        let owned;
        /* Wide-directory probes need no allocated ancestry for a direct display root. */
        let direct = source.node(id).is_some_and(|node| {
            (state.display.show_hidden || state.display.selected_only || !node.data.hidden)
                && (roots.contains_key(&id)
                    || node
                        .parent
                        .is_some_and(|parent| state.root == Root::ChildrenOf(parent)))
        });
        if let Some(rank) = direct_rank.filter(|_| direct) {
            /* A source-ordered directory page compares sibling positions, not full paths. */
            let current = ranks.position(source, id);
            if current < rank || after && current == rank {
                left = middle + 1;
            } else {
                right = middle;
            }
            continue;
        }
        let current = if direct {
            single.as_slice()
        } else {
            owned = source_path(source, state, roots, id)?
                .ok_or_else(|| Error::invalid("surviving row is outside the display scope"))?;
            &owned
        };
        if compare_paths(source, state, roots, current, path, ranks).is_lt()
            || (after && current.starts_with(path))
        {
            left = middle + 1;
        } else {
            right = middle;
        }
    }
    Ok(left)
}

struct MembershipUpdate {
    children: MatchedChildren,
    changed: HashSet<NodeId>,
    needed: Vec<NodeId>,
    visited: usize,
}

struct Subtree {
    id: NodeId,
    parent: Option<NodeId>,
    depth: usize,
    last: bool,
    descend: bool,
}

fn normalize_targets(
    source: &Source,
    targets: &HashSet<NodeId>,
    node_only: &HashSet<NodeId>,
) -> Result<Vec<NodeId>> {
    let subtrees: Vec<_> = targets
        .iter()
        .copied()
        .filter(|id| source.contains(*id) && !node_only.contains(id))
        .collect();
    let mut normalized = State::normalize(source, &subtrees, Scope::Subtree)?;
    let roots: HashSet<_> = normalized.iter().copied().collect();
    let singles: Vec<_> = targets
        .iter()
        .copied()
        .filter(|id| {
            if !source.contains(*id) || !node_only.contains(id) {
                return false;
            }
            let mut current = Some(*id);
            while let Some(id) = current {
                if roots.contains(&id) {
                    return false;
                }
                current = source.node(id).and_then(|node| node.parent);
            }
            true
        })
        .collect();
    normalized.extend(singles);
    Ok(normalized)
}

fn update_membership(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    dirty: &Invalidation,
    roots: &HashMap<NodeId, usize>,
) -> Result<MembershipUpdate> {
    let mut matched = previous.matched_children.clone();
    if state.display.pattern.is_empty() && !state.display.selected_only {
        return Ok(MembershipUpdate {
            children: matched,
            changed: HashSet::new(),
            needed: Vec::new(),
            visited: 0,
        });
    }
    let mut affected: HashSet<_> = dirty
        .selected
        .iter()
        .copied()
        .chain(
            dirty
                .changes
                .iter()
                .filter(|change| change.kind != ChangeKind::Loading)
                .filter_map(|change| change.node),
        )
        .collect();
    for id in affected.clone() {
        for &root in roots.keys() {
            if source.is_ancestor(id, root) || previous.source.is_ancestor(id, root) {
                affected.insert(root);
            }
        }
    }
    for change in &dirty.changes {
        for id in change.removed.iter() {
            matched.remove(id);
        }
    }
    let mut rebuild = HashSet::new();
    let mut work = 0;
    for id in affected.clone() {
        let Some(node) = source.node(id) else {
            continue;
        };
        if source_path(source, state, roots, id)?.is_none() {
            continue;
        }
        let old_scope = source_path(&previous.source, &previous.state, roots, id)?.is_some();
        let inherited_changed = state.display.selected_only
            && (!previous.source.contains(id)
                || state.selection.inherited(source, id)?
                    != previous.state.selection.inherited(&previous.source, id)?);
        if node.data.can_expand
            && (!old_scope || previous.matched_children.get(&id).is_none() || inherited_changed)
        {
            let mut pending = vec![id];
            while let Some(current) = pending.pop() {
                let node = source.node(current).expect("source subtree");
                if !state.display.show_hidden && !state.display.selected_only && node.data.hidden {
                    continue;
                }
                affected.insert(current);
                rebuild.insert(current);
                pending.extend(node.children());
                work += 1;
            }
        }
    }
    for (tree, view) in [(source, state), (&*previous.source, &previous.state)] {
        let mut seen = HashSet::new();
        for id in affected.clone() {
            if source_path(tree, view, roots, id)?.is_none() {
                continue;
            }
            let mut current = Some(id);
            while let Some(id) = current {
                if view.root == Root::ChildrenOf(id) || !seen.insert(id) {
                    break;
                }
                affected.insert(id);
                if roots.contains_key(&id) {
                    break;
                }
                current = tree.node(id).and_then(|node| node.parent);
            }
        }
    }
    let mut children = HashMap::<NodeId, HashSet<NodeId>>::new();
    for &id in &affected {
        for tree in [source, &*previous.source] {
            if let Some(parent) = tree.node(id).and_then(|node| node.parent) {
                children.entry(parent).or_default().insert(id);
            }
        }
    }
    let mut ordered = Vec::new();
    for &id in &affected {
        if let Some(path) = source_path(source, state, roots, id)? {
            ordered.push((path, id));
        }
    }
    ordered.sort_unstable_by(|a, b| b.cmp(a));
    let reordered: HashSet<_> = dirty
        .changes
        .iter()
        .filter(|change| change.kind == ChangeKind::Reorder)
        .filter_map(|change| change.node)
        .collect();
    for (_, id) in ordered {
        work += 1;
        let node = source.node(id).expect("affected node");
        if !node.data.can_expand {
            matched.remove(&id);
            continue;
        }
        let mut retained = if let Some(cached) = matched
            .get(&id)
            .filter(|_| !rebuild.contains(&id) && !reordered.contains(&id))
        {
            let mut retained = cached.clone();
            let mut incoming = Vec::new();
            for &child in children.get(&id).into_iter().flatten() {
                let include = source
                    .node(child)
                    .is_some_and(|child| child.parent == Some(id))
                    && member(source, state, previous, &matched, child, true)?;
                if retained.position(&child).is_some() == include
                    && previous
                        .source
                        .node(id)
                        .is_some_and(|old| old.children.same_version(&node.children))
                {
                    continue;
                }
                if let Some(at) = retained.position(&child) {
                    retained.splice(at, at + 1, Vec::new())?;
                }
                if include {
                    incoming.push(child);
                }
            }
            for child in incoming {
                let order = node.children.position(&child).expect("source child rank");
                let (mut left, mut right) = (0, retained.len());
                while left < right {
                    let middle = left + (right - left) / 2;
                    let sibling = retained.get(middle).expect("matched child rank");
                    if node
                        .children
                        .position(sibling)
                        .expect("surviving child rank")
                        < order
                    {
                        left = middle + 1;
                    } else {
                        right = middle;
                    }
                }
                retained.splice(left, left, vec![child])?;
            }
            retained
        } else {
            let mut retained = Vec::new();
            for child in node.children() {
                work += 1;
                if member(source, state, previous, &matched, child, true)? {
                    retained.push(child);
                }
            }
            IndexedSequence::from_vec(retained)?
        };
        if let Some(cached) = previous.matched_children.get(&id)
            && cached.same_content(&retained)
        {
            retained = cached.clone();
        }
        matched.insert(id, retained);
    }
    let mut changed = HashSet::new();
    let mut needed = Vec::new();
    for id in affected {
        let old = source_path(&previous.source, &previous.state, roots, id)?.is_some()
            && visible(
                &previous.source,
                &previous.state,
                previous,
                &previous.matched_children,
                id,
            )?;
        let new = source_path(source, state, roots, id)?.is_some()
            && visible(source, state, previous, &matched, id)?;
        if old != new {
            changed.insert(id);
        }
        if state.display.mode == Mode::List
            && source_path(source, state, roots, id)?.is_some()
            && source.node(id).is_some_and(|node| {
                node.data.can_expand && node.completeness != Completeness::Complete
            })
        {
            needed.push(id);
        }
    }
    Ok(MembershipUpdate {
        children: matched,
        changed,
        needed,
        visited: work,
    })
}

fn subtree(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    matched: &MatchedChildren,
    target: Subtree,
) -> Result<(Vec<Row>, Vec<NodeId>, usize)> {
    let Subtree {
        id: root,
        parent,
        depth,
        last: connector_last,
        descend,
    } = target;
    struct Walk {
        id: NodeId,
        parent: Option<usize>,
        depth: usize,
        inherited: u32,
        selected: u32,
        last: bool,
        exit: bool,
    }
    let inherited = state.expansion.inherited(source, root)?;
    let selected = state.selection.inherited(source, root)?;
    let tree = state.display.mode == Mode::Tree;
    let mut work = vec![Walk {
        id: root,
        parent: None,
        depth,
        inherited,
        selected,
        last: connector_last,
        exit: false,
    }];
    let mut rows = Vec::<Row>::new();
    let mut needed = Vec::new();
    let mut visited = 0;
    while let Some(walk) = work.pop() {
        if walk.exit {
            rows[walk.parent.expect("exiting row")].last_descendant =
                rows.last().expect("subtree row").id;
            continue;
        }
        let mut id = walk.id;
        let mut inherited = walk.inherited.max(state.expansion.marks(id).subtree);
        let mut selected = walk.selected.max(state.selection.marks(id).subtree);
        let mut chain = Vec::new();
        visited += 1;
        if tree && state.display.compress {
            loop {
                let node = source.node(id).ok_or_else(|| Error::missing(id))?;
                if !node.data.can_expand
                    || !node.data.foldable
                    || node.child_count() != 1
                    || inherited.max(state.expansion.marks(id).own) & 1 == 0
                {
                    break;
                }
                let child = node.child_at(0).expect("single child");
                let child_node = source.node(child).expect("source child");
                let child_selected = selected.max(state.selection.marks(child).subtree);
                if !child_node.data.can_expand
                    || !child_node.data.foldable
                    || !visible(source, state, previous, matched, child)?
                    || selection_kind(source, state, id, selected)?
                        != selection_kind(source, state, child, child_selected)?
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
                inherited = inherited.max(state.expansion.marks(id).subtree);
                selected = child_selected;
                visited += 1;
            }
        }
        let node = source.node(id).ok_or_else(|| Error::missing(id))?;
        let parent_id = walk.parent.map(|index| rows[index].id).or(parent);
        let index = if tree || visible(source, state, previous, matched, id)? {
            let index = rows.len();
            if let Some(parent) = walk.parent.filter(|_| tree) {
                rows[parent].last_child = Some(id);
            }
            rows.push(Row {
                id,
                label: node.data.label.clone(),
                text: None,
                chain: (!chain.is_empty()).then(|| chain.into()),
                depth: if tree { walk.depth } else { 0 },
                parent: if tree { parent_id } else { None },
                source_ancestor: parent_id,
                last_child: None,
                last_descendant: id,
                connector_last: !tree || walk.last,
            });
            Some(index)
        } else {
            walk.parent
        };
        if !node.data.can_expand || (tree && inherited.max(state.expansion.marks(id).own) & 1 == 0)
        {
            continue;
        }
        if node.completeness != Completeness::Complete {
            needed.push(id);
        }
        if !descend {
            continue;
        }
        let children = if state.display.selected_only || !state.display.pattern.is_empty() {
            matched
                .get(&id)
                .map_or_else(Vec::new, |children| children.iter().copied().collect())
        } else {
            let mut children = Vec::new();
            for child in node.children() {
                if visible(source, state, previous, matched, child)? {
                    children.push(child);
                }
            }
            children
        };
        let children = if tree {
            sorted(source, children, &state.display)
        } else {
            children
        };
        if tree {
            work.push(Walk {
                id: walk.id,
                parent: index,
                depth: walk.depth,
                inherited,
                selected,
                last: true,
                exit: true,
            });
        }
        for (at, id) in children.iter().copied().enumerate().rev() {
            work.push(Walk {
                id,
                parent: index,
                depth: walk.depth + 1,
                inherited,
                selected,
                last: if state.display.selected_only {
                    node.child_at(node.child_count().saturating_sub(1)) == Some(id)
                } else {
                    at + 1 == children.len()
                },
                exit: false,
            });
        }
    }
    Ok((rows, needed, visited))
}

fn update_row(rows: &mut IndexedSequence<Row>, row: Row) -> Result<()> {
    let Some(at) = rows.position(&row.id) else {
        return Ok(());
    };
    if rows.get(at) != Some(&row) {
        rows.splice(at, at + 1, vec![row])?;
    }
    Ok(())
}

fn boundaries(
    source: &Source,
    state: &State,
    roots: &HashMap<NodeId, usize>,
    rows: &mut IndexedSequence<Row>,
    affected: &HashSet<NodeId>,
    ranks: &mut Ranks,
) -> Result<()> {
    if state.display.mode == Mode::List {
        return Ok(());
    }
    let mut parents: Vec<_> = affected
        .iter()
        .filter_map(|id| rows.lookup(*id).map(|row| (row.depth, row.id)))
        .collect();
    parents.sort_unstable_by(|a, b| b.cmp(a));
    parents.dedup();
    for (_, id) in parents {
        let mut row = rows.lookup(id).expect("surviving boundary").clone();
        let old_last = row.last_child;
        let path =
            source_path(source, state, roots, row.folded_ids()[0])?.expect("visible parent path");
        let end = boundary_at(source, state, roots, rows, &path, true, ranks)?;
        let descendant = rows.get(end - 1).expect("visible parent range");
        let mut last = (descendant.id != id).then_some(descendant.id);
        while let Some(child) = last {
            let parent = rows.lookup(child).expect("visible child").parent;
            if parent == Some(id) {
                break;
            }
            last = parent;
        }
        row.last_child = last;
        row.last_descendant = descendant.id;
        update_row(rows, row)?;
        for child in [old_last, last].into_iter().flatten() {
            if let Some(mut child) = rows
                .lookup(child)
                .cloned()
                .filter(|row| row.parent == Some(id))
            {
                child.connector_last = if state.display.selected_only {
                    let siblings = source.child_sequence(Some(id))?;
                    siblings.get(siblings.len().saturating_sub(1)) == child.folded_ids().first()
                } else {
                    last == Some(child.id)
                };
                update_row(rows, child)?;
            }
        }
    }
    Ok(())
}

fn compression_targets(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    targets: &mut HashSet<NodeId>,
    boundary: &HashSet<NodeId>,
) {
    if state.display.mode != Mode::Tree || !state.display.compress {
        return;
    }
    let roots: HashSet<_> = match state.root {
        Root::Forest(_) => state.display_roots(source).into_iter().collect(),
        _ => HashSet::new(),
    };
    let can_join = |tree: &Source, id| {
        tree.node(id).is_some_and(|node| {
            node.data.can_expand && node.data.foldable && node.child_count() == 1
        })
    };
    /* A child insertion/removal can split or join its parent's old row, including
    when that parent is only an alias inside a longer compressed chain. */
    for &id in boundary {
        if state.root != Root::ChildrenOf(id)
            && previous.position(id).is_some()
            && (can_join(source, id) || can_join(&previous.source, id))
        {
            targets.insert(id);
        }
    }
    let mut pending: Vec<_> = targets.iter().copied().collect();
    while let Some(id) = pending.pop() {
        if let Some(head) = previous
            .rows
            .lookup(id)
            .and_then(|row| row.folded_ids().first())
            .copied()
            && targets.insert(head)
        {
            pending.push(head);
        }
        if roots.contains(&id) {
            continue;
        }
        for tree in [source, &*previous.source] {
            if let Some(parent) = tree.node(id).and_then(|node| node.parent)
                && state.root != Root::ChildrenOf(parent)
                && previous.position(parent).is_some()
                && can_join(tree, parent)
                && targets.insert(parent)
            {
                pending.push(parent);
            }
        }
    }
}

pub(crate) fn project(
    source: &Source,
    state: &State,
    previous: &Snapshot,
    dirty: &Invalidation,
) -> Result<Option<LayoutUpdate>> {
    if state.display != previous.state.display
        || state.root != previous.state.root
        || dirty.full
        || matches!(&state.root, Root::ChildrenOf(id) if dirty.expanded.iter().chain(&dirty.selected).any(|node| source.within(*node, *id)))
        || (dirty.changes.is_empty() && dirty.expanded.is_empty() && dirty.selected.is_empty())
    {
        return Ok(None);
    }
    if matches!(state.root, Root::Forest(_))
        && state.display_roots(source) != previous.state.display_roots(&previous.source)
    {
        return Ok(None);
    }
    if let Root::ChildrenOf(root) = state.root
        && (!source.contains(root)
            || dirty.changes.iter().any(|change| {
                change.kind == ChangeKind::Reparent
                    && change.node.is_some_and(|id| {
                        source.within(id, root) || previous.source.within(id, root)
                    })
            }))
    {
        return Ok(None);
    }
    let roots = match &state.root {
        Root::Forest(_) => state.display_roots(source),
        _ => Vec::new(),
    };
    let root_order: HashMap<_, _> = roots
        .iter()
        .copied()
        .enumerate()
        .map(|(at, id)| (id, at))
        .collect();
    let MembershipUpdate {
        children: matched_children,
        changed: membership_changed,
        needed: new_reads,
        visited: match_work,
    } = update_membership(source, state, previous, dirty, &root_order)?;
    let matched = &matched_children;
    let mut node_only = HashSet::new();
    if state.display.mode == Mode::List {
        let subtrees: HashSet<_> = dirty
            .changes
            .iter()
            .filter(|change| change.kind != ChangeKind::Update)
            .filter_map(|change| change.node)
            .collect();
        for change in &dirty.changes {
            let Some(id) = change.node else { continue };
            if change.kind != ChangeKind::Update
                || membership_changed.contains(&id)
                || dirty.selected.contains(&id)
                || dirty.expanded.contains(&id)
                || subtrees.contains(&id)
            {
                continue;
            }
            if previous
                .source
                .node(id)
                .zip(source.node(id))
                .is_some_and(|(old, new)| old.data.hidden == new.data.hidden)
            {
                node_only.insert(id);
            }
        }
    }
    let mut targets = dirty.expanded.clone();
    targets.extend(&dirty.selected);
    targets.extend(&membership_changed);
    for change in &dirty.changes {
        if change.kind == ChangeKind::Loading {
            continue;
        }
        let Some(id) = change.node else {
            return Ok(None);
        };
        if state.root == Root::ChildrenOf(id) {
            if matches!(change.kind, ChangeKind::Update | ChangeKind::Completeness) {
                continue;
            }
            return Ok(None);
        }
        targets.insert(id);
    }
    for id in targets.clone() {
        for &root in &roots {
            if source.is_ancestor(id, root) || previous.source.is_ancestor(id, root) {
                targets.insert(root);
            }
        }
    }
    for id in targets.clone() {
        if source_path(source, state, &root_order, id)?.is_none()
            && source_path(&previous.source, &previous.state, &root_order, id)?.is_none()
        {
            targets.remove(&id);
        }
    }
    let mut boundary = HashSet::new();
    for tree in [source, &*previous.source] {
        let mut seen = HashSet::new();
        for &id in &targets {
            let mut current = tree.node(id).and_then(|node| node.parent);
            while let Some(parent) = current {
                if !seen.insert(parent) {
                    break;
                }
                boundary.insert(parent);
                current = tree.node(parent).and_then(|node| node.parent);
            }
        }
    }
    compression_targets(source, state, previous, &mut targets, &boundary);
    let mut removals = Vec::new();
    let mut old_ranks = Ranks::default();
    let mut ranks = Ranks::default();
    for id in normalize_targets(&previous.source, &targets, &node_only)? {
        if let Some(path) = source_path(&previous.source, &previous.state, &root_order, id)? {
            if node_only.contains(&id) {
                if let Some(at) = previous.position(id) {
                    removals.push((at, at + 1));
                }
            } else if sorted_list(state) {
                let mut pending = vec![id];
                while let Some(id) = pending.pop() {
                    let node = previous.source.node(id).expect("old subtree");
                    if !state.display.show_hidden
                        && !state.display.selected_only
                        && node.data.hidden
                    {
                        continue;
                    }
                    if let Some(at) = previous.position(id) {
                        removals.push((at, at + 1));
                    }
                    if state.display.selected_only || !state.display.pattern.is_empty() {
                        if let Some(children) = previous.matched_children.get(&id) {
                            pending.extend(children.iter().copied());
                        }
                    } else {
                        pending.extend(node.children());
                    }
                }
            } else {
                let start = boundary_at(
                    &previous.source,
                    &previous.state,
                    &root_order,
                    &previous.rows,
                    &path,
                    false,
                    &mut old_ranks,
                )?;
                let end = boundary_at(
                    &previous.source,
                    &previous.state,
                    &root_order,
                    &previous.rows,
                    &path,
                    true,
                    &mut old_ranks,
                )?;
                if start != end {
                    removals.push((start, end));
                }
            }
        }
    }
    removals.sort_unstable();
    let mut rows = previous.rows.clone();
    let mut visited = match_work;
    for (start, end) in removals.into_iter().rev() {
        rows.splice(start, end, Vec::new())?;
    }
    boundaries(source, state, &root_order, &mut rows, &boundary, &mut ranks)?;
    let mut incoming = Vec::new();
    for id in normalize_targets(source, &targets, &node_only)? {
        if let Some(path) = visible_path(source, state, previous, matched, &root_order, id)? {
            incoming.push((path, id));
        }
    }
    incoming
        .sort_unstable_by(|a, b| compare_paths(source, state, &root_order, &a.0, &b.0, &mut ranks));
    let mut needed = HashSet::new();
    for &id in previous.needed_children.iter() {
        if !source
            .node(id)
            .is_some_and(|node| node.data.can_expand && node.completeness != Completeness::Complete)
        {
            continue;
        }
        if state.root == Root::ChildrenOf(id)
            || (state.display.mode == Mode::List
                && source_path(source, state, &root_order, id)?.is_some())
            || (rows.position(&id).is_some() && state.expanded(source, id)?)
        {
            needed.insert(id);
        }
    }
    needed.extend(new_reads);
    if let Root::ChildrenOf(id) = state.root
        && source
            .node(id)
            .is_some_and(|node| node.data.can_expand && node.completeness != Completeness::Complete)
    {
        needed.insert(id);
    }
    /* Independent display roots can be inserted into gaps in the unchanged base.
     * Coalesce each gap so a directory page does not reindex one row at a time. */
    let batch_roots = !sorted_list(state) && incoming.iter().all(|(path, _)| path.len() == 1);
    let mut root_segments: Vec<(usize, Vec<Row>)> = Vec::new();
    let mut text =
        (state.display.mode == Mode::List && state.display.list_text == ListText::Ancestry).then(
            || super::text::Builder::new(source, &state.root, &previous.text_roots, Some(previous)),
        );
    for (path, id) in incoming {
        let mut parent = None;
        if path.len() > 1 {
            let mut current = source.node(id).and_then(|node| node.parent);
            for _ in 1..path.len() {
                let Some(id) = current else { break };
                if state.display.mode == Mode::List
                    && visible(source, state, previous, matched, id)?
                {
                    parent = Some(id);
                    break;
                }
                if let Some(row) = rows.lookup(id) {
                    parent = Some(row.id);
                    break;
                }
                current = source.node(id).and_then(|node| node.parent);
            }
        }
        let depth = parent
            .and_then(|id| rows.lookup(id))
            .map_or(0, |row| row.depth + 1);
        let at = boundary_at(source, state, &root_order, &rows, &path, false, &mut ranks)?;
        let last = if state.display.selected_only {
            if path.len() == 1 && matches!(state.root, Root::Forest(_)) {
                roots.last() == Some(&id)
            } else {
                let siblings =
                    source.child_sequence(source.node(id).expect("visible node").parent)?;
                siblings.get(siblings.len().saturating_sub(1)) == Some(&id)
            }
        } else {
            false
        };
        let (mut segment, requests, count) = subtree(
            source,
            state,
            previous,
            matched,
            Subtree {
                id,
                parent,
                depth,
                last,
                descend: !node_only.contains(&id),
            },
        )?;
        visited += count;
        needed.extend(requests);
        if let Some(text) = &mut text {
            for row in &mut segment {
                row.text = Some(text.text(source.node(row.id).expect("projected node"))?);
            }
        }
        if sorted_list(state) {
            for row in segment {
                let path =
                    source_path(source, state, &root_order, row.id)?.expect("visible list path");
                let at = boundary_at(source, state, &root_order, &rows, &path, false, &mut ranks)?;
                rows.splice(at, at, vec![row])?;
            }
        } else if batch_roots {
            if let Some((_, rows)) = root_segments
                .last_mut()
                .filter(|(previous_at, _)| *previous_at == at)
            {
                rows.extend(segment);
            } else {
                root_segments.push((at, segment));
            }
        } else {
            rows.splice(at, at, segment)?;
        }
        if let Some(parent) = parent {
            boundary.insert(parent);
        }
        if !batch_roots {
            boundaries(source, state, &root_order, &mut rows, &boundary, &mut ranks)?;
        }
    }
    if batch_roots {
        rows.splice_many(
            root_segments
                .into_iter()
                .map(|(at, segment)| (at, at, segment))
                .collect(),
        )?;
        boundaries(source, state, &root_order, &mut rows, &boundary, &mut ranks)?;
    }
    let mut last_root = rows.get(rows.len().saturating_sub(1)).map(|row| row.id);
    if state.display.mode == Mode::Tree {
        while let Some(parent) = last_root
            .and_then(|id| rows.lookup(id))
            .and_then(|row| row.parent)
        {
            last_root = Some(parent);
        }
    }
    for id in [previous.last_root, last_root].into_iter().flatten() {
        if let Some(mut row) = rows
            .lookup(id)
            .cloned()
            .filter(|row| state.display.mode == Mode::Tree && row.parent.is_none())
        {
            row.connector_last = if state.display.selected_only {
                let outer = row.folded_ids()[0];
                if matches!(state.root, Root::Forest(_)) {
                    roots.last() == Some(&outer)
                } else {
                    let siblings =
                        source.child_sequence(source.node(outer).and_then(|node| node.parent))?;
                    siblings.get(siblings.len().saturating_sub(1)) == Some(&outer)
                }
            } else {
                last_root == Some(row.id)
            };
            update_row(&mut rows, row)?;
        }
    }
    let same_content = previous.rows.same_content(&rows);
    let same = same_content || previous.rows.same_content_by(&rows, Row::same_layout);
    if same_content {
        rows = previous.rows.clone();
    }
    Ok(Some(LayoutUpdate {
        rows,
        last_root,
        needed: needed.into_iter().collect(),
        visited: visited + boundary.len(),
        same,
        matched_children,
    }))
}
