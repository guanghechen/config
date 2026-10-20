use super::super::test_support::*;
use super::super::*;
use std::sync::Arc;

#[test]
fn t_children_pages_preserve_old_members_until_complete_and_keep_reserved_work_on_bad_sequence() {
    let (mut engine, _, root) = fixture(2);
    let Reply::Applied { effects, .. } = engine.request_children(&[root], false).unwrap() else {
        panic!("request");
    };
    let (token, sequence) = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, sequence } => Some((*token, *sequence)),
            _ => None,
        })
        .unwrap();
    let old = engine.source.id("n1").unwrap();
    engine
        .children_page(
            token,
            sequence,
            vec![Record::new("n0", NodeData::leaf("updated"))],
            false,
        )
        .unwrap();
    assert!(engine.source.contains(old));
    assert_eq!(
        engine.source.node(root).unwrap().completeness,
        Completeness::Partial
    );
    assert_eq!(
        engine
            .children_page(token, sequence, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert_eq!(engine.reads.len(), 1);
    engine
        .children_page(
            token,
            sequence + 1,
            vec![Record::new("last", NodeData::leaf("last"))],
            true,
        )
        .unwrap();
    assert!(!engine.source.contains(old));
    assert_eq!(engine.source.node(root).unwrap().child_count(), 2);
    assert_eq!(
        engine.source.node(root).unwrap().completeness,
        Completeness::Complete
    );
    assert!(engine.reads.is_empty());
}

#[test]
fn t_children_capacity_failure_preserves_source_and_requires_explicit_retry() {
    let (mut engine, _, root) = fixture(1);
    engine.limits.nodes = engine.source.len();
    let Reply::Applied { effects, .. } = engine.request_children(&[root], false).unwrap() else {
        panic!("request");
    };
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    let old = engine.source.id("n0").unwrap();
    let result = engine.children_page(
        token,
        1,
        vec![Record::new("too-many", NodeData::leaf("overflow"))],
        true,
    );
    assert_eq!(result.unwrap_err().code, ErrorCode::ResourceLimit);
    assert_eq!(engine.source.id("too-many"), None);
    assert!(engine.source.contains(old));
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Error
    );
    assert!(engine.schedule_reads().unwrap().is_empty());
    engine.limits.nodes += 10;
    assert!(engine.schedule_reads().unwrap().is_empty());
    let Reply::Applied { effects, .. } = engine.request_children(&[root], true).unwrap() else {
        panic!("retry");
    };
    assert!(
        effects
            .iter()
            .any(|effect| matches!(effect, Effect::NeedChildren { .. }))
    );
}

#[test]
fn t_filtered_list_keeps_unknown_reads_through_hidden_parent_updates() {
    let (mut engine, state, root) = fixture(0);
    apply(
        &mut engine,
        vec![
            Operation::Insert {
                key: "parent".into(),
                parent: Some(root.into()),
                position: Position::Last,
                data: NodeData::branch("parent"),
                completeness: Completeness::Unknown,
            },
            Operation::Insert {
                key: "leaf".into(),
                parent: Some("parent".into()),
                position: Position::Last,
                data: NodeData::leaf("noise"),
                completeness: Completeness::Complete,
            },
        ],
    );
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            mode: Mode::List,
            pattern: "needle".into(),
            ..DisplayOptions::default()
        },
    );
    project(&mut engine, state);
    for operations in [
        vec![Operation::Update {
            node: "leaf".into(),
            patch: NodePatch {
                label: Some("needle".into()),
                ..NodePatch::default()
            },
        }],
        vec![Operation::Update {
            node: "parent".into(),
            patch: NodePatch {
                hidden: Some(true),
                ..NodePatch::default()
            },
        }],
        vec![Operation::Update {
            node: "leaf".into(),
            patch: NodePatch {
                label: Some("noise".into()),
                ..NodePatch::default()
            },
        }],
        vec![Operation::Update {
            node: "parent".into(),
            patch: NodePatch {
                hidden: Some(false),
                ..NodePatch::default()
            },
        }],
        vec![Operation::Remove {
            node: "parent".into(),
        }],
    ] {
        apply(&mut engine, operations);
        project(&mut engine, state);
        assert_projection(&engine, state);
    }
}

