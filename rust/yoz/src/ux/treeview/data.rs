use super::model::*;
use super::storage::{IndexedSequence as Sequence, Map};
use std::collections::HashSet;
use std::sync::Arc;

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum NodeRef {
    Id(NodeId),
    Key(Arc<str>),
}

impl From<NodeId> for NodeRef {
    fn from(value: NodeId) -> Self {
        Self::Id(value)
    }
}

impl From<&str> for NodeRef {
    fn from(value: &str) -> Self {
        Self::Key(value.into())
    }
}

#[derive(Clone, Debug, Default)]
pub enum Position {
    First,
    #[default]
    Last,
    Before(NodeRef),
    After(NodeRef),
}

#[derive(Clone, Debug, Default)]
pub struct NodePatch {
    pub label: Option<Arc<str>>,
    pub can_expand: Option<bool>,
    pub foldable: Option<bool>,
    pub hidden: Option<bool>,
    pub score: Option<f64>,
    pub icon: Option<Option<Arc<str>>>,
    pub highlight: Option<Option<Arc<str>>>,
    pub right_text: Option<Option<Arc<str>>>,
    pub fields: Option<Fields>,
    pub completeness: Option<Completeness>,
}

#[derive(Clone, Debug)]
pub enum Operation {
    Insert {
        key: Arc<str>,
        parent: Option<NodeRef>,
        position: Position,
        data: NodeData,
        completeness: Completeness,
    },
    Update {
        node: NodeRef,
        patch: NodePatch,
    },
    Reparent {
        node: NodeRef,
        parent: Option<NodeRef>,
        position: Position,
    },
    Reorder {
        parent: Option<NodeRef>,
        children: Vec<NodeRef>,
    },
    Remove {
        node: NodeRef,
    },
}

#[derive(Clone, Debug)]
pub struct Batch {
    pub base_revision: Revision,
    pub operations: Vec<Operation>,
}

#[derive(Clone)]
pub struct Node {
    pub(crate) _payloads: Arc<[Arc<super::memory::Payload>]>,
    pub id: NodeId,
    pub key: Arc<str>,
    pub parent: Option<NodeId>,
    pub data: Arc<NodeData>,
    pub completeness: Completeness,
    pub load_state: LoadState,
    pub error: Option<Error>,
    pub request_epoch: u64,
    pub next_sequence: u64,
    pub modified: Revision,
    pub subtree_revision: Revision,
    pub(crate) children: Sequence<NodeId>,
    pub(crate) bytes: usize,
}

impl Node {
    pub fn child_count(&self) -> usize {
        self.children.len()
    }

    pub fn children(&self) -> impl Iterator<Item = NodeId> + '_ {
        self.children.iter().copied()
    }

    pub fn child_at(&self, index: usize) -> Option<NodeId> {
        self.children.get(index).copied()
    }
}

/** Readonly version of the provider forest. Only the owning transaction writes a candidate. */
#[derive(Clone)]
pub struct Source {
    pub(crate) identity: u64,
    pub(crate) revision: Revision,
    /** Node membership and parentage; metadata and sibling order do not change it. */
    pub(crate) ancestry_revision: Revision,
    pub(crate) nodes: Map<NodeId, Node>,
    pub(crate) keys: Map<Arc<str>, NodeId>,
    pub(crate) roots: Sequence<NodeId>,
    pub(crate) bytes: usize,
    pub(crate) query_results: Map<super::provider::DataScope, super::query::QueryResult>,
}

