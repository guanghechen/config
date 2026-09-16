use super::command::*;
use super::data::{Batch, Source};
use super::engine::Engine;
use super::model::*;
use super::projection::Snapshot;
use super::provider::{DataScope, Import, ProviderId, Record};
use super::query::{QueryId, QueryInfo, QueryInput, QueryToken};
use super::reads::ReadToken;
use super::render::{RenderContext, RenderPlan};
use super::tasks::*;
use std::collections::{BTreeMap, HashSet, VecDeque};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex, RwLock, Weak};
use std::time::{Duration, Instant};

pub enum Action {
    Batch(Batch),
    TaskBatch(Batch, TaskUpdateToken),
    Import(Import),
    CreateState(Root, DisplayOptions),
    Dispatch(u64, Command, Context),
    Lock(u64, Revision, Option<Instant>),
    Unlock(u64, LockToken),
    Authorize(u64, LockToken, CleanupToken, Arc<[ExpectedChange]>),
    CreateProvider(DataScope),
    ProviderImport(ProviderId, Revision, Vec<Record>),
    ProviderBatch(ProviderId, Batch),
    RequestChildren(Vec<NodeId>, bool),
    ChildrenPage(ReadToken, u64, Vec<Record>, bool),
    ChildrenFailed(ReadToken, u64, Error),
    ChildrenCancelled(ReadToken),
    CreateQuery(ProviderHandle),
    AcceptQuery(QueryId, QueryInput),
    CancelQuery(QueryId),
    QueryPage(QueryToken, u64, Vec<Record>, bool),
    QueryFailed(QueryToken, u64, Error),
    QueryCancelled(QueryToken),
    Plan {
        base: Option<Arc<Snapshot>>,
        target: Arc<Snapshot>,
        old_context: Option<RenderContext>,
        context: RenderContext,
        reset: bool,
    },
    ReleaseState(u64),
    ReleaseProvider(ProviderId),
    ReleaseQuery(QueryId),
    Attach(u64),
    Detach(u64),
    Refresh(u64),
}

impl Action {
    fn completion(&self) -> Option<u64> {
        match self {
            Self::ChildrenPage(token, ..)
            | Self::ChildrenFailed(token, ..)
            | Self::ChildrenCancelled(token) => Some(token.work),
            Self::QueryPage(token, ..)
            | Self::QueryFailed(token, ..)
            | Self::QueryCancelled(token) => Some(token.work),
            _ => None,
        }
    }

    fn bytes(&self) -> usize {
        fn records(records: &[Record]) -> usize {
            records
                .iter()
                .map(|record| {
                    record
                        .data
                        .validate()
                        .unwrap_or(usize::MAX / 4)
                        .saturating_add(record.key.len())
                        .saturating_add(std::mem::size_of::<Record>())
                })
                .fold(0usize, usize::saturating_add)
        }
        match self {
            Self::Import(import) => records(&import.records),
            Self::ProviderImport(_, _, items)
            | Self::ChildrenPage(_, _, items, _)
            | Self::QueryPage(_, _, items, _) => records(items),
            Self::Batch(batch) | Self::TaskBatch(batch, _) | Self::ProviderBatch(_, batch) => batch
                .operations
                .iter()
                .map(|operation| {
                    super::provider::operation_bytes(operation).unwrap_or(usize::MAX / 4)
                })
                .fold(0usize, usize::saturating_add),
            Self::AcceptQuery(_, input) => input.pattern.len().saturating_add(
                NodeData {
                    fields: input.options.clone(),
                    ..NodeData::default()
                }
                .validate()
                .unwrap_or(usize::MAX / 4),
            ),
            Self::Dispatch(_, command, _) => match command {
                Command::SetRoot(Root::Forest(ids)) => ids.len().saturating_mul(8),
                Command::SetExpanded {
                    targets: Targets::Nodes(ids),
                    ..
                }
                | Command::Select {
                    targets: Targets::Nodes(ids),
                    ..
                } => ids.len().saturating_mul(8),
                _ => 256,
            },
            _ => 256,
        }
    }

    fn control(&self) -> bool {
        matches!(
            self,
            Self::ReleaseState(_)
                | Self::ReleaseProvider(_)
                | Self::ReleaseQuery(_)
                | Self::Attach(_)
                | Self::Detach(_)
        )
    }
}

