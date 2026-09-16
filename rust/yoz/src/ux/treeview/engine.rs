use super::command::*;
use super::data::{Batch, Change, ChangeKind, Operation, Source};
use super::model::*;
use super::projection::Snapshot;
use super::state::{SelectAction, State};
use super::tasks::*;
use std::collections::{BTreeMap, HashSet};
use std::sync::Arc;
use std::time::Instant;

#[derive(Clone, Default)]
pub(crate) struct Invalidation {
    pub pending: bool,
    pub layout: bool,
    pub full: bool,
    pub text: HashSet<NodeId>,
    pub changes: Vec<Change>,
    pub expanded: HashSet<NodeId>,
    pub selected: HashSet<NodeId>,
}

#[derive(Clone)]
pub(crate) struct StateEntry {
    pub state: State,
    pub frame: Arc<Snapshot>,
    pub dirty: Invalidation,
    pub task: Option<Task>,
    pub views: usize,
}

/** The single writer. Callers serialize access; all candidate versions stay private until commit. */
#[derive(Clone)]
pub struct Engine {
    pub(crate) source: Arc<Source>,
    pub(crate) states: BTreeMap<u64, StateEntry>,
    pub(crate) commit: Revision,
    pub(crate) limits: Limits,
    pub(crate) memory: Arc<super::memory::Budget>,
    pub(crate) providers: BTreeMap<u64, super::provider::Provider>,
    pub(crate) reads: BTreeMap<u64, super::reads::ReadWork>,
    pub(crate) read_queue: std::collections::VecDeque<NodeId>,
    pub(crate) manual_reads: HashSet<NodeId>,
    pub(crate) queries: BTreeMap<u64, super::query::Query>,
    pub(crate) query_work: BTreeMap<u64, super::query::QueryWork>,
    pub(crate) deferred_effects: Vec<Effect>,
}

impl Engine {
    pub fn new(limits: Limits) -> Result<Self> {
        Ok(Self {
            source: Arc::new(Source::empty()?),
            states: BTreeMap::new(),
            commit: Revision::default(),
            memory: super::memory::Budget::new(limits.memory_bytes),
            limits,
            providers: BTreeMap::new(),
            reads: BTreeMap::new(),
            read_queue: std::collections::VecDeque::new(),
            manual_reads: HashSet::new(),
            queries: BTreeMap::new(),
            query_work: BTreeMap::new(),
            deferred_effects: Vec::new(),
        })
    }

    pub fn source(&self) -> &Arc<Source> {
        &self.source
    }

    pub fn create_state(&mut self, root: Root, display: DisplayOptions) -> Result<u64> {
        let _memory = self.memory.enter();
        if self.states.len() >= self.limits.states {
            return Err(Error::limit("state capacity exceeded"));
        }
        if display.pattern.len() > 4096 {
            return Err(Error::limit("filter pattern exceeds 4096 bytes"));
        }
        let mut state = State::new(&self.source, root, display)?;
        let mut frame = Snapshot::build(
            self.source.clone(),
            &mut state,
            None,
            false,
            Arc::new([]),
            self.commit,
        )?;
        frame.queries = self
            .queries
            .values()
            .map(|query| query.info.clone())
            .collect();
        let frame = Arc::new(frame);
        self.memory.check()?;
        let id = state.id;
        self.states.insert(
            id,
            StateEntry {
                state,
                frame,
                dirty: Invalidation::default(),
                task: None,
                views: 0,
            },
        );
        Ok(id)
    }

    pub fn snapshot(&self, state: u64) -> Result<Arc<Snapshot>> {
        self.states
            .get(&state)
            .map(|entry| entry.frame.clone())
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state has been released"))
    }

    pub fn release_state(&mut self, state: u64) {
        self.states.remove(&state);
    }

    pub(crate) fn revisions(&self, state: Option<u64>) -> Revisions {
        let entry = state.and_then(|id| self.states.get(&id));
        Revisions {
            commit: self.commit,
            data: self.source.revision(),
            state: entry.map(|entry| entry.state.revision),
            selection: entry.map(|entry| entry.state.selection_revision),
        }
    }

    pub(crate) fn applied(&self, state: Option<u64>, effects: Vec<Effect>) -> Reply {
        Reply::Applied {
            revisions: self.revisions(state),
            effects: effects.into(),
        }
    }