impl std::fmt::Debug for Source {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("Source")
            .field("identity", &self.identity)
            .field("revision", &self.revision)
            .field("nodes", &self.len())
            .finish()
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum ChangeKind {
    Insert,
    Update,
    Reparent,
    Reorder,
    Remove,
    Completeness,
    Loading,
}

#[derive(Clone, Debug)]
pub(crate) struct Change {
    pub kind: ChangeKind,
    pub node: Option<NodeId>,
    pub old_parent: Option<NodeId>,
    pub new_parent: Option<NodeId>,
    pub removed: Arc<[NodeId]>,
}

impl Change {
    pub fn structural(&self) -> bool {
        !matches!(self.kind, ChangeKind::Update | ChangeKind::Loading)
    }
}

impl Source {
    pub(crate) fn empty() -> Result<Self> {
        Ok(Self {
            identity: identity()?,
            revision: Revision::default(),
            ancestry_revision: Revision::default(),
            nodes: Map::default(),
            keys: Map::default(),
            roots: Sequence::default(),
            bytes: 0,
            query_results: Map::default(),
        })
    }

    pub fn identity(&self) -> u64 {
        self.identity
    }
    pub fn revision(&self) -> Revision {
        self.revision
    }

    /** Compare node identities, parentage and provider data, ignoring loading and sibling order. */
    pub fn same_content(&self, other: &Self) -> bool {
        self.identity == other.identity
            && self.nodes.changed_keys(&other.nodes).into_iter().all(|id| {
                self.node(id)
                    .zip(other.node(id))
                    .is_some_and(|(left, right)| {
                        left.parent == right.parent && left.data == right.data
                    })
            })
    }

    pub fn query_results(
        &self,
    ) -> impl Iterator<Item = (super::provider::DataScope, &super::query::QueryResult)> {
        self.query_results
            .iter()
            .map(|(scope, result)| (*scope, result))
    }
    pub fn len(&self) -> usize {
        self.nodes.len()
    }
    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }
    pub fn payload_bytes(&self) -> usize {
        self.bytes
    }
    pub fn node(&self, id: NodeId) -> Option<&Node> {
        self.nodes.get(&id)
    }
    pub fn contains(&self, id: NodeId) -> bool {
        self.nodes.get(&id).is_some()
    }

    pub fn id(&self, key: &str) -> Option<NodeId> {
        self.keys.get(&Arc::<str>::from(key)).copied()
    }

