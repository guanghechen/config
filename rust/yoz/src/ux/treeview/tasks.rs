use super::data::{Change, ChangeKind, Source};
use super::model::*;
use super::state::SelectionSources;
use super::storage::Map;
use std::collections::{HashMap, HashSet};
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
    Slot {
        node: NodeId,
        can_expand: bool,
        completeness: Completeness,
    },
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

#[derive(Clone, Copy)]
struct ReadGrant {
    epoch: u64,
    root: NodeId,
    admit_new: bool,
}

#[derive(Clone)]
pub(crate) struct Task {
    reads: Map<NodeId, ReadGrant>,
    pub native_job: Option<u64>,
    pub lock: LockToken,
    pub valid: bool,
    references: Map<NodeId, ()>,
    protected: Map<NodeId, usize>,
    pub needed: Arc<[NodeId]>,
    pub cleanup: Option<CleanupToken>,
    pub roots: Arc<[NodeId]>,
    root_index: Map<NodeId, ()>,
    members: Map<NodeId, NodeId>,
    pub expected: Option<ExpectedUpdate>,
    pub removed: Map<NodeId, ()>,
    pub cleaned: bool,
    pub deadline: Option<Instant>,
    pub prepared: Option<(SelectionSources, Arc<Source>, super::command::Revisions)>,
}

impl Task {
    pub fn new(
        source: &Source,
        sources: &SelectionSources,
        deadline: Option<Instant>,
    ) -> Result<Self> {
        let (references, protected) = Self::reference_index(source, sources)?;
        Ok(Self {
            reads: Map::default(),
            native_job: None,
            lock: LockToken(identity()?),
            valid: true,
            references,
            protected,
            needed: sources.needed_children.clone(),
            cleanup: None,
            roots: Arc::new([]),
            root_index: Map::default(),
            members: Map::default(),
            expected: None,
            removed: Map::default(),
            cleaned: false,
            deadline,
            prepared: None,
        })
    }

    pub fn prepare(
        &mut self,
        source: &Source,
        sources: &SelectionSources,
    ) -> Result<Option<CleanupToken>> {
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
        (self.references, self.protected) = Self::reference_index(source, sources)?;
        if sources.summary.pending {
            return Ok(None);
        }
        let cleanup = CleanupToken(identity()?);
        self.roots = sources.subtree_roots.clone();
        for id in self.roots.iter() {
            self.root_index.insert(*id, ());
        }
        self.cleanup = Some(cleanup);
        Ok(Some(cleanup))
    }

    fn reference_index(
        source: &Source,
        sources: &SelectionSources,
    ) -> Result<(Map<NodeId, ()>, Map<NodeId, usize>)> {
        let ids: HashSet<_> = sources
            .subtree_roots
            .iter()
            .chain(sources.self_only_nodes.iter())
            .chain(sources.needed_children.iter())
            .copied()
            .collect();
        let mut parents = HashMap::new();
        let mut children = HashMap::<NodeId, usize>::new();
        for id in &ids {
            let mut current = Some(*id);
            while let Some(id) = current {
                if parents.contains_key(&id) {
                    break;
                }
                let parent = source.node(id).ok_or_else(|| Error::missing(id))?.parent;
                parents.insert(id, parent);
                children.entry(id).or_default();
                if let Some(parent) = parent {
                    *children.entry(parent).or_default() += 1;
                }
                current = parent;
            }
        }
        let mut counts: HashMap<_, usize> = parents
            .keys()
            .map(|id| (*id, usize::from(ids.contains(id))))
            .collect();
        let mut ready: Vec<_> = children
            .iter()
            .filter_map(|(id, count)| (*count == 0).then_some(*id))
            .collect();
        while let Some(id) = ready.pop() {
            if let Some(parent) = parents[&id] {
                let count = counts[&id];
                *counts.get_mut(&parent).expect("reference ancestor") += count;
                let remaining = children
                    .get_mut(&parent)
                    .expect("reference ancestor children");
                *remaining -= 1;
                if *remaining == 0 {
                    ready.push(parent);
                }
            }
        }
        let mut references: Vec<_> = ids.into_iter().map(|id| (id, ())).collect();
        references.sort_unstable_by_key(|(id, _)| *id);
        let mut counts: Vec<_> = counts.into_iter().collect();
        counts.sort_unstable_by_key(|(id, _)| *id);
        Ok((Map::from_sorted(references), Map::from_sorted(counts)))
    }

    pub fn source_root(&mut self, id: NodeId) -> Option<NodeId> {
        let mut current = id;
        let mut path = Vec::new();
        let source = &self.prepared.as_ref()?.1;
        let root = loop {
            if self.root_index.get(&current).is_some() {
                break current;
            }
            if let Some(root) = self.members.get(&current) {
                break *root;
            }
            path.push(current);
            current = source.node(current)?.parent?;
        };
        for id in path {
            self.members.insert(id, root);
        }
        Some(root)
    }

    fn ancestor_reference(
        &self,
        source: &Source,
        mut node: Option<NodeId>,
        excluding: Option<NodeId>,
    ) -> bool {
        while let Some(id) = node {
            if Some(id) != excluding && self.references.get(&id).is_some() {
                return true;
            }
            node = source.node(id).and_then(|node| node.parent);
        }
        false
    }

