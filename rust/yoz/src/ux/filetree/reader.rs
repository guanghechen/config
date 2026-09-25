use super::resource;
use super::scan::{Page, Reservation, Scan};
use super::work::{Demand, Dirty, Request, submit, wait};
use crate::ux::treeview::{
    Action, Effect, Engine, Error, NativeAction, NativeReader, ReadToken, Reply, Result,
    WeakDataHandle,
};
use std::collections::{BTreeMap, HashSet};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

fn refreshing_ancestor(
    engine: &Engine,
    dirty: &crate::ux::treeview::storage::Map<crate::ux::treeview::NodeId, Demand>,
    node: crate::ux::treeview::NodeId,
) -> bool {
    let mut parent = engine.source().node(node).and_then(|node| node.parent);
    while let Some(id) = parent {
        if dirty.get(&id).is_some()
            || engine.manual_reads.contains(&id)
            || engine.observed_reads.contains(&id)
        {
            return true;
        }
        parent = engine.source().node(id).and_then(|node| node.parent);
    }
    false
}

fn can_admit_refresh(engine: &Engine, node: crate::ux::treeview::NodeId) -> bool {
    let leased: HashSet<_> = engine.leased_reads.values().copied().collect();
    let requested: HashSet<_> = engine
        .manual_reads
        .iter()
        .chain(engine.observed_reads.iter())
        .chain(leased.iter())
        .copied()
        .collect();
    let retained = requested
        .iter()
        .filter(|&&id| id == node || leased.contains(&id) || !engine.source().within(node, id))
        .count();
    retained + usize::from(!requested.contains(&node)) <= engine.limits.queued_reads
}

struct Slot {
    scan: Mutex<Option<Scan>>,
    cancelled: AtomicBool,
}

pub(crate) struct Reader {
    watcher: super::watch::Watcher,
    probes: BTreeMap<crate::ux::treeview::NodeId, (Request<Reply>, u64)>,
    index: Arc<Mutex<super::index::Index>>,
    dirty: Dirty,
    refresh: Option<crate::ux::treeview::Ticket>,
    slots: BTreeMap<u64, Arc<Slot>>,
    pending: BTreeMap<u64, (ReadToken, u64)>,
    staging: Arc<AtomicUsize>,
}

impl Reader {
    pub fn new(
        index: Arc<Mutex<super::index::Index>>,
        dirty: Dirty,
        interest: Arc<Mutex<super::watch::Interest>>,
    ) -> Self {
        Self {
            watcher: super::watch::Watcher::new(interest, dirty.clone()),
            probes: BTreeMap::new(),
            index,
            dirty,
            refresh: None,
            slots: BTreeMap::new(),
            pending: BTreeMap::new(),
            staging: Arc::new(AtomicUsize::new(0)),
        }
    }
}

impl Drop for Reader {
    fn drop(&mut self) {
        for slot in self.slots.values() {
            slot.cancelled.store(true, Ordering::Release);
        }
    }
}

impl NativeReader for Reader {
    fn effect(&mut self, effect: &Effect) -> bool {
        match effect {
            Effect::NeedChildren { token, sequence } => {
                self.pending.insert(token.work, (*token, *sequence));
                true
            }
            Effect::CancelChildren { token } => {
                if let Some(slot) = self.slots.remove(&token.work) {
                    slot.cancelled.store(true, Ordering::Release);
                }
                self.pending.insert(token.work, (*token, 0));
                true
            }
            _ => false,
        }
    }