    pub fn apply_batch(&mut self, batch: Batch) -> Result<Reply> {
        self.apply_operations(batch, None, None)
    }

    pub fn apply_task_batch(&mut self, batch: Batch, token: TaskUpdateToken) -> Result<Reply> {
        self.apply_operations(batch, None, Some(token))
    }

    pub(crate) fn apply_operations(
        &mut self,
        batch: Batch,
        request: Option<NodeId>,
        task_update: Option<TaskUpdateToken>,
    ) -> Result<Reply> {
        let _memory = self.memory.enter();
        if batch.base_revision != self.source.revision() {
            return Err(Error::stale("base data revision changed"));
        }
        super::provider::check_batch_size(&batch.operations, &self.limits)?;
        if batch.operations.is_empty() {
            return Ok(Reply::NoChange);
        }
        let revision = self.source.revision().next()?;
        let commit = self.commit.next()?;
        let mut source = (*self.source).clone();
        let mut states = self.states.clone();
        let mut effects = Vec::new();
        let mut invalidated = Vec::new();
        let mut structural = false;
        let mut own_state = None;
        let mut expected = Vec::new();
        if let Some(token) = task_update {
            for (&id, entry) in &states {
                if let Some(update) = entry.task.as_ref().and_then(|task| task.expected.as_ref())
                    && update.token == token
                {
                    own_state = Some(id);
                    expected = update.changes.to_vec();
                    break;
                }
            }
            if own_state.is_none() {
                return Err(Error::stale("task update authorization expired"));
            }
        }
        let mut expected_index = 0;
        for operation in &batch.operations {
            if let Operation::Reparent { node, .. } = operation {
                let id = source.resolve(node)?;
                for entry in states.values_mut() {
                    entry.state.preserve_reparent(&source, id)?;
                }
            }
            let old = source.clone();
            let change = source.apply(operation, revision, &self.limits, request)?;
            self.memory.check()?;
            let own = if task_update.is_some()
                && change.structural()
                && change.kind != ChangeKind::Reorder
            {
                let actual = match change.kind {
                    ChangeKind::Reparent => ExpectedChange::Reparent {
                        node: change.node.expect("reparent identity"),
                        parent: change.new_parent,
                    },
                    ChangeKind::Remove => ExpectedChange::Remove {
                        node: change.node.expect("removed identity"),
                    },
                    _ => {
                        return Err(Error::stale(
                            "task update contains an unexpected structural change",
                        ));
                    }
                };
                if expected.get(expected_index) != Some(&actual) {
                    return Err(Error::stale(
                        "task update does not match its authorized changes",
                    ));
                }
                expected_index += 1;
                true
            } else {
                false
            };
            structural |= change.structural();
            if !change.removed.is_empty() {
                invalidated.extend(change.removed.iter().copied());
            }
            for (&id, entry) in &mut states {
                entry.state.changed_source(&source, &change)?;
                if let Some(task) = &mut entry.task {
                    let required = request.is_some_and(|node| task.needed.contains(&node));
                    task.changed(
                        &old,
                        &source,
                        &change,
                        own && own_state == Some(id),
                        required,
                    );
                }
                entry.dirty.pending = true;
                let layout = Self::changes_layout(
                    &entry.state,
                    operation,
                    &change,
                    &entry.frame,
                    (&old, &source),
                );
                entry.dirty.layout |= layout;
                if let Some(node) = change.node {
                    entry.dirty.text.insert(node);
                }
                if !layout {
                    continue;
                }
                if entry.dirty.changes.len() < 4096 {
                    entry.dirty.changes.push(change.clone());
                } else {
                    entry.dirty.changes.clear();
                    entry.dirty.full = true;
                }
            }
        }
        if task_update.is_some() && expected_index != expected.len() {
            return Err(Error::stale("task update omitted an authorized change"));
        }
        for (&id, entry) in &mut states {
            entry.state.finish_source_batch(&source, structural)?;
            if own_state == Some(id)
                && let Some(task) = &mut entry.task
            {
                task.expected = None;
            }
            if let Root::ChildrenOf(root) = entry.state.root
                && self.source.contains(root)
                && !source.contains(root)
            {
                effects.push(Effect::RootUnavailable {
                    state: id,
                    node: root,
                });
            }
            effects.push(Effect::ViewChanged { state: id });
        }
        if !invalidated.is_empty() {
            effects.push(Effect::NodeInvalidated {
                nodes: invalidated.into(),
            });
        }
        self.memory.check()?;
        self.source = Arc::new(source);
        self.states = states;
        self.commit = commit;
        Ok(self.applied(None, effects))
    }