#[derive(Clone)]
pub enum Outcome {
    Reply(Reply),
    State(StateHandle),
    Provider(ProviderHandle),
    Query(QueryHandle),
    Plan(Arc<RenderPlan>),
    TaskUpdate(TaskUpdateToken),
}

#[derive(Clone)]
pub struct Ticket(Arc<Mutex<Option<Outcome>>>);

impl Ticket {
    fn pending() -> Self {
        Self(Arc::new(Mutex::new(None)))
    }
    pub fn ready(error: Error) -> Self {
        let ticket = Self::pending();
        ticket.finish(Outcome::Reply(error.into()));
        ticket
    }
    fn finish(&self, value: Outcome) {
        let mut outcome = self.0.lock().unwrap_or_else(|poison| poison.into_inner());
        if outcome.is_none() {
            *outcome = Some(value);
        }
    }
    pub fn poll(&self) -> Option<Outcome> {
        self.0
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
            .clone()
    }
}

struct Work {
    action: Action,
    ticket: Ticket,
    bytes: usize,
    _state: Option<StateHandle>,
    _upload: Option<UploadPermit>,
}

#[derive(Default)]
struct Queue {
    items: VecDeque<Work>,
    ordinary: usize,
    bytes: usize,
    completions: HashSet<u64>,
    disposed: bool,
}

#[derive(Clone, Debug)]
pub struct StateStatus {
    pub revisions: Revisions,
    pub locked: bool,
    pub projection_error: Option<Error>,
}

struct Publication {
    source: Arc<Source>,
    frames: BTreeMap<u64, Arc<Snapshot>>,
    states: BTreeMap<u64, StateStatus>,
    queries: BTreeMap<u64, QueryInfo>,
    active_work: HashSet<u64>,
}

struct Shared {
    queue: Mutex<Queue>,
    wake: Condvar,
    publication: RwLock<Publication>,
    events: Mutex<BTreeMap<(u8, u64), Effect>>,
    limits: Limits,
    views: AtomicUsize,
    input_bytes: AtomicUsize,
    uploads: AtomicUsize,
}

pub(crate) struct UploadPermit {
    shared: Arc<Shared>,
    bytes: usize,
}

impl UploadPermit {
    pub fn charge(&mut self, bytes: usize) -> Result<()> {
        self.shared
            .input_bytes
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |used| {
                used.checked_add(bytes)
                    .filter(|total| *total <= self.shared.limits.batch_bytes.saturating_mul(2))
            })
            .map_err(|_| Error::limit("private input staging capacity exceeded"))?;
        self.bytes += bytes;
        Ok(())
    }
}

impl Drop for UploadPermit {
    fn drop(&mut self) {
        self.shared
            .input_bytes
            .fetch_sub(self.bytes, Ordering::Relaxed);
        self.shared.uploads.fetch_sub(1, Ordering::Relaxed);
    }
}

struct Runtime {
    shared: Arc<Shared>,
}

impl Drop for Runtime {
    fn drop(&mut self) {
        stop(
            &self.shared,
            Error::new(ErrorCode::Disposed, "data owner released"),
        );
    }
}

#[derive(Clone)]
pub struct DataHandle(Arc<Runtime>);

struct StateLink {
    data: DataHandle,
    id: u64,
}
impl Drop for StateLink {
    fn drop(&mut self) {
        self.data.submit(Action::ReleaseState(self.id));
    }
}
#[derive(Clone)]
pub struct StateHandle(Arc<StateLink>);

struct ProviderLink {
    data: DataHandle,
    id: ProviderId,
}
impl Drop for ProviderLink {
    fn drop(&mut self) {
        self.data.submit(Action::ReleaseProvider(self.id));
    }
}
#[derive(Clone)]
pub struct ProviderHandle(Arc<ProviderLink>);

struct QueryLink {
    provider: ProviderHandle,
    id: QueryId,
}
impl Drop for QueryLink {
    fn drop(&mut self) {
        self.provider.data().submit(Action::ReleaseQuery(self.id));
    }
}
#[derive(Clone)]
pub struct QueryHandle(Arc<QueryLink>);