    fn publish(&mut self, engine: &Engine, data: &WeakDataHandle) {
        let _memory = engine.memory.enter();
        let moving = self
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .moving;
        let move_blocks = |node| {
            moving.is_some_and(|root| {
                engine.source().within(root, node) || engine.source().within(node, root)
            })
        };
        self.watcher.publish(
            engine,
            data,
            &self.index.lock().unwrap_or_else(|error| error.into_inner()),
        );
        let completed: Vec<_> = self
            .probes
            .iter()
            .filter_map(|(id, (request, generation))| {
                request.poll().map(|result| (*id, *generation, result))
            })
            .collect();
        for (id, generation, result) in completed {
            self.probes.remove(&id);
            if matches!(&result, Err(error) if matches!(error.code,
                crate::ux::treeview::ErrorCode::Stale | crate::ux::treeview::ErrorCode::Busy))
            {
                /* Keep retries private: a later NoChange must not leave a sticky watch error. */
                continue;
            }
            {
                let mut dirty = self.dirty.lock().unwrap_or_else(|error| error.into_inner());
                if dirty.get(&id).map(|demand| demand.generation) == Some(generation) {
                    dirty.remove(&id);
                }
            }
            if let Err(error) = result {
                self.watcher.error(error);
            }
        }
        if self
            .refresh
            .as_ref()
            .is_some_and(|ticket| ticket.poll().is_some())
        {
            self.refresh = None;
        }
        if self.refresh.is_none() {
            let mut dirty = self.dirty.lock().unwrap_or_else(|error| error.into_inner());
            let requested: HashSet<_> = engine
                .manual_reads
                .iter()
                .chain(engine.observed_reads.iter())
                .chain(engine.leased_reads.values())
                .copied()
                .collect();
            let capacity = engine.limits.queued_reads.saturating_sub(requested.len());
            let mut ancestors = BTreeMap::new();
            /* Full queues only need to inspect the ancestors of their bounded request set. */
            for id in requested {
                let mut parent = engine.source().node(id).and_then(|node| node.parent);
                let mut pending = None;
                while let Some(id) = parent {
                    if let Some(demand) = dirty.get(&id) {
                        pending = Some((id, *demand));
                    }
                    parent = engine.source().node(id).and_then(|node| node.parent);
                }
                if let Some((id, demand)) = pending {
                    ancestors.insert(id, demand);
                }
            }
            let mut ids: Vec<_> = ancestors
                .into_iter()
                .filter(|(id, _)| !refreshing_ancestor(engine, &dirty, *id))
                .filter(|(id, _)| !move_blocks(*id))
                .filter(|(id, _)| {
                    engine
                        .source()
                        .node(*id)
                        .is_some_and(|node| node.data.can_expand)
                        && can_admit_refresh(engine, *id)
                })
                .take(64)
                .collect();
            let more: Vec<_> = dirty
                .iter()
                .filter(|(id, _)| !ids.iter().any(|(ancestor, _)| ancestor == *id))
                .filter(|(id, _)| !refreshing_ancestor(engine, &dirty, **id))
                .filter(|(id, _)| !move_blocks(**id))
                .take(capacity.min(64 - ids.len()))
                .map(|(id, generation)| (*id, *generation))
                .collect();
            ids.extend(more);
            let mut live = Vec::new();
            for (id, generation) in ids {
                if generation.observed && !engine.observed_interest(id) {
                    dirty.remove(&id);
                    continue;
                }
                if engine
                    .source()
                    .node(id)
                    .is_some_and(|node| node.data.can_expand)
                {
                    live.push((id, generation));
                } else if engine.source().contains(id) {
                    if self.probes.len() < 4 && !self.probes.contains_key(&id) {
                        let source = engine.source().clone();
                        let data = data.clone();
                        let index = self.index.clone();
                        let observed = generation.observed;
                        let request = Request::run(move || {
                            let path = resource::path(&source, id)?;
                            let entry = match super::Entry::read(&path) {
                                Ok(mut entry) => {
                                    #[cfg(any(target_os = "macos", windows))]
                                    {
                                        entry.name = resource::observed_name(&path)?;
                                    }
                                    Ok(Some(entry))
                                }
                                Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                                    Ok(None)
                                }
                                Err(error) => Err(resource::io_error("probe resource", error)),
                            };
                            let data = data.upgrade().ok_or_else(|| {
                                Error::new(
                                    crate::ux::treeview::ErrorCode::Disposed,
                                    "Filetree released",
                                )
                            })?;
                            wait(data.submit(Action::Native(Box::new(Probe {
                                source,
                                node: id,
                                path,
                                entry,
                                index,
                                observed,
                            }))))
                        });
                        self.probes.insert(id, (request, generation.generation));
                    }
                } else {
                    dirty.remove(&id);
                }
            }
            if !live.is_empty() {
                if let Some(data) = data.upgrade() {
                    self.refresh = Some(data.submit(Action::Native(Box::new(RefreshDemand {
                        nodes: live,
                        dirty: self.dirty.clone(),
                    }))));
                }
            }
        }
        self.slots.retain(|work, slot| {
            let active = engine.reads.get(work).is_some_and(|read| !read.cancelled);
            if !active {
                slot.cancelled.store(true, Ordering::Release);
            }
            active
        });
        let pending = std::mem::take(&mut self.pending);
        for (work, (token, sequence)) in pending {
            if sequence == 0 {
                if let Some(data) = data.upgrade() {
                    data.submit(Action::ChildrenCancelled(token));
                }
                continue;
            }
            if engine.check_read(token, sequence).is_err() {
                continue;
            }
            if !engine.needed(token.node) {
                if let Some(data) = data.upgrade() {
                    data.submit(Action::ChildrenCancelled(token));
                }
                continue;
            }
            if move_blocks(token.node) {
                self.pending.insert(work, (token, sequence));
                continue;
            }
            if refreshing_ancestor(
                engine,
                &self.dirty.lock().unwrap_or_else(|error| error.into_inner()),
                token.node,
            ) {
                /* Waiting descendants must release slots needed to start the ancestor. */
                if let Some(data) = data.upgrade() {
                    data.submit(Action::Native(Box::new(Restart { token, sequence })));
                }
                continue;
            }
            if sequence > 1
                && engine.states.values().any(|entry| entry.views != 0)
                && data
                    .upgrade()
                    .is_some_and(|data| !data.publication_acknowledged(engine.source().revision()))
            {
                self.pending.insert(work, (token, sequence));
                continue;
            }
            let slot = self
                .slots
                .entry(work)
                .or_insert_with(|| {
                    Arc::new(Slot {
                        scan: Mutex::new(None),
                        cancelled: AtomicBool::new(false),
                    })
                })
                .clone();
            let source = engine.source().clone();
            let memory = engine.memory.clone();
            let staging = self.staging.clone();
            let data = data.clone();
            let index = self.index.clone();
            let dirty = self.dirty.clone();
            let scheduled = submit(Box::new(move || {
                if slot.cancelled.load(Ordering::Acquire) {
                    return;
                }
                let mut context = resource::path(&source, token.node).ok().zip(
                    resource::entry(&source, token.node)
                        .ok()
                        .map(|entry| entry.identity),
                );
                let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    let scan = slot
                        .scan
                        .lock()
                        .unwrap_or_else(|error| error.into_inner())
                        .take();
                    let mut scan = match scan {
                        Some(scan) => scan,
                        None => Scan::new(
                            &source,
                            token.node,
                            Reservation::new(memory.clone(), staging.clone()),
                        )?,
                    };
                    context = Some(scan.context());
                    let page = scan.page(
                        token.node,
                        Reservation::new(memory, staging),
                        &slot.cancelled,
                    )?;
                    if !page.done {
                        *slot.scan.lock().unwrap_or_else(|error| error.into_inner()) = Some(scan);
                    }
                    Ok(page)
                }))
                .unwrap_or_else(|_| Err(Error::invalid("directory worker panicked")));
                if let Some(data) = data.upgrade() {
                    if slot.cancelled.load(Ordering::Acquire) {
                        data.submit(Action::ChildrenCancelled(token));
                    } else {
                        match result {
                            Ok(page) => {
                                data.submit(Action::Native(Box::new(Completion {
                                    token,
                                    sequence,
                                    page,
                                    index,
                                })));
                            }
                            Err(error) => {
                                let mut retargeted = None;
                                let unavailable = context.clone().and_then(|(path, expected)| {
                                    let gone = match super::Entry::read(&path) {
                                        Ok(entry) => {
                                            if entry.identity == expected
                                                && resource::entry(&source, token.node).is_ok_and(
                                                    |old| {
                                                        old.kind == super::Kind::Link
                                                            && (old.target != entry.target
                                                                || old.target_unknown
                                                                    != entry.target_unknown)
                                                    },
                                                )
                                            {
                                                retargeted = Some((path.clone(), entry.clone()));
                                            }
                                            entry.identity != expected
                                        }
                                        Err(error) => error.kind() == std::io::ErrorKind::NotFound,
                                    };
                                    gone.then_some((path, expected))
                                });
                                data.submit(Action::Native(Box::new(Failure {
                                    source,
                                    token,
                                    sequence,
                                    error,
                                    context,
                                    unavailable,
                                    retargeted,
                                    index,
                                    dirty,
                                })));
                            }
                        }
                    }
                }
            }));
            if scheduled.is_err() {
                self.pending.insert(work, (token, sequence));
            }
        }
    }
}

