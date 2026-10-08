use super::data::{Change, ChangeKind, Node, Source};
use super::model::*;
use super::storage::{Map, SequenceIter};

const FOREST: NodeId = NodeId(0);
const MAX_GENERATION: u32 = u32::MAX / 2;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub(crate) struct Marks {
    pub subtree: u32,
    pub own: u32,
}

#[derive(Clone, Default)]
pub(crate) struct Stamps {
    pub generation: u32,
    pub clear: u32,
    pub nodes: Map<NodeId, Marks>,
    maxima: Map<NodeId, u32>,
    child_maxima: Map<NodeId, Map<(u32, NodeId), ()>>,
}

impl Stamps {
    pub fn marks(&self, node: NodeId) -> Marks {
        self.nodes.get(&node).copied().unwrap_or_default()
    }

    pub fn maximum(&self, node: NodeId) -> u32 {
        self.maxima.get(&node).copied().unwrap_or(0)
    }

    pub fn is_clear(&self) -> bool {
        self.clear >= self.maximum(FOREST)
    }

    pub fn inherited(&self, source: &Source, node: NodeId) -> Result<u32> {
        let mut value = self.clear;
        let mut current = Some(node);
        while let Some(id) = current {
            let node = source.node(id).ok_or_else(|| Error::missing(id))?;
            value = value.max(self.marks(id).subtree);
            current = node.parent;
        }
        Ok(value)
    }

    pub fn value(&self, source: &Source, node: NodeId) -> Result<bool> {
        Ok(self.inherited(source, node)?.max(self.marks(node).own) & 1 != 0)
    }

    pub fn changes_value(
        &self,
        source: &Source,
        node: NodeId,
        value: bool,
        scope: Scope,
    ) -> Result<bool> {
        let inherited = self.inherited(source, node)?;
        let current = inherited.max(self.marks(node).own) & 1 != 0;
        Ok(current != value
            || (scope == Scope::Subtree
                && (inherited & 1 != u32::from(value) || self.maximum(node) > inherited)))
    }

    fn next_generation(&self) -> Result<u32> {
        self.generation
            .checked_add(1)
            .filter(|generation| *generation <= MAX_GENERATION)
            .ok_or_else(|| Error::limit("stamp generation exhausted"))
    }

    pub fn assign(
        &mut self,
        source: &Source,
        targets: &[(NodeId, bool)],
        scope: Scope,
    ) -> Result<bool> {
        for (id, _) in targets {
            if !source.contains(*id) {
                return Err(Error::missing(*id));
            }
        }
        if targets.is_empty() {
            return Ok(false);
        }
        let generation = self.next_generation()?;
        for &(id, value) in targets {
            let stamp = generation * 2 + u32::from(value);
            let mut marks = self.marks(id);
            match scope {
                Scope::SelfOnly => marks.own = stamp,
                Scope::Subtree => marks.subtree = stamp,
            }
            self.nodes.insert(id, marks);
            self.refresh(source, id)?;
        }
        self.generation = generation;
        Ok(true)
    }

    pub fn clear_all(&mut self) -> Result<()> {
        let generation = self.next_generation()?;
        self.clear = generation * 2;
        self.generation = generation;
        Ok(())
    }

    pub fn preserve_inherited(&mut self, source: &Source, node: NodeId) -> Result<()> {
        let inherited = self.inherited(source, node)?;
        let mut marks = self.marks(node);
        if marks.subtree != inherited {
            marks.subtree = inherited;
            self.nodes.insert(node, marks);
            self.refresh(source, node)?;
        }
        Ok(())
    }

    fn update_child(&mut self, parent: NodeId, child: NodeId, old: u32, new: u32) {
        let mut children = self.child_maxima.get(&parent).cloned().unwrap_or_default();
        if old != 0 {
            children.remove(&(old, child));
        }
        if new != 0 {
            children.insert((new, child), ());
        }
        if children.is_empty() {
            self.child_maxima.remove(&parent);
        } else {
            self.child_maxima.insert(parent, children);
        }
    }

    fn refresh(&mut self, source: &Source, mut current: NodeId) -> Result<()> {
        loop {
            let old = self.maximum(current);
            let marks = self.marks(current);
            let child_maximum = self
                .child_maxima
                .get(&current)
                .and_then(Map::last)
                .map_or(0, |((stamp, _), _)| *stamp);
            let new = marks.subtree.max(marks.own).max(child_maximum);
            if old == new {
                return Ok(());
            }
            if new == 0 {
                self.maxima.remove(&current);
            } else {
                self.maxima.insert(current, new);
            }
            if current == FOREST {
                return Ok(());
            }
            let parent = source
                .node(current)
                .ok_or_else(|| Error::missing(current))?
                .parent
                .unwrap_or(FOREST);
            self.update_child(parent, current, old, new);
            current = parent;
        }
    }

