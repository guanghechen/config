use super::super::test_support::*;
use super::super::*;
use crate::test_support::eventually;
use std::sync::Arc;
use std::time::{Duration, Instant};

fn wait(ticket: Ticket) -> Outcome {
    let start = Instant::now();
    loop {
        if let Some(result) = ticket.poll() {
            return result;
        }
        assert!(
            start.elapsed() < Duration::from_secs(10),
            "native ticket never completed"
        );
        std::thread::yield_now();
    }
}

#[test]
fn t_closed_listener_releases_capacity_during_an_inflight_notification() {
    use super::Listener;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Mutex, mpsc};

    struct BlockedListener {
        closed: AtomicBool,
        block: Mutex<Option<mpsc::Receiver<()>>>,
        entered: mpsc::SyncSender<()>,
    }
    impl Listener for BlockedListener {
        fn wake(&self) {
            if let Some(release) = self.block.lock().unwrap().take() {
                self.entered.send(()).unwrap();
                release.recv_timeout(Duration::from_secs(5)).unwrap();
            }
        }
        fn close(&self) {
            self.closed.store(true, Ordering::Release);
        }
        fn is_closed(&self) -> bool {
            self.closed.load(Ordering::Acquire)
        }
    }

    let data = DataHandle::new(Limits {
        views: 1,
        ..Limits::default()
    })
    .unwrap();
    let (entered, observed) = mpsc::sync_channel(1);
    let first = Arc::new(BlockedListener {
        closed: AtomicBool::new(false),
        block: Mutex::new(None),
        entered: entered.clone(),
    });
    let listener: Arc<dyn Listener> = first.clone();
    data.listen(&listener).unwrap();
    drop(listener);
    let (release, blocked) = mpsc::channel();
    *first.block.lock().unwrap() = Some(blocked);
    data.acknowledge_publication(data.source().revision());
    observed.recv_timeout(Duration::from_secs(5)).unwrap();
    let inflight = Arc::downgrade(&first);
    first.close();
    drop(first);
    assert!(
        inflight.upgrade().is_some(),
        "the worker still owns the old listener"
    );
    let second: Arc<dyn Listener> = Arc::new(BlockedListener {
        closed: AtomicBool::new(false),
        block: Mutex::new(None),
        entered,
    });
    let result = data.listen(&second);
    release.send(()).unwrap();
    assert!(
        result.is_ok(),
        "closed listeners must not consume capacity: {result:?}"
    );
}

#[test]
fn t_runtime_current_selection_lock_serializes_with_updates_and_rejects_later_edits() {
    let data = DataHandle::new(Limits::default()).unwrap();
    assert!(matches!(
        wait(data.submit(Action::Import(Import {
            base_revision: data.source().revision(),
            scope: DataScope::Forest,
            records: records(2),
        }))),
        Outcome::Reply(Reply::Applied { .. })
    ));
    let root = data.source().id("root").unwrap();
    let selected = data.source().id("n0").unwrap();
    let other = data.source().id("n1").unwrap();
    let Outcome::State(state) = wait(data.submit(Action::CreateState(
        Root::ChildrenOf(root),
        DisplayOptions::default(),
    ))) else {
        panic!("state");
    };
    assert!(matches!(
        wait(state.dispatch(
            Command::Select {
                targets: Targets::Nodes(vec![selected].into()),
                action: SelectAction::Select,
                scope: Scope::Subtree,
            },
            Context::default(),
        )),
        Outcome::Reply(Reply::Applied { .. })
    ));
    let observed = state.status().unwrap().revisions.selection.unwrap();
    let update = data.submit(Action::Batch(Batch {
        base_revision: data.source().revision(),
        operations: vec![Operation::Insert {
            key: "unrelated".into(),
            parent: Some(root.into()),
            position: Position::Last,
            data: NodeData::leaf("unrelated"),
            completeness: Completeness::Complete,
        }],
    }));
    let strict = state.submit(Action::Lock(state.id(), observed, None));
    let current = state.submit(Action::LockCurrent(state.id(), None));
    let later = state.dispatch(
        Command::Select {
            targets: Targets::Nodes(vec![other].into()),
            action: SelectAction::Select,
            scope: Scope::Subtree,
        },
        Context::default(),
    );
    assert!(matches!(
        wait(update),
        Outcome::Reply(Reply::Applied { .. })
    ));
    assert!(matches!(
        wait(strict),
        Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Stale
    ));
    let Outcome::Reply(Reply::Locked { token, .. }) = wait(current) else {
        panic!("current selection must lock after the queued structural update");
    };
    assert!(matches!(
        wait(later),
        Outcome::Reply(Reply::Rejected { error }) if error.code == ErrorCode::Busy
    ));
    let Outcome::Reply(Reply::Ready { sources, .. }) = wait(state.dispatch(
        Command::PrepareSources {
            lock: token,
            retry: false,
        },
        Context::default(),
    )) else {
        panic!("ready");
    };
    assert_eq!(sources.subtree_roots.as_ref(), &[selected]);
    wait(state.submit(Action::Unlock(state.id(), token)));
    assert!(!state.status().unwrap().locked);
}