#[test]
fn t_compressed_chain_retains_intermediate_reads_and_reports_their_error() {
    let (mut engine, state, root) = fixture(0);
    let data = |label: &str| NodeData {
        foldable: true,
        ..NodeData::branch(label)
    };
    apply(
        &mut engine,
        vec![
            Operation::Insert {
                key: "a".into(),
                parent: Some(root.into()),
                position: Position::Last,
                data: data("a"),
                completeness: Completeness::Partial,
            },
            Operation::Insert {
                key: "b".into(),
                parent: Some("a".into()),
                position: Position::Last,
                data: data("b"),
                completeness: Completeness::Complete,
            },
        ],
    );
    let a = engine.source.id("a").unwrap();
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            compress: true,
            ..DisplayOptions::default()
        },
    );
    set_expanded(&mut engine, state, &[a], true, Scope::Subtree);
    engine.states.get_mut(&state).unwrap().views = 1;
    let frame = project(&mut engine, state);
    assert_eq!(frame.rows(0, 1).unwrap()[0].label, "a/b");
    assert!(frame.needed_children.contains(&a));
    let effects = engine.schedule_reads().unwrap();
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } if token.node == a => Some(*token),
            _ => None,
        })
        .unwrap();
    engine
        .children_failed(token, 1, Error::invalid("read failed"))
        .unwrap();
    let frame = project(&mut engine, state);
    let row = frame.rows(0, 1).unwrap().remove(0);
    assert_eq!(row.load_state, LoadState::Error);
    assert_eq!(row.error.unwrap().node, Some(a));
}

#[test]
fn t_collapse_before_projection_stops_the_next_children_page() {
    let (mut engine, state, root) = fixture(0);
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "branch".into(),
            parent: Some(root.into()),
            position: Position::Last,
            data: NodeData::branch("branch"),
            completeness: Completeness::Unknown,
        }],
    );
    let branch = engine.source.id("branch").unwrap();
    engine.states.get_mut(&state).unwrap().views = 1;
    set_expanded(&mut engine, state, &[branch], true, Scope::SelfOnly);
    project(&mut engine, state);
    let effects = engine.schedule_reads().unwrap();
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    set_expanded(&mut engine, state, &[branch], false, Scope::SelfOnly);
    let Reply::Applied { effects, .. } = engine.children_page(token, 1, Vec::new(), false).unwrap()
    else {
        panic!("page");
    };
    assert!(
        !effects
            .iter()
            .any(|effect| matches!(effect, Effect::NeedChildren { .. }))
    );
    assert!(engine.reads.is_empty());
    assert!(
        !engine.states[&state]
            .state
            .expanded(&engine.source, branch)
            .unwrap()
    );
}

#[test]
fn t_old_children_cancel_does_not_end_a_replacement_manual_read() {
    let (mut engine, _, root) = fixture(0);
    let read = |reply: Reply| match reply {
        Reply::Applied { effects, .. } => effects
            .iter()
            .find_map(|effect| match effect {
                Effect::NeedChildren { token, .. } => Some(*token),
                _ => None,
            })
            .unwrap(),
        _ => panic!("read request"),
    };
    let old = read(engine.request_children(&[root], false).unwrap());
    let new = read(engine.request_children(&[root], true).unwrap());
    engine.children_cancelled(old).unwrap();
    let Reply::Applied { effects, .. } = engine
        .children_page(
            new,
            1,
            vec![Record::new("fresh", NodeData::leaf("fresh"))],
            false,
        )
        .unwrap()
    else {
        panic!("page")
    };
    assert!(effects.iter().any(
        |effect| matches!(effect, Effect::NeedChildren { token, sequence: 2 } if *token == new)
    ));
    assert!(engine.children_cancelled(old).is_err());
    engine.children_page(new, 2, Vec::new(), true).unwrap();
    assert_eq!(
        engine.source().node(root).unwrap().completeness,
        Completeness::Complete
    );
}

#[test]
fn t_observed_reads_finish_the_current_page_but_stop_without_a_consumer() {
    let (mut engine, state, root) = fixture(0);
    engine.states.get_mut(&state).unwrap().views = 1;
    let Reply::Applied { effects, .. } = engine.request_observed_children(&[root], true).unwrap()
    else {
        panic!("request")
    };
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    engine.states.get_mut(&state).unwrap().views = 0;
    let Reply::Applied { effects, .. } = engine
        .children_page(
            token,
            1,
            vec![Record::new("new", NodeData::leaf("new"))],
            false,
        )
        .unwrap()
    else {
        panic!("page")
    };
    assert!(
        effects
            .iter()
            .all(|effect| !matches!(effect, Effect::NeedChildren { .. }))
    );
    assert_eq!(engine.source().node(root).unwrap().child_count(), 1);
    assert_eq!(
        engine.source().node(root).unwrap().load_state,
        LoadState::Idle
    );
    assert!(engine.observed_reads.is_empty());
    assert!(engine.manual_reads.is_empty());
}