    pub fn changed_source(&mut self, source: &Source, change: &Change) -> Result<()> {
        match change.kind {
            ChangeKind::Reparent if change.old_parent != change.new_parent => {
                let node = change.node.expect("reparent node");
                let maximum = self.maximum(node);
                let old_parent = change.old_parent.unwrap_or(FOREST);
                let new_parent = change.new_parent.unwrap_or(FOREST);
                self.update_child(old_parent, node, maximum, 0);
                self.update_child(new_parent, node, 0, maximum);
                self.refresh(source, old_parent)?;
                self.refresh(source, new_parent)?;
            }
            ChangeKind::Remove => {
                let node = change.node.expect("removed root");
                let maximum = self.maximum(node);
                let parent = change.old_parent.unwrap_or(FOREST);
                self.update_child(parent, node, maximum, 0);
                for id in change.removed.iter() {
                    self.nodes.remove(id);
                    self.maxima.remove(id);
                    self.child_maxima.remove(id);
                }
                self.refresh(source, parent)?;
            }
            _ => {}
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Summary {
    pub full: bool,
    pub known_roots: usize,
    pub known_self_only: usize,
    pub pending: bool,
}

impl Summary {
    pub fn is_empty(self) -> bool {
        self.known_roots == 0 && self.known_self_only == 0 && !self.pending
    }

    pub fn is_nonempty(self) -> bool {
        self.known_roots != 0 || self.known_self_only != 0
    }

    fn merge(&mut self, child: Self) {
        self.known_roots += child.known_roots;
        self.known_self_only += child.known_self_only;
        self.pending |= child.pending;
    }
}

#[derive(Clone, Copy, Eq, PartialEq)]
struct CacheKey {
    structure: Revision,
    maximum: u32,
    inherited: u32,
}

#[derive(Clone, Copy)]
pub(crate) struct NodeSummary {
    pub summary: Summary,
    pub needs_children: bool,
}

#[derive(Clone, Default)]
pub(crate) struct SummaryCache {
    entries: Map<NodeId, (CacheKey, NodeSummary)>,
}

struct Pending<'a> {
    node: &'a Node,
    key: CacheKey,
    children: SequenceIter<'a, NodeId>,
    inherited: u32,
    marked: bool,
    all_full: bool,
    aggregate: Summary,
}

impl SummaryCache {
    pub fn forget(&mut self, nodes: &[NodeId]) {
        for id in nodes {
            self.entries.remove(id);
        }
    }

    fn cached(&self, node: &Node, stamps: &Stamps, parent: u32) -> (CacheKey, Option<NodeSummary>) {
        let inherited = parent.max(stamps.marks(node.id).subtree);
        let maximum = stamps.maximum(node.id);
        let key = CacheKey {
            structure: node.subtree_revision,
            maximum,
            inherited,
        };
        if inherited >= maximum {
            let full = inherited & 1 != 0;
            return (
                key,
                Some(NodeSummary {
                    summary: Summary {
                        full,
                        known_roots: usize::from(full),
                        ..Summary::default()
                    },
                    needs_children: false,
                }),
            );
        }
        (
            key,
            self.entries
                .get(&node.id)
                .and_then(|(cached_key, summary)| (*cached_key == key).then_some(*summary)),
        )
    }

    pub fn lookup(
        &self,
        source: &Source,
        stamps: &Stamps,
        node: NodeId,
        parent: u32,
    ) -> Result<Option<NodeSummary>> {
        let node = source.node(node).ok_or_else(|| Error::missing(node))?;
        Ok(self.cached(node, stamps, parent).1)
    }

    pub fn node(
        &mut self,
        source: &Source,
        stamps: &Stamps,
        id: NodeId,
        parent: u32,
    ) -> Result<NodeSummary> {
        fn pending<'a>(node: &'a Node, stamps: &Stamps, key: CacheKey) -> Pending<'a> {
            Pending {
                node,
                key,
                children: node.children.iter(),
                inherited: key.inherited,
                marked: key.inherited.max(stamps.marks(node.id).own) & 1 != 0,
                all_full: true,
                aggregate: Summary::default(),
            }
        }
        let node = source.node(id).ok_or_else(|| Error::missing(id))?;
        let (key, cached) = self.cached(node, stamps, parent);
        if let Some(summary) = cached {
            return Ok(summary);
        }
        let mut stack = vec![pending(node, stamps, key)];
        loop {
            let frame = stack.last_mut().expect("pending summary");
            if let Some(&child) = frame.children.next() {
                let child = source.node(child).ok_or_else(|| Error::missing(child))?;
                let (key, summary) = self.cached(child, stamps, frame.inherited);
                if let Some(summary) = summary {
                    frame.all_full &= summary.summary.full;
                    frame.aggregate.merge(summary.summary);
                } else {
                    stack.push(pending(child, stamps, key));
                }
                continue;
            }
            let frame = stack.pop().expect("finished summary");
            let complete = frame.node.completeness == Completeness::Complete;
            let inherited_true = frame.inherited & 1 != 0;
            let full = frame.marked && frame.all_full && (complete || inherited_true);
            let result = if full {
                NodeSummary {
                    summary: Summary {
                        full: true,
                        known_roots: 1,
                        ..Summary::default()
                    },
                    needs_children: false,
                }
            } else {
                let direct_pending =
                    !complete && (inherited_true || (frame.marked && frame.all_full));
                let mut summary = frame.aggregate;
                summary.known_self_only += usize::from(frame.marked);
                summary.pending |= direct_pending;
                NodeSummary {
                    summary,
                    needs_children: direct_pending,
                }
            };
            self.entries.insert(frame.node.id, (frame.key, result));
            if let Some(parent) = stack.last_mut() {
                parent.all_full &= result.summary.full;
                parent.aggregate.merge(result.summary);
            } else {
                return Ok(result);
            }
        }
    }