#[test]
fn t_runtime_idle_waits_for_reader_publication_after_an_accepted_layout_action() {
    use std::sync::{Mutex, mpsc};

    struct Reader {
        block: Arc<Mutex<Option<mpsc::Receiver<()>>>>,
        entered: mpsc::SyncSender<()>,
    }
    impl NativeReader for Reader {
        fn publish(&mut self, _: &Engine, _: &WeakDataHandle) {
            if let Some(release) = self.block.lock().unwrap().take() {
                self.entered.send(()).unwrap();
                release.recv_timeout(Duration::from_secs(5)).unwrap();
            }
        }
        fn effect(&mut self, _: &Effect) -> bool {
            false
        }
        fn needs_poll(&self) -> bool {
            false
        }
    }

    let block = Arc::new(Mutex::new(None));
    let (entered, observed) = mpsc::sync_channel(1);
    let data = DataHandle::with_reader(
        Limits::default(),
        Some(Box::new(Reader {
            block: block.clone(),
            entered,
        })),
    )
    .unwrap();
    let Outcome::State(state) = wait(data.submit(Action::CreateState(
        Root::Forest(Arc::from([])),
        DisplayOptions::default(),
    ))) else {
        panic!("state");
    };
    let deadline = Instant::now() + Duration::from_secs(5);
    while !data.is_idle() {
        assert!(Instant::now() < deadline);
        std::thread::yield_now();
    }
    let (release, blocked) = mpsc::channel();
    *block.lock().unwrap() = Some(blocked);
    assert!(matches!(
        wait(state.dispatch(
            Command::SetDisplay(DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: state.status().unwrap().revisions.state,
                ..Context::default()
            },
        )),
        Outcome::Reply(Reply::Applied { .. })
    ));
    observed.recv_timeout(Duration::from_secs(5)).unwrap();
    assert_eq!(data.queue_depth(), 0);
    assert!(!data.has_work());
    let idle_before_publication = data.is_idle();
    release.send(()).unwrap();
    assert!(
        !idle_before_publication,
        "an accepted layout action must finish reader publication before becoming idle"
    );
    while !data.is_idle() {
        assert!(Instant::now() < deadline);
        std::thread::yield_now();
    }
    assert!(state.applicable(&state.snapshot().unwrap(), None));
}

#[test]
fn t_runtime_only_polls_pending_native_work_and_wakes_for_publication_ack() {
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct Reader(Arc<AtomicUsize>);
    impl runtime::NativeReader for Reader {
        fn publish(&mut self, _: &Engine, _: &runtime::WeakDataHandle) {
            self.0.fetch_add(1, Ordering::SeqCst);
        }
        fn effect(&mut self, _: &Effect) -> bool {
            false
        }
        fn needs_poll(&self) -> bool {
            self.0.load(Ordering::SeqCst) < 3
        }
    }

    let polls = Arc::new(AtomicUsize::new(0));
    let data =
        DataHandle::with_reader(Limits::default(), Some(Box::new(Reader(polls.clone())))).unwrap();
    // Pending reader was not polled.
    eventually(|| polls.load(Ordering::SeqCst) >= 3);
    std::thread::sleep(Duration::from_millis(40));
    assert_eq!(
        polls.load(Ordering::SeqCst),
        3,
        "idle reader must stop polling"
    );

    data.acknowledge_publication(data.source().revision());
    // Publication ack did not wake the owner.
    eventually(|| polls.load(Ordering::SeqCst) >= 4);
    std::thread::sleep(Duration::from_millis(40));
    assert_eq!(
        polls.load(Ordering::SeqCst),
        4,
        "ack must not start idle polling"
    );
    assert!(matches!(
        wait(data.submit(Action::CreateState(
            Root::Forest(Arc::from([])),
            DisplayOptions::default()
        ))),
        Outcome::State(_)
    ));
}

