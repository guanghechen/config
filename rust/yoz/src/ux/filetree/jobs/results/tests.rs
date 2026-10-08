use super::*;

fn details(source: PathBuf, target: Option<PathBuf>) -> Details {
    Details {
        source,
        target,
        source_physical: None,
        target_physical: None,
        error: None,
        error_kind: None,
        os_code: None,
        sync_error: None,
        _path_memory: None,
    }
}

fn record(
    memory: &Arc<Memory>,
    value: Details,
    node: u64,
    status: ItemStatus,
    previous: &mut Weak<Parents>,
) -> Arc<ItemResult> {
    let bytes = 4096
        + value.source.as_os_str().len() * 2
        + value
            .target
            .as_ref()
            .map_or(0, |path| path.as_os_str().len() * 2);
    ItemResult::new(
        ItemId(node),
        Some(NodeId(node)),
        status,
        value,
        memory.reserve(bytes).unwrap(),
        previous,
        None,
    )
}

#[test]
fn t_success_results_share_long_prefixes_and_query_pages_release_independently() {
    let budget = Budget::new(64 * 1024 * 1024);
    let memory = Memory::new(budget.clone());
    let source = PathBuf::from("source").join("ancestor/".repeat(80));
    let target = PathBuf::from("target").join("destination/".repeat(60));
    let mut previous = Weak::new();
    let records: Vec<_> = (1..=100_000)
        .map(|node| {
            let name = format!("entry-{node:06}.txt");
            record(
                &memory,
                details(source.join(&name), Some(target.join(&name))),
                node,
                ItemStatus::Success,
                &mut previous,
            )
        })
        .collect();
    assert!(memory.used() < 24 * 1024 * 1024, "{}", memory.used());
    let retained = memory.used();
    let page = records[98_000..98_512].to_vec();
    assert_eq!(memory.used(), retained);
    assert_eq!(
        budget.used(),
        retained,
        "queries share charged records instead of retaining expanded paths"
    );
    for (index, result) in page.iter().enumerate() {
        let node = 98_001 + index as u64;
        let name = format!("entry-{node:06}.txt");
        assert_eq!(result.node, Some(NodeId(node)));
        assert_eq!(result.item, ItemId(node));
        assert_eq!(result.source(), source.join(&name));
        assert_eq!(result.target(), Some(target.join(&name)));
    }
    drop(records);
    assert!(
        memory.used() > 0 && memory.used() < retained,
        "caller-held records remain charged"
    );
    drop(page);
    assert_eq!(memory.used(), 0);
    assert_eq!(budget.used(), 0);
}

#[test]
fn t_shared_result_prefix_is_charged_until_its_last_success_is_dropped() {
    let budget = Budget::new(1024 * 1024);
    let memory = Memory::new(budget.clone());
    let mut previous = Weak::new();
    let first = record(
        &memory,
        details("source/one".into(), None),
        1,
        ItemStatus::Success,
        &mut previous,
    );
    let second = record(
        &memory,
        details("source/two".into(), None),
        2,
        ItemStatus::Success,
        &mut previous,
    );
    let charged = memory.used();
    let prefix = previous.upgrade().unwrap()._memory.bytes();
    drop(first);
    assert!(memory.used() < charged);
    assert!(memory.used() > prefix);
    assert_eq!(memory.used(), budget.used());
    assert_eq!(second.source(), Path::new("source/two"));
    drop(second);
    assert_eq!(memory.used(), 0);
    assert_eq!(budget.used(), 0);
}

