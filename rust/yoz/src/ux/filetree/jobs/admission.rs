use super::walk::Origin;
use super::*;

const BATCH_ITEMS: usize = 128;
const BATCH_BYTES: usize = 64 * 1024;

/** Reserve captured payload sizes before reading or cloning entries; the owner keeps the lease. */
struct Entries {
    values: Vec<Entry>,
    memory: Reservation,
}

impl Entries {
    fn new(memory: &Arc<Memory>, origin: &Origin) -> Result<Self> {
        Ok(Self {
            values: Vec::new(),
            memory: memory.reserve(512 + origin.path.as_os_str().len() * 2)?,
        })
    }

    fn full(&self, bytes: usize) -> bool {
        self.values.len() == BATCH_ITEMS
            || (!self.values.is_empty() && self.memory.bytes() + bytes > BATCH_BYTES)
    }

    fn push(&mut self, bytes: usize, read: impl FnOnce() -> Result<Entry>) -> Result<()> {
        if self.full(bytes) || self.memory.bytes() + bytes > BATCH_BYTES {
            return Err(Error::limit("operation admission batch capacity exceeded"));
        }
        self.memory.grow(bytes)?;
        self.values.push(read()?);
        Ok(())
    }
}

struct Admit {
    tree: Filetree,
    task: Option<TaskContext>,
    job: u64,
    parent: NodeId,
    origin: Arc<Origin>,
    entries: Entries,
    result: Arc<Mutex<Vec<NodeId>>>,
}

impl NativeAction for Admit {
    fn bytes(&self) -> usize {
        512 + self.origin.path.as_os_str().len() * 2
            + self
                .entries
                .values
                .iter()
                .map(|entry| entry.encoded_len() * 2 + 128)
                .sum::<usize>()
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let parent = resource::entry(engine.source(), self.parent)?;
        if resource::path(engine.source(), self.parent)? != self.origin.path
            || Signature::entry(&parent, true) != self.origin.signature
        {
            return Err(Error::stale("discovery parent occurrence changed"));
        }
        let mut candidate = engine.clone();
        if let Some(context) = &self.task {
            let task = candidate
                .states
                .get_mut(&context.state.id())
                .and_then(|state| state.task.as_mut())
                .ok_or_else(|| Error::stale("discovery task expired"))?;
            task.check(context.lock, Some(context.cleanup))?;
            if task.native_job != Some(self.job)
                || task.source_root(self.parent) != Some(self.origin.root)
            {
                return Err(Error::stale("discovery parent is outside task roots"));
            }
        }
        let mut index = self
            .tree
            .index
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let mut next = index.clone();
        let mut nodes = vec![None; self.entries.values.len()];
        let mut missing = Vec::new();
        let mut names = HashSet::new();
        for (position, entry) in self.entries.values.iter().enumerate() {
            if !names.insert(&entry.name) {
                return Err(Error::stale("discovery repeated a directory occurrence"));
            }
            if let Some(node) = index.child(Some(self.parent), &entry.name) {
                if Signature::entry(&resource::entry(candidate.source(), node)?, false)
                    != Signature::entry(entry, false)
                {
                    return Err(Error::stale("discovered occurrence was replaced"));
                }
                if let Some(context) = &self.task {
                    let task = candidate
                        .states
                        .get_mut(&context.state.id())
                        .unwrap()
                        .task
                        .as_mut()
                        .unwrap();
                    if task.source_root(node) != Some(self.origin.root) {
                        return Err(Error::stale(
                            "discovered occurrence has no original admission",
                        ));
                    }
                }
                nodes[position] = Some(node);
            } else {
                if !self.origin.discover {
                    return Err(Error::stale(
                        "complete directory cannot discover new members",
                    ));
                }
                missing.push((position, entry, resource::key()?));
            }
        }
        missing.sort_unstable_by(|a, b| a.1.sort_cmp(b.1));
        let operations = missing
            .iter()
            .map(|(_, entry, key)| {
                Ok(Operation::Insert {
                    key: key.clone(),
                    parent: Some(self.parent.into()),
                    position: resource::position(
                        candidate.source(),
                        Some(self.parent),
                        entry,
                        None,
                    )?,
                    data: entry.node_data(),
                    completeness: if entry.directory() || entry.target_unknown {
                        Completeness::Unknown
                    } else {
                        Completeness::Complete
                    },
                })
            })
            .collect::<Result<Vec<_>>>()?;
        let batch = Batch {
            base_revision: candidate.source().revision(),
            operations: operations.clone(),
        };
        let reply = if let Some(context) = &self.task {
            candidate.apply_job_discovery(
                batch,
                JobDiscovery {
                    state: context.state.id(),
                    job: self.job,
                    lock: context.lock,
                    cleanup: context.cleanup,
                    parent: self.parent,
                    root: self.origin.root,
                },
            )?
        } else {
            candidate.apply_batch(batch)?
        };
        for (position, _, key) in missing {
            nodes[position] = candidate.source().id(&key);
        }
        next.update(engine.source(), candidate.source(), &operations)?;
        candidate.memory.check()?;
        *self
            .result
            .lock()
            .unwrap_or_else(|error| error.into_inner()) = nodes
            .into_iter()
            .map(|node| node.expect("admitted node"))
            .collect();
        *index = next;
        *engine = candidate;
        Ok(engine.applied(None, reply.into_effects()))
    }
}