    fn changes_layout(
        state: &State,
        operation: &Operation,
        change: &Change,
        frame: &Snapshot,
        sources: (&Source, &Source),
    ) -> bool {
        if change.structural() {
            return true;
        }
        let Operation::Update { patch, .. } = operation else {
            return false;
        };
        let filter_changed = !state.display.pattern.is_empty()
            && change.node.is_none_or(|id| {
                sources
                    .0
                    .node(id)
                    .zip(sources.1.node(id))
                    .is_none_or(|(old, new)| {
                        !frame.unchanged_match(&state.display, &old.data.label, &new.data.label)
                    })
            });
        (patch.label.is_some() && (filter_changed || state.display.sort == Sort::Name))
            || (patch.score.is_some() && state.display.sort == Sort::Score)
            || (patch.hidden.is_some()
                && !state.display.show_hidden
                && !state.display.selected_only)
            || (patch.foldable.is_some()
                && state.display.compress
                && state.display.mode == Mode::Tree)
    }

    fn targets(
        &self,
        state: &State,
        targets: &Targets,
        action: Option<SelectAction>,
        scope: Scope,
        context: &Context,
    ) -> Result<Vec<NodeId>> {
        let (raw, frame) = match targets {
            Targets::Nodes(nodes) => (nodes.to_vec(), context.frame.as_deref()),
            Targets::Range { frame, start, end } => {
                if *start > *end || *end > frame.len() {
                    return Err(Error::invalid("input range is outside the captured frame"));
                }
                (
                    frame
                        .rows
                        .iter_from(*start)
                        .take(end - start)
                        .map(|row| row.id)
                        .collect(),
                    Some(frame.as_ref()),
                )
            }
        };
        if let Some(frame) = frame
            && (frame.source().identity() != self.source.identity() || frame.state_id() != state.id)
        {
            return Err(Error::stale("input frame belongs to another state"));
        }
        let resolved = if matches!(targets, Targets::Range { .. }) {
            let frame = frame.expect("range owns its frame");
            let original = State::normalize(frame.source(), &raw, scope)?;
            for id in &original {
                if !self.source.contains(*id) {
                    return Err(Error::missing(*id));
                }
            }
            let live: Vec<_> = raw
                .iter()
                .copied()
                .filter(|id| self.source.contains(*id))
                .collect();
            let current = State::normalize(&self.source, &live, scope)?;
            if original.iter().copied().collect::<HashSet<_>>()
                != current.iter().copied().collect::<HashSet<_>>()
            {
                return Err(Error::stale("range ancestor relationships changed"));
            }
            original
        } else {
            State::normalize(&self.source, &raw, scope)?
        };
        if action == Some(SelectAction::Toggle) && !resolved.is_empty() {
            let frame =
                frame.ok_or_else(|| Error::invalid("toggle requires the displayed frame"))?;
            for id in &resolved {
                if frame.state.selection.value(frame.source(), *id)?
                    != state.selection.value(&self.source, *id)?
                {
                    return Err(Error::stale("toggle marked value changed"));
                }
            }
        }
        Ok(resolved)
    }

