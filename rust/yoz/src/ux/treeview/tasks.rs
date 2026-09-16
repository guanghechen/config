use super::data::{Change, ChangeKind, Source};
use super::model::*;
use super::state::SelectionSources;
use std::collections::HashSet;
use std::sync::Arc;
use std::time::Instant;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct LockToken(pub(crate) u64);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CleanupToken(pub(crate) u64);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TaskUpdateToken(pub(crate) u64);

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ExpectedChange {
    Reparent {
        node: NodeId,
        parent: Option<NodeId>,
    },
    Remove {
        node: NodeId,
    },
}

#[derive(Clone)]
pub(crate) struct ExpectedUpdate {
    pub token: TaskUpdateToken,
    pub changes: Arc<[ExpectedChange]>,
}

#[derive(Clone)]
pub(crate) struct Task {
    pub lock: LockToken,
    pub valid: bool,
    pub references: Arc<[NodeId]>,
    pub needed: Arc<[NodeId]>,
    pub cleanup: Option<CleanupToken>,
    pub roots: Arc<[NodeId]>,
    pub expected: Option<ExpectedUpdate>,
    pub removed: HashSet<NodeId>,
    pub cleaned: bool,
    pub deadline: Option<Instant>,
    pub prepared: Option<(SelectionSources, Arc<Source>, super::command::Revisions)>,
}

impl Task {
    pub fn new(sources: &SelectionSources, deadline: Option<Instant>) -> Result<Self> {
        let references = sources
            .subtree_roots
            .iter()
            .chain(sources.self_only_nodes.iter())
            .chain(sources.needed_children.iter())
            .copied()
            .collect();
        Ok(Self {
            lock: LockToken(identity()?),
            valid: true,
            references,
            needed: sources.needed_children.clone(),
            cleanup: None,
            roots: Arc::new([]),
            expected: None,
            removed: HashSet::new(),
            cleaned: false,
            deadline,
            prepared: None,
        })
    }

    pub fn prepare(&mut self, sources: &SelectionSources) -> Result<Option<CleanupToken>> {
        if !self.valid {
            return Err(Error::stale("task source topology changed"));
        }
        if self.cleaned {
            return Err(Error::stale("task cleanup already completed"));
        }
        if let Some(cleanup) = self.cleanup {
            return Ok(Some(cleanup));
        }
        self.needed = sources.needed_children.clone();
        self.references = sources
            .subtree_roots
            .iter()
            .chain(sources.self_only_nodes.iter())
            .chain(sources.needed_children.iter())
            .copied()
            .collect();
        if sources.summary.pending {
            return Ok(None);
        }
        let cleanup = CleanupToken(identity()?);
        self.roots = sources.subtree_roots.clone();
        self.cleanup = Some(cleanup);
        Ok(Some(cleanup))
    }

    pub fn check(&self, lock: LockToken, cleanup: Option<CleanupToken>) -> Result<()> {
        if self.lock != lock || cleanup.is_some_and(|token| self.cleanup != Some(token)) {
            return Err(Error::stale("task token no longer owns this selection"));
        }
        if !self.valid || self.cleaned {
            return Err(Error::stale("task cleanup context is no longer valid"));
        }
        Ok(())
    }

    pub fn changed(
        &mut self,
        old: &Source,
        new: &Source,
        change: &Change,
        own: bool,
        required_read: bool,
    ) {
        if !self.valid
            || matches!(
                change.kind,
                ChangeKind::Update | ChangeKind::Loading | ChangeKind::Reorder
            )
        {
            return;
        }
        if required_read && self.cleanup.is_none() {
            return;
        }
        let affected = change.node.is_some_and(|id| {
            self.references.iter().any(|reference| {
                old.within(*reference, id)
                    || new.within(*reference, id)
                    || (change.kind != ChangeKind::Insert
                        && (old.within(id, *reference) || new.within(id, *reference)))
            })
        });
        if !affected {
            return;
        }
        if own {
            for id in change.removed.iter() {
                self.removed.insert(*id);
            }
        } else {
            self.valid = false;
        }
    }

    pub fn authorize(
        &mut self,
        source: &Source,
        changes: Arc<[ExpectedChange]>,
    ) -> Result<TaskUpdateToken> {
        self.check(self.lock, self.cleanup)?;
        if self.cleanup.is_none() || changes.is_empty() {
            return Err(Error::invalid(
                "expected task changes require prepared sources",
            ));
        }
        let mut seen = HashSet::new();
        for change in changes.iter() {
            let (node, parent) = match *change {
                ExpectedChange::Reparent { node, parent } => (node, parent),
                ExpectedChange::Remove { node } => (node, None),
            };
            if !self.roots.contains(&node) || !source.contains(node) || !seen.insert(node) {
                return Err(Error::stale(
                    "expected change is not a distinct prepared source",
                ));
            }
            for other in self
                .references
                .iter()
                .copied()
                .filter(|other| *other != node)
            {
                if source.within(node, other)
                    || parent.is_some_and(|parent| source.within(other, parent) || parent == node)
                {
                    return Err(Error::stale(
                        "expected move would affect another task source",
                    ));
                }
            }
            source.validate_parent(parent)?;
        }
        let token = TaskUpdateToken(identity()?);
        self.expected = Some(ExpectedUpdate { token, changes });
        Ok(token)
    }
}
