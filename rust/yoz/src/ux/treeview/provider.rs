use super::Reply;
use super::data::{Batch, NodePatch, NodeRef, Operation, Position, Source};
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
                && patch.fields.is_none();
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