impl Runner {
    pub(super) fn cleanup_nodes(&mut self) -> Result<(Arc<[NodeId]>, Reservation)> {
        self.check_context()?;
        let successes = std::mem::take(&mut self.successful);
        let memory = self.reserve(successes.len() * 2 * std::mem::size_of::<NodeId>() + 128)?;
        let mut nodes = Vec::with_capacity(successes.len());
        let mut pending: Option<(Arc<Origin>, NodeId, Entries)> = None;
        for result in successes {
            if let Some(node) = result.node {
                nodes.push(node);
                continue;
            }
            let (origin, signature) = result
                .witness()
                .ok_or_else(|| Error::stale("successful detached item has no captured identity"))?;
            let bytes = 512 + result.source_bytes() * 2 + signature.extra_bytes() * 4;
            if pending
                .as_ref()
                .is_some_and(|(old, _, entries)| old.id != origin.id || entries.full(bytes))
            {
                let (origin, node, entries) = pending.take().expect("cleanup parent");
                nodes.extend(self.admit(&origin, node, entries)?);
            }
            if pending.is_none() {
                pending = Some((
                    origin.clone(),
                    self.bind_origin(origin)?,
                    Entries::new(&self.job.0.task_memory, origin)?,
                ));
            }
            pending.as_mut().expect("cleanup batch").2.push(bytes, || {
                let mut entry = Entry::read(&result.source()).map_err(|error| {
                    if matches!(
                        error.kind(),
                        std::io::ErrorKind::NotFound | std::io::ErrorKind::NotADirectory
                    ) {
                        Error::stale("successful source disappeared before selection cleanup")
                    } else {
                        resource::io_error("read successful source for cleanup", error)
                    }
                })?;
                if !signature.matches(&entry) {
                    return Err(Error::stale(
                        "successful source identity changed before cleanup",
                    ));
                }
                entry.cycle = origin.cycle(&entry);
                Ok(entry)
            })?;
        }
        if let Some((origin, node, entries)) = pending {
            nodes.extend(self.admit(&origin, node, entries)?);
        }
        nodes.sort_unstable();
        nodes.dedup();
        Ok((nodes.into(), memory))
    }

    fn admit(&self, origin: &Arc<Origin>, parent: NodeId, entries: Entries) -> Result<Vec<NodeId>> {
        self.check_context()?;
        /* A NodeId binding caches Source admission, never filesystem identity. Revalidate
         * the full captured chain even when this parent was already bound by an earlier batch. */
        for ancestor in
            std::iter::successors(Some(origin.as_ref()), |origin| origin.parent.as_deref())
        {
            let signature = Signature::read(&ancestor.path, true).map_err(|error| {
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::NotFound | std::io::ErrorKind::NotADirectory
                ) {
                    Error::stale("admission ancestor disappeared")
                } else {
                    resource::io_error("verify admission ancestor", error)
                }
            })?;
            if signature != ancestor.signature {
                return Err(Error::stale("admission ancestor identity changed"));
            }
        }
        let result = Arc::new(Mutex::new(Vec::new()));
        let request = Admit {
            tree: self.tree.clone(),
            task: self.plan.task.clone(),
            job: self.job.0.id,
            parent,
            origin: origin.clone(),
            entries,
            result: result.clone(),
        };
        work::wait(self.tree.data().submit(Action::Native(Box::new(request))))?;
        let values = std::mem::take(&mut *result.lock().unwrap_or_else(|error| error.into_inner()));
        Ok(values)
    }

    fn bind_origin(&mut self, origin: &Arc<Origin>) -> Result<NodeId> {
        let mut chain = Vec::new();
        let mut current = origin;
        let mut node = loop {
            if let Some(node) = current
                .node
                .or_else(|| self.bindings.get(&current.id).copied())
            {
                break node;
            }
            chain.push(current.clone());
            current = current
                .parent
                .as_ref()
                .ok_or_else(|| Error::stale("detached origin has no prepared root"))?;
        };
        for child in chain.into_iter().rev() {
            let parent = child.parent.as_ref().expect("origin parent");
            let mut entries = Entries::new(&self.job.0.task_memory, parent)?;
            entries.push(
                512 + child.path.as_os_str().len() * 2 + child.signature.link_bytes() * 4,
                || {
                    let entry = Entry::read(&child.path)
                        .map_err(|error| resource::io_error("read cleanup ancestor", error))?;
                    if Signature::entry(&entry, true) != child.signature {
                        return Err(Error::stale("cleanup ancestor identity changed"));
                    }
                    Ok(entry)
                },
            )?;
            self.bindings_memory.grow(64)?;
            node = self.admit(parent, node, entries)?[0];
            self.bindings.insert(child.id, node);
        }
        Ok(node)
    }

    pub(super) fn bind_item(&mut self, source: &mut Item) -> Result<()> {
        if source.resource.is_none() {
            let parent = source
                .parent
                .as_ref()
                .ok_or_else(|| Error::stale("detached item has no captured parent"))?;
            let node = self.bind_origin(parent)?;
            let mut entries = Entries::new(&self.job.0.task_memory, parent)?;
            entries.push(512 + source.entry.encoded_len() * 2, || {
                Ok(source.entry.clone())
            })?;
            let admitted = self.admit(parent, node, entries)?[0];
            source.resource = Some(Resource {
                node: admitted,
                source: self.tree.source(),
            });
        }
        source.current(&self.tree.source(), &self.plan.source)
    }
}