/// A selection over an Unknown root whose read failed, locked twice. Asserts that the stale lock is
/// rejected and that a retry restarts only the selection's failed read, owned by the task. Returns
/// the engine, its state, the root, the current lock and the restarted read.
fn retried_source_read() -> (Engine, u64, NodeId, LockToken, ReadToken) {
    let (mut engine, state, root) = fixture(1);
    let excluded = engine.source.id("n0").unwrap();
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: root.into(),
                patch: NodePatch {
                    completeness: Some(Completeness::Unknown),
                    ..NodePatch::default()
                },
            },
            Operation::Insert {
                key: "unrelated".into(),
                parent: None,
                position: Position::Last,
                data: NodeData::branch("unrelated"),
                completeness: Completeness::Unknown,
            },
        ],
    );
    let unrelated = engine.source.id("unrelated").unwrap();
    for (node, action) in [
        (root, SelectAction::Select),
        (excluded, SelectAction::Deselect),
    ] {
        engine
            .dispatch(
                state,
                Command::Select {
                    targets: Targets::Nodes(vec![node].into()),
                    action,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
    }
    for node in [root, unrelated] {
        engine
            .set_slot(
                node,
                None,
                LoadState::Error,
                Some(Error::new(ErrorCode::ProviderError, "read failed")),
                None,
            )
            .unwrap();
    }
    let lock = |engine: &mut Engine| {
        let revision = engine.states[&state].state.selection_revision;
        let Reply::Locked { token, .. } = engine.lock_selection(state, revision, None).unwrap()
        else {
            panic!("lock");
        };
        token
    };
    let previous = lock(&mut engine);
    assert_eq!(
        engine
            .dispatch(
                state,
                Command::PrepareSources {
                    lock: previous,
                    retry: false
                },
                Context::default()
            )
            .unwrap_err()
            .code,
        ErrorCode::ProviderError
    );
    assert!(engine.states[&state].state.locked.is_none());

    let current = lock(&mut engine);
    assert_eq!(
        engine
            .dispatch(
                state,
                Command::PrepareSources {
                    lock: previous,
                    retry: true
                },
                Context::default()
            )
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Error
    );
    assert!(matches!(
        engine
            .dispatch(
                state,
                Command::PrepareSources {
                    lock: current,
                    retry: true
                },
                Context::default()
            )
            .unwrap(),
        Reply::Pending { .. }
    ));
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Loading
    );
    assert!(engine.source.node(root).unwrap().error.is_none());
    assert_eq!(
        engine.source.node(unrelated).unwrap().load_state,
        LoadState::Error
    );
    assert_eq!(engine.reads.len(), 1);
    assert!(!engine.manual_reads.contains(&root));
    assert!(engine.needed(root));
    let read = engine.reads.values().next().unwrap().token;
    assert_eq!(read.node, root);
    assert!(engine.deferred_effects.iter().any(|effect| matches!(effect,
        Effect::NeedChildren { token, .. } if *token == read)));
    (engine, state, root, current, read)
}
#[test]
fn t_source_retry_read_cancelled_after_unlock_releases_its_demand() {
    let (mut engine, state, root, current, read) = retried_source_read();
    engine.unlock_selection(state, current).unwrap();
    assert!(!engine.needed(root));
    engine.children_cancelled(read).unwrap();
    assert!(engine.reads.is_empty());
}

#[test]
fn t_source_retry_read_failure_releases_the_lock_and_task() {
    let (mut engine, state, _, _, read) = retried_source_read();
    engine
        .children_failed(
            read,
            1,
            Error::new(ErrorCode::ProviderError, "still unavailable"),
        )
        .unwrap();
    assert!(engine.states[&state].state.locked.is_none());
    assert!(engine.states[&state].task.is_none());
    assert!(engine.schedule_reads().unwrap().is_empty());
}

#[test]
fn t_source_retry_read_completion_prepares_the_same_source_on_repeat() {
    let (mut engine, state, _, current, read) = retried_source_read();
    engine
        .children_page(
            read,
            1,
            vec![
                Record::new("n0", NodeData::leaf("excluded")),
                Record::new("n1", NodeData::leaf("included")),
            ],
            true,
        )
        .unwrap();
    let Reply::Ready {
        source, sources, ..
    } = engine
        .dispatch(
            state,
            Command::PrepareSources {
                lock: current,
                retry: false,
            },
            Context::default(),
        )
        .unwrap()
    else {
        panic!("ready");
    };
    assert_eq!(
        sources.subtree_roots.as_ref(),
        &[engine.source.id("n1").unwrap()]
    );
    let Reply::Ready {
        source: repeated, ..
    } = engine
        .dispatch(
            state,
            Command::PrepareSources {
                lock: current,
                retry: true,
            },
            Context::default(),
        )
        .unwrap()
    else {
        panic!("ready");
    };
    assert!(Arc::ptr_eq(&source, &repeated));
}