    pub fn dispatch(&mut self, state_id: u64, command: Command, context: Context) -> Result<Reply> {
        let _memory = self.memory.enter();
        let mut entry = self
            .states
            .get(&state_id)
            .cloned()
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state has been released"))?;
        if let Some(expected) = context.expected_state {
            entry.state.check_revision(expected)?;
        }
        let command = match command {
            Command::ToggleExpanded { node, scope } => {
                let targets = Targets::Nodes(vec![node].into());
                self.targets(&entry.state, &targets, None, scope, &context)?;
                let frame = context.frame.as_ref().ok_or_else(|| {
                    Error::invalid("expansion toggle requires the displayed frame")
                })?;
                let expanded = frame.state.expanded(frame.source(), node)?;
                if expanded != entry.state.expanded(&self.source, node)? {
                    return Err(Error::stale("toggle expanded value changed"));
                }
                Command::SetExpanded {
                    targets,
                    value: !expanded,
                    scope,
                }
            }
            command => command,
        };
        if matches!(command, Command::SetRoot(_) | Command::SetDisplay(_))
            && context.expected_state.is_none()
        {
            return Err(Error::invalid(
                "absolute display changes require expected_state",
            ));
        }
        let mut effects = Vec::new();
        let changed = match command {
            Command::ToggleExpanded { .. } => unreachable!("expanded toggle resolved above"),
            Command::SetRoot(root) => {
                State::validate_root(&self.source, &root)?;
                if entry.state.root == root {
                    return Ok(Reply::NoChange);
                }
                entry.state.root = root;
                entry.state.revision = entry.state.revision.next()?;
                entry.dirty.layout = true;
                true
            }
            Command::SetDisplay(display) => {
                if display.pattern.len() > 4096 {
                    return Err(Error::limit("filter pattern exceeds 4096 bytes"));
                }
                if entry.state.display == display {
                    return Ok(Reply::NoChange);
                }
                entry.state.display = display;
                entry.state.revision = entry.state.revision.next()?;
                entry.dirty.layout = true;
                true
            }
            Command::SetExpanded {
                targets,
                value,
                scope,
            } => {
                let nodes = self.targets(&entry.state, &targets, None, scope, &context)?;
                let mut layout_changed = false;
                for id in &nodes {
                    if self
                        .source
                        .node(*id)
                        .is_some_and(|node| node.data.can_expand)
                    {
                        layout_changed |=
                            entry
                                .state
                                .expansion
                                .changes_value(&self.source, *id, value, scope)?;
                    }
                }
                let changed = entry
                    .state
                    .set_expanded(&self.source, &nodes, value, scope)?;
                entry.dirty.layout |=
                    changed && layout_changed && entry.state.display.mode == Mode::Tree;
                entry.dirty.expanded.extend(nodes);
                changed
            }
            Command::Select {
                targets,
                action,
                scope,
            } => {
                entry.state.check_unlocked()?;
                let nodes = self.targets(&entry.state, &targets, Some(action), scope, &context)?;
                let mut layout_changed = action == SelectAction::Toggle;
                if !layout_changed {
                    for id in &nodes {
                        layout_changed |= entry.state.selection.changes_value(
                            &self.source,
                            *id,
                            action == SelectAction::Select,
                            scope,
                        )?;
                    }
                }
                let changed = entry.state.select(&self.source, &nodes, action, scope)?;
                if entry.state.display.selected_only || entry.state.display.compress {
                    entry.dirty.selected.extend(nodes);
                }
                entry.dirty.layout |= changed
                    && layout_changed
                    && (entry.state.display.selected_only || entry.state.display.compress);
                changed
            }
            Command::ClearSelection => {
                entry.state.clear_selection()?;
                entry.dirty.layout |=
                    entry.state.display.selected_only || entry.state.display.compress;
                true
            }
            Command::SetCursor(node) => {
                if let Some(node) = node {
                    if !self.source.contains(node) {
                        return Err(Error::missing(node));
                    }
                    if entry.frame.position(node).is_none() {
                        return Ok(Reply::NoChange);
                    }
                }
                if entry.state.cursor == node {
                    return Ok(Reply::NoChange);
                }
                entry.state.cursor = node;
                entry.state.revision = entry.state.revision.next()?;
                true
            }
            Command::Navigate {
                frame,
                row,
                direction,
            } => {
                if frame.state_id() != state_id
                    || frame.source().identity() != self.source.identity()
                {
                    return Err(Error::stale("navigation frame belongs to another state"));
                }
                let Some(target) = frame
                    .navigate(row, direction)
                    .and_then(|row| frame.row(row))
                    .map(|row| row.id)
                else {
                    return Ok(Reply::NoChange);
                };
                if !self.source.contains(target) || entry.frame.position(target).is_none() {
                    return Ok(Reply::NoChange);
                }
                if entry.state.cursor == Some(target) {
                    return Ok(Reply::NoChange);
                }
                entry.state.cursor = Some(target);
                entry.state.revision = entry.state.revision.next()?;
                true
            }
            Command::InspectSelection => {
                let sources = entry.state.sources(&self.source)?;
                self.states.insert(state_id, entry);
                return Ok(Reply::Inspected {
                    revisions: self.revisions(Some(state_id)),
                    sources,
                });
            }
            Command::PrepareSources(lock) => {
                let revisions = self.revisions(Some(state_id));
                let task = entry
                    .task
                    .as_mut()
                    .ok_or_else(|| Error::stale("selection lock expired"))?;
                task.check(lock, None)?;
                if let Some((sources, source, revisions)) = &task.prepared {
                    return Ok(Reply::Ready {
                        revisions: *revisions,
                        sources: sources.clone(),
                        source: source.clone(),
                        cleanup: task.cleanup.expect("prepared cleanup"),
                    });
                }
                let sources = entry.state.sources(&self.source)?;
                if let Some(error) = sources.needed_children.iter().find_map(|id| {
                    self.source
                        .node(*id)
                        .and_then(|node| node.error.clone())
                        .or_else(|| {
                            self.query_for_slot(*id)
                                .and_then(|query| query.info.error.clone())
                        })
                }) {
                    let effect = self.fail_task(state_id, lock, error.clone())?;
                    self.deferred_effects.push(effect);
                    return Err(error);
                }
                let cleanup = task.prepare(&sources)?;
                if cleanup.is_some() {
                    task.prepared = Some((sources.clone(), self.source.clone(), revisions));
                }
                self.states.insert(state_id, entry);
                let revisions = self.revisions(Some(state_id));
                return Ok(match cleanup {
                    Some(cleanup) => Reply::Ready {
                        revisions,
                        sources,
                        cleanup,
                        source: self.source.clone(),
                    },
                    None => Reply::Pending { revisions, sources },
                });
            }
            Command::Unselect {
                lock,
                cleanup,
                successful,
            } => {
                let task = entry
                    .task
                    .as_mut()
                    .ok_or_else(|| Error::stale("selection lock expired"))?;
                task.check(lock, Some(cleanup))?;
                let mut seen = HashSet::new();
                let mut targets = Vec::new();
                for id in successful.iter().copied() {
                    if !task.roots.contains(&id) || !seen.insert(id) {
                        return Err(Error::stale(
                            "cleanup contains an unprepared or duplicate source",
                        ));
                    }
                    if task.removed.contains(&id) {
                        continue;
                    }
                    if !self.source.contains(id) {
                        return Err(Error::missing(id));
                    }
                    targets.push((id, false));
                }
                let revision = entry.state.revision.next()?;
                let selection_revision = entry.state.selection_revision.next()?;
                let changed =
                    entry
                        .state
                        .selection
                        .assign(&self.source, &targets, Scope::Subtree)?;
                task.cleaned = true;
                if changed {
                    entry.state.revision = revision;
                    entry.state.selection_revision = selection_revision;
                    entry.dirty.layout |=
                        entry.state.display.selected_only || entry.state.display.compress;
                }
                if !changed {
                    self.states.insert(state_id, entry);
                    return Ok(Reply::NoChange);
                }
                true
            }
        };
        if !changed {
            return Ok(Reply::NoChange);
        }
        self.memory.check()?;
        let commit = self.commit.next()?;
        entry.dirty.pending = true;
        effects.push(Effect::ViewChanged { state: state_id });
        self.states.insert(state_id, entry);
        self.commit = commit;
        Ok(self.applied(Some(state_id), effects))
    }