struct ViewLink {
    state: StateHandle,
    id: u64,
}
impl Drop for ViewLink {
    fn drop(&mut self) {
        self.state
            .data()
            .0
            .shared
            .views
            .fetch_sub(1, Ordering::Relaxed);
        self.state.data().submit(Action::Detach(self.state.id()));
    }
}
#[derive(Clone)]
pub struct ViewHandle(Arc<ViewLink>);

impl DataHandle {
    pub fn new(limits: Limits) -> Result<Self> {
        let engine = Engine::new(limits.clone())?;
        let shared = Arc::new(Shared {
            queue: Mutex::new(Queue::default()),
            wake: Condvar::new(),
            events: Mutex::new(BTreeMap::new()),
            publication: RwLock::new(Publication {
                source: engine.source.clone(),
                frames: BTreeMap::new(),
                states: BTreeMap::new(),
                queries: BTreeMap::new(),
                active_work: HashSet::new(),
            }),
            limits,
            views: AtomicUsize::new(0),
            input_bytes: AtomicUsize::new(0),
            uploads: AtomicUsize::new(0),
        });
        let runtime = Arc::new(Runtime {
            shared: shared.clone(),
        });
        let weak = Arc::downgrade(&runtime);
        std::thread::Builder::new()
            .name("yoz-treeview".into())
            .spawn(move || run(engine, shared, weak))
            .map_err(|error| Error::new(ErrorCode::ResourceLimit, error.to_string()))?;
        Ok(Self(runtime))
    }

    pub fn source(&self) -> Arc<Source> {
        self.0
            .shared
            .publication
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .source
            .clone()
    }

    pub fn submit(&self, action: Action) -> Ticket {
        self.enqueue(action, None, None)
    }

    pub(crate) fn reserve_upload(&self) -> Result<UploadPermit> {
        self.0
            .shared
            .uploads
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |count| {
                (count < 2).then_some(count + 1)
            })
            .map_err(|_| Error::limit("two private imports are already in progress"))?;
        Ok(UploadPermit {
            shared: self.0.shared.clone(),
            bytes: 0,
        })
    }

    pub(crate) fn submit_upload(&self, action: Action, permit: UploadPermit) -> Ticket {
        self.enqueue(action, None, Some(permit))
    }

    pub(crate) fn limits(&self) -> &Limits {
        &self.0.shared.limits
    }

    fn enqueue(
        &self,
        action: Action,
        state: Option<StateHandle>,
        upload: Option<UploadPermit>,
    ) -> Ticket {
        let ticket = Ticket::pending();
        let bytes = upload
            .as_ref()
            .map_or_else(|| action.bytes(), |permit| permit.bytes);
        let completion = action.completion();
        let control = action.control();
        let active = completion.is_none_or(|id| {
            self.0
                .shared
                .publication
                .read()
                .unwrap_or_else(|poison| poison.into_inner())
                .active_work
                .contains(&id)
        });
        let mut queue = self
            .0
            .shared
            .queue
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        let error = if queue.disposed {
            Some(Error::new(ErrorCode::Disposed, "data owner released"))
        } else if !active {
            Some(Error::stale(
                "asynchronous work has no completion reservation",
            ))
        } else if completion.is_some_and(|id| queue.completions.contains(&id)) {
            Some(Error::stale("a page already awaits commit for this work"))
        } else if !control
            && completion.is_none()
            && (queue.ordinary >= self.0.shared.limits.queued_actions
                || bytes > self.0.shared.limits.batch_bytes
                || queue.bytes.saturating_add(bytes) > self.0.shared.limits.batch_bytes * 2)
        {
            Some(Error::limit("action queue capacity exceeded"))
        } else {
            None
        };
        if let Some(error) = error {
            ticket.finish(Outcome::Reply(error.into()));
            return ticket;
        }
        if let Some(id) = completion {
            queue.completions.insert(id);
        } else if !control {
            queue.ordinary += 1;
            queue.bytes = queue.bytes.saturating_add(bytes);
        }
        queue.items.push_back(Work {
            action,
            ticket: ticket.clone(),
            bytes,
            _state: state,
            _upload: upload,
        });
        self.0.shared.wake.notify_one();
        ticket
    }

    pub fn events(&self) -> Vec<Effect> {
        let mut events = self
            .0
            .shared
            .events
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        std::mem::take(&mut *events).into_values().collect()
    }

    pub fn is_disposed(&self) -> bool {
        self.0
            .shared
            .queue
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
            .disposed
    }

    pub fn queue_depth(&self) -> usize {
        self.0
            .shared
            .queue
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
            .items
            .len()
    }
}