    pub fn roots(&self) -> impl Iterator<Item = NodeId> + '_ {
        self.roots.iter().copied()
    }

    pub(crate) fn resolve(&self, reference: &NodeRef) -> Result<NodeId> {
        match reference {
            NodeRef::Id(id) if self.contains(*id) => Ok(*id),
            NodeRef::Id(id) => Err(Error::missing(*id)),
            NodeRef::Key(key) => self.keys.get(key).copied().ok_or_else(|| {
                Error::new(
                    ErrorCode::MissingNode,
                    format!("provider key is not alive: {key}"),
                )
            }),
        }
    }

    pub fn is_ancestor(&self, ancestor: NodeId, mut node: NodeId) -> bool {
        while let Some(parent) = self.node(node).and_then(|node| node.parent) {
            if parent == ancestor {
                return true;
            }
            node = parent;
        }
        false
    }

    pub fn within(&self, root: NodeId, node: NodeId) -> bool {
        root == node || self.is_ancestor(root, node)
    }

    pub(crate) fn child_sequence(&self, parent: Option<NodeId>) -> Result<&Sequence<NodeId>> {
        match parent {
            None => Ok(&self.roots),
            Some(parent) => self
                .node(parent)
                .map(|node| &node.children)
                .ok_or_else(|| Error::missing(parent)),
        }
    }

    pub(crate) fn validate_parent(&self, parent: Option<NodeId>) -> Result<()> {
        if let Some(parent) = parent {
            let parent_node = self.node(parent).ok_or_else(|| Error::missing(parent))?;
            if !parent_node.data.can_expand {
                return Err(Error::invalid("a leaf cannot own children"));
            }
        }
        Ok(())
    }

    fn position(&self, parent: Option<NodeId>, position: &Position) -> Result<usize> {
        let children = self.child_sequence(parent)?;
        match position {
            Position::First => Ok(0),
            Position::Last => Ok(children.len()),
            Position::Before(reference) | Position::After(reference) => {
                let sibling = self.resolve(reference)?;
                let position_index = children
                    .position(&sibling)
                    .ok_or_else(|| Error::invalid("insertion anchor is not a sibling"))?;
                Ok(position_index + usize::from(matches!(position, Position::After(_))))
            }
        }
    }

    fn set_children(
        &mut self,
        parent: Option<NodeId>,
        children: Sequence<NodeId>,
        revision: Revision,
        request: Option<NodeId>,
    ) -> Result<()> {
        if let Some(parent) = parent {
            let mut node = self
                .node(parent)
                .ok_or_else(|| Error::missing(parent))?
                .clone();
            node.children = children;
            node.modified = revision;
            if request != Some(parent) {
                node.request_epoch = node
                    .request_epoch
                    .checked_add(1)
                    .ok_or_else(|| Error::limit("children request epoch exhausted"))?;
                node.next_sequence = 1;
                node.load_state = LoadState::Idle;
                node.error = None;
            }
            self.nodes.insert(parent, node);
            self.touch_ancestors(Some(parent), revision)?;
        } else {
            self.roots = children;
        }
        Ok(())
    }

    pub(crate) fn touch_ancestors(
        &mut self,
        mut current: Option<NodeId>,
        revision: Revision,
    ) -> Result<()> {
        while let Some(id) = current {
            let mut node = self.node(id).ok_or_else(|| Error::missing(id))?.clone();
            if node.subtree_revision == revision {
                break;
            }
            node.subtree_revision = revision;
            current = node.parent;
            self.nodes.insert(id, node);
        }
        Ok(())
    }

    pub(crate) fn apply(
        &mut self,
        operation: &Operation,
        revision: Revision,
        limits: &Limits,
        request: Option<NodeId>,
    ) -> Result<Change> {
        self.apply_inner(operation, revision, limits, request, None)
    }

    /** A children page inserts into fixed gaps and repairs its sibling index once. */
    pub(crate) fn insert_children(
        &mut self,
        parent: NodeId,
        operations: &[Operation],
        revision: Revision,
        limits: &Limits,
    ) -> Result<Vec<Change>> {
        let mut ids = Vec::with_capacity(operations.len());
        let mut changes = Vec::with_capacity(operations.len());
        let mut gaps = std::collections::BTreeMap::<usize, Vec<NodeId>>::new();
        for operation in operations {
            let Operation::Insert { position, .. } = operation else {
                unreachable!("validated children inserts")
            };
            let at = self.position(Some(parent), position)?;
            changes.push(self.apply_inner(
                operation,
                revision,
                limits,
                Some(parent),
                Some(&mut ids),
            )?);
            gaps.entry(at)
                .or_default()
                .push(*ids.last().expect("inserted child"));
        }
        let mut children = self.child_sequence(Some(parent))?.clone();
        children.splice_many(
            gaps.into_iter()
                .map(|(at, values)| (at, at, values))
                .collect(),
        )?;
        self.set_children(Some(parent), children, revision, Some(parent))?;
        Ok(changes)
    }

    fn apply_inner(
        &mut self,
        operation: &Operation,
        revision: Revision,
        limits: &Limits,
        request: Option<NodeId>,
        append: Option<&mut Vec<NodeId>>,
    ) -> Result<Change> {
        let change = match operation {
            Operation::Insert {
                key,
                parent,
                position,
                data,
                completeness,
            } => {
                if self.keys.get(key).is_some() {
                    return Err(Error::invalid("duplicate provider key"));
                }
                if self.len() >= limits.nodes {
                    return Err(Error::limit("node capacity exceeded"));
                }
                let parent = parent
                    .as_ref()
                    .map(|parent| self.resolve(parent))
                    .transpose()?;
                self.validate_parent(parent)?;
                let at = if append.is_none() {
                    self.position(parent, position)?
                } else {
                    0
                };
                if !data.can_expand && *completeness != Completeness::Complete {
                    return Err(Error::invalid("leaf children must be complete"));
                }
                let bytes = data
                    .validate()?
                    .checked_add(key.len())
                    .ok_or_else(|| Error::limit("payload size overflow"))?;
                let total = self
                    .bytes
                    .checked_add(bytes)
                    .ok_or_else(|| Error::limit("payload size overflow"))?;
                if total > limits.payload_bytes {
                    return Err(Error::limit("payload capacity exceeded"));
                }
                let id = NodeId(identity()?);
                let data = Arc::new(data.clone());
                let node = Node {
                    _payloads: super::memory::Payload::node(key.clone(), data.clone()),
                    id,
                    key: key.clone(),
                    parent,
                    data,
                    completeness: *completeness,
                    load_state: LoadState::Idle,
                    error: None,
                    request_epoch: 0,
                    next_sequence: 1,
                    modified: revision,
                    subtree_revision: revision,
                    children: Sequence::default(),
                    bytes,
                };
                self.nodes.insert(id, node);
                self.keys.insert(key.clone(), id);
                if let Some(append) = append {
                    append.push(id);
                } else {
                    let mut children = self.child_sequence(parent)?.clone();
                    children.splice(at, at, vec![id])?;
                    self.set_children(parent, children, revision, request)?;
                }
                self.bytes = total;
                Change {
                    kind: ChangeKind::Insert,
                    node: Some(id),
                    old_parent: None,
                    new_parent: parent,
                    removed: Arc::new([]),
                }
            }
            Operation::Update { node, patch } => {
                let id = self.resolve(node)?;
                let mut node = self.node(id).ok_or_else(|| Error::missing(id))?.clone();
                let mut data = (*node.data).clone();
                if let Some(value) = &patch.label {
                    data.label = value.clone();
                }
                if let Some(value) = patch.can_expand {
                    data.can_expand = value;
                }
                if let Some(value) = patch.foldable {
                    data.foldable = value;
                }
                if let Some(value) = patch.hidden {
                    data.hidden = value;
                }
                if let Some(value) = patch.score {
                    data.score = value;
                }
                if let Some(value) = &patch.icon {
                    data.icon = value.clone();
                }
                if let Some(value) = &patch.highlight {
                    data.highlight = value.clone();
                }
                if let Some(value) = &patch.right_text {
                    data.right_text = value.clone();
                }
                if let Some(value) = &patch.fields {
                    data.fields = value.clone();
                }
                let completeness = patch.completeness.unwrap_or(node.completeness);
                if !data.can_expand
                    && (!node.children.is_empty() || completeness != Completeness::Complete)
                {
                    return Err(Error::invalid("leaf must have complete, empty children"));
                }
                let bytes = data
                    .validate()?
                    .checked_add(node.key.len())
                    .ok_or_else(|| Error::limit("payload size overflow"))?;
                let total = self
                    .bytes
                    .checked_sub(node.bytes)
                    .and_then(|total| total.checked_add(bytes))
                    .ok_or_else(|| Error::limit("payload size overflow"))?;
                if total > limits.payload_bytes {
                    return Err(Error::limit("payload capacity exceeded"));
                }
                let structural =
                    completeness != node.completeness || data.can_expand != node.data.can_expand;
                if structural && request != Some(id) {
                    node.request_epoch = node
                        .request_epoch
                        .checked_add(1)
                        .ok_or_else(|| Error::limit("children request epoch exhausted"))?;
                    node.next_sequence = 1;
                    node.load_state = LoadState::Idle;
                    node.error = None;
                }
                node.data = Arc::new(data);
                node._payloads = super::memory::Payload::node(node.key.clone(), node.data.clone());
                node.completeness = completeness;
                node.bytes = bytes;
                node.modified = revision;
                let parent = node.parent;
                self.nodes.insert(id, node);
                self.bytes = total;
                if structural {
                    self.touch_ancestors(Some(id), revision)?;
                }
                Change {
                    kind: if structural {
                        ChangeKind::Completeness
                    } else {
                        ChangeKind::Update
                    },
                    node: Some(id),
                    old_parent: parent,
                    new_parent: parent,
                    removed: Arc::new([]),
                }
            }
            Operation::Reparent {
                node,
                parent,
                position,
            } => {
                let id = self.resolve(node)?;
                let parent = parent
                    .as_ref()
                    .map(|parent| self.resolve(parent))
                    .transpose()?;
                self.validate_parent(parent)?;
                if parent.is_some_and(|parent| parent == id || self.is_ancestor(id, parent)) {
                    return Err(Error::invalid("reparent would create a cycle"));
                }
                if matches!(position, Position::Before(reference) | Position::After(reference) if self.resolve(reference)? == id)
                {
                    return Err(Error::invalid("a node cannot be its own insertion anchor"));
                }
                let mut node = self.node(id).ok_or_else(|| Error::missing(id))?.clone();
                let previous_parent = node.parent;
                let mut previous_children = self.child_sequence(previous_parent)?.clone();
                let previous_index = previous_children
                    .position(&id)
                    .ok_or_else(|| Error::invalid("parent does not contain its child"))?;
                previous_children.splice(previous_index, previous_index + 1, vec![])?;
                self.set_children(previous_parent, previous_children, revision, request)?;
                let at = self.position(parent, position)?;
                let mut children = self.child_sequence(parent)?.clone();
                children.splice(at, at, vec![id])?;
                self.set_children(parent, children, revision, request)?;
                node.parent = parent;
                node.modified = revision;
                node.subtree_revision = revision;
                self.nodes.insert(id, node);
                Change {
                    kind: ChangeKind::Reparent,
                    node: Some(id),
                    old_parent: previous_parent,
                    new_parent: parent,
                    removed: Arc::new([]),
                }
            }
            Operation::Reorder { parent, children } => {
                let parent = parent
                    .as_ref()
                    .map(|parent| self.resolve(parent))
                    .transpose()?;
                let ids = children
                    .iter()
                    .map(|node| self.resolve(node))
                    .collect::<Result<Vec<_>>>()?;
                let actual: HashSet<_> = self.child_sequence(parent)?.iter().copied().collect();
                let requested: HashSet<_> = ids.iter().copied().collect();
                if actual != requested || requested.len() != ids.len() {
                    return Err(Error::invalid(
                        "reorder must contain every sibling exactly once",
                    ));
                }
                self.set_children(parent, Sequence::from_vec(ids)?, revision, request)?;
                Change {
                    kind: ChangeKind::Reorder,
                    node: parent,
                    old_parent: parent,
                    new_parent: parent,
                    removed: Arc::new([]),
                }
            }
            Operation::Remove { node } => {
                let id = self.resolve(node)?;
                let parent = self.node(id).ok_or_else(|| Error::missing(id))?.parent;
                let mut removed = Vec::new();
                let mut stack = vec![(id, 0usize)];
                while let Some((current, child_index)) = stack.last_mut() {
                    let node = self
                        .node(*current)
                        .ok_or_else(|| Error::missing(*current))?;
                    if let Some(child) = node.child_at(*child_index) {
                        *child_index += 1;
                        stack.push((child, 0));
                    } else {
                        removed.push(*current);
                        stack.pop();
                    }
                }
                let mut children = self.child_sequence(parent)?.clone();
                let at = children
                    .position(&id)
                    .ok_or_else(|| Error::invalid("parent does not contain its child"))?;
                children.splice(at, at + 1, vec![])?;
                self.set_children(parent, children, revision, request)?;
                for removed_id in &removed {
                    self.query_results
                        .remove(&super::provider::DataScope::Children(*removed_id));
                    self.query_results
                        .remove(&super::provider::DataScope::Descendants(*removed_id));
                    let node = self
                        .node(*removed_id)
                        .ok_or_else(|| Error::missing(*removed_id))?;
                    let key = node.key.clone();
                    self.bytes -= node.bytes;
                    self.keys.remove(&key);
                    self.nodes.remove(removed_id);
                }
                Change {
                    kind: ChangeKind::Remove,
                    node: Some(id),
                    old_parent: parent,
                    new_parent: None,
                    removed: removed.into(),
                }
            }
        };
        super::memory::check()?;
        if matches!(
            change.kind,
            ChangeKind::Insert | ChangeKind::Reparent | ChangeKind::Remove
        ) {
            self.ancestry_revision = revision;
        }
        self.revision = revision;
        Ok(change)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn insert(key: &str, parent: Option<&str>, branch: bool) -> Operation {
        Operation::Insert {
            key: key.into(),
            parent: parent.map(NodeRef::from),
            position: Position::Last,
            data: if branch {
                NodeData::branch(key)
            } else {
                NodeData::leaf(key)
            },
            completeness: Completeness::Complete,
        }
    }

    #[test]
    fn t_same_content_ignores_loading_and_sibling_order() {
        let mut source = Source::empty().unwrap();
        let limits = Limits::default();
        for operation in [
            insert("p", None, true),
            insert("a", Some("p"), false),
            insert("b", Some("p"), false),
        ] {
            source
                .apply(&operation, Revision(1), &limits, None)
                .unwrap();
        }
        let old = source.clone();
        source
            .apply(
                &Operation::Update {
                    node: "p".into(),
                    patch: NodePatch {
                        completeness: Some(Completeness::Partial),
                        ..NodePatch::default()
                    },
                },
                Revision(2),
                &limits,
                None,
            )
            .unwrap();
        let id = source.id("p").unwrap();
        let mut loading = source.node(id).unwrap().clone();
        loading.load_state = LoadState::Loading;
        source.nodes.insert(id, loading);
        assert_ne!(old.revision(), source.revision());
        assert!(old.same_content(&source));
        assert!(source.same_content(&old));

        source
            .apply(
                &Operation::Reorder {
                    parent: Some("p".into()),
                    children: vec!["b".into(), "a".into()],
                },
                Revision(3),
                &limits,
                None,
            )
            .unwrap();
        assert_ne!(
            old.node(id).unwrap().child_at(0),
            source.node(id).unwrap().child_at(0)
        );
        assert!(old.same_content(&source));
        assert!(source.same_content(&old));
    }

    #[test]
    fn t_same_content_rejects_identity_parentage_and_provider_changes() {
        let mut source = Source::empty().unwrap();
        let limits = Limits::default();
        assert!(!source.same_content(&Source::empty().unwrap()));
        for operation in [insert("p", None, true), insert("a", Some("p"), false)] {
            source
                .apply(&operation, Revision(1), &limits, None)
                .unwrap();
        }
        for operation in [
            Operation::Update {
                node: "a".into(),
                patch: NodePatch {
                    label: Some("renamed".into()),
                    ..NodePatch::default()
                },
            },
            Operation::Update {
                node: "p".into(),
                patch: NodePatch {
                    fields: Some(Arc::new(std::collections::BTreeMap::from([(
                        "resource".to_owned(),
                        Value::Bytes(Arc::from(&b"changed target"[..])),
                    )]))),
                    ..NodePatch::default()
                },
            },
            Operation::Reparent {
                node: "a".into(),
                parent: None,
                position: Position::Last,
            },
            insert("b", Some("p"), false),
            Operation::Remove { node: "a".into() },
        ] {
            let mut changed = source.clone();
            changed
                .apply(&operation, Revision(2), &limits, None)
                .unwrap();
            assert!(!source.same_content(&changed), "{operation:?}");
            assert!(!changed.same_content(&source), "{operation:?}");
        }
        let mut replaced = source.clone();
        replaced
            .apply(
                &Operation::Remove { node: "a".into() },
                Revision(2),
                &limits,
                None,
            )
            .unwrap();
        replaced
            .apply(&insert("a", Some("p"), false), Revision(3), &limits, None)
            .unwrap();
        assert!(!source.same_content(&replaced));
    }

    #[test]
    fn t_identity_survives_updates_but_not_remove_and_reinsert() {
        let mut source = Source::empty().unwrap();
        let limits = Limits::default();
        source
            .apply(&insert("a", None, false), Revision(1), &limits, None)
            .unwrap();
        let id = source.id("a").unwrap();
        let old = source.clone();
        source
            .apply(
                &Operation::Update {
                    node: id.into(),
                    patch: NodePatch {
                        label: Some("b".into()),
                        ..NodePatch::default()
                    },
                },
                Revision(2),
                &limits,
                None,
            )
            .unwrap();
        assert_eq!(source.id("a"), Some(id));
        assert_eq!(&*old.node(id).unwrap().data.label, "a");
        assert_eq!(&*source.node(id).unwrap().data.label, "b");
        source
            .apply(
                &Operation::Remove { node: id.into() },
                Revision(3),
                &limits,
                None,
            )
            .unwrap();
        source
            .apply(&insert("a", None, false), Revision(4), &limits, None)
            .unwrap();
        assert_ne!(source.id("a"), Some(id));
        assert!(source.node(id).is_none());
    }

    #[test]
    fn t_parent_constraints_and_order_are_explicit() {
        let mut source = Source::empty().unwrap();
        let limits = Limits::default();
        for operation in [
            insert("p", None, true),
            insert("a", Some("p"), true),
            insert("b", Some("p"), false),
        ] {
            source
                .apply(&operation, Revision(1), &limits, None)
                .unwrap();
        }
        let p = source.id("p").unwrap();
        let a = source.id("a").unwrap();
        let b = source.id("b").unwrap();
        assert!(
            source
                .apply(
                    &Operation::Reparent {
                        node: p.into(),
                        parent: Some(a.into()),
                        position: Position::Last
                    },
                    Revision(2),
                    &limits,
                    None
                )
                .is_err()
        );
        assert!(
            source
                .apply(&insert("c", Some("b"), false), Revision(2), &limits, None)
                .is_err()
        );
        source
            .apply(
                &Operation::Reorder {
                    parent: Some(p.into()),
                    children: vec![b.into(), a.into()],
                },
                Revision(2),
                &limits,
                None,
            )
            .unwrap();
        assert_eq!(
            source.node(p).unwrap().children().collect::<Vec<_>>(),
            [b, a]
        );
        assert!(
            source
                .apply(
                    &Operation::Reorder {
                        parent: Some(p.into()),
                        children: vec![a.into(), a.into()]
                    },
                    Revision(3),
                    &limits,
                    None
                )
                .is_err()
        );
    }

    #[test]
    fn t_remove_uses_iterative_traversal_for_deep_trees() {
        let mut source = Source::empty().unwrap();
        let limits = Limits::default();
        let mut parent = None;
        for index in 0..10_000 {
            let key = format!("n{index}");
            source
                .apply(
                    &insert(&key, parent.as_deref(), true),
                    Revision(1),
                    &limits,
                    None,
                )
                .unwrap();
            parent = Some(key);
        }
        let root = source.id("n0").unwrap();
        let previous = source.clone();
        let removed = source
            .apply(
                &Operation::Remove { node: root.into() },
                Revision(2),
                &limits,
                None,
            )
            .unwrap();
        assert_eq!(removed.removed.len(), 10_000);
        assert!(source.is_empty());
        assert_eq!(previous.len(), 10_000);
        assert_eq!(source.payload_bytes(), 0);
    }
}