#[test]
fn t_runtime_publishes_task_expiry_without_another_action() {
    let data = DataHandle::new(Limits::default()).unwrap();
    let Outcome::State(state) = wait(data.submit(Action::CreateState(
        Root::Forest(Arc::from([])),
        DisplayOptions::default(),
    ))) else {
        panic!("state");
    };
    let revision = state.status().unwrap().revisions.selection.unwrap();
    assert!(matches!(
        wait(state.submit(Action::Lock(
            state.id(),
            revision,
            Some(Instant::now() + Duration::from_millis(30)),
        ))),
        Outcome::Reply(Reply::Locked { .. })
    ));

    // Task expiry must publish an applicable frame without new input.
    eventually(|| {
        let frame = state.snapshot().unwrap();
        let status = state.status().unwrap();
        let applicable = !status.locked && state.applicable(&frame, None);
        if applicable {
            assert_eq!(status.revisions.state, Some(frame.state_revision()));
        }
        applicable
    });
}

#[test]
fn t_runtime_publishes_deferred_loading_without_provider_response() {
    let data = DataHandle::new(Limits::default()).unwrap();
    assert!(matches!(
        wait(data.submit(Action::Batch(Batch {
            base_revision: data.source().revision(),
            operations: vec![Operation::Insert {
                key: "root".into(),
                parent: None,
                position: Position::Last,
                data: NodeData::branch("root"),
                completeness: Completeness::Unknown,
            }],
        }))),
        Outcome::Reply(Reply::Applied { .. })
    ));
    let root = data.source().id("root").unwrap();
    let Outcome::State(state) = wait(data.submit(Action::CreateState(
        Root::ChildrenOf(root),
        DisplayOptions::default(),
    ))) else {
        panic!("state");
    };
    let _view = state.attach().unwrap();

    // Deferred reads must publish Loading before the provider responds.
    eventually(|| {
        let frame = state.snapshot().unwrap();
        frame.source().node(root).unwrap().load_state == LoadState::Loading
            && state.applicable(&frame, None)
    });
}

#[test]
fn t_runtime_deadline_observation_lasts_until_failure_is_drained() {
    for delay in [Duration::ZERO, Duration::from_millis(30)] {
        let data = DataHandle::new(Limits::default()).unwrap();
        let Outcome::State(state) = wait(data.submit(Action::CreateState(
            Root::Forest(Arc::from([])),
            DisplayOptions::default(),
        ))) else {
            panic!("state");
        };
        let revision = state.status().unwrap().revisions.selection.unwrap();
        let Outcome::Reply(Reply::Locked { token, .. }) = wait(state.submit(Action::Lock(
            state.id(),
            revision,
            Some(Instant::now() + delay),
        ))) else {
            panic!("lock");
        };
        let started = Instant::now();
        let mut failures = 0;
        loop {
            let (effects, pending) = data.poll_events();
            for effect in effects {
                let Effect::TaskFailed { lock, error } = effect else {
                    panic!("unexpected task effect");
                };
                assert_eq!(lock, token);
                assert_eq!(error.code, ErrorCode::Stale);
                failures += 1;
            }
            if !pending {
                assert_eq!(failures, 1, "failure must precede suspension");
                break;
            }
            assert!(started.elapsed() < Duration::from_secs(10));
            std::thread::yield_now();
        }
        assert!(!state.status().unwrap().locked);
        let (effects, pending) = data.poll_events();
        assert!(effects.is_empty());
        assert!(!pending);
    }
}