impl StateHandle {
    pub fn id(&self) -> u64 {
        self.0.id
    }
    pub fn data(&self) -> &DataHandle {
        &self.0.data
    }
    pub fn submit(&self, action: Action) -> Ticket {
        self.data().enqueue(action, Some(self.clone()), None)
    }
    pub fn dispatch(&self, command: Command, context: Context) -> Ticket {
        self.submit(Action::Dispatch(self.id(), command, context))
    }
    pub fn snapshot(&self) -> Result<Arc<Snapshot>> {
        self.data()
            .0
            .shared
            .publication
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .frames
            .get(&self.id())
            .cloned()
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state released"))
    }
    pub fn status(&self) -> Result<StateStatus> {
        self.data()
            .0
            .shared
            .publication
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .states
            .get(&self.id())
            .cloned()
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "state released"))
    }

    pub fn applicable(&self, frame: &Snapshot, minimum: Option<Revision>) -> bool {
        let publication = self
            .data()
            .0
            .shared
            .publication
            .read()
            .unwrap_or_else(|poison| poison.into_inner());
        publication
            .frames
            .get(&self.id())
            .is_some_and(|current| current.id == frame.id)
            && publication
                .states
                .get(&self.id())
                .is_some_and(|state| state.revisions.state == Some(frame.state_revision()))
            && publication.source.revision() == frame.source().revision()
            && minimum.is_none_or(|minimum| frame.commit_revision >= minimum)
            && publication.queries.len() == frame.queries.len()
            && frame.queries.iter().all(|query| {
                publication
                    .queries
                    .get(&query.session.0)
                    .is_some_and(|current| {
                        current.generation == query.generation
                            && current.result_generation == query.result_generation
                            && current.load_state == query.load_state
                            && current.error == query.error
                    })
            })
    }
    pub fn attach(&self) -> Result<ViewHandle> {
        self.snapshot()?;
        let shared = &self.data().0.shared;
        shared
            .views
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |views| {
                (views < shared.limits.views).then_some(views + 1)
            })
            .map_err(|_| Error::limit("view capacity exceeded"))?;
        let id = match identity() {
            Ok(id) => id,
            Err(error) => {
                shared.views.fetch_sub(1, Ordering::Relaxed);
                return Err(error);
            }
        };
        self.submit(Action::Attach(self.id()));
        Ok(ViewHandle(Arc::new(ViewLink {
            state: self.clone(),
            id,
        })))
    }
}

impl ProviderHandle {
    pub fn id(&self) -> ProviderId {
        self.0.id
    }
    pub fn data(&self) -> &DataHandle {
        &self.0.data
    }
}
impl QueryHandle {
    pub fn id(&self) -> QueryId {
        self.0.id
    }
    pub fn data(&self) -> &DataHandle {
        self.0.provider.data()
    }
    pub fn info(&self) -> Result<QueryInfo> {
        self.data()
            .0
            .shared
            .publication
            .read()
            .unwrap_or_else(|poison| poison.into_inner())
            .queries
            .get(&self.id().0)
            .cloned()
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "query session released"))
    }
}
impl ViewHandle {
    pub fn id(&self) -> u64 {
        self.0.id
    }
    pub fn state(&self) -> &StateHandle {
        &self.0.state
    }
    pub fn snapshot(&self) -> Result<Arc<Snapshot>> {
        self.state().snapshot()
    }
}

