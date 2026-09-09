use super::*;
use crate::test_support::Fixture;
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
