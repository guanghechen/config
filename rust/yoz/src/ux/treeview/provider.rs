use super::Reply;
use super::data::{Batch, Node, NodePatch, NodeRef, Operation, Position, Source};
use super::engine::Engine;
use super::model::*;
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum DataScope {
    Forest,
    Descendants(NodeId),
    Children(NodeId),
}

impl DataScope {
    pub fn anchor(self) -> Option<NodeId> {
        match self {
            Self::Forest => None,
            Self::Descendants(node) | Self::Children(node) => Some(node),
        }
    }

    pub(crate) fn validate(self, source: &Source) -> Result<()> {
        source.validate_parent(self.anchor())
    }

    pub(crate) fn contains(self, source: &Source, id: NodeId) -> bool {
        match self {
            Self::Forest => source.contains(id),
            Self::Descendants(root) => source.is_ancestor(root, id),
            Self::Children(root) => source
                .node(id)
                .is_some_and(|node| node.parent == Some(root)),
        }
    }

    fn parent_allowed(self, source: &Source, parent: Option<NodeId>) -> bool {
        match self {
            Self::Forest => parent.is_none_or(|id| source.contains(id)),
            Self::Descendants(root) => parent.is_some_and(|parent| source.within(root, parent)),
            Self::Children(root) => parent == Some(root),
        }
    }