fn execute(engine: &mut Engine, action: Action, runtime: &Weak<Runtime>) -> Result<Outcome> {
    let _memory = engine.memory.enter();
    let data = || {
        runtime
            .upgrade()
            .map(DataHandle)
            .ok_or_else(|| Error::new(ErrorCode::Disposed, "data owner released"))
    };
    let reply = match action {
        Action::Batch(batch) => engine.apply_batch(batch)?,
        Action::TaskBatch(batch, token) => engine.apply_task_batch(batch, token)?,
        Action::Import(import) => engine.import(import)?,
        Action::CreateState(root, display) => {
            let id = engine.create_state(root, display)?;
            return Ok(Outcome::State(StateHandle(Arc::new(StateLink {
                data: data()?,
                id,
            }))));
        }
        Action::Dispatch(id, command, context) => engine.dispatch(id, command, context)?,
        Action::Lock(id, revision, deadline) => engine.lock_selection(id, revision, deadline)?,
        Action::Unlock(id, token) => engine.unlock_selection(id, token)?,
        Action::Authorize(id, lock, cleanup, changes) => {
            return engine
                .authorize_task_update(id, lock, cleanup, changes)
                .map(Outcome::TaskUpdate);
        }
        Action::CreateProvider(scope) => {
            let id = engine.create_provider(scope)?;
            return Ok(Outcome::Provider(ProviderHandle(Arc::new(ProviderLink {
                data: data()?,
                id,
            }))));
        }
        Action::ProviderImport(provider, base, records) => {
            engine.provider_import(provider, base, records)?
        }
        Action::ProviderBatch(provider, batch) => engine.provider_batch(provider, batch)?,
        Action::RequestChildren(nodes, retry) => engine.request_children(&nodes, retry)?,
        Action::ChildrenPage(token, sequence, records, done) => {
            engine.children_page(token, sequence, records, done)?
        }
        Action::ChildrenFailed(token, sequence, error) => {
            engine.children_failed(token, sequence, error)?
        }
        Action::ChildrenCancelled(token) => engine.children_cancelled(token)?,
        Action::CreateQuery(provider) => {
            let id = engine.create_query(provider.id())?;
            return Ok(Outcome::Query(QueryHandle(Arc::new(QueryLink {
                provider,
                id,
            }))));
        }
        Action::AcceptQuery(session, input) => engine.accept_query(session, input)?,
        Action::CancelQuery(session) => engine.cancel_query(session)?,
        Action::QueryPage(token, sequence, records, done) => {
            engine.query_page(token, sequence, records, done)?
        }
        Action::QueryFailed(token, sequence, error) => {
            engine.query_failed(token, sequence, error)?
        }
        Action::QueryCancelled(token) => engine.query_cancelled(token)?,
        Action::Plan {
            base,
            target,
            old_context,
            context,
            reset,
        } => {
            return RenderPlan::new(base, target, old_context.as_ref(), context, reset)
                .map(|plan| Outcome::Plan(Arc::new(plan)));
        }
        Action::ReleaseState(id) => {
            engine.release_state(id);
            Reply::NoChange
        }
        Action::ReleaseProvider(id) => {
            engine.release_provider(id);
            Reply::NoChange
        }
        Action::ReleaseQuery(id) => {
            let effects = engine.release_query(id)?;
            engine.applied(None, effects)
        }
        Action::Attach(id) => {
            if let Some(entry) = engine.states.get_mut(&id) {
                entry.views += 1;
            }
            Reply::NoChange
        }
        Action::Detach(id) => {
            if let Some(entry) = engine.states.get_mut(&id) {
                entry.views = entry.views.saturating_sub(1);
            }
            Reply::NoChange
        }
        Action::Refresh(id) => {
            let entry = engine
                .states
                .get_mut(&id)
                .ok_or_else(|| Error::new(ErrorCode::Disposed, "state released"))?;
            entry.dirty.pending = true;
            entry.dirty.layout = true;
            entry.dirty.full = true;
            Reply::NoChange
        }
    };
    Ok(Outcome::Reply(reply))
}

fn events(shared: &Shared, effects: impl IntoIterator<Item = Effect>) {
    let mut events = shared
        .events
        .lock()
        .unwrap_or_else(|poison| poison.into_inner());
    for effect in effects {
        let key = match &effect {
            Effect::NeedChildren { token, .. } | Effect::CancelChildren { token } => {
                (0, token.work)
            }
            Effect::Query { token, .. } | Effect::CancelQuery { token } => (1, token.work),
            Effect::TaskFailed { lock, .. } => (2, lock.0),
            Effect::RootUnavailable { state, .. } => (3, *state),
            _ => continue,
        };
        events.insert(key, effect);
    }
}

