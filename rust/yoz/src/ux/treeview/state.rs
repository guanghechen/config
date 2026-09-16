use super::data::{Change, Source};
use super::model::*;
use super::stamps::{Stamps, Summary, SummaryCache};
use super::storage::SequenceIter;
use std::collections::HashSet;
use std::sync::Arc;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SelectAction {
    Select,
    Deselect,
    Toggle,
}

#[derive(Clone, Debug)]
pub struct SelectionSources {
    pub data_revision: Revision,
    pub selection_revision: Revision,
    pub summary: Summary,
    pub subtree_roots: Arc<[NodeId]>,
    pub self_only_nodes: Arc<[NodeId]>,
    pub needed_children: Arc<[NodeId]>,
}

#[derive(Clone)]
pub(crate) struct State {
    pub id: u64,
    pub data_identity: u64,
    pub root: Root,
    pub display: DisplayOptions,
    pub cursor: Option<NodeId>,
    pub revision: Revision,
    pub selection_revision: Revision,
    pub selection: Stamps,
    pub expansion: Stamps,
    pub summaries: SummaryCache,
    pub locked: Option<u64>,
}

impl State {
    pub fn new(source: &Source, root: Root, display: DisplayOptions) -> Result<Self> {
        Self::validate_root(source, &root)?;
        Ok(Self {
            id: identity()?,
            data_identity: source.identity(),
            root,
            display,
            cursor: None,
            revision: Revision::default(),
            selection_revision: Revision::default(),
            selection: Stamps::default(),
            expansion: Stamps::default(),
            summaries: SummaryCache::default(),
            locked: None,
        })
    }

    pub fn validate_root(source: &Source, root: &Root) -> Result<()> {
        let mut seen = HashSet::new();
        let ids: &[NodeId] = match root {
            Root::ChildrenOf(node) => std::slice::from_ref(node),
            Root::Forest(nodes) => nodes,
        };
        for id in ids {
            if !source.contains(*id) {
                return Err(Error::missing(*id));
            }
            if !seen.insert(*id) {
                return Err(Error::invalid("duplicate display root"));
            }
        }
        Ok(())
    }

    pub fn display_roots(&self, source: &Source) -> Vec<NodeId> {
        match &self.root {
            Root::ChildrenOf(id) => source
                .node(*id)
                .map(|node| node.children().collect())
                .unwrap_or_default(),
            Root::Forest(ids) => {
                let included: HashSet<_> = ids.iter().copied().collect();
                ids.iter()
                    .copied()
                    .filter(|id| {
                        let Some(node) = source.node(*id) else {
                            return false;
                        };
                        let mut parent = node.parent;
                        while let Some(current) = parent {
                            if included.contains(&current) {
                                return false;
                            }
                            parent = source.node(current).and_then(|node| node.parent);
                        }
                        true
                    })
                    .collect()
            }
        }
    }

    pub fn normalize(source: &Source, ids: &[NodeId], scope: Scope) -> Result<Vec<NodeId>> {
        let mut seen = HashSet::with_capacity(ids.len());
        let mut unique = Vec::with_capacity(ids.len());
        for id in ids {
            if !source.contains(*id) {
                return Err(Error::missing(*id));
            }
            if seen.insert(*id) {
                unique.push(*id);
            }
        }
        if scope == Scope::SelfOnly {
            return Ok(unique);
        }
        unique.retain(|id| {
            let mut parent = source.node(*id).and_then(|node| node.parent);
            while let Some(current) = parent {
                if seen.contains(&current) {
                    return false;
                }
                parent = source.node(current).and_then(|node| node.parent);
            }
            true
        });
        Ok(unique)
    }

    pub fn check_revision(&self, expected: Revision) -> Result<()> {
        if self.revision != expected {
            return Err(Error::stale("state revision changed"));
        }
        Ok(())
    }

    pub fn check_unlocked(&self) -> Result<()> {
        if self.locked.is_some() {
            return Err(Error::new(
                ErrorCode::Busy,
                "selection is owned by an active task",
            ));
        }
        Ok(())
    }

    pub fn select(
        &mut self,
        source: &Source,
        ids: &[NodeId],
        action: SelectAction,
        scope: Scope,
    ) -> Result<bool> {
        self.check_unlocked()?;
        let ids = Self::normalize(source, ids, scope)?;
        let targets = ids
            .into_iter()
            .map(|id| {
                let value = match action {
                    SelectAction::Select => true,
                    SelectAction::Deselect => false,
                    SelectAction::Toggle => !self.selection.value(source, id)?,
                };
                Ok((id, value))
            })
            .collect::<Result<Vec<_>>>()?;
        if targets.is_empty() {
            return Ok(false);
        }
        let revision = self.revision.next()?;
        let selection_revision = self.selection_revision.next()?;
        self.selection.assign(source, &targets, scope)?;
        self.revision = revision;
        self.selection_revision = selection_revision;
        Ok(true)
    }