    pub fn lock_selection(
        &mut self,
        state_id: u64,
        expected: Revision,
        deadline: Option<Instant>,
    ) -> Result<Reply> {
        let mut entry = self
            .states
            .get(&state_id)
            .cloned()
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state has been released"))?;
        entry.state.check_unlocked()?;
        if entry.state.selection_revision != expected {
            return Err(Error::stale("selection revision changed"));
        }
        let task = Task::new(&entry.state.sources(&self.source)?, deadline)?;
        let token = task.lock;
        entry.state.revision = entry.state.revision.next()?;
        entry.state.locked = Some(token.0);
        entry.dirty.pending = true;
        entry.task = Some(task);
        let commit = self.commit.next()?;
        self.states.insert(state_id, entry);
        self.commit = commit;
        Ok(Reply::Locked {
            revisions: self.revisions(Some(state_id)),
            token,
        })
    }

    pub fn unlock_selection(&mut self, state_id: u64, token: LockToken) -> Result<Reply> {
        let mut entry = self
            .states
            .get(&state_id)
            .cloned()
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state has been released"))?;
        if entry.state.locked != Some(token.0) {
            return Err(Error::stale("selection lock expired"));
        }
        entry.state.revision = entry.state.revision.next()?;
        entry.state.locked = None;
        entry.task = None;
        entry.dirty.pending = true;
        let commit = self.commit.next()?;
        self.states.insert(state_id, entry);
        self.commit = commit;
        Ok(self.applied(
            Some(state_id),
            vec![Effect::ViewChanged { state: state_id }],
        ))
    }