struct Completion {
    token: ReadToken,
    sequence: u64,
    page: Page,
    index: Arc<Mutex<super::index::Index>>,
}
impl NativeAction for Completion {
    fn bytes(&self) -> usize {
        self.page.bytes
    }
    fn completion(&self) -> Option<u64> {
        Some(self.token.work)
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        engine
            .check_read(self.token, self.sequence)
            .or_else(|error| {
                engine.children_failed(self.token, self.sequence, error.clone())?;
                Err(error)
            })?;
        let valid = (|| {
            let entry = resource::entry(engine.source(), self.token.node)?;
            if entry.identity != self.page.identity
                || entry.target_identity() != self.page.target
                || resource::path(engine.source(), self.token.node)? != self.page.path
            {
                return Err(Error::stale(
                    "directory resource changed before page commit",
                ));
            }
            for operation in &self.page.operations {
                use crate::ux::treeview::Operation;
                let (node, children) = match operation {
                    Operation::Update { node, patch } => {
                        let Some(fields) = &patch.fields else {
                            continue;
                        };
                        let node = engine.source().resolve(node)?;
                        let old = resource::entry(engine.source(), node)?;
                        let entry = super::Entry::from_fields(fields)
                            .map_err(|error| resource::io_error("decode page resource", error))?;
                        if entry == old {
                            continue;
                        }
                        (node, resource::ends_children(&old, &entry))
                    }
                    Operation::Remove { node } => (engine.source().resolve(node)?, true),
                    Operation::Reparent { node, .. } => (engine.source().resolve(node)?, false),
                    _ => continue,
                };
                if !resource::unchanged(&self.page.source, engine.source(), node, children) {
                    return Err(Error::stale("page resource changed during enumeration"));
                }
            }
            if self.page.done {
                let received = &engine
                    .reads
                    .get(&self.token.work)
                    .expect("validated read")
                    .received;
                let members: HashSet<&str> = self.page.members.iter().map(AsRef::as_ref).collect();
                /* The last page also removes unobserved members without explicit operations. */
                for id in engine
                    .source()
                    .node(self.token.node)
                    .expect("scan directory")
                    .children()
                {
                    let node = engine.source().node(id).expect("scan child");
                    if received.position(&id).is_none()
                        && !members.contains(node.key.as_ref())
                        && !resource::unchanged(&self.page.source, engine.source(), id, true)
                    {
                        return Err(Error::stale("unobserved child changed during enumeration"));
                    }
                }
            }
            Ok(())
        })();
        if valid.is_err() {
            return restart(engine, self.token);
        }
        let _memory = engine.memory.enter();
        let mut candidate = engine.clone();
        let mut index = self.index.lock().unwrap_or_else(|error| error.into_inner());
        let mut next = index.clone();
        let operations = resource::retarget_children(engine.source(), self.page.operations)?;
        let reply = match candidate.children_delta(
            self.token,
            self.sequence,
            operations.clone(),
            self.page.members,
            self.page.done,
        ) {
            Ok(reply) => reply,
            Err(error) => {
                drop(candidate);
                drop(next);
                return engine.children_failed(self.token, self.sequence, error);
            }
        };
        next.update(engine.source(), candidate.source(), &operations)?;
        if self.page.done {
            /* Complete enumeration alone may remove members absent from every page. */
            for id in engine
                .source()
                .node(self.token.node)
                .expect("scan directory")
                .children()
            {
                if !candidate.source().contains(id) {
                    next.update(
                        engine.source(),
                        candidate.source(),
                        &[crate::ux::treeview::Operation::Remove { node: id.into() }],
                    )?;
                }
            }
        }
        if let Err(error) = engine.memory.check() {
            drop(next);
            drop(candidate);
            return engine.children_failed(self.token, self.sequence, error);
        }
        *engine = candidate;
        *index = next;
        Ok(reply)
    }
}

