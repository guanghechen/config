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
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                (count < 16).then_some(count + 1)
            })
            .map_err(|_| Error::new(ErrorCode::Busy, "file operation capacity exceeded"))?;
        let active = Active;
        let memory = self.data().memory();
        let _guard = memory.enter();
        let job = Job(Arc::new(Shared {
            _source: plan.target.source.clone(),
            _state: None,
            id: resource::sequence()?,
            cancel: AtomicBool::new(false),
            bytes: AtomicU64::new(0),
            state: Mutex::new(Status {
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
                running.0.changed.notify_all();
            })
            .map_err(|error| resource::io_error("start file creation", error))?;
        Ok(job)
    }
}

fn create(tree: &Filetree, job: &Job, plan: CreatePlan) -> Result<()> {
    let mut parent = plan.target;
    let mut retained = 0usize;
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
        let bytes = path.as_os_str().len() * 4 + 256;
        if retained.saturating_add(bytes) > RESULT_LIMIT {
            return Err(Error::limit("file creation result capacity exceeded"));
        }
        let charge = Arc::new(Charge::new(bytes));
        tree.data().memory().check()?;
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
            retained += bytes;
            let item = Arc::new(ItemResult {
                node: resolved
                    .as_ref()
                    .map_or(parent.node, |resource| resource.node),
                source: path.clone(),
                target: Some(path),
                status: ItemStatus::Success,
                source_physical: None,
                target_physical: None,
                error: None,
                error_kind: None,
                os_code: None,
                sync_error: resolved.as_ref().err().cloned(),
                _memory: charge,
                _path_memory: None,
                bytes,
            });
            let mut status = job
                .0
                .state
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            status.results.push(item);
            status.published = status.results.len();
        }
        parent = resolved?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ux::filetree::tests::{Directory, request};
    use std::fs;
    use std::time::Instant;

    fn finished(job: &Job) -> JobStatus {
        let start = Instant::now();
        loop {
            let status = job.status();
            if status.terminal {
                return status;
            }
            assert!(start.elapsed() < Duration::from_secs(10));
            std::thread::sleep(Duration::from_millis(1));
        }
    }

    #[test]
    fn t_create_reobserves_publication_conflicts_without_recreating_or_retargeting() {
        use std::sync::mpsc;
        struct Hold(mpsc::Sender<()>, mpsc::Receiver<()>);
        impl NativeAction for Hold {
            fn bytes(&self) -> usize {
                0
            }
            fn apply(self: Box<Self>, _: &mut Engine) -> Result<Reply> {
                self.0.send(()).unwrap();
                let _ = self.1.recv();
                Ok(Reply::NoChange)
            }
        }

        for race in ["sibling", "replacement", "parent"] {
            let directory = Directory::new();
            let root = directory.0.join("parent");
            fs::create_dir(&root).unwrap();
            let sibling = root.join("sibling");
            let path = root.join("created");
            fs::write(&sibling, b"sibling").unwrap();
            let tree = request(Filetree::open(root.clone()));
            let target = tree.inspect(tree.source(), tree.root()).unwrap();
            let (entered, ready) = mpsc::channel();
            let (release, held) = mpsc::channel();
            let gate = tree
                .data()
                .submit(Action::Native(Box::new(Hold(entered, held))));
            ready.recv_timeout(Duration::from_secs(10)).unwrap();
            let observed = tree.resolve(sibling);
            let start = Instant::now();
            while tree.data().queue_depth() < 1 {
                assert!(start.elapsed() < Duration::from_secs(10));
                std::thread::sleep(Duration::from_millis(1));
            }
            let job = tree
                .start_create(CreatePlan {
                    target,
                    path: "created".into(),
                    directory: false,
                })
                .unwrap();
            while tree.data().queue_depth() < 2 {
                assert!(start.elapsed() < Duration::from_secs(10));
                std::thread::sleep(Duration::from_millis(1));
            }
            let identity = Entry::read(&path).unwrap().identity;
            if race == "replacement" {
                fs::rename(&path, directory.0.join("original")).unwrap();
                fs::write(&path, b"replacement").unwrap();
            } else if race == "parent" {
                let original = directory.0.join("original-parent");
                fs::rename(&root, &original).unwrap();
                fs::create_dir(&root).unwrap();
                fs::hard_link(original.join("created"), &path).unwrap();
            }
            release.send(()).unwrap();
            work::wait(gate).unwrap();
            request(observed);
            let status = finished(&job);
            assert_eq!(status.results, 1);
            let results = job.results(0, 1).unwrap();
            assert_eq!(results[0].status, ItemStatus::Success);
            if race == "replacement" {
                assert_eq!(status.error.unwrap().code, ErrorCode::Stale);
                assert!(results[0].sync_error.is_some());
                assert_eq!(fs::read(&path).unwrap(), b"replacement");
                assert_eq!(
                    Entry::read(&directory.0.join("original")).unwrap().identity,
                    identity
                );
            } else if race == "parent" {
                assert!(status.error.is_some());
                assert!(results[0].sync_error.is_some());
                assert_eq!(Entry::read(&path).unwrap().identity, identity);
                assert_eq!(
                    Entry::read(&directory.0.join("original-parent/created"))
                        .unwrap()
                        .identity,
                    identity
                );
            } else {
                assert!(status.error.is_none(), "{:?}", status.error);
                assert!(results[0].sync_error.is_none());
                assert_eq!(Entry::read(&path).unwrap().identity, identity);
                assert_eq!(
                    tree.inspect(tree.source(), results[0].node)
                        .unwrap()
                        .entry()
                        .unwrap()
                        .identity,
                    identity
                );
            }
        }
    }

    #[test]
    fn t_create_parents_and_empty_file_preserves_existing_contents_on_collision() {
        let directory = Directory::new();
        let tree = request(Filetree::open(directory.0.clone()));
        let target = tree.inspect(tree.source(), tree.root()).unwrap();
        let plan = || CreatePlan {
            target: target.clone(),
            path: "notes/sub/file".into(),
            directory: false,
        };
        let job = tree.start_create(plan()).unwrap();
        let status = finished(&job);
        assert!(status.error.is_none(), "{:?}", status.error);
        assert_eq!(status.results, 3);
        assert!(
            job.results(0, 3)
                .unwrap()
                .iter()
                .all(|item| item.status == ItemStatus::Success && item.sync_error.is_none())
        );
        let path = directory.0.join("notes/sub/file");
        fs::write(&path, "keep").unwrap();
        let collided = tree.start_create(plan()).unwrap();
        assert!(finished(&collided).error.is_some());
        assert_eq!(fs::read_to_string(path).unwrap(), "keep");
        assert!(
            tree.start_create(CreatePlan {
                target,
                path: "../outside".into(),
                directory: false
            })
            .is_err()
        );
    }

    #[cfg(unix)]
    #[test]
    fn t_create_uses_default_permissions_with_process_umask() {
        use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};

        let directory = Directory::new();
        let control_directory = directory.0.join("control-directory");
        fs::DirBuilder::new()
            .mode(0o755)
            .create(&control_directory)
            .unwrap();
        let control_file = directory.0.join("control-file");
        fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o666)
            .open(&control_file)
            .unwrap();
        let tree = request(Filetree::open(directory.0.clone()));
        let target = tree.inspect(tree.source(), tree.root()).unwrap();
        for (path, directory) in [("new/sub/file", false), ("empty-directory", true)] {
            let job = tree
                .start_create(CreatePlan {
                    target: target.clone(),
                    path: path.into(),
                    directory,
                })
                .unwrap();
            let status = finished(&job);
            assert!(status.error.is_none(), "{:?}", status.error);
        }
        for (path, control) in [
            ("new", &control_directory),
            ("new/sub", &control_directory),
            ("empty-directory", &control_directory),
            ("new/sub/file", &control_file),
        ] {
            assert_eq!(
                fs::metadata(directory.0.join(path))
                    .unwrap()
                    .permissions()
                    .mode()
                    & 0o777,
                fs::metadata(control).unwrap().permissions().mode() & 0o777,
                "{path} must use the same defaults and umask as direct creation"
            );
        }
    }

    #[test]
    fn t_create_rejects_replaced_destination_and_cancellation_keeps_published_parents() {
        let directory = Directory::new();
        let base = directory.0.join("base");
        fs::create_dir(&base).unwrap();
        let tree = request(Filetree::open(base.clone()));
        let target = tree.inspect(tree.source(), tree.root()).unwrap();
        fs::rename(&base, directory.0.join("old")).unwrap();
        fs::create_dir(&base).unwrap();
        let stale = tree
            .start_create(CreatePlan {
                target,
                path: "file".into(),
                directory: false,
            })
            .unwrap();
        assert!(finished(&stale).error.is_some());
        assert!(!base.join("file").exists());
        let target = request(tree.resolve(base));
        let job = tree
            .start_create(CreatePlan {
                target,
                path: (0..64).map(|_| "p").collect(),
                directory: true,
            })
            .unwrap();
        let start = Instant::now();
        while job.status().results == 0 {
            assert!(!job.status().terminal, "{:?}", job.status().error);
            assert!(start.elapsed() < Duration::from_secs(10));
            std::thread::sleep(Duration::from_millis(1));
        }
        job.cancel();
        let status = finished(&job);
        assert!(status.cancelled);
        assert!(status.results > 0 && status.results < 64);
        for item in job.results(0, status.results).unwrap() {
            assert!(item.target.as_ref().unwrap().is_dir());
        }
    }
}