    pub fn authorize_task_update(
        &mut self,
        state_id: u64,
        lock: LockToken,
        cleanup: CleanupToken,
        changes: Arc<[ExpectedChange]>,
    ) -> Result<TaskUpdateToken> {
        let entry = self
            .states
            .get_mut(&state_id)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state has been released"))?;
        let task = entry
            .task
            .as_mut()
            .ok_or_else(|| Error::stale("selection lock expired"))?;
        task.check(lock, Some(cleanup))?;
        task.authorize(&self.source, changes)
    }

    pub(crate) fn fail_task(
        &mut self,
        state_id: u64,
        lock: LockToken,
        error: Error,
    ) -> Result<Effect> {
        self.unlock_selection(state_id, lock)?;
        Ok(Effect::TaskFailed { lock, error })
    }

    pub fn expire_tasks(&mut self, now: Instant) -> Result<Vec<Effect>> {
        let expired: Vec<_> = self
            .states
            .iter()
            .filter_map(|(&id, entry)| {
                entry
                    .task
                    .as_ref()
                    .filter(|task| {
                        task.cleanup.is_none()
                            && task.deadline.is_some_and(|deadline| now >= deadline)
                    })
                    .map(|task| (id, task.lock))
            })
            .collect();
        expired
            .into_iter()
            .map(|(id, lock)| {
                self.fail_task(
                    id,
                    lock,
                    Error::new(ErrorCode::Stale, "source preparation deadline expired"),
                )
            })
            .collect()
    }

