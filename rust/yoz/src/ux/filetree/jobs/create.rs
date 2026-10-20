use super::*;

pub struct CreatePlan {
    pub target: Resource,
    pub path: PathBuf,
    pub directory: bool,
}

impl Filetree {
    pub fn start_create(&self, plan: CreatePlan) -> Result<Job> {
        if plan.target.source.identity() != self.source().identity()
            || !plan.target.entry()?.directory()
        {
            return Err(Error::invalid("invalid creation directory"));
        }
        let components: Vec<_> = plan.path.components().collect();
        if components.is_empty()
            || components.len() > 256
            || plan.path.as_os_str().len() > 32 * 1024
            || components
                .iter()
                .any(|component| !matches!(component, Component::Normal(_)))
        {
            return Err(Error::invalid(
                "new path must be a nonempty relative path without . or ..",
            ));
        }
        ACTIVE
            .try_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                (count < 16).then_some(count + 1)
            })
            .map_err(|_| Error::new(ErrorCode::Busy, "file operation capacity exceeded"))?;
        let active = Active;
        let memory = self.data().memory();
        let _guard = memory.enter();
        let job = Job(Arc::new(Shared {
            _source: plan.target.source.clone(),
            _state: None,
            data: self.data().downgrade(),
            id: resource::sequence()?,
            cancel: AtomicBool::new(false),
            bytes: AtomicU64::new(0),
            processed: AtomicUsize::new(0),
            revision: AtomicU64::new(1),
            progress: Mutex::new(None),
            state: Mutex::new(Status {
                phase: JobPhase::Preparing,
                terminal: false,
                cancelled: false,
                confirmation: None,
                answer: None,
                results: Vec::new(),
                published: 0,
                error: None,
                cleanup: None,
            }),
            changed: Condvar::new(),
            task_memory: Memory::new(memory.clone()),
            _memory: Charge::new(1024 + plan.path.as_os_str().len() * 2),
        }));
        memory.check()?;
        let tree = self.clone();
        let running = job.clone();
        std::thread::Builder::new()
            .name(format!("yoz-filetree-create-{}", job.0.id))
            .spawn(move || {
                let _active = active;
                let _guard = memory.enter();
                let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    create(&tree, &running, plan)
                }))
                .unwrap_or_else(|_| Err(Error::invalid("file creation worker panicked")));
                let mut status = running
                    .0
                    .state
                    .lock()
                    .unwrap_or_else(|error| error.into_inner());
                status.cancelled = running.0.cancel.load(Ordering::Acquire);
                status.error = result.err();
                status.terminal = true;
                status.phase = JobPhase::Complete;
                running.0.changed.notify_all();
                drop(status);
                running.notify();
            })
            .map_err(|error| resource::io_error("start file creation", error))?;
        Ok(job)
    }
}

fn create(tree: &Filetree, job: &Job, plan: CreatePlan) -> Result<()> {
    job.set_phase(JobPhase::Working);
    let mut parent = plan.target;
    let mut previous = Weak::new();
    let components: Vec<_> = plan
        .path
        .components()
        .map(|component| component.as_os_str().to_owned())
        .collect();
    for (index, name) in components.iter().enumerate() {
        let _slot = EXECUTOR.lock().unwrap_or_else(|error| error.into_inner());
        if job.0.cancel.load(Ordering::Acquire) {
            return Ok(());
        }
        job_owner::current(&tree.source(), &parent, true)?;
        let parent_path = parent.path()?;
        let signature = Signature::entry(&parent.entry()?, true);
        signature
            .verify(&parent_path, true)
            .map_err(|error| resource::io_error("verify creation directory", error))?;
        let path = parent_path.join(name);
        let bytes = path.as_os_str().len() * 4 + 4096;
        let charge = job.0.task_memory.reserve(bytes)?;
        let directory = index + 1 < components.len() || plan.directory;
        let mut created = false;
        let (identity, existing) = match Entry::read(&path) {
            Ok(entry) if index + 1 < components.len() && entry.directory() => {
                (entry.identity, Some(Signature::entry(&entry, true)))
            }
            Ok(_) => {
                return Err(Error::new(
                    ErrorCode::ProviderError,
                    "new path already exists",
                ));
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                let destination = Destination {
                    path: path.clone(),
                    parent: signature.clone(),
                    expected: None,
                };
                let mode = if directory { 0o755 } else { 0o666 };
                let identity = io::create_new(&destination, directory, mode)
                    .map_err(|error| resource::io_error("create entry", error))?;
                created = true;
                (identity, None)
            }
            Err(error) => return Err(resource::io_error("inspect new path", error)),
        };
        let mut retries = 2;
        let resolved = loop {
            let resolved = tree.resolve(path.clone());
            let result = loop {
                if let Some(result) = resolved.poll() {
                    break result;
                }
                std::thread::sleep(Duration::from_millis(1));
            };
            if retries == 0
                || job.0.cancel.load(Ordering::Acquire)
                || !matches!(&result, Err(error) if error.code == ErrorCode::Stale)
            {
                break result;
            }
            /* A concurrent publication can invalidate this observation after IO succeeded.
             * Reobserve without repeating IO; the parent and resulting identity stay pinned. */
            if let Err(error) = signature.verify(&parent_path, true) {
                break Err(resource::io_error("verify creation directory", error));
            }
            retries -= 1;
        }
        .and_then(|resource| {
            let entry = resource.entry()?;
            if entry.identity != identity
                || created
                    && entry.kind
                        != if directory {
                            Kind::Directory
                        } else {
                            Kind::File
                        }
                || existing
                    .as_ref()
                    .is_some_and(|expected| Signature::entry(&entry, true) != *expected)
            {
                return Err(Error::stale(
                    "created or observed parent was replaced before publication",
                ));
            }
            Ok(resource)
        });
        if created {
            let item = ItemResult::new(
                ItemId(index as u64 + 1),
                resolved.as_ref().ok().map(|resource| resource.node),
                ItemStatus::Success,
                results::Details {
                    source: path.clone(),
                    target: Some(path),
                    source_physical: None,
                    target_physical: None,
                    error: None,
                    error_kind: None,
                    os_code: None,
                    sync_error: resolved.as_ref().err().cloned(),
                    _path_memory: None,
                },
                charge,
                &mut previous,
                None,
            );
            let mut status = job
                .0
                .state
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            status.results.push(item);
            status.published = status.results.len();
            drop(status);
            job.processed();
            job.notify();
        }
        parent = resolved?;
    }
    Ok(())
}