#[test]
fn t_terminal_result_pages_remain_readable_when_the_data_budget_is_exhausted() {
    let data = DataHandle::new(Limits::default()).unwrap();
    let budget = data.memory();
    let memory = Memory::new(budget.clone());
    let mut previous = Weak::new();
    let results: Vec<_> = (0..1200)
        .map(|node| {
            record(
                &memory,
                details(
                    format!("source/entry-{node}").into(),
                    Some(format!("target/entry-{node}").into()),
                ),
                node,
                ItemStatus::Success,
                &mut previous,
            )
        })
        .collect();
    let job = Job(Arc::new(Shared {
        _source: data.source(),
        _state: None,
        data: data.downgrade(),
        id: 1,
        cancel: AtomicBool::new(false),
        bytes: AtomicU64::new(0),
        processed: AtomicUsize::new(1200),
        revision: AtomicU64::new(1),
        progress: Mutex::new(None),
        state: Mutex::new(Status {
            phase: JobPhase::Complete,
            terminal: true,
            cancelled: false,
            confirmation: None,
            answer: None,
            results,
            published: 1200,
            error: None,
            cleanup: None,
        }),
        changed: Condvar::new(),
        task_memory: memory.clone(),
        _memory: Charge::new(1024),
    }));
    let used = memory.used();
    assert!(memory.reserve(RESULT_LIMIT).is_err());
    assert_eq!(used, memory.used());
    let pressure = {
        let _guard = budget.enter();
        Charge::new(Limits::default().memory_bytes)
    };
    let before = budget.used();
    assert!(memory.reserve(1).is_err());
    assert_eq!(used, memory.used());
    assert_eq!(before, budget.used());
    for first in (0..1200).step_by(512) {
        let page = job.results(first, (first + 512).min(1200)).unwrap();
        for (offset, result) in page.iter().enumerate() {
            assert_eq!(result.node, Some(NodeId((first + offset) as u64)));
            assert_eq!(
                result.source(),
                PathBuf::from(format!("source/entry-{}", first + offset))
            );
        }
        assert_eq!(
            before,
            budget.used(),
            "result draining cannot require another retained native allocation"
        );
    }
    assert_eq!(job.status().results, 1200);
    assert!(job.results(0, 513).is_err());
    drop(pressure);
    drop(job);
    assert_eq!(memory.used(), 0);
}

#[test]
fn t_result_details_keep_failures_sync_errors_renames_and_physical_paths() {
    let budget = Budget::new(1024 * 1024);
    let memory = Memory::new(budget.clone());
    let mut previous = Weak::new();
    for kind in 0..5 {
        let mut value = details("source/name".into(), Some("target/name".into()));
        let status = match kind {
            0 => {
                value.error = Some(Error::new(ErrorCode::ProviderError, "copy failed"));
                value.os_code = Some(13);
                value.error_kind = Some("PermissionDenied".into());
                ItemStatus::Failed
            }
            1 => ItemStatus::Skipped,
            2 => {
                value.sync_error = Some(Error::stale("source changed"));
                ItemStatus::Success
            }
            3 => {
                value.target = Some("target/renamed".into());
                ItemStatus::Success
            }
            4 => {
                value.source_physical = Some("actual-source/name".into());
                value.target_physical = Some("actual-target/name".into());
                value._path_memory = Some(memory.reserve(256).unwrap());
                ItemStatus::Success
            }
            _ => unreachable!(),
        };
        let result = record(&memory, value, 1, status, &mut previous);
        assert!(matches!(result.contents, Contents::Detail { .. }));
        assert_eq!(result.source(), Path::new("source/name"));
        match kind {
            0 => {
                assert_eq!(result.status, ItemStatus::Failed);
                assert_eq!(result.os_code(), Some(13));
                assert_eq!(result.error_kind(), Some("PermissionDenied"));
            }
            1 => assert_eq!(result.status, ItemStatus::Skipped),
            2 => assert_eq!(result.sync_error().unwrap().code, ErrorCode::Stale),
            3 => assert_eq!(result.target(), Some("target/renamed".into())),
            4 => assert_eq!(
                result.source_physical(),
                Some(Path::new("actual-source/name"))
            ),
            _ => unreachable!(),
        }
        drop(result);
        assert_eq!(memory.used(), 0);
        assert_eq!(budget.used(), 0);
    }
}

#[cfg(unix)]
#[test]
fn t_compact_results_roundtrip_non_utf8_names_and_literal_backslashes() {
    use std::os::unix::ffi::OsStringExt;
    let budget = Budget::new(1024 * 1024);
    let memory = Memory::new(budget.clone());
    let mut previous = Weak::new();
    for name in [
        OsString::from_vec(b"raw-\xff".to_vec()),
        OsString::from("literal\\name"),
    ] {
        let source = Path::new("source").join(&name);
        let target = Path::new("target").join(&name);
        let result = record(
            &memory,
            details(source.clone(), Some(target.clone())),
            1,
            ItemStatus::Success,
            &mut previous,
        );
        assert_eq!(result.source(), source);
        assert_eq!(result.target(), Some(target));
    }
    assert_eq!(memory.used(), 0);
    assert_eq!(budget.used(), 0);
}