    pub fn forest(&mut self, source: &Source, stamps: &Stamps) -> Result<Summary> {
        if stamps.is_clear() {
            return Ok(Summary::default());
        }
        let mut result = Summary::default();
        for id in source.roots() {
            result.merge(self.node(source, stamps, id, stamps.clear)?.summary);
        }
        Ok(result)
    }
}

#[cfg(test)]
mod tests {
    use super::super::data::{NodePatch, NodeRef, Operation, Position};
    use super::*;

    fn fixture() -> (Source, NodeId, NodeId, NodeId) {
        let mut source = Source::empty().unwrap();
        for (key, parent, data) in [
            ("p", None, NodeData::branch("p")),
            ("a", Some("p"), NodeData::leaf("a")),
            ("b", Some("p"), NodeData::leaf("b")),
        ] {
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
        let ids = (
            source.id("p").unwrap(),
            source.id("a").unwrap(),
            source.id("b").unwrap(),
        );
        (source, ids.0, ids.1, ids.2)
    }

    #[test]
    fn t_subtree_exclusions_preserve_parent_self_and_recompute_full() {
        let (source, p, a, b) = fixture();
        let mut stamps = Stamps::default();
        let mut cache = SummaryCache::default();
        stamps
            .assign(&source, &[(p, true)], Scope::Subtree)
            .unwrap();
        assert_eq!(cache.forest(&source, &stamps).unwrap().known_roots, 1);
        stamps
            .assign(&source, &[(a, false)], Scope::Subtree)
            .unwrap();
        assert_eq!(
            cache
                .node(&source, &stamps, p, stamps.clear)
                .unwrap()
                .summary,
            Summary {
                full: false,
                known_roots: 1,
                known_self_only: 1,
                pending: false
            }
        );
        stamps
            .assign(&source, &[(b, false)], Scope::Subtree)
            .unwrap();
        assert_eq!(cache.forest(&source, &stamps).unwrap().known_self_only, 1);
        assert!(stamps.value(&source, p).unwrap());
        stamps
            .assign(&source, &[(a, true), (b, true)], Scope::Subtree)
            .unwrap();
        assert!(
            cache
                .node(&source, &stamps, p, stamps.clear)
                .unwrap()
                .summary
                .full
        );
    }

    #[test]
    fn t_self_only_and_unknown_children_have_distinct_coverage() {
        let (mut source, p, a, b) = fixture();
        for id in [a, b] {
            source
                .apply(
                    &Operation::Remove { node: id.into() },
                    Revision(2),
                    &Limits::default(),
                    None,
                )
                .unwrap();
        }
        source
            .apply(
                &Operation::Update {
                    node: p.into(),
                    patch: NodePatch {
                        completeness: Some(Completeness::Unknown),
                        ..NodePatch::default()
                    },
                },
                Revision(3),
                &Limits::default(),
                None,
            )
            .unwrap();
        let mut stamps = Stamps::default();
        let mut cache = SummaryCache::default();
        stamps
            .assign(&source, &[(p, true)], Scope::SelfOnly)
            .unwrap();
        let partial = cache.node(&source, &stamps, p, 0).unwrap();
        assert_eq!(partial.summary.known_self_only, 1);
        assert!(partial.summary.pending && partial.needs_children);
        stamps
            .assign(&source, &[(p, true)], Scope::Subtree)
            .unwrap();
        assert_eq!(
            cache.node(&source, &stamps, p, 0).unwrap().summary,
            Summary {
                full: true,
                known_roots: 1,
                known_self_only: 0,
                pending: false
            }
        );
        stamps
            .assign(&source, &[(p, false)], Scope::SelfOnly)
            .unwrap();
        let partial = cache.node(&source, &stamps, p, 0).unwrap();
        assert!(partial.summary.pending);
        assert_eq!(partial.summary.known_self_only, 0);
    }

    #[test]
    fn t_reparent_preserves_inherited_without_spreading_self_overrides() {
        let (mut source, p, a, _) = fixture();
        source
            .apply(
                &Operation::Insert {
                    key: "q".into(),
                    parent: None,
                    position: Position::Last,
                    data: NodeData::branch("q"),
                    completeness: Completeness::Complete,
                },
                Revision(2),
                &Limits::default(),
                None,
            )
            .unwrap();
        let q = source.id("q").unwrap();
        let mut stamps = Stamps::default();
        stamps
            .assign(&source, &[(p, true)], Scope::Subtree)
            .unwrap();
        stamps
            .assign(&source, &[(a, false)], Scope::SelfOnly)
            .unwrap();
        stamps.preserve_inherited(&source, a).unwrap();
        assert_eq!(stamps.marks(a), Marks { subtree: 3, own: 4 });
        let change = source
            .apply(
                &Operation::Reparent {
                    node: a.into(),
                    parent: Some(q.into()),
                    position: Position::Last,
                },
                Revision(3),
                &Limits::default(),
                None,
            )
            .unwrap();
        stamps.changed_source(&source, &change).unwrap();
        assert!(!stamps.value(&source, a).unwrap());
        assert_eq!(stamps.generation, 2);
        assert_eq!(stamps.maximum(q), 4);
        let removed = source
            .apply(
                &Operation::Remove { node: a.into() },
                Revision(4),
                &Limits::default(),
                None,
            )
            .unwrap();
        stamps.changed_source(&source, &removed).unwrap();
        assert_eq!(stamps.maximum(q), 0);
        assert_eq!(stamps.maximum(p), 3);
    }

    #[test]
    fn t_same_value_assignments_refresh_intent_and_overflow_does_not_write() {
        let (source, p, _, _) = fixture();
        let mut stamps = Stamps::default();
        stamps
            .assign(&source, &[(p, true)], Scope::Subtree)
            .unwrap();
        stamps
            .assign(&source, &[(p, true)], Scope::Subtree)
            .unwrap();
        assert_eq!(stamps.marks(p).subtree, 5);
        let before = stamps.nodes.clone();
        stamps.generation = MAX_GENERATION;
        assert!(
            stamps
                .assign(&source, &[(p, false)], Scope::Subtree)
                .is_err()
        );
        assert!(before.same_version(&stamps.nodes));
        assert!(!stamps.assign(&source, &[], Scope::SelfOnly).unwrap());
    }

    #[test]
    fn t_lazy_marks_match_eager_values_for_interleaved_scopes() {
        let (source, p, a, b) = fixture();
        let ids = [p, a, b];
        let mut expected = [false; 3];
        let mut stamps = Stamps::default();
        let mut cache = SummaryCache::default();
        let mut seed = 37u64;
        for _ in 0..1000 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let target = (seed >> 32) as usize % ids.len();
            let subtree = seed & 1 == 0;
            let value = seed & 2 == 0;
            if seed & 31 == 31 {
                stamps.clear_all().unwrap();
                expected.fill(false);
            } else {
                stamps
                    .assign(
                        &source,
                        &[(ids[target], value)],
                        if subtree {
                            Scope::Subtree
                        } else {
                            Scope::SelfOnly
                        },
                    )
                    .unwrap();
                expected[target] = value;
                if subtree && target == 0 {
                    expected.fill(value);
                }
            }
            assert_eq!(ids.map(|id| stamps.value(&source, id).unwrap()), expected);
            let summary = cache.forest(&source, &stamps).unwrap();
            assert_eq!(summary.is_empty(), !expected.iter().any(|value| *value));
            assert!(!summary.pending);
            assert_eq!(
                cache
                    .node(&source, &stamps, p, stamps.clear)
                    .unwrap()
                    .summary
                    .full,
                expected.iter().all(|value| *value)
            );
        }
    }
}