#[test]
fn t_source_retry_capacity_failure_preserves_error_and_read_ownership() {
    let (mut engine, state, root) = fixture(1);
    let excluded = engine.source.id("n0").unwrap();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: root.into(),
            patch: NodePatch {
                completeness: Some(Completeness::Unknown),
                ..NodePatch::default()
            },
        }],
    );
    for (node, action) in [
        (root, SelectAction::Select),
        (excluded, SelectAction::Deselect),
    ] {
        engine
            .dispatch(
                state,
                Command::Select {
                    targets: Targets::Nodes(vec![node].into()),
                    action,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
    }
    engine
        .set_slot(
            root,
            None,
            LoadState::Error,
            Some(Error::new(ErrorCode::ProviderError, "read failed")),
            None,
        )
        .unwrap();
    let revision = engine.states[&state].state.selection_revision;
    let Reply::Locked { token, .. } = engine.lock_selection(state, revision, None).unwrap() else {
        panic!("lock");
    };
    let before = engine.source.clone();
    let commit = engine.commit;
    let state_revision = engine.states[&state].state.revision;
    let _guard = engine.memory.enter();
    let held =
        super::super::memory::Charge::new(engine.limits.memory_bytes - engine.memory.used() - 32);
    let used = engine.memory.used();
    let result = engine.dispatch(
        state,
        Command::PrepareSources {
            lock: token,
            retry: true,
        },
        Context::default(),
    );
    assert_eq!(result.unwrap_err().code, ErrorCode::ResourceLimit);
    assert_eq!(engine.memory.used(), used);
    assert!(Arc::ptr_eq(&engine.source, &before));
    assert_eq!(
        engine.source.node(root).unwrap().request_epoch,
        before.node(root).unwrap().request_epoch
    );
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Error
    );
    assert_eq!(
        engine
            .source
            .node(root)
            .unwrap()
            .error
            .as_ref()
            .unwrap()
            .message
            .as_ref(),
        "read failed"
    );
    assert_eq!(engine.commit, commit);
    assert_eq!(engine.states[&state].state.revision, state_revision);
    let task = engine.states[&state].task.as_ref().unwrap();
    assert_eq!(task.lock, token);
    assert!(task.valid && task.cleanup.is_none() && task.prepared.is_none());
    assert_eq!(task.needed.as_ref(), &[root]);
    assert!(engine.reads.is_empty() && engine.read_queue.is_empty());
    assert!(engine.manual_reads.is_empty() && engine.observed_reads.is_empty());
    assert!(engine.deferred_effects.is_empty());

    drop(held);
    assert!(matches!(
        engine
            .dispatch(
                state,
                Command::PrepareSources {
                    lock: token,
                    retry: true
                },
                Context::default()
            )
            .unwrap(),
        Reply::Pending { .. }
    ));
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Loading
    );
    assert_eq!(engine.reads.len(), 1);
    assert!(engine.states[&state].task.as_ref().unwrap().valid);
}

#[test]
fn t_source_retry_does_not_read_a_fully_selected_directory() {
    let (mut engine, state, root) = fixture(0);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: root.into(),
            patch: NodePatch {
                completeness: Some(Completeness::Unknown),
                ..NodePatch::default()
            },
        }],
    );
    engine
        .set_slot(
            root,
            None,
            LoadState::Error,
            Some(Error::new(ErrorCode::ProviderError, "unreadable")),
            None,
        )
        .unwrap();
    select(
        &mut engine,
        state,
        &[root],
        SelectAction::Select,
        Scope::Subtree,
    );
    let revision = engine.states[&state].state.selection_revision;
    let Reply::Locked { token, .. } = engine.lock_selection(state, revision, None).unwrap() else {
        panic!("lock");
    };
    let before = engine.source.revision();
    let Reply::Ready { sources, .. } = engine
        .dispatch(
            state,
            Command::PrepareSources {
                lock: token,
                retry: true,
            },
            Context::default(),
        )
        .unwrap()
    else {
        panic!("ready");
    };
    assert_eq!(sources.subtree_roots.as_ref(), &[root]);
    assert_eq!(engine.source.revision(), before);
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Error
    );
    assert!(engine.reads.is_empty());
}
