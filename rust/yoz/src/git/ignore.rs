use super::job::{self, Outcome, QueryJob};
use super::model::parent;
use super::process;
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
    use super::*;
    use crate::git::test_support::Fixture;
    use std::time::{Duration, Instant};

    fn cache(fixture: &Fixture) -> IgnoreCache {
        let options = fixture.options();
        IgnoreCache::new(options.cwd, options.root).unwrap()
    }

    fn repo_paths(fixture: &Fixture, names: &[&str]) -> Vec<Vec<u8>> {
        names
            .iter()
            .map(|name| {
                fixture
                    .0
                    .join(name)
                    .to_str()
                    .unwrap()
                    .replace('\\', "/")
                    .into_bytes()
            })
            .collect()
    }

    fn start(cache: &IgnoreCache, paths: Vec<Vec<u8>>) -> IgnoreJob {
        cache.start(paths, std::env::vars_os().collect()).unwrap()
    }

    fn finish(job: &mut IgnoreJob) -> Arc<IgnoreReport> {
        let started = Instant::now();
        loop {
            match job.poll().unwrap() {
                Some(Outcome::Completed(report)) => return Arc::clone(report),
                Some(other) => panic!("unexpected outcome: {other:?}"),
                None => {}
            }
            assert!(started.elapsed() < Duration::from_secs(5));
            std::thread::sleep(Duration::from_millis(1));
        }
    }

    #[test]
    fn t_cache_publishes_positive_events_once_and_caches_negatives() {
        let fixture = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["ignored", "visible"]);
        let report = finish(&mut start(&cache, paths.clone()));
        assert_eq!(report.changed, paths[..1]);
        assert!(cache.lookup(&paths[0]));
        assert!(!cache.lookup(&paths[1]));
        assert_eq!(report.processes, 1);
        let hit = finish(&mut start(&cache, paths.clone()));
        assert!(hit.changed.is_empty());
        assert_eq!(hit.processes, 0);
        assert_eq!(hit.lstat_calls, 0);
        cache.clear();
        assert_eq!(
            finish(&mut start(&cache, paths.clone())).changed,
            paths[..1]
        );
    }

    #[test]
    fn t_root_ignore_fingerprint_invalidates_cached_negatives() {
        let fixture = Fixture::new();
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["new"]);
        finish(&mut start(&cache, paths.clone()));
        fixture.write(".gitignore", "new\n");
        assert!(!cache.lookup(&paths[0]));
        assert_eq!(finish(&mut start(&cache, paths.clone())).changed, paths);
        fixture.write(".gitignore", "!new\n");
        assert_eq!(finish(&mut start(&cache, paths.clone())).changed, paths);
        assert!(!cache.lookup(&paths[0]));
    }

    #[test]
    fn t_failed_batch_preserves_positives_but_does_not_cache_unknown_paths() {
        let fixture = Fixture::new();
        let outside = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let mut paths = repo_paths(&fixture, &["ignored", "unknown"]);
        paths.insert(1, outside.options().root);
        let report = finish(&mut start(&cache, paths.clone()));
        assert_eq!(report.warning.as_ref().unwrap().code, Some(128));
        assert!(cache.lookup(&paths[0]));
        assert!(!cache.current.borrow().values.contains_key(&paths[2]));
        let retry = finish(&mut start(&cache, vec![paths[2].clone()]));
        assert_eq!(retry.processes, 1);
    }

    #[test]
    fn t_failed_fingerprint_refresh_notifies_when_requested_positives_become_unknown() {
        let fixture = Fixture::new();
        let outside = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let path = repo_paths(&fixture, &["ignored"]).remove(0);
        finish(&mut start(&cache, vec![path.clone()]));
        fixture.write(".gitignore", "!ignored\n");
        let report = finish(&mut start(
            &cache,
            vec![outside.options().root, path.clone()],
        ));
        assert!(report.warning.is_some());
        assert_eq!(report.changed, vec![path.clone()]);
        assert!(!cache.current.borrow().values.contains_key(&path));
    }

    #[test]
    fn t_competing_publication_rebases_without_duplicate_events() {
        let fixture = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["ignored"]);
        let mut first = start(&cache, paths.clone());
        let mut second = start(&cache, paths.clone());
        assert_eq!(finish(&mut first).changed, paths);
        let second = finish(&mut second);
        assert!(second.changed.is_empty());
        assert_eq!(second.processes, 0);
    }

    #[test]
    fn t_competing_disjoint_requests_preserve_each_others_cache_entries() {
        let fixture = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["ignored", "visible"]);
        let mut first = start(&cache, paths[..1].to_vec());
        let mut second = start(&cache, paths[1..].to_vec());
        finish(&mut first);
        finish(&mut second);
        assert!(cache.lookup(&paths[0]));
        assert_eq!(cache.current.borrow().values.get(&paths[1]), Some(&false));
        assert_eq!(finish(&mut start(&cache, paths)).processes, 0);
    }

    #[test]
    fn t_failed_noop_queries_do_not_invalidate_competing_generations() {
        let fixture = Fixture::new();
        let outside = Fixture::new();
        let cache = cache(&fixture);
        finish(&mut start(&cache, vec![]));
        let before = Arc::clone(&cache.current.borrow());
        let report = finish(&mut start(&cache, vec![outside.options().root]));
        assert!(report.warning.is_some());
        assert!(Arc::ptr_eq(&before, &cache.current.borrow()));
    }

    #[test]
    fn t_invalidation_before_publication_retries_the_original_request() {
        let fixture = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["ignored"]);
        let mut job = start(&cache, paths.clone());
        let started = Instant::now();
        while job.worker.as_mut().unwrap().poll().unwrap().is_none() {
            assert!(started.elapsed() < Duration::from_secs(5));
            std::thread::sleep(Duration::from_millis(1));
        }
        fixture.write(".gitignore", "other\n");
        cache.clear();
        let report = finish(&mut job);
        assert!(report.changed.is_empty());
        assert_eq!(report.processes, 1);
        assert!(!cache.lookup(&paths[0]));
    }

    #[test]
    fn t_cancellation_and_disposal_never_publish_a_worker_result() {
        let fixture = Fixture::new();
        fixture.write(".gitignore", "ignored\n");
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["ignored"]);
        let mut job = start(&cache, paths.clone());
        job.cancel().unwrap();
        let started = Instant::now();
        while job.poll().unwrap().is_none() {
            assert!(started.elapsed() < Duration::from_secs(5));
            std::thread::sleep(Duration::from_millis(1));
        }
        assert!(matches!(job.poll().unwrap(), Some(Outcome::Cancelled)));
        assert!(!cache.lookup(&paths[0]));
        job.dispose();
        job.dispose();
        assert!(job.poll().is_err());
        assert!(job.cancel().is_err());
    }

    #[test]
    fn t_capacity_reset_rebuilds_all_paths_in_an_oversized_batch() {
        let fixture = Fixture::new();
        let cache = cache(&fixture);
        let mut paths: Vec<_> = (0..1999)
            .map(|index| repo_paths(&fixture, &[&format!("file-{index}")]).remove(0))
            .collect();
        finish(&mut start(&cache, paths.clone()));
        paths.extend(repo_paths(&fixture, &["new-a", "new-b"]));
        finish(&mut start(&cache, paths.clone()));
        assert_eq!(cache.current.borrow().values.len(), 2001);
        let hit = finish(&mut start(&cache, paths));
        assert_eq!(hit.processes, 0);
        assert_eq!(hit.lstat_calls, 0);
    }

    #[test]
    fn t_query_resolution_memoizes_shared_ancestors() {
        let fixture = Fixture::new();
        let cache = cache(&fixture);
        let paths = (0..100)
            .map(|index| repo_paths(&fixture, &[&format!("shared/file-{index}")]).remove(0))
            .collect();
        let report = finish(&mut start(&cache, paths));
        assert_eq!(report.lstat_calls, 102);
    }

    #[test]
    #[cfg(unix)]
    fn t_nested_symlinks_inherit_the_outermost_link_ignore_state() {
        use std::os::unix::fs::symlink;
        let fixture = Fixture::new();
        fixture.write(".gitignore", "link\n");
        fixture.write("target/leaf/file", "content");
        symlink("target", fixture.0.join("link")).unwrap();
        symlink("leaf", fixture.0.join("target/inner")).unwrap();
        let cache = cache(&fixture);
        let paths = repo_paths(&fixture, &["link", "link/leaf/file", "link/inner/file"]);
        let report = finish(&mut start(&cache, paths.clone()));
        assert!(report.warning.is_none());
        assert_eq!(report.changed.len(), paths.len());
        for path in paths {
            assert!(cache.lookup(&path));
        }
    }

    #[test]
    fn t_boundary_rejects_relative_and_nul_paths() {
        let fixture = Fixture::new();
        let cache = cache(&fixture);
        assert!(cache.start(vec![b"relative".to_vec()], vec![]).is_err());
        assert!(cache.start(vec![b"/bad\0path".to_vec()], vec![]).is_err());
        assert!(IgnoreCache::new("relative".into(), b"relative".to_vec()).is_err());
    }
}