    pub fn clear_selection(&mut self) -> Result<()> {
        self.check_unlocked()?;
        let revision = self.revision.next()?;
        let selection_revision = self.selection_revision.next()?;
        self.selection.clear_all()?;
        self.revision = revision;
        self.selection_revision = selection_revision;
        Ok(())
    }

    pub fn set_expanded(
        &mut self,
        source: &Source,
        ids: &[NodeId],
        value: bool,
        scope: Scope,
    ) -> Result<bool> {
        let ids = Self::normalize(source, ids, scope)?;
        let targets: Vec<_> = ids
            .into_iter()
            .filter(|id| source.node(*id).is_some_and(|node| node.data.can_expand))
            .map(|id| (id, value))
            .collect();
        if targets.is_empty() {
            return Ok(false);
        }
        let revision = self.revision.next()?;
        self.expansion.assign(source, &targets, scope)?;
        self.revision = revision;
        Ok(true)
    }

    pub fn expanded(&self, source: &Source, node: NodeId) -> Result<bool> {
        let data = source.node(node).ok_or_else(|| Error::missing(node))?;
        Ok(data.data.can_expand && self.expansion.value(source, node)?)
    }

    pub fn demands_children(&self, source: &Source, node: NodeId) -> bool {
        if !source.node(node).is_some_and(|node| node.data.can_expand) {
            return false;
        }
        if self.root == Root::ChildrenOf(node) {
            return true;
        }
        if self.display.mode == Mode::Tree && !self.expanded(source, node).unwrap_or(false) {
            return false;
        }
        let roots: HashSet<_> = match &self.root {
            Root::Forest(ids) => ids.iter().copied().collect(),
            _ => HashSet::new(),
        };
        let mut current = Some(node);
        let mut visible = true;
        let mut included = false;
        while let Some(id) = current {
            let Some(data) = source.node(id) else {
                return false;
            };
            visible &= self.display.show_hidden || self.display.selected_only || !data.data.hidden;
            if id != node && self.display.mode == Mode::Tree {
                visible &= self.expanded(source, id).unwrap_or(false);
            }
            if roots.contains(&id) {
                included = visible;
            }
            if data
                .parent
                .is_some_and(|parent| self.root == Root::ChildrenOf(parent))
            {
                return visible;
            }
            current = data.parent;
        }
        included
    }

    pub fn preserve_reparent(&mut self, source: &Source, node: NodeId) -> Result<()> {
        self.selection.preserve_inherited(source, node)?;
        self.expansion.preserve_inherited(source, node)?;
        Ok(())
    }

    pub fn changed_source(&mut self, source: &Source, change: &Change) -> Result<()> {
        self.selection.changed_source(source, change)?;
        self.expansion.changed_source(source, change)?;
        self.summaries.forget(&change.removed);
        Ok(())
    }

    pub fn finish_source_batch(&mut self, source: &Source, structural: bool) -> Result<()> {
        if structural {
            self.selection_revision = self.selection_revision.next()?;
            self.revision = self.revision.next()?;
        }
        if let Root::Forest(ids) = &self.root
            && ids.iter().any(|id| !source.contains(*id))
        {
            self.root = Root::Forest(
                ids.iter()
                    .copied()
                    .filter(|id| source.contains(*id))
                    .collect(),
            );
        }
        Ok(())
    }

    pub fn summary(&mut self, source: &Source) -> Result<Summary> {
        self.summaries.forest(source, &self.selection)
    }