struct Restart {
    token: ReadToken,
    sequence: u64,
}
impl NativeAction for Restart {
    fn bytes(&self) -> usize {
        std::mem::size_of::<Self>()
    }
    fn completion(&self) -> Option<u64> {
        Some(self.token.work)
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        if let Err(error) = engine.check_read(self.token, self.sequence) {
            return engine.children_failed(self.token, self.sequence, error);
        }
        restart(engine, self.token)
    }
}

pub(super) fn restart(engine: &mut Engine, token: ReadToken) -> Result<Reply> {
    let manual = engine.manual_reads.contains(&token.node);
    let observed = engine.observed_reads.contains(&token.node);
    let leases = engine.leased_reads.clone();
    let persistent = manual || leases.values().any(|node| *node == token.node);
    let mut candidate = engine.clone();
    candidate.children_cancelled(token)?;
    /* Restart changes the read epoch, not the lifetime of its callers' leases. */
    candidate.leased_reads = leases;
    let reply = if persistent {
        let reply = candidate.request_children(&[token.node], true)?;
        if !manual {
            candidate.manual_reads.remove(&token.node);
        }
        if observed {
            candidate.observed_reads.insert(token.node);
        }
        reply
    } else {
        candidate.request_observed_children(&[token.node], true)?
    };
    *engine = candidate;
    Ok(reply)
}