    fn adjust_ancestors(
        &mut self,
        source: &Source,
        mut node: Option<NodeId>,
        count: usize,
        add: bool,
    ) {
        while let Some(id) = node {
            let old = self.protected.get(&id).copied().unwrap_or(0);
            let value = if add { old + count } else { old - count };
            if value == 0 {
                self.protected.remove(&id);
            } else {
                self.protected.insert(id, value);
            }
            node = source.node(id).and_then(|node| node.parent);
        }
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
        read: Option<NodeId>,
    ) {
        if !self.valid
            || matches!(
                change.kind,
                ChangeKind::Update | ChangeKind::Loading | ChangeKind::Reorder
            )
            || (change.kind == ChangeKind::Reparent && change.old_parent == change.new_parent)
        {
            return;
        }
        if required_read && self.cleanup.is_none() {
            return;
        }
        if let Some(slot) = read {
            if let Some(grant) = self.reads.get(&slot).copied().filter(|grant| {
                new.node(slot)
                    .is_some_and(|node| node.request_epoch == grant.epoch)
            }) {
                if change.kind == ChangeKind::Completeness && change.node == Some(slot) {
                    return;
                }
                if grant.admit_new
                    && change.kind == ChangeKind::Insert
                    && change.new_parent == Some(slot)
                {
                    if let Some(id) = change.node {
                        self.members.insert(id, grant.root);
                    }
                    return;
                }
            }
        }
        let affected = change.node.is_some_and(|id| {
            self.ancestor_reference(old, Some(id), None)
                || self.ancestor_reference(new, Some(id), None)
                || (change.kind != ChangeKind::Insert && self.protected.get(&id).is_some())
        });
        if !affected {
            return;
        }
        if own {
            if let Some(id) = change.node {
                let count = self.protected.get(&id).copied().unwrap_or(0);
                if count != 0 && matches!(change.kind, ChangeKind::Reparent | ChangeKind::Remove) {
                    self.adjust_ancestors(
                        old,
                        old.node(id).and_then(|node| node.parent),
                        count,
                        false,
                    );
                    if change.kind == ChangeKind::Reparent {
                        self.adjust_ancestors(
                            new,
                            new.node(id).and_then(|node| node.parent),
                            count,
                            true,
                        );
                    }
                }
            }
            for id in change.removed.iter() {
                self.removed.insert(*id, ());
                self.references.remove(id);
                self.protected.remove(id);
            }
        } else {
            self.valid = false;
        }
    }

    pub fn grant_read(
        &mut self,
        source: &Source,
        parent: NodeId,
        epoch: u64,
        admit_new: bool,
    ) -> Result<()> {
        self.check(self.lock, self.cleanup)?;
        let root = self
            .source_root(parent)
            .ok_or_else(|| Error::stale("read is outside prepared task roots"))?;
        if self.cleanup.is_none() || !source.contains(parent) {
            return Err(Error::stale("task has no prepared read scope"));
        }
        self.reads.insert(
            parent,
            ReadGrant {
                epoch,
                root,
                admit_new,
            },
        );
        Ok(())
    }

    pub fn restart_read(&mut self, parent: NodeId, epoch: u64, next: u64) {
        if !self.valid || self.cleaned {
            return;
        }
        if let Some(mut grant) = self.reads.get(&parent).copied()
            && (grant.epoch == epoch || Some(grant.epoch) == epoch.checked_add(1))
        {
            /* Keep both the prepared root and its original discovery restriction. */
            grant.epoch = next;
            self.reads.insert(parent, grant);
        }
    }

    pub fn finish_read(&mut self, token: super::reads::ReadToken) {
        if self
            .reads
            .get(&token.node)
            .is_some_and(|grant| grant.epoch == token.epoch)
        {
            self.reads.remove(&token.node);
            self.needed = self
                .needed
                .iter()
                .copied()
                .filter(|id| *id != token.node)
                .collect();
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
            let (node, parent, slot) = match *change {
                ExpectedChange::Reparent { node, parent } => (node, parent, false),
                ExpectedChange::Remove { node } => (node, None, false),
                ExpectedChange::Slot { node, .. } => (node, None, true),
            };
            if self.source_root(node).is_none()
                || !source.contains(node)
                || !seen.insert((node, slot))
            {
                return Err(Error::stale(
                    "expected change is not a distinct prepared source",
                ));
            }
            /* A valid prepared subtree may contain its own admitted child scopes. Moving
             * that subtree carries those references; a different prepared root remains excluded. */
            if parent == Some(node)
                || (self.ancestor_reference(source, parent, Some(node))
                    && parent.and_then(|parent| self.source_root(parent)) != self.source_root(node))
            {
                return Err(Error::stale(
                    "expected move would affect another task source",
                ));
            }
            source.validate_parent(parent)?;
        }
        let token = TaskUpdateToken(identity()?);
        for (node, _) in seen {
            if self.references.get(&node).is_none() {
                self.references.insert(node, ());
                self.adjust_ancestors(source, Some(node), 1, true);
            }
        }
        self.expected = Some(ExpectedUpdate { token, changes });
        Ok(token)
    }
}