    pub fn project(&mut self) -> Vec<(u64, Result<Arc<Snapshot>>)> {
        let _memory = self.memory.enter();
        let mut frames = Vec::new();
        let queries: Arc<[_]> = self
            .queries
            .values()
            .map(|query| query.info.clone())
            .collect();
        for (&id, entry) in &mut self.states {
            if !entry.dirty.pending {
                continue;
            }
            let mut state = entry.state.clone();
            let result = Snapshot::rebuild(
                self.source.clone(),
                &mut state,
                &entry.frame,
                &entry.dirty,
                self.commit,
            )
            .and_then(|mut frame| {
                self.memory.check()?;
                frame.queries = queries.clone();
                Ok(Arc::new(frame))
            });
            if let Ok(frame) = &result {
                entry.state = state;
                entry.frame = frame.clone();
            }
            entry.dirty = Invalidation::default();
            frames.push((id, result));
        }
        frames
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ux::treeview::{NodeData, NodePatch, Position};

    fn insert(key: &str, parent: Option<NodeId>, branch: bool) -> Operation {
        Operation::Insert {
            key: key.into(),
            parent: parent.map(Into::into),
            position: Position::Last,
            data: if branch {
                NodeData::branch(key)
            } else {
                NodeData::leaf(key)
            },
            completeness: Completeness::Complete,
        }
    }

    fn batch(engine: &mut Engine, operations: Vec<Operation>) -> Result<Reply> {
        engine.apply_batch(Batch {
            base_revision: engine.source.revision(),
            operations,
        })
    }

    fn fixture() -> (Engine, u64, NodeId, NodeId, NodeId) {
        let mut engine = Engine::new(Limits::default()).unwrap();
        batch(
            &mut engine,
            vec![insert("A", None, true), insert("B", None, true)],
        )
        .unwrap();
        let a = engine.source.id("A").unwrap();
        let b = engine.source.id("B").unwrap();
        batch(&mut engine, vec![insert("C", Some(a), false)]).unwrap();
        let c = engine.source.id("C").unwrap();
        let state = engine
            .create_state(Root::Forest(vec![a, b].into()), DisplayOptions::default())
            .unwrap();
        (engine, state, a, b, c)
    }

    fn select(
        engine: &mut Engine,
        state: u64,
        nodes: &[NodeId],
        action: SelectAction,
        scope: Scope,
    ) -> Result<Reply> {
        engine.dispatch(
            state,
            Command::Select {
                targets: Targets::Nodes(nodes.into()),
                action,
                scope,
            },
            Context {
                frame: Some(engine.snapshot(state)?),
                ..Context::default()
            },
        )
    }

    #[test]
    fn t_failed_batch_discards_identity_and_every_state_patch() {
        let (mut engine, state, a, b, c) = fixture();
        select(
            &mut engine,
            state,
            &[a],
            SelectAction::Select,
            Scope::Subtree,
        )
        .unwrap();
        let other = engine
            .create_state(Root::Forest(vec![a, b].into()), DisplayOptions::default())
            .unwrap();
        select(
            &mut engine,
            other,
            &[b],
            SelectAction::Select,
            Scope::Subtree,
        )
        .unwrap();
        let source = engine.source.clone();
        let first_marks = engine.states[&state].state.selection.clone();
        let second_marks = engine.states[&other].state.selection.clone();
        let result = batch(
            &mut engine,
            vec![
                Operation::Reparent {
                    node: c.into(),
                    parent: Some(b.into()),
                    position: Position::Last,
                },
                insert("unpublished", None, false),
                Operation::Reparent {
                    node: b.into(),
                    parent: Some(c.into()),
                    position: Position::Last,
                },
            ],
        );
        assert!(result.is_err());
        assert!(Arc::ptr_eq(&engine.source, &source));
        assert_eq!(engine.source.node(c).unwrap().parent, Some(a));
        assert_eq!(engine.source.id("unpublished"), None);
        assert!(
            engine.states[&state]
                .state
                .selection
                .nodes
                .same_version(&first_marks.nodes)
        );
        assert!(
            engine.states[&other]
                .state
                .selection
                .nodes
                .same_version(&second_marks.nodes)
        );
    }

    #[test]
    fn t_reparent_preserves_each_old_chain_in_operation_order() {
        let (mut engine, state, a, b, c) = fixture();
        select(
            &mut engine,
            state,
            &[a],
            SelectAction::Select,
            Scope::Subtree,
        )
        .unwrap();
        select(
            &mut engine,
            state,
            &[b],
            SelectAction::Deselect,
            Scope::Subtree,
        )
        .unwrap();
        batch(
            &mut engine,
            vec![
                Operation::Reparent {
                    node: c.into(),
                    parent: Some(b.into()),
                    position: Position::Last,
                },
                Operation::Reparent {
                    node: c.into(),
                    parent: Some(a.into()),
                    position: Position::Last,
                },
            ],
        )
        .unwrap();
        assert!(
            !engine.states[&state]
                .state
                .selection
                .value(&engine.source, c)
                .unwrap()
        );
        assert_eq!(engine.states[&state].state.selection.generation, 2);
    }

    #[test]
    fn t_old_frame_range_keeps_ids_after_insert_and_rejects_changed_toggle() {
        let (mut engine, state, a, _, _) = fixture();
        let frame = engine.snapshot(state).unwrap();
        batch(
            &mut engine,
            vec![Operation::Insert {
                key: "X".into(),
                parent: None,
                position: Position::First,
                data: NodeData::leaf("X"),
                completeness: Completeness::Complete,
            }],
        )
        .unwrap();
        engine
            .dispatch(
                state,
                Command::Select {
                    targets: Targets::Range {
                        frame: frame.clone(),
                        start: 0,
                        end: 1,
                    },
                    action: SelectAction::Select,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        let result = engine.dispatch(
            state,
            Command::Select {
                targets: Targets::Range {
                    frame,
                    start: 0,
                    end: 1,
                },
                action: SelectAction::Toggle,
                scope: Scope::Subtree,
            },
            Context::default(),
        );
        assert_eq!(result.unwrap_err().code, ErrorCode::Stale);
        assert!(
            engine.states[&state]
                .state
                .selection
                .value(&engine.source, a)
                .unwrap()
        );
        assert!(
            !engine.states[&state]
                .state
                .selection
                .value(&engine.source, engine.source.id("X").unwrap())
                .unwrap()
        );
    }

    #[test]
    fn t_removed_covered_child_does_not_invalidate_recursive_range() {
        let (mut engine, state, a, _, c) = fixture();
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![a].into()),
                    value: true,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        engine.project();
        let frame = engine.snapshot(state).unwrap();
        batch(&mut engine, vec![Operation::Remove { node: c.into() }]).unwrap();
        engine
            .dispatch(
                state,
                Command::Select {
                    targets: Targets::Range {
                        frame: frame.clone(),
                        start: 0,
                        end: 2,
                    },
                    action: SelectAction::Select,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        let own = engine.dispatch(
            state,
            Command::Select {
                targets: Targets::Range {
                    frame,
                    start: 0,
                    end: 2,
                },
                action: SelectAction::Select,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        );
        assert_eq!(own.unwrap_err().code, ErrorCode::MissingNode);
    }

    #[test]
    fn t_task_cleanup_is_atomic_and_does_not_recover_after_external_move_back() {
        let (mut engine, state, a, b, _) = fixture();
        select(
            &mut engine,
            state,
            &[a, b],
            SelectAction::Select,
            Scope::Subtree,
        )
        .unwrap();
        let selection = engine.states[&state].state.selection_revision;
        let Reply::Locked { token, .. } = engine.lock_selection(state, selection, None).unwrap()
        else {
            panic!("lock");
        };
        let Reply::Ready { cleanup, .. } = engine
            .dispatch(state, Command::PrepareSources(token), Context::default())
            .unwrap()
        else {
            panic!("ready");
        };
        assert_eq!(
            select(
                &mut engine,
                state,
                &[a],
                SelectAction::Deselect,
                Scope::Subtree
            )
            .unwrap_err()
            .code,
            ErrorCode::Busy
        );
        batch(
            &mut engine,
            vec![
                Operation::Reparent {
                    node: b.into(),
                    parent: Some(a.into()),
                    position: Position::Last,
                },
                Operation::Reparent {
                    node: b.into(),
                    parent: None,
                    position: Position::Last,
                },
            ],
        )
        .unwrap();
        let generation = engine.states[&state].state.selection.generation;
        let cleanup = engine.dispatch(
            state,
            Command::Unselect {
                lock: token,
                cleanup,
                successful: vec![a].into(),
            },
            Context::default(),
        );
        assert_eq!(cleanup.unwrap_err().code, ErrorCode::Stale);
        assert_eq!(engine.states[&state].state.selection.generation, generation);
        engine.unlock_selection(state, token).unwrap();
        let revision = engine.states[&state].state.selection_revision;
        engine.lock_selection(state, revision, None).unwrap();
        assert_eq!(
            engine.unlock_selection(state, token).unwrap_err().code,
            ErrorCode::Stale
        );
    }

    #[test]
    fn t_metadata_preserves_cleanup_but_task_changes_require_exact_authorization() {
        let (mut engine, state, a, b, _) = fixture();
        select(
            &mut engine,
            state,
            &[a],
            SelectAction::Select,
            Scope::Subtree,
        )
        .unwrap();
        let revision = engine.states[&state].state.selection_revision;
        let Reply::Locked { token, .. } = engine.lock_selection(state, revision, None).unwrap()
        else {
            panic!("lock");
        };
        let Reply::Ready { cleanup, .. } = engine
            .dispatch(state, Command::PrepareSources(token), Context::default())
            .unwrap()
        else {
            panic!("ready");
        };
        batch(
            &mut engine,
            vec![Operation::Update {
                node: a.into(),
                patch: NodePatch {
                    label: Some("renamed".into()),
                    ..NodePatch::default()
                },
            }],
        )
        .unwrap();
        let authorization = engine
            .authorize_task_update(
                state,
                token,
                cleanup,
                vec![ExpectedChange::Reparent {
                    node: a,
                    parent: Some(b),
                }]
                .into(),
            )
            .unwrap();
        engine
            .apply_task_batch(
                Batch {
                    base_revision: engine.source.revision(),
                    operations: vec![Operation::Reparent {
                        node: a.into(),
                        parent: Some(b.into()),
                        position: Position::Last,
                    }],
                },
                authorization,
            )
            .unwrap();
        engine
            .dispatch(
                state,
                Command::Unselect {
                    lock: token,
                    cleanup,
                    successful: vec![a].into(),
                },
                Context::default(),
            )
            .unwrap();
        assert!(
            !engine.states[&state]
                .state
                .selection
                .value(&engine.source, a)
                .unwrap()
        );
        assert!(
            engine
                .dispatch(
                    state,
                    Command::Unselect {
                        lock: token,
                        cleanup,
                        successful: vec![a].into()
                    },
                    Context::default()
                )
                .is_err()
        );
    }
}