struct Failure {
    source: Arc<crate::ux::treeview::Source>,
    token: ReadToken,
    sequence: u64,
    error: Error,
    context: Option<(std::path::PathBuf, super::FileIdentity)>,
    unavailable: Option<(std::path::PathBuf, super::FileIdentity)>,
    retargeted: Option<(std::path::PathBuf, super::Entry)>,
    dirty: Dirty,
    index: Arc<Mutex<super::index::Index>>,
}
impl NativeAction for Failure {
    fn bytes(&self) -> usize {
        self.error.message.len() + 256
    }
    fn completion(&self) -> Option<u64> {
        Some(self.token.work)
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        if engine.check_read(self.token, self.sequence).is_err() {
            return engine.children_failed(self.token, self.sequence, self.error);
        }
        if refreshing_ancestor(
            engine,
            &self.dirty.lock().unwrap_or_else(|error| error.into_inner()),
            self.token.node,
        ) {
            return restart(engine, self.token);
        }
        if let Some((path, identity)) = self.context {
            if resource::path(engine.source(), self.token.node)? != path
                || resource::entry(engine.source(), self.token.node)?.identity != identity
            {
                return restart(engine, self.token);
            }
        }
        if let Some((path, mut entry)) = self.retargeted {
            if resource::entry(engine.source(), self.token.node)?.identity == entry.identity
                && resource::path(engine.source(), self.token.node)? == path
            {
                use crate::ux::treeview::{Batch, NodePatch, Operation};
                let _memory = engine.memory.enter();
                if let Some(parent) = engine
                    .source()
                    .node(self.token.node)
                    .and_then(|node| node.parent)
                {
                    entry.cycle = entry.target_identity().is_some_and(|target| {
                        resource::ancestors(engine.source(), parent)
                            .is_ok_and(|ids| ids.contains(&target))
                    });
                }
                let old = resource::entry(engine.source(), self.token.node)?;
                entry.retain_unknown_target(&old);
                if entry != old
                    && !resource::unchanged(
                        &self.source,
                        engine.source(),
                        self.token.node,
                        resource::ends_children(&old, &entry),
                    )
                {
                    return restart(engine, self.token);
                }
                let mut candidate = engine.clone();
                let data = entry.node_data();
                let mut operations = vec![Operation::Update {
                    node: self.token.node.into(),
                    patch: NodePatch {
                        fields: Some(data.fields),
                        can_expand: Some(data.can_expand),
                        ..NodePatch::default()
                    },
                }];
                if old.sort_key() != entry.sort_key() {
                    let parent = engine
                        .source()
                        .node(self.token.node)
                        .and_then(|node| node.parent);
                    operations.push(Operation::Reparent {
                        node: self.token.node.into(),
                        parent: parent.map(Into::into),
                        position: resource::position(
                            engine.source(),
                            parent,
                            &entry,
                            Some(self.token.node),
                        )?,
                    });
                }
                let operations = resource::retarget_children(engine.source(), operations)?;
                let mut effects = candidate
                    .apply_batch(Batch {
                        base_revision: candidate.source().revision(),
                        operations: operations.clone(),
                    })?
                    .into_effects();
                if entry.target_unknown {
                    effects.extend(
                        candidate
                            .children_failed(self.token, self.sequence, self.error.clone())?
                            .into_effects(),
                    );
                    candidate.set_slot(
                        self.token.node,
                        Some(crate::ux::treeview::Completeness::Partial),
                        crate::ux::treeview::LoadState::Error,
                        Some(self.error),
                        None,
                    )?;
                } else if entry.directory() {
                    effects.extend(restart(&mut candidate, self.token)?.into_effects());
                } else {
                    candidate.children_cancelled(self.token)?;
                    effects.extend(
                        candidate
                            .states
                            .iter()
                            .filter(|(_, state)| {
                                state.state.root
                                    == crate::ux::treeview::Root::ChildrenOf(self.token.node)
                            })
                            .map(|(&state, _)| Effect::RootUnavailable {
                                state,
                                node: self.token.node,
                            }),
                    );
                }
                let mut index = self.index.lock().unwrap_or_else(|error| error.into_inner());
                let mut next = index.clone();
                next.update(engine.source(), candidate.source(), &operations)?;
                engine.memory.check()?;
                *index = next;
                *engine = candidate;
                return Ok(engine.applied(None, effects));
            }
        }
        if let Some((path, identity)) = self.unavailable {
            if resource::entry(engine.source(), self.token.node)?.identity == identity
                && resource::path(engine.source(), self.token.node)? == path
            {
                if !resource::unchanged(&self.source, engine.source(), self.token.node, true) {
                    return restart(engine, self.token);
                }
                let _memory = engine.memory.enter();
                let mut candidate = engine.clone();
                let operations = vec![crate::ux::treeview::Operation::Remove {
                    node: self.token.node.into(),
                }];
                let reply = candidate.apply_batch(crate::ux::treeview::Batch {
                    base_revision: candidate.source().revision(),
                    operations: operations.clone(),
                })?;
                candidate.children_cancelled(self.token)?;
                let mut index = self.index.lock().unwrap_or_else(|error| error.into_inner());
                let mut next = index.clone();
                next.update(engine.source(), candidate.source(), &operations)?;
                engine.memory.check()?;
                *index = next;
                *engine = candidate;
                return Ok(reply);
            }
        }
        engine.children_failed(self.token, self.sequence, self.error)
    }
}