fn publish(engine: &Engine, shared: &Shared, failures: &BTreeMap<u64, Error>) {
    let next = Publication {
        source: engine.source.clone(),
        frames: engine
            .states
            .iter()
            .map(|(&id, entry)| (id, entry.frame.clone()))
            .collect(),
        states: engine
            .states
            .iter()
            .map(|(&id, entry)| {
                (
                    id,
                    StateStatus {
                        revisions: engine.revisions(Some(id)),
                        locked: entry.state.locked.is_some(),
                        projection_error: failures.get(&id).cloned(),
                    },
                )
            })
            .collect(),
        queries: engine
            .queries
            .iter()
            .map(|(&id, query)| (id, query.info.clone()))
            .collect(),
        active_work: engine
            .reads
            .keys()
            .chain(engine.query_work.keys())
            .copied()
            .collect(),
    };
    let old = {
        let mut publication = shared
            .publication
            .write()
            .unwrap_or_else(|poison| poison.into_inner());
        std::mem::replace(&mut *publication, next)
    };
    drop(old);
}

fn stop(shared: &Shared, error: Error) {
    let work = {
        let mut queue = shared
            .queue
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        queue.disposed = true;
        std::mem::take(&mut queue.items)
    };
    for item in work {
        item.ticket.finish(Outcome::Reply(error.clone().into()));
    }
    shared.wake.notify_all();
}

fn run(engine: Engine, shared: Arc<Shared>, runtime: Weak<Runtime>) {
    if std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        run_inner(engine, shared.clone(), runtime)
    }))
    .is_err()
    {
        stop(
            &shared,
            Error::new(ErrorCode::Disposed, "treeview worker stopped after a panic"),
        );
    }
}

fn run_inner(mut engine: Engine, shared: Arc<Shared>, runtime: Weak<Runtime>) {
    let mut failures = BTreeMap::new();
    loop {
        let started = Instant::now();
        let mut processed = 0;
        while processed < 32 && started.elapsed() < Duration::from_millis(2) {
            let work = {
                let mut queue = shared
                    .queue
                    .lock()
                    .unwrap_or_else(|poison| poison.into_inner());
                if queue.disposed {
                    return;
                }
                let work = queue.items.pop_front();
                if let Some(work) = &work
                    && work.action.completion().is_none()
                    && !work.action.control()
                {
                    queue.ordinary -= 1;
                    queue.bytes = queue.bytes.saturating_sub(work.bytes);
                }
                work
            };
            let Some(work) = work else { break };
            let completion = work.action.completion();
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                execute(&mut engine, work.action, &runtime)
            }));
            match result {
                Ok(result) => {
                    let outcome = result.unwrap_or_else(|error| Outcome::Reply(error.into()));
                    publish(&engine, &shared, &failures);
                    if let Some(completion) = completion {
                        shared
                            .queue
                            .lock()
                            .unwrap_or_else(|poison| poison.into_inner())
                            .completions
                            .remove(&completion);
                    }
                    events(&shared, std::mem::take(&mut engine.deferred_effects));
                    if let Outcome::Reply(Reply::Applied { effects, .. }) = &outcome {
                        events(&shared, effects.iter().cloned());
                    }
                    work.ticket.finish(outcome);
                }
                Err(_) => {
                    work.ticket.finish(Outcome::Reply(
                        Error::new(ErrorCode::Disposed, "treeview worker stopped after a panic")
                            .into(),
                    ));
                    stop(
                        &shared,
                        Error::new(ErrorCode::Disposed, "treeview worker stopped"),
                    );
                    return;
                }
            }
            processed += 1;
        }
        for (id, frame) in engine.project() {
            match frame {
                Ok(_) => {
                    failures.remove(&id);
                }
                Err(error) => {
                    failures.insert(id, error);
                }
            }
        }
        let mut effects = Vec::new();
        if let Ok(expired) = engine.expire_tasks(Instant::now()) {
            effects.extend(expired);
        }
        if let Ok(queries) = engine.schedule_queries() {
            effects.extend(queries);
        }
        if let Ok(reads) = engine.schedule_reads() {
            effects.extend(reads);
        }
        publish(&engine, &shared, &failures);
        events(&shared, effects);
        let queue = shared
            .queue
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        if queue.disposed {
            return;
        }
        if queue.items.is_empty() {
            drop(
                shared
                    .wake
                    .wait_timeout(queue, Duration::from_millis(10))
                    .unwrap_or_else(|poison| poison.into_inner()),
            );
        }
    }
}