    pub(crate) fn overlaps(self, other: Self, source: &Source) -> bool {
        match (self, other) {
            (Self::Forest, _) | (_, Self::Forest) => true,
            (Self::Children(a), Self::Children(b)) => a == b,
            (Self::Descendants(a), Self::Descendants(b)) => {
                source.within(a, b) || source.within(b, a)
            }
            (Self::Descendants(a), Self::Children(b))
            | (Self::Children(b), Self::Descendants(a)) => source.within(a, b),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ProviderId(pub(crate) u64);

#[derive(Clone)]
pub(crate) struct Provider {
    pub scope: DataScope,
}

#[derive(Clone, Debug)]
pub struct Record {
    pub key: Arc<str>,
    pub parent: Option<NodeRef>,
    pub data: NodeData,
    pub completeness: Option<Completeness>,
}

impl Record {
    pub fn new(key: impl Into<Arc<str>>, data: NodeData) -> Self {
        Self {
            key: key.into(),
            parent: None,
            data,
            completeness: None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Import {
    pub base_revision: Revision,
    pub scope: DataScope,
    pub records: Vec<Record>,
}

pub(crate) fn operation_bytes(operation: &Operation) -> Result<usize> {
    let reference = |value: &NodeRef| match value {
        NodeRef::Id(_) => 0,
        NodeRef::Key(key) => key.len().saturating_add(16),
    };
    let position = |value: &Position| match value {
        Position::Before(node) | Position::After(node) => reference(node),
        _ => 0,
    };
    let bytes = match operation {
        Operation::Insert {
            key,
            data,
            parent,
            position: at,
            ..
        } => data
            .validate()?
            .saturating_add(key.len())
            .saturating_add(16)
            .saturating_add(parent.as_ref().map_or(0, reference))
            .saturating_add(position(at)),
        Operation::Update { node, patch } => NodeData {
            label: patch.label.clone().unwrap_or_default(),
            icon: patch.icon.clone().flatten(),
            highlight: patch.highlight.clone().flatten(),
            right_text: patch.right_text.clone().flatten(),
            fields: patch.fields.clone().unwrap_or_else(empty_fields),
            payload: patch.payload.clone().flatten(),
            score: patch.score.unwrap_or_default(),
            ..NodeData::default()
        }
        .validate()?
        .saturating_add(reference(node)),
        Operation::Reparent {
            node,
            parent,
            position: at,
        } => reference(node)
            .saturating_add(parent.as_ref().map_or(0, reference))
            .saturating_add(position(at)),
        Operation::Reorder { parent, children } => children
            .iter()
            .map(reference)
            .fold(parent.as_ref().map_or(0, reference), usize::saturating_add)
            .saturating_add(
                children
                    .len()
                    .saturating_mul(std::mem::size_of::<NodeRef>()),
            ),
        Operation::Remove { node } => reference(node),
    };
    Ok(bytes.saturating_add(std::mem::size_of::<Operation>()))
}

pub(crate) fn check_batch_size(operations: &[Operation], limits: &Limits) -> Result<()> {
    if operations.len() > limits.batch_nodes {
        return Err(Error::limit("operation batch capacity exceeded"));
    }
    let mut bytes = 0usize;
    for operation in operations {
        bytes = bytes.saturating_add(operation_bytes(operation)?);
        if bytes > limits.batch_bytes {
            return Err(Error::limit("batch byte capacity exceeded"));
        }
    }
    Ok(())
}

pub(crate) fn check_scope(
    source: &Source,
    scope: DataScope,
    operation: &Operation,
    protected: &[DataScope],
) -> Result<()> {
    scope.validate(source)?;
    let node_allowed = |reference: &NodeRef| -> Result<NodeId> {
        let id = source.resolve(reference)?;
        if !scope.contains(source, id) {
            return Err(Error::invalid("node is outside the provider scope"));
        }
        Ok(id)
    };
    let parent_allowed = |reference: &Option<NodeRef>| -> Result<()> {
        let parent = reference
            .as_ref()
            .map(|reference| source.resolve(reference))
            .transpose()?;
        if !scope.parent_allowed(source, parent) {
            return Err(Error::invalid("parent is outside the provider scope"));
        }
        Ok(())
    };
    match operation {
        Operation::Insert { parent, .. } => parent_allowed(parent)?,
        Operation::Update { node, patch } => {
            let anchor_completeness = source.resolve(node).ok() == scope.anchor()
                && patch.completeness.is_some()
                && patch.label.is_none()
                && patch.can_expand.is_none()
                && patch.foldable.is_none()
                && patch.hidden.is_none()
                && patch.score.is_none()
                && patch.icon.is_none()
                && patch.highlight.is_none()
                && patch.right_text.is_none()
                && patch.fields.is_none()
                && patch.payload.is_none();
            if !anchor_completeness {
                node_allowed(node)?;
            }
        }
        Operation::Reparent { node, parent, .. } => {
            node_allowed(node)?;
            parent_allowed(parent)?;
        }
        Operation::Reorder { parent, .. } => parent_allowed(parent)?,
        Operation::Remove { node } => {
            let node = node_allowed(node)?;
            for scope in protected {
                if scope
                    .anchor()
                    .is_none_or(|anchor| source.within(node, anchor))
                {
                    return Err(Error::invalid(
                        "remove would invalidate another provider scope",
                    ));
                }
            }
        }
    }
    Ok(())
}

/// Plan pure additions without constructing a disposable source version.
fn append_import(
    source: &Source,
    records: &[Record],
    parents: &[Option<NodeRef>],
    children: &[Vec<usize>],
    order: &[usize],
) -> Option<Vec<Operation>> {
    if source.len() > records.len() {
        return None;
    }
    let mut known = 0;
    for (index, record) in records.iter().enumerate() {
        let Some(id) = source.id(&record.key) else {
            continue;
        };
        known += 1;
        let node = source.node(id)?;
        let parent = match &parents[index] {
            Some(NodeRef::Key(key)) => Some(source.id(key)?),
            Some(NodeRef::Id(id)) => Some(*id),
            None => None,
        };
        if node.parent != parent
            || *node.data != record.data
            || node.completeness != record.completeness.unwrap_or(Completeness::Complete)
        {
            return None;
        }
    }
    if known != source.len() {
        return None;
    }
    for (index, desired) in children.iter().enumerate() {
        let parent = if index == records.len() {
            None
        } else if let Some(id) = source.id(&records[index].key) {
            Some(id)
        } else {
            continue;
        };
        let existing = source.child_sequence(parent).ok()?;
        if existing.len() > desired.len()
            || existing.iter().zip(desired).any(|(id, &index)| {
                source.node(*id).expect("existing child").key != records[index].key
            })
        {
            return None;
        }
    }
    Some(
        order
            .iter()
            .filter(|&&index| source.id(&records[index].key).is_none())
            .map(|&index| Operation::Insert {
                key: records[index].key.clone(),
                parent: parents[index].clone(),
                position: Position::Last,
                data: records[index].data.clone(),
                completeness: Completeness::Complete,
            })
            .collect(),
    )
}

/** Align a complete membership declaration. Input order supplies sibling order, not mutation order. */
pub(crate) fn plan_import(
    source: &Source,
    scope: DataScope,
    records: &[Record],
    replace: bool,
    complete: bool,
    limits: &Limits,
    protected: &[DataScope],
) -> Result<Vec<Operation>> {
    scope.validate(source)?;
    if records.len() > limits.batch_nodes {
        return Err(Error::limit("record batch capacity exceeded"));
    }
    let mut keys = HashMap::with_capacity(records.len());
    let mut bytes = 0usize;
    for (index, record) in records.iter().enumerate() {
        if keys.insert(record.key.clone(), index).is_some() {
            return Err(Error::invalid("duplicate key in snapshot"));
        }
        bytes = bytes
            .checked_add(record.data.validate()?.saturating_add(record.key.len()))
            .ok_or_else(|| Error::limit("snapshot byte size overflow"))?;
        if bytes > limits.batch_bytes {
            return Err(Error::limit("snapshot byte capacity exceeded"));
        }
        if let Some(id) = source.id(&record.key)
            && !scope.contains(source, id)
        {
            return Err(Error::invalid("snapshot key belongs to another scope"));
        }
        if complete
            && !matches!(scope, DataScope::Children(_))
            && record
                .completeness
                .is_some_and(|value| value != Completeness::Complete)
        {
            return Err(Error::invalid(
                "complete snapshot cannot omit unknown or partial descendants",
            ));
        }
    }
    let mut parents = vec![None; records.len()];
    let mut children = vec![Vec::<usize>::new(); records.len() + 1];
    let top = records.len();
    for (index, record) in records.iter().enumerate() {
        let parent_key = match &record.parent {
            Some(NodeRef::Key(key)) => Some(key.clone()),
            Some(NodeRef::Id(id)) if Some(*id) == scope.anchor() => None,
            Some(NodeRef::Id(id)) => Some(
                source
                    .node(*id)
                    .ok_or_else(|| Error::missing(*id))?
                    .key
                    .clone(),
            ),
            None => None,
        };
        let parent = if let Some(key) = &parent_key {
            if scope
                .anchor()
                .and_then(|id| source.node(id))
                .is_some_and(|node| node.key == *key)
            {
                None
            } else if let Some(parent) = keys.get(key).copied() {
                Some(parent)
            } else if !replace {
                let id = source
                    .id(key)
                    .ok_or_else(|| Error::invalid("page parent is neither known nor declared"))?;
                if !scope.parent_allowed(source, Some(id)) {
                    return Err(Error::invalid("page parent is outside its scope"));
                }
                None
            } else {
                return Err(Error::invalid("snapshot parent is not declared"));
            }
        } else {
            None
        };
        if matches!(scope, DataScope::Children(_)) && parent.is_some() {
            return Err(Error::invalid(
                "children slot input must contain direct children only",
            ));
        }
        parents[index] = match parent {
            Some(parent) => Some(NodeRef::Key(records[parent].key.clone())),
            None if !replace
                && parent_key
                    .as_ref()
                    .is_some_and(|key| source.id(key).is_some()) =>
            {
                Some(NodeRef::Key(parent_key.expect("known parent")))
            }
            None => scope.anchor().map(NodeRef::Id),
        };
        children[parent.unwrap_or(top)].push(index);
    }
    let mut order = Vec::with_capacity(records.len());
    let mut queue: VecDeque<_> = children[top].iter().copied().collect();
    while let Some(index) = queue.pop_front() {
        order.push(index);
        for child in children[index].iter().rev() {
            queue.push_front(*child);
        }
    }
    if order.len() != records.len() {
        return Err(Error::invalid("snapshot contains a parent cycle"));
    }
    if replace
        && complete
        && scope == DataScope::Forest
        && protected.is_empty()
        && let Some(operations) = append_import(source, records, &parents, &children, &order)
    {
        return Ok(operations);
    }
    let revision = source.revision().next()?;
    let mut candidate = source.clone();
    let mut operations = Vec::new();
    let mut apply = |operation: Operation, candidate: &mut Source| -> Result<()> {
        check_scope(candidate, scope, &operation, protected)?;
        candidate.apply(&operation, revision, limits, scope.anchor())?;
        operations.push(operation);
        Ok(())
    };
    for &index in &order {
        let record = &records[index];
        let parent = &parents[index];
        if let Some(id) = candidate.id(&record.key) {
            let node = candidate.node(id).expect("resolved key");
            if record.data.can_expand && !node.data.can_expand {
                apply(
                    Operation::Update {
                        node: NodeRef::Key(record.key.clone()),
                        patch: NodePatch {
                            can_expand: Some(true),
                            ..NodePatch::default()
                        },
                    },
                    &mut candidate,
                )?;
            }
            let parent_id = parent
                .as_ref()
                .map(|parent| candidate.resolve(parent))
                .transpose()?;
            if candidate.node(id).expect("existing node").parent != parent_id {
                apply(
                    Operation::Reparent {
                        node: NodeRef::Key(record.key.clone()),
                        parent: parent.clone(),
                        position: Position::Last,
                    },
                    &mut candidate,
                )?;
            }
        } else {
            let completeness = record.completeness.unwrap_or(
                if record.data.can_expand && (!complete || matches!(scope, DataScope::Children(_)))
                {
                    Completeness::Unknown
                } else {
                    Completeness::Complete
                },
            );
            apply(
                Operation::Insert {
                    key: record.key.clone(),
                    parent: parent.clone(),
                    position: Position::Last,
                    data: record.data.clone(),
                    completeness,
                },
                &mut candidate,
            )?;
        }
    }
    if replace {
        let mut pending: Vec<_> = candidate
            .child_sequence(scope.anchor())?
            .iter()
            .copied()
            .collect();
        while let Some(id) = pending.pop() {
            let node = candidate.node(id).ok_or_else(|| Error::missing(id))?;
            if !keys.contains_key(&node.key) {
                apply(Operation::Remove { node: id.into() }, &mut candidate)?;
            } else if !matches!(scope, DataScope::Children(_)) {
                pending.extend(node.children());
            }
        }
    }
    for &index in &order {
        let record = &records[index];
        let id = candidate.id(&record.key).expect("aligned key");
        let node = candidate.node(id).expect("aligned node");
        let completeness = record.completeness.unwrap_or(
            if complete && !matches!(scope, DataScope::Children(_)) {
                Completeness::Complete
            } else {
                node.completeness
            },
        );
        if *node.data != record.data || node.completeness != completeness {
            apply(
                Operation::Update {
                    node: NodeRef::Key(record.key.clone()),
                    patch: NodePatch {
                        label: Some(record.data.label.clone()),
                        can_expand: Some(record.data.can_expand),
                        foldable: Some(record.data.foldable),
                        hidden: Some(record.data.hidden),
                        score: Some(record.data.score),
                        icon: Some(record.data.icon.clone()),
                        highlight: Some(record.data.highlight.clone()),
                        right_text: Some(record.data.right_text.clone()),
                        fields: Some(record.data.fields.clone()),
                        payload: Some(record.data.payload.clone()),
                        completeness: Some(completeness),
                    },
                },
                &mut candidate,
            )?;
        }
    }
    if replace {
        for parent_index in std::iter::once(top).chain(order.iter().copied()) {
            if parent_index != top && matches!(scope, DataScope::Children(_)) {
                continue;
            }
            let parent = if parent_index == top {
                scope.anchor().map(NodeRef::Id)
            } else {
                Some(NodeRef::Key(records[parent_index].key.clone()))
            };
            let parent_id = parent
                .as_ref()
                .map(|parent| candidate.resolve(parent))
                .transpose()?;
            let desired: Vec<_> = children[parent_index]
                .iter()
                .map(|&index| NodeRef::Key(records[index].key.clone()))
                .collect();
            let desired_ids: Vec<_> = desired
                .iter()
                .map(|node| candidate.resolve(node))
                .collect::<Result<_>>()?;
            let actual: Vec<_> = candidate
                .child_sequence(parent_id)?
                .iter()
                .copied()
                .collect();
            if actual != desired_ids {
                apply(
                    Operation::Reorder {
                        parent,
                        children: desired,
                    },
                    &mut candidate,
                )?;
            }
        }
    }
    if replace
        && complete
        && let Some(anchor) = scope.anchor()
        && candidate
            .node(anchor)
            .is_some_and(|node| node.completeness != Completeness::Complete)
    {
        apply(
            Operation::Update {
                node: anchor.into(),
                patch: NodePatch {
                    completeness: Some(Completeness::Complete),
                    ..NodePatch::default()
                },
            },
            &mut candidate,
        )?;
    }
    Ok(operations)
}

/** Build the first complete forest directly; no existing state or identity needs reconciliation. */
fn initial_source(source: &Source, records: Vec<Record>, limits: &Limits) -> Result<Source> {
    use super::storage::{IndexedSequence, Map};
    if records.len() > limits.batch_nodes || records.len() > limits.nodes {
        return Err(Error::limit("initial forest node capacity exceeded"));
    }
    let revision = source.revision().next()?;
    let mut keys = HashMap::with_capacity(records.len());
    let mut sizes = Vec::with_capacity(records.len());
    let mut bytes = 0usize;
    let mut batch_bytes = 0usize;
    for (index, record) in records.iter().enumerate() {
        if keys.insert(record.key.clone(), index).is_some() {
            return Err(Error::invalid("duplicate key in snapshot"));
        }
        let size = record.data.validate()?.saturating_add(record.key.len());
        bytes = bytes.saturating_add(size);
        let parent_bytes = match &record.parent {
            Some(NodeRef::Key(key)) => key.len().saturating_add(16),
            _ => 0,
        };
        batch_bytes = batch_bytes
            .saturating_add(size)
            .saturating_add(16 + std::mem::size_of::<Operation>())
            .saturating_add(parent_bytes);
        if batch_bytes > limits.batch_bytes || bytes > limits.payload_bytes {
            return Err(Error::limit("initial forest payload capacity exceeded"));
        }
        if record
            .completeness
            .is_some_and(|value| value != Completeness::Complete)
        {
            return Err(Error::invalid(
                "complete snapshot cannot omit unknown or partial descendants",
            ));
        }
        sizes.push(size);
    }
    let mut parents = Vec::with_capacity(records.len());
    let mut children = vec![Vec::new(); records.len() + 1];
    let top = records.len();
    for (index, record) in records.iter().enumerate() {
        let parent = match &record.parent {
            Some(NodeRef::Key(key)) => Some(
                *keys
                    .get(key)
                    .ok_or_else(|| Error::invalid("snapshot parent is not declared"))?,
            ),
            Some(NodeRef::Id(id)) => return Err(Error::missing(*id)),
            None => None,
        };
        if parent.is_some_and(|parent| !records[parent].data.can_expand) {
            return Err(Error::invalid("a leaf cannot own children"));
        }
        parents.push(parent);
        children[parent.unwrap_or(top)].push(index);
    }
    let mut pending = children[top].clone();
    let mut visited = 0;
    while let Some(index) = pending.pop() {
        visited += 1;
        pending.extend(children[index].iter().copied());
    }
    if visited != records.len() {
        return Err(Error::invalid("snapshot contains a parent cycle"));
    }
    let ids = (0..records.len())
        .map(|_| identity().map(NodeId))
        .collect::<Result<Vec<_>>>()?;
    let mut nodes = Vec::with_capacity(records.len());
    let mut names = Vec::with_capacity(records.len());
    for (index, record) in records.into_iter().enumerate() {
        let id = ids[index];
        let data = Arc::new(record.data);
        let descendants =
            IndexedSequence::from_vec(children[index].iter().map(|&child| ids[child]).collect())?;
        let node = Node {
            _payloads: super::memory::Payload::node(record.key.clone(), data.clone()),
            id,
            key: record.key.clone(),
            parent: parents[index].map(|parent| ids[parent]),
            data,
            completeness: Completeness::Complete,
            load_state: LoadState::Idle,
            error: None,
            request_epoch: u64::from(!descendants.is_empty()),
            next_sequence: 1,
            modified: revision,
            subtree_revision: revision,
            children: descendants,
            bytes: sizes[index],
        };
        nodes.push((id, node));
        names.push((record.key, id));
        super::memory::check()?;
    }
    names.sort_unstable_by(|a, b| a.0.cmp(&b.0));
    let mut candidate = source.clone();
    candidate.nodes = Map::from_sorted(nodes);
    candidate.keys = Map::from_sorted(names);
    candidate.roots =
        IndexedSequence::from_vec(children[top].iter().map(|&child| ids[child]).collect())?;
    candidate.revision = revision;
    candidate.ancestry_revision = revision;
    candidate.bytes = bytes;
    super::memory::check()?;
    Ok(candidate)
}

impl Engine {
    pub fn create_provider(&mut self, scope: DataScope) -> Result<ProviderId> {
        scope.validate(&self.source)?;
        if self.providers.len() >= self.limits.states {
            return Err(Error::limit("provider capacity exceeded"));
        }
        if self
            .providers
            .values()
            .any(|provider| scope.overlaps(provider.scope, &self.source))
        {
            return Err(Error::invalid("provider scope overlaps an existing writer"));
        }
        let id = ProviderId(identity()?);
        self.providers.insert(id.0, Provider { scope });
        Ok(id)
    }

    pub fn release_provider(&mut self, provider: ProviderId) {
        self.providers.remove(&provider.0);
    }

    pub(crate) fn provider_scope(&self, id: ProviderId) -> Result<DataScope> {
        let scope = self
            .providers
            .get(&id.0)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "provider released"))?
            .scope;
        scope.validate(&self.source)?;
        Ok(scope)
    }

    pub fn import(&mut self, import: Import) -> Result<Reply> {
        if import.base_revision != self.source.revision() {
            return Err(Error::stale("base data revision changed"));
        }
        let _memory = self.memory.enter();
        if import.scope == DataScope::Forest
            && self.source.revision() == Revision::default()
            && self.source.is_empty()
            && self.states.is_empty()
            && self.providers.is_empty()
            && self.reads.is_empty()
            && self.queries.is_empty()
        {
            if import.records.is_empty() {
                return Ok(Reply::NoChange);
            }
            let source = initial_source(&self.source, import.records, &self.limits)?;
            let commit = self.commit.next()?;
            self.source = Arc::new(source);
            self.commit = commit;
            return Ok(self.applied(None, Vec::new()));
        }
        let operations = plan_import(
            &self.source,
            import.scope,
            &import.records,
            true,
            true,
            &self.limits,
            &[],
        )?;
        self.apply_batch(Batch {
            base_revision: import.base_revision,
            operations,
        })
    }

    pub fn provider_import(
        &mut self,
        provider: ProviderId,
        base: Revision,
        records: Vec<Record>,
    ) -> Result<Reply> {
        let scope = self.provider_scope(provider)?;
        if base != self.source.revision() {
            return Err(Error::stale("base data revision changed"));
        }
        let protected: Vec<_> = self
            .providers
            .iter()
            .filter(|(id, _)| **id != provider.0)
            .map(|(_, provider)| provider.scope)
            .collect();
        let _memory = self.memory.enter();
        let operations = plan_import(
            &self.source,
            scope,
            &records,
            true,
            true,
            &self.limits,
            &protected,
        )?;
        self.apply_batch(Batch {
            base_revision: base,
            operations,
        })
    }

    pub fn provider_batch(&mut self, provider: ProviderId, batch: Batch) -> Result<Reply> {
        let scope = self.provider_scope(provider)?;
        let protected: Vec<_> = self
            .providers
            .iter()
            .filter(|(id, _)| **id != provider.0)
            .map(|(_, provider)| provider.scope)
            .collect();
        check_batch_size(&batch.operations, &self.limits)?;
        if batch.base_revision != self.source.revision() {
            return Err(Error::stale("base data revision changed"));
        }
        let mut candidate = (*self.source).clone();
        let revision = candidate.revision().next()?;
        for operation in &batch.operations {
            check_scope(&candidate, scope, operation, &protected)?;
            candidate.apply(operation, revision, &self.limits, None)?;
        }
        self.apply_batch(batch)
    }
}

#[cfg(test)]
mod tests {
    use super::super::{Command, Context, SelectAction, Targets};
    use super::*;

    #[test]
    fn t_initial_import_matches_reconciliation_for_unordered_declarations() {
        let records = vec![
            Record {
                parent: Some("branch".into()),
                ..Record::new("leaf", NodeData::leaf("leaf"))
            },
            Record::new("root", NodeData::branch("root")),
            Record {
                parent: Some("root".into()),
                ..Record::new("branch", NodeData::branch("branch"))
            },
            Record {
                parent: Some("root".into()),
                ..Record::new("last", NodeData::leaf("last"))
            },
        ];
        let mut sources = Vec::new();
        for existing_state in [false, true] {
            let mut engine = Engine::new(Limits::default()).unwrap();
            if existing_state {
                engine
                    .create_state(Root::Forest(Arc::new([])), DisplayOptions::default())
                    .unwrap();
            }
            let empty = engine.source.clone();
            engine
                .import(Import {
                    base_revision: empty.revision(),
                    scope: DataScope::Forest,
                    records: records.clone(),
                })
                .unwrap();
            assert!(empty.is_empty());
            assert_eq!(empty.identity(), engine.source.identity());
            sources.push(engine.source);
        }
        for record in records {
            let shape = |source: &Source| {
                let node = source.node(source.id(&record.key).unwrap()).unwrap();
                (
                    node.data.clone(),
                    node.parent.map(|id| source.node(id).unwrap().key.clone()),
                    node.children()
                        .map(|id| source.node(id).unwrap().key.clone())
                        .collect::<Vec<_>>(),
                    node.completeness,
                )
            };
            assert_eq!(shape(&sources[0]), shape(&sources[1]));
        }
    }

    #[test]
    fn t_initial_import_rejects_invalid_forests_and_restores_the_budget() {
        for case in [
            "cycle",
            "parent",
            "leaf",
            "duplicate",
            "partial",
            "bytes",
            "memory",
        ] {
            let limits = Limits {
                batch_bytes: if case == "bytes" { 128 } else { 1024 * 1024 },
                memory_bytes: if case == "memory" { 64 } else { 1024 * 1024 },
                ..Limits::default()
            };
            let mut engine = Engine::new(limits).unwrap();
            let original = engine.source.clone();
            let memory = engine.memory.used();
            let mut records = vec![
                Record::new("root", NodeData::branch("root")),
                Record {
                    parent: Some("root".into()),
                    ..Record::new("child", NodeData::leaf("child"))
                },
            ];
            match case {
                "cycle" => {
                    records[0].parent = Some("child".into());
                    records[1].data.can_expand = true;
                }
                "parent" => records[1].parent = Some("absent".into()),
                "leaf" => records[0].data.can_expand = false,
                "duplicate" => records.push(records[1].clone()),
                "partial" => records[0].completeness = Some(Completeness::Partial),
                _ => {}
            }
            assert!(
                engine
                    .import(Import {
                        base_revision: original.revision(),
                        scope: DataScope::Forest,
                        records
                    })
                    .is_err(),
                "{case}"
            );
            assert!(Arc::ptr_eq(&original, &engine.source), "{case}");
            assert_eq!(engine.memory.used(), memory, "{case}");
        }
    }

    #[test]
    fn t_full_import_appends_then_reconciles_order_values_and_removal() {
        fn import(engine: &mut Engine, records: &[Record]) -> Reply {
            engine
                .import(Import {
                    base_revision: engine.source.revision(),
                    scope: DataScope::Forest,
                    records: records.to_vec(),
                })
                .unwrap()
        }
        fn child(key: &str, parent: &str, branch: bool) -> Record {
            Record {
                key: key.into(),
                parent: Some(parent.into()),
                data: if branch {
                    NodeData::branch(key)
                } else {
                    NodeData::leaf(key)
                },
                completeness: None,
            }
        }
        fn children(engine: &Engine, parent: NodeId) -> Vec<String> {
            engine
                .source
                .child_sequence(Some(parent))
                .unwrap()
                .iter()
                .map(|id| engine.source.node(*id).unwrap().key.to_string())
                .collect()
        }

        let mut engine = Engine::new(Limits::default()).unwrap();
        let root = Record::new("root", NodeData::branch("root"));
        import(&mut engine, std::slice::from_ref(&root));
        let root_id = engine.source.id("root").unwrap();
        let original = engine.source.clone();
        let state = engine
            .create_state(Root::ChildrenOf(root_id), DisplayOptions::default())
            .unwrap();
        engine
            .dispatch(
                state,
                Command::Select {
                    targets: Targets::Nodes(vec![root_id].into()),
                    action: SelectAction::Select,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        let nested = child("nested", "branch", false);
        let branch = child("branch", "root", true);
        let tail = child("tail", "root", false);
        import(
            &mut engine,
            &[nested.clone(), root.clone(), branch.clone(), tail.clone()],
        );
        let nested_id = engine.source.id("nested").unwrap();
        let tail_id = engine.source.id("tail").unwrap();
        assert_eq!(engine.source.id("root"), Some(root_id));
        assert_eq!(children(&engine, root_id), ["branch", "tail"]);
        assert!(
            engine.states[&state]
                .state
                .selection
                .value(&engine.source, nested_id)
                .unwrap()
        );
        assert_eq!(original.child_sequence(Some(root_id)).unwrap().len(), 0);

        let mut reordered = vec![
            root.clone(),
            child("first", "root", false),
            tail,
            branch,
            nested,
        ];
        import(&mut engine, &reordered);
        assert_eq!(children(&engine, root_id), ["first", "tail", "branch"]);
        assert_eq!(engine.source.id("tail"), Some(tail_id));
        assert!(matches!(import(&mut engine, &reordered), Reply::NoChange));
        reordered[2].data.label = "updated".into();
        import(&mut engine, &reordered);
        assert_eq!(
            engine.source.node(tail_id).unwrap().data.label.as_ref(),
            "updated"
        );

        import(&mut engine, &[root, child("first", "root", false)]);
        assert_eq!(children(&engine, root_id), ["first"]);
        assert!(engine.source.id("tail").is_none());
        assert!(engine.source.id("nested").is_none());
        assert_eq!(engine.source.id("root"), Some(root_id));
    }

    #[test]
    fn t_appended_import_rejections_preserve_the_published_source() {
        for limit in [false, true] {
            let mut engine = Engine::new(Limits {
                nodes: if limit { 2 } else { 100 },
                ..Limits::default()
            })
            .unwrap();
            let original = engine.source.clone();
            let mut records = vec![Record::new(
                "parent",
                if limit {
                    NodeData::branch("parent")
                } else {
                    NodeData::leaf("parent")
                },
            )];
            for key in ["one", "two"] {
                records.push(Record {
                    key: key.into(),
                    parent: Some("parent".into()),
                    data: NodeData::leaf(key),
                    completeness: None,
                });
            }
            let error = engine
                .import(Import {
                    base_revision: engine.source.revision(),
                    scope: DataScope::Forest,
                    records,
                })
                .unwrap_err();
            assert_eq!(
                error.code,
                if limit {
                    ErrorCode::ResourceLimit
                } else {
                    ErrorCode::InvalidUpdate
                }
            );
            assert!(Arc::ptr_eq(&original, &engine.source));
        }
    }

    #[test]
    fn t_native_payload_import_preserves_identity_and_retained_versions() {
        let mut engine = Engine::new(Limits::default()).unwrap();
        let original: Arc<[u8]> = Arc::from(&b"original resource"[..]);
        let updated: Arc<[u8]> = Arc::from(&b"updated resource"[..]);
        let fields = Arc::new(std::collections::BTreeMap::from([(
            "category".to_owned(),
            Value::String("queryable".into()),
        )]));
        let mut versions = Vec::new();
        for payload in [original.clone(), updated.clone()] {
            engine
                .import(Import {
                    base_revision: engine.source.revision(),
                    scope: DataScope::Forest,
                    records: vec![Record::new(
                        "item",
                        NodeData {
                            fields: fields.clone(),
                            payload: Some(payload),
                            ..NodeData::leaf("item")
                        },
                    )],
                })
                .unwrap();
            versions.push(engine.source.clone());
        }
        let id = versions[0].id("item").unwrap();
        assert_eq!(engine.source.id("item"), Some(id));
        assert!(!versions[0].same_content(&versions[1]));
        for payload in [None, Some(None)] {
            engine
                .apply_batch(Batch {
                    base_revision: engine.source.revision(),
                    operations: vec![Operation::Update {
                        node: id.into(),
                        patch: NodePatch {
                            label: Some("renamed".into()),
                            payload: payload.clone(),
                            ..NodePatch::default()
                        },
                    }],
                })
                .unwrap();
            let current = &engine.source.node(id).unwrap().data;
            assert!(Arc::ptr_eq(&current.fields, &fields));
            assert_eq!(current.payload.is_none(), payload.is_some());
        }
        for (source, expected) in versions.iter().zip([original, updated]) {
            assert!(Arc::ptr_eq(
                source.node(id).unwrap().data.payload.as_ref().unwrap(),
                &expected
            ));
        }
    }

    #[test]
    fn t_native_payload_respects_batch_and_source_byte_limits() {
        let limits = Limits {
            batch_bytes: 1024,
            payload_bytes: 512,
            ..Limits::default()
        };
        let mut engine = Engine::new(limits).unwrap();
        engine
            .import(Import {
                base_revision: engine.source.revision(),
                scope: DataScope::Forest,
                records: vec![Record::new("item", NodeData::leaf("item"))],
            })
            .unwrap();
        let original = engine.source.clone();
        for (size, expected) in [
            (2048, "batch byte capacity exceeded"),
            (512, "payload capacity exceeded"),
        ] {
            let error = engine
                .apply_batch(Batch {
                    base_revision: engine.source.revision(),
                    operations: vec![Operation::Update {
                        node: "item".into(),
                        patch: NodePatch {
                            payload: Some(Some(vec![0; size].into())),
                            ..NodePatch::default()
                        },
                    }],
                })
                .unwrap_err();
            assert_eq!(error.code, ErrorCode::ResourceLimit);
            assert_eq!(error.message.as_ref(), expected);
            assert!(Arc::ptr_eq(&engine.source, &original));
        }
    }

    #[test]
    fn t_children_provider_cannot_replace_its_anchor_payload() {
        let mut engine = Engine::new(Limits::default()).unwrap();
        engine
            .import(Import {
                base_revision: engine.source.revision(),
                scope: DataScope::Forest,
                records: vec![Record::new("root", NodeData::branch("root"))],
            })
            .unwrap();
        let root = engine.source.id("root").unwrap();
        let provider = engine.create_provider(DataScope::Children(root)).unwrap();
        let original = engine.source.clone();
        let error = engine
            .provider_batch(
                provider,
                Batch {
                    base_revision: engine.source.revision(),
                    operations: vec![Operation::Update {
                        node: root.into(),
                        patch: NodePatch {
                            completeness: Some(Completeness::Partial),
                            payload: Some(Some(Arc::from(&b"outside scope"[..]))),
                            ..NodePatch::default()
                        },
                    }],
                },
            )
            .unwrap_err();
        assert_eq!(error.code, ErrorCode::InvalidUpdate);
        assert!(Arc::ptr_eq(&engine.source, &original));
    }
}