struct Probe {
    observed: bool,
    source: Arc<crate::ux::treeview::Source>,
    node: crate::ux::treeview::NodeId,
    path: std::path::PathBuf,
    entry: Result<Option<super::Entry>>,
    index: Arc<Mutex<super::index::Index>>,
}
impl NativeAction for Probe {
    fn bytes(&self) -> usize {
        8192
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        use crate::ux::treeview::{Batch, NodePatch, Operation, Position};
        if self
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .move_blocks(engine.source(), self.node)
        {
            return Err(Error::stale("probe waits for directory move publication"));
        }
        if !engine.source().contains(self.node) {
            return Ok(Reply::NoChange);
        }
        let old = resource::entry(engine.source(), self.node)?;
        if old.identity != resource::entry(&self.source, self.node)?.identity
            || resource::path(engine.source(), self.node)? != self.path
        {
            return Err(Error::stale("probe resource changed"));
        }
        let parent = engine.source().node(self.node).and_then(|node| node.parent);
        let mut observed = self.entry;
        if let Ok(Some(entry)) = &mut observed {
            if entry.identity == old.identity && entry.kind == old.kind {
                entry.anchor = old.anchor.clone();
                if let Some(parent) = parent {
                    if let Some(target) = entry.target_identity() {
                        entry.cycle =
                            resource::ancestors(engine.source(), parent)?.contains(&target);
                    }
                }
                entry.retain_unknown_target(&old);
            }
        }
        let children = match &observed {
            Ok(Some(entry)) if entry.identity == old.identity && entry.kind == old.kind => {
                resource::ends_children(&old, entry)
            }
            _ => true,
        };
        if !matches!(&observed, Ok(Some(entry)) if entry == &old)
            && !resource::unchanged(&self.source, engine.source(), self.node, children)
        {
            return Err(Error::stale("probe observation changed before commit"));
        }
        let _memory = engine.memory.enter();
        let mut candidate = engine.clone();
        let mut operations = Vec::new();
        let mut reload = false;
        match observed {
            Err(error) => {
                candidate.set_slot(
                    self.node,
                    None,
                    crate::ux::treeview::LoadState::Error,
                    Some(error),
                    None,
                )?;
            }
            Ok(Some(entry)) if entry.identity == old.identity && entry.kind == old.kind => {
                reload = entry.directory() || entry.target_unknown;
                if entry != old {
                    let data = entry.node_data();
                    operations.push(Operation::Update {
                        node: self.node.into(),
                        patch: NodePatch {
                            label: Some(data.label),
                            fields: Some(data.fields),
                            can_expand: Some(data.can_expand),
                            foldable: Some(data.foldable),
                            hidden: Some(data.hidden),
                            completeness: entry
                                .target_unknown
                                .then_some(crate::ux::treeview::Completeness::Partial),
                            ..NodePatch::default()
                        },
                    });
                    if old.sort_key() != entry.sort_key() {
                        let position = if parent.is_some() {
                            resource::position(engine.source(), parent, &entry, Some(self.node))?
                        } else {
                            Position::Last
                        };
                        operations.push(Operation::Reparent {
                            node: self.node.into(),
                            parent: parent.map(Into::into),
                            position,
                        });
                    }
                }
            }
            _ => operations.push(Operation::Remove {
                node: self.node.into(),
            }),
        }
        let operations = resource::retarget_children(engine.source(), operations)?;
        let mut effects = candidate
            .apply_batch(Batch {
                base_revision: candidate.source().revision(),
                operations: operations.clone(),
            })?
            .into_effects();
        if reload
            && candidate
                .source()
                .node(self.node)
                .is_some_and(|node| node.load_state != crate::ux::treeview::LoadState::Loading)
        {
            effects.extend(
                if self.observed {
                    candidate.request_observed_children(&[self.node], true)?
                } else {
                    candidate.request_children(&[self.node], true)?
                }
                .into_effects(),
            );
        }
        let mut index = self.index.lock().unwrap_or_else(|error| error.into_inner());
        let mut next = index.clone();
        next.update(engine.source(), candidate.source(), &operations)?;
        engine.memory.check()?;
        *index = next;
        *engine = candidate;
        Ok(engine.applied(None, effects))
    }
}