    pub fn sources(&mut self, source: &Source) -> Result<SelectionSources> {
        struct Walk<'a> {
            children: SequenceIter<'a, NodeId>,
            inherited: u32,
        }
        let summary = self.summary(source)?;
        let mut roots = Vec::new();
        let mut own = Vec::new();
        let mut needed = Vec::new();
        if !summary.is_empty() {
            let mut stack = vec![Walk {
                children: source.roots.iter(),
                inherited: self.selection.clear,
            }];
            while let Some(walk) = stack.last_mut() {
                let Some(&id) = walk.children.next() else {
                    stack.pop();
                    continue;
                };
                let inherited = walk.inherited;
                let result = self
                    .summaries
                    .node(source, &self.selection, id, inherited)?;
                if result.summary.full {
                    roots.push(id);
                    continue;
                }
                if result.summary.is_empty() {
                    continue;
                }
                let node = source.node(id).ok_or_else(|| Error::missing(id))?;
                let marks = self.selection.marks(id);
                let next = inherited.max(marks.subtree);
                if next.max(marks.own) & 1 != 0 {
                    own.push(id);
                }
                if result.needs_children {
                    needed.push(id);
                }
                stack.push(Walk {
                    children: node.children.iter(),
                    inherited: next,
                });
            }
        }
        Ok(SelectionSources {
            data_revision: source.revision(),
            selection_revision: self.selection_revision,
            summary,
            subtree_roots: roots.into(),
            self_only_nodes: own.into(),
            needed_children: needed.into(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::super::data::{Operation, Position};
    use super::*;

    fn fixture() -> (Source, NodeId, NodeId, NodeId) {
        let mut source = Source::empty().unwrap();
        for (key, parent) in [("a", None), ("b", Some("a")), ("q", None)] {
            source
                .apply(
                    &Operation::Insert {
                        key: key.into(),
                        parent: parent.map(Into::into),
                        position: Position::Last,
                        data: NodeData::branch(key),
                        completeness: Completeness::Complete,
                    },
                    Revision(1),
                    &Limits::default(),
                    None,
                )
                .unwrap();
        }
        let ids = (
            source.id("a").unwrap(),
            source.id("b").unwrap(),
            source.id("q").unwrap(),
        );
        (source, ids.0, ids.1, ids.2)
    }

    #[test]
    fn t_forest_retains_covered_entries_and_recovers_their_order() {
        let (mut source, a, b, q) = fixture();
        let mut state = State::new(
            &source,
            Root::Forest(vec![b, q, a].into()),
            DisplayOptions::default(),
        )
        .unwrap();
        assert_eq!(state.display_roots(&source), [q, a]);
        state.preserve_reparent(&source, b).unwrap();
        let change = source
            .apply(
                &Operation::Reparent {
                    node: b.into(),
                    parent: None,
                    position: Position::Last,
                },
                Revision(2),
                &Limits::default(),
                None,
            )
            .unwrap();
        state.changed_source(&source, &change).unwrap();
        state.finish_source_batch(&source, true).unwrap();
        assert_eq!(state.display_roots(&source), [b, q, a]);
        assert!(
            State::new(
                &source,
                Root::Forest(vec![a, a].into()),
                DisplayOptions::default()
            )
            .is_err()
        );
    }

    #[test]
    fn t_self_scope_preserves_parent_child_inputs_and_sources_ignore_display_root() {
        let (source, a, b, q) = fixture();
        let mut state =
            State::new(&source, Root::ChildrenOf(q), DisplayOptions::default()).unwrap();
        state
            .select(&source, &[a, b, a], SelectAction::Select, Scope::SelfOnly)
            .unwrap();
        assert_eq!(state.selection.marks(a).own, 3);
        assert_eq!(state.selection.marks(b).own, 3);
        assert_eq!(state.sources(&source).unwrap().subtree_roots.as_ref(), [a]);
        state
            .select(&source, &[b], SelectAction::Deselect, Scope::SelfOnly)
            .unwrap();
        let sources = state.sources(&source).unwrap();
        assert!(sources.subtree_roots.is_empty());
        assert_eq!(sources.self_only_nodes.as_ref(), [a]);
        assert!(!sources.summary.is_empty());
    }

    #[test]
    fn t_ordinary_collapse_keeps_descendant_expansion_and_lock_allows_browsing() {
        let (source, a, b, _) = fixture();
        let mut state =
            State::new(&source, Root::ChildrenOf(a), DisplayOptions::default()).unwrap();
        state
            .set_expanded(&source, &[a], true, Scope::Subtree)
            .unwrap();
        state
            .set_expanded(&source, &[a], false, Scope::SelfOnly)
            .unwrap();
        assert!(!state.expanded(&source, a).unwrap());
        assert!(state.expanded(&source, b).unwrap());
        state.locked = Some(9);
        assert_eq!(state.clear_selection().unwrap_err().code, ErrorCode::Busy);
        assert_eq!(
            state
                .select(&source, &[], SelectAction::Select, Scope::Subtree)
                .unwrap_err()
                .code,
            ErrorCode::Busy
        );
        state
            .set_expanded(&source, &[a], true, Scope::SelfOnly)
            .unwrap();
        assert!(state.expanded(&source, b).unwrap());
    }
}
