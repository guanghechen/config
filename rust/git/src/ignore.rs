use crate::job::{self, Outcome, QueryJob};
use crate::model::parent;
use crate::process;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::SystemTime;

const CAPACITY: usize = 2000;
type Fingerprint = [Option<(SystemTime, u64)>; 2];

#[derive(Default)]
struct CacheSnapshot {
    values: HashMap<Vec<u8>, bool>,
    fingerprint: Option<Fingerprint>,
}

struct Context {
    cwd: PathBuf,
    root: Vec<u8>,
}

/// The owner thread publishes snapshots. Workers only borrow immutable inputs;
/// UI lookups never wait for a worker-held lock or perform filesystem I/O.
#[derive(Clone)]
pub struct IgnoreCache {
    context: Arc<Context>,
    current: Rc<RefCell<Arc<CacheSnapshot>>>,
}

#[derive(Debug)]
pub struct IgnoreWarning {
    pub code: Option<i32>,
    pub stderr: String,
}

#[derive(Debug, Default)]
pub struct IgnoreReport {
    pub changed: Vec<Vec<u8>>,
    pub warning: Option<IgnoreWarning>,
    pub processes: usize,
    pub lstat_calls: usize,
}

struct Request {
    context: Arc<Context>,
    paths: Vec<Vec<u8>>,
    environment: Vec<(OsString, OsString)>,
}

struct Prepared {
    base: Arc<CacheSnapshot>,
    next: Arc<CacheSnapshot>,
    report: Arc<IgnoreReport>,
}

pub struct IgnoreJob {
    cache: IgnoreCache,
    request: Arc<Request>,
    worker: Option<QueryJob<Arc<Prepared>>>,
    terminal: Option<Outcome<Arc<IgnoreReport>>>,
    cancelled: bool,
    disposed: bool,
}

fn os_path(bytes: &[u8]) -> Result<&Path, String> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        Ok(Path::new(std::ffi::OsStr::from_bytes(bytes)))
    }
    #[cfg(not(unix))]
    {
        std::str::from_utf8(bytes)
            .map(Path::new)
            .map_err(|error| error.to_string())
    }
}

impl IgnoreCache {
    pub fn new(cwd: PathBuf, root: Vec<u8>) -> Result<Self, String> {
        if !cwd.is_absolute() {
            return Err("Git ignore cwd must be absolute".into());
        }
        Ok(Self {
            context: Arc::new(Context { cwd, root }),
            current: Rc::new(RefCell::new(Arc::new(CacheSnapshot::default()))),
        })
    }

    pub fn lookup(&self, path: &[u8]) -> bool {
        self.current
            .borrow()
            .values
            .get(path)
            .copied()
            .unwrap_or(false)
    }

    pub fn clear(&self) {
        *self.current.borrow_mut() = Arc::new(CacheSnapshot::default());
    }

    pub fn start(
        &self,
        paths: Vec<Vec<u8>>,
        environment: Vec<(OsString, OsString)>,
    ) -> Result<IgnoreJob, String> {
        for path in &paths {
            if path.contains(&0) || !os_path(path)?.is_absolute() {
                return Err("Git ignore paths must be absolute and contain no NUL bytes".into());
            }
        }
        let request = Arc::new(Request {
            context: Arc::clone(&self.context),
            paths,
            environment,
        });
        let worker = start_worker(Arc::clone(&request), Arc::clone(&self.current.borrow()))?;
        Ok(IgnoreJob {
            cache: self.clone(),
            request,
            worker: Some(worker),
            terminal: None,
            cancelled: false,
            disposed: false,
        })
    }
}

impl IgnoreJob {
    pub fn poll(&mut self) -> Result<Option<&Outcome<Arc<IgnoreReport>>>, String> {
        if self.disposed {
            return Err("Git ignore job has been disposed".into());
        }
        if self.terminal.is_none() {
            let outcome = self
                .worker
                .as_mut()
                .ok_or("Git ignore worker missing")?
                .poll()?
                .cloned();
            match outcome {
                None => {}
                Some(_) if self.cancelled => self.terminal = Some(Outcome::Cancelled),
                Some(Outcome::Cancelled) => self.terminal = Some(Outcome::Cancelled),
                Some(Outcome::Failed(error)) => self.terminal = Some(Outcome::Failed(error)),
                Some(Outcome::Completed(prepared)) => {
                    let current = Arc::clone(&self.cache.current.borrow());
                    if Arc::ptr_eq(&current, &prepared.base) {
                        *self.cache.current.borrow_mut() = Arc::clone(&prepared.next);
                        self.terminal = Some(Outcome::Completed(Arc::clone(&prepared.report)));
                    } else {
                        // Invalidation or a competing publication won. Rebase the entire request,
                        // retaining every path so a capacity reset cannot lose former cache hits.
                        match start_worker(Arc::clone(&self.request), current) {
                            Ok(worker) => self.worker = Some(worker),
                            Err(error) => self.terminal = Some(Outcome::Failed(error)),
                        }
                    }
                }
            }
            if self.terminal.is_some() {
                self.worker = None;
            }
        }
        Ok(self.terminal.as_ref())
    }

    pub fn cancel(&mut self) -> Result<(), String> {
        if self.disposed {
            return Err("Git ignore job has been disposed".into());
        }
        self.cancelled = true;
        if let Some(worker) = &mut self.worker {
            worker.cancel()?;
        }
        Ok(())
    }

    pub fn dispose(&mut self) {
        self.cancelled = true;
        self.disposed = true;
        self.worker = None;
        self.terminal = None;
    }
}