struct RefreshDemand {
    nodes: Vec<(crate::ux::treeview::NodeId, Demand)>,
    dirty: Dirty,
}
impl NativeAction for RefreshDemand {
    fn bytes(&self) -> usize {
        self.nodes.len() * 24
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let _memory = engine.memory.enter();
        let mut candidate = engine.clone();
        let mut dirty = self.dirty.lock().unwrap_or_else(|error| error.into_inner());
        let mut next = dirty.clone();
        let mut effects = Vec::new();
        for (node, demand) in self.nodes {
            if demand.observed && !candidate.observed_interest(node) {
                if next.get(&node) == Some(&demand) {
                    next.remove(&node);
                }
                continue;
            }
            if candidate
                .source()
                .node(node)
                .is_none_or(|node| !node.data.can_expand)
                || refreshing_ancestor(&candidate, &next, node)
                || !can_admit_refresh(&candidate, node)
            {
                continue;
            }
            let deferred: Vec<_> = candidate
                .manual_reads
                .iter()
                .chain(candidate.observed_reads.iter())
                .copied()
                .filter(|&id| id != node && candidate.source().within(node, id))
                .map(|id| (id, !candidate.manual_reads.contains(&id)))
                .collect();
            let generation = resource::sequence()?;
            /* The owner swaps descendant demand for its ancestor without ending read leases. */
            for (id, observed) in deferred {
                candidate.manual_reads.remove(&id);
                candidate.observed_reads.remove(&id);
                let observed = observed && next.get(&id).is_none_or(|demand| demand.observed);
                next.insert(
                    id,
                    Demand {
                        generation,
                        observed,
                    },
                );
            }
            effects.extend(
                if demand.observed {
                    candidate.request_observed_children(&[node], true)?
                } else {
                    candidate.request_children(&[node], true)?
                }
                .into_effects(),
            );
            if next.get(&node) == Some(&demand) {
                next.remove(&node);
            }
        }
        engine.memory.check()?;
        *engine = candidate;
        *dirty = next;
        Ok(engine.applied(None, effects))
    }
}

#[cfg(test)]
mod tests;