#[test]
fn t_runtime_deadline_observation_tracks_only_unprepared_timed_tasks() {
    let data = DataHandle::new(Limits::default()).unwrap();
    let mut tasks = Vec::new();
    for _ in 0..2 {
        let Outcome::State(state) = wait(data.submit(Action::CreateState(
            Root::Forest(Arc::from([])),
            DisplayOptions::default(),
        ))) else {
            panic!("state");
        };
        let revision = state.status().unwrap().revisions.selection.unwrap();
        let Outcome::Reply(Reply::Locked { token, .. }) = wait(state.submit(Action::Lock(
            state.id(),
            revision,
            Some(Instant::now() + Duration::from_secs(10)),
        ))) else {
            panic!("lock");
        };
        tasks.push((state, token));
    }
    assert!(data.poll_events().1);
    let (prepared, prepared_token) = &tasks[0];
    assert!(matches!(
        wait(prepared.dispatch(
            Command::PrepareSources {
                lock: *prepared_token,
                retry: false,
            },
            Context::default(),
        )),
        Outcome::Reply(Reply::Ready { .. })
    ));
    assert!(data.poll_events().1, "the other task still has a deadline");
    let (unlocked, unlocked_token) = &tasks[1];
    assert!(matches!(
        wait(unlocked.submit(Action::Unlock(unlocked.id(), *unlocked_token))),
        Outcome::Reply(Reply::Applied { .. })
    ));
    assert!(!data.poll_events().1);
    assert!(prepared.status().unwrap().locked);
    assert!(!unlocked.status().unwrap().locked);
    let revision = unlocked.status().unwrap().revisions.selection.unwrap();
    assert!(matches!(
        wait(unlocked.submit(Action::Lock(unlocked.id(), revision, None))),
        Outcome::Reply(Reply::Locked { .. })
    ));
    assert!(
        !data.poll_events().1,
        "untimed tasks do not need deadline polling"
    );
}

#[test]
fn t_runtime_futures_complete_and_shared_views_hold_a_live_state() {
    let data = DataHandle::new(Limits::default()).unwrap();
    let outcome = wait(data.submit(Action::Import(Import {
        base_revision: data.source().revision(),
        scope: DataScope::Forest,
        records: records(10),
    })));
    assert!(matches!(outcome, Outcome::Reply(Reply::Applied { .. })));
    let root = data.source().id("root").unwrap();
    let Outcome::State(state) = wait(data.submit(Action::CreateState(
        Root::ChildrenOf(root),
        DisplayOptions::default(),
    ))) else {
        panic!("state");
    };
    let a = state.attach().unwrap();
    let b = state.attach().unwrap();
    assert_ne!(a.id(), b.id());
    let ticket = state.dispatch(
        Command::Select {
            targets: Targets::Nodes(vec![root].into()),
            action: SelectAction::Select,
            scope: Scope::Subtree,
        },
        Context::default(),
    );
    drop(a);
    drop(state);
    drop(data);
    assert!(matches!(
        wait(ticket),
        Outcome::Reply(Reply::Applied { .. })
    ));
    let outcome = wait(
        b.state()
            .dispatch(Command::InspectSelection, Context::default()),
    );
    assert!(
        matches!(outcome, Outcome::Reply(Reply::Inspected { sources, .. }) if sources.summary.known_roots == 1)
    );
}

#[test]
fn t_zero_queue_capacity_returns_completed_resource_limit_without_mutation() {
    let data = DataHandle::new(Limits {
        queued_actions: 0,
        ..Limits::default()
    })
    .unwrap();
    let initial = data.source();
    let ticket = data.submit(Action::Import(Import {
        base_revision: initial.revision(),
        scope: DataScope::Forest,
        records: records(1),
    }));
    assert!(
        matches!(ticket.poll(), Some(Outcome::Reply(Reply::Rejected { error })) if error.code == ErrorCode::ResourceLimit)
    );
    assert!(Arc::ptr_eq(&initial, &data.source()));
}