fn start_worker(
    request: Arc<Request>,
    base: Arc<CacheSnapshot>,
) -> Result<QueryJob<Arc<Prepared>>, String> {
    job::spawn("yoz-git-ignore", move |cancelled| {
        prepare(&request, base, cancelled).map(Arc::new)
    })
}

fn fingerprint(cwd: &Path) -> Fingerprint {
    [".gitignore", ".git/info/exclude"].map(|relative| {
        let metadata = std::fs::metadata(cwd.join(relative)).ok()?;
        Some((metadata.modified().ok()?, metadata.len()))
    })
}

fn query_path(
    path: &[u8],
    root: &[u8],
    resolved: &mut HashMap<Vec<u8>, Option<Vec<u8>>>,
    stat_calls: &mut usize,
) -> Result<Vec<u8>, String> {
    if path != root
        && !(path.starts_with(root)
            && (root.ends_with(b"/") || path.get(root.len()) == Some(&b'/')))
    {
        return Ok(path.to_vec());
    }
    let mut current = path;
    let mut visited = Vec::new();
    let mut ancestor = None;
    loop {
        if let Some(cached) = resolved.get(current) {
            ancestor = cached.clone();
            break;
        }
        *stat_calls += 1;
        let symlink = std::fs::symlink_metadata(os_path(current)?)
            .is_ok_and(|metadata| metadata.file_type().is_symlink());
        visited.push((current.to_vec(), symlink));
        if current == root {
            break;
        }
        let Some(next) = parent(current) else {
            break;
        };
        current = next;
    }
    // Git cannot cross any directory symlink. Resolve the outermost one, even
    // when the symlink's target contains another symlink closer to the leaf.
    for (path, symlink) in visited.into_iter().rev() {
        if ancestor.is_none() && symlink {
            ancestor = Some(path.clone());
        }
        resolved.insert(path, ancestor.clone());
    }
    Ok(ancestor.unwrap_or_else(|| path.to_vec()))
}

fn prepare(
    request: &Request,
    base: Arc<CacheSnapshot>,
    cancelled: &AtomicBool,
) -> Result<Prepared, String> {
    if cancelled.load(Ordering::Acquire) {
        return Err(process::CANCELLED.into());
    }
    let fingerprint = fingerprint(&request.context.cwd);
    let mut reset = base
        .fingerprint
        .as_ref()
        .is_some_and(|previous| previous != &fingerprint);
    let mut seen = HashSet::new();
    let unique: Vec<_> = request
        .paths
        .iter()
        .filter(|path| seen.insert(path.as_slice()))
        .collect();
    let mut pending: Vec<_> = unique
        .iter()
        .copied()
        .filter(|path| reset || !base.values.contains_key(path.as_slice()))
        .collect();
    if !pending.is_empty() && base.values.len() + pending.len() > CAPACITY {
        reset = true;
        pending = unique;
    }
    if pending.is_empty() && !reset && base.fingerprint.as_ref() == Some(&fingerprint) {
        return Ok(Prepared {
            next: Arc::clone(&base),
            base,
            report: Arc::new(IgnoreReport::default()),
        });
    }

    let mut values = if reset {
        HashMap::new()
    } else {
        base.values.clone()
    };
    let mut resolved = HashMap::new();
    let mut query_seen = HashSet::new();
    let mut input = Vec::new();
    let mut paths = Vec::new();
    let mut report = IgnoreReport::default();
    let mut inserted = false;
    for path in pending {
        if cancelled.load(Ordering::Acquire) {
            return Err(process::CANCELLED.into());
        }
        let query = query_path(
            path,
            &request.context.root,
            &mut resolved,
            &mut report.lstat_calls,
        )?;
        if query_seen.insert(query.clone()) {
            input.extend_from_slice(&query);
            input.push(0);
        }
        paths.push((path, query));
    }
    if !paths.is_empty() {
        let args = ["check-ignore", "--stdin", "-z"].map(OsString::from);
        let output = process::output(
            &request.context.cwd,
            &request.environment,
            &args,
            Some(input),
            cancelled,
        )?;
        report.processes = 1;
        let complete = matches!(output.status.code(), Some(0 | 1));
        let ignored: HashSet<_> = output
            .stdout
            .split_inclusive(|byte| *byte == 0)
            .filter_map(|field| field.strip_suffix(&[0]))
            .collect();
        if !complete {
            report.warning = Some(IgnoreWarning {
                code: output.status.code(),
                stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
            });
        }
        for (path, query) in paths {
            let ignored = ignored.contains(query.as_slice());
            // A failed command may have consumed only part of stdin. Missing output is unknown.
            if ignored || complete {
                let previous = values.insert(path.clone(), ignored);
                inserted |= previous.is_none();
            }
            // Fingerprint invalidation happens asynchronously. Compare with the state the UI
            // was displaying, including positive entries invalidated to unknown by a failed query.
            if base.values.get(path.as_slice()).copied().unwrap_or(false)
                != values.get(path.as_slice()).copied().unwrap_or(false)
            {
                report.changed.push(path.clone());
            }
        }
    }
    if cancelled.load(Ordering::Acquire) {
        return Err(process::CANCELLED.into());
    }
    report.changed.sort();
    let next = if !reset && !inserted && base.fingerprint.as_ref() == Some(&fingerprint) {
        Arc::clone(&base)
    } else {
        Arc::new(CacheSnapshot {
            values,
            fingerprint: Some(fingerprint),
        })
    };
    Ok(Prepared {
        base,
        next,
        report: Arc::new(report),
    })
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/git/ignore_test.rs"
    ));
}
