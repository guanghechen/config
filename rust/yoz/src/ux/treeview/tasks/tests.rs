use super::super::test_support::*;
use super::super::*;
use std::sync::Arc;

#[test]
fn t_selection_inspection_retains_the_source_that_resolved_its_nodes() {
    let (mut engine, state, _) = ancestry_fixture();
    let node = engine.source.id("a").unwrap();
    select(
        &mut engine,
        state,
        &[node],
        SelectAction::Select,
        Scope::Subtree,
    );
    let Reply::Inspected {
        sources, source, ..
    } = engine
        .dispatch(state, Command::InspectSelection, Context::default())
        .unwrap()
    else {
        panic!("inspection");
    };
    apply(&mut engine, vec![Operation::Remove { node: node.into() }]);
    assert_eq!(sources.data_revision, source.revision());
    assert_eq!(&*sources.subtree_roots, &[node]);
    assert!(source.contains(node));
    assert!(!engine.source.contains(node));
}

fn prepare_subtree(engine: &mut Engine, state: u64, node: NodeId) -> (LockToken, CleanupToken) {
    select(engine, state, &[node], SelectAction::Select, Scope::Subtree);
    let selection = engine.states[&state].state.selection_revision;
    let Reply::Locked { token, .. } = engine.lock_selection(state, selection, None).unwrap() else {
        panic!("lock")
    };
    let Reply::Ready { cleanup, .. } = engine
        .dispatch(
            state,
            Command::PrepareSources {
                lock: token,
                retry: false,
            },
            Context::default(),
        )
        .unwrap()
    else {
        panic!("ready")
    };
    (token, cleanup)
}

#[test]
fn t_prepared_leaf_task_survives_ancestor_completeness_changes() {
    let (mut engine, state, root) = fixture(2);
    let leaf = engine.source.id("n0").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, leaf);
    for completeness in [Completeness::Partial, Completeness::Complete] {
        apply(
            &mut engine,
            vec![Operation::Update {
                node: root.into(),
                patch: NodePatch {
                    completeness: Some(completeness),
                    ..NodePatch::default()
                },
            }],
        );
        engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .check(lock, Some(cleanup))
            .unwrap();
    }
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![leaf].into(),
            },
            Context::default(),
        )
        .unwrap();
    assert!(
        !engine.states[&state]
            .state
            .selection
            .value(&engine.source, leaf)
            .unwrap()
    );
}

#[test]
fn t_prepared_leaf_task_still_rejects_ancestor_topology_changes() {
    let (mut engine, state, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let parent = engine.source.id("lib").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, leaf);
    apply(
        &mut engine,
        vec![Operation::Reparent {
            node: parent.into(),
            parent: Some(root.into()),
            position: Position::Last,
        }],
    );
    assert_eq!(
        engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .check(lock, Some(cleanup))
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
}

#[test]
fn t_prepared_complete_directory_refresh_preserves_scope_before_job_claim() {
    for change in ["unchanged", "insert", "remove", "reparent"] {
        let (mut engine, state, root) = fixture(2);
        let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
        let Reply::Applied { effects, .. } = engine.request_children(&[root], false).unwrap()
        else {
            panic!("request");
        };
        let token = effects
            .iter()
            .find_map(|effect| match effect {
                Effect::NeedChildren { token, .. } => Some(*token),
                _ => None,
            })
            .unwrap();
        engine
            .children_page(
                token,
                1,
                vec![Record::new("n0", NodeData::leaf("node-00000"))],
                false,
            )
            .unwrap();
        assert!(engine.states[&state].task.as_ref().unwrap().valid);
        assert!(
            !engine.states[&state]
                .task
                .as_ref()
                .unwrap()
                .can_discover(root)
        );
        let mut records = Vec::new();
        if change != "remove" {
            records.push(Record::new("n1", NodeData::leaf("node-00001")));
        }
        if change == "insert" {
            records.push(Record::new("new", NodeData::leaf("new")));
        }
        engine.children_page(token, 2, records, true).unwrap();
        if change == "reparent" {
            let node = engine.source.id("n0").unwrap();
            apply(
                &mut engine,
                vec![Operation::Reparent {
                    node: node.into(),
                    parent: None,
                    position: Position::Last,
                }],
            );
        }
        let result = engine.dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![root].into(),
            },
            Context::default(),
        );
        if change == "unchanged" {
            result.unwrap();
        } else {
            assert_eq!(result.unwrap_err().code, ErrorCode::Stale, "{change}");
        }
    }
}

#[test]
fn t_prepared_unknown_directory_does_not_gain_discovery_before_job_claim() {
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
    prepare_subtree(&mut engine, state, root);
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
    engine
        .children_page(
            token,
            1,
            vec![Record::new("new", NodeData::leaf("new"))],
            true,
        )
        .unwrap();
    assert!(!engine.states[&state].task.as_ref().unwrap().valid);
}

#[test]
fn t_prepared_subtree_task_rejects_unowned_completeness_changes() {
    let (mut engine, state, root) = fixture(2);
    let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: root.into(),
            patch: NodePatch {
                completeness: Some(Completeness::Partial),
                ..NodePatch::default()
            },
        }],
    );
    assert_eq!(
        engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .check(lock, Some(cleanup))
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
}

#[test]
fn t_partial_task_cleanup_accepts_prepared_descendants_and_preserves_parent_self() {
    let (mut engine, state, _) = ancestry_fixture();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let outside = engine.source.id("readme").unwrap();
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "b".into(),
            parent: Some(lib.into()),
            position: Position::Last,
            data: NodeData::leaf("failed.lua"),
            completeness: Completeness::Complete,
        }],
    );
    let failed = engine.source.id("b").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, src);
    let invalid = engine.dispatch(
        state,
        Command::Unselect {
            lock,
            cleanup,
            successful: vec![leaf, outside].into(),
        },
        Context::default(),
    );
    assert_eq!(invalid.unwrap_err().code, ErrorCode::Stale);
    assert!(
        engine.states[&state]
            .state
            .selection
            .value(&engine.source, leaf)
            .unwrap()
    );
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![leaf].into(),
            },
            Context::default(),
        )
        .unwrap();
    let selection = &engine.states[&state].state.selection;
    assert!(!selection.value(&engine.source, leaf).unwrap());
    for id in [src, lib, failed] {
        assert!(selection.value(&engine.source, id).unwrap());
    }
}

#[test]
fn t_partial_task_cleanup_collapses_only_current_success_ancestry() {
    let (mut engine, state, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let src = engine.source.id("src").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, src);
    let authorization = engine
        .authorize_task_update(
            state,
            lock,
            cleanup,
            vec![ExpectedChange::Reparent {
                node: leaf,
                parent: Some(root),
            }]
            .into(),
        )
        .unwrap();
    engine
        .apply_task_batch(
            Batch {
                base_revision: engine.source.revision(),
                operations: vec![Operation::Reparent {
                    node: leaf.into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                }],
            },
            authorization,
        )
        .unwrap();
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![src, leaf].into(),
            },
            Context::default(),
        )
        .unwrap();
    for id in [src, leaf] {
        assert!(
            !engine.states[&state]
                .state
                .selection
                .value(&engine.source, id)
                .unwrap()
        );
    }

    let (mut engine, state, _) = ancestry_fixture();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, src);
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![lib, leaf].into(),
            },
            Context::default(),
        )
        .unwrap();
    assert_eq!(engine.states[&state].state.selection.marks(leaf).subtree, 0);
    assert!(
        engine.states[&state]
            .state
            .selection
            .value(&engine.source, src)
            .unwrap()
    );
}

#[test]
fn t_partial_task_cleanup_tracks_moved_descendant_conflicts() {
    let (mut engine, state, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let src = engine.source.id("src").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, src);
    let authorization = engine
        .authorize_task_update(
            state,
            lock,
            cleanup,
            vec![ExpectedChange::Reparent {
                node: leaf,
                parent: Some(root),
            }]
            .into(),
        )
        .unwrap();
    engine
        .apply_task_batch(
            Batch {
                base_revision: engine.source.revision(),
                operations: vec![Operation::Reparent {
                    node: leaf.into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                }],
            },
            authorization,
        )
        .unwrap();
    apply(&mut engine, vec![Operation::Remove { node: leaf.into() }]);
    let result = engine.dispatch(
        state,
        Command::Unselect {
            lock,
            cleanup,
            successful: vec![src].into(),
        },
        Context::default(),
    );
    assert_eq!(result.unwrap_err().code, ErrorCode::Stale);
    assert!(
        engine.states[&state]
            .state
            .selection
            .value(&engine.source, src)
            .unwrap()
    );
}

#[test]
fn t_task_prepare_capacity_failure_preserves_unprepared_context() {
    let (mut engine, state, _) = ancestry_fixture();
    let src = engine.source.id("src").unwrap();
    select(
        &mut engine,
        state,
        &[src],
        SelectAction::Select,
        Scope::Subtree,
    );
    let Reply::Locked { token, .. } = engine
        .lock_selection(state, engine.states[&state].state.selection_revision, None)
        .unwrap()
    else {
        panic!("lock")
    };
    let _guard = engine.memory.enter();
    let held =
        super::super::memory::Charge::new(engine.limits.memory_bytes - engine.memory.used() - 32);
    let used = engine.memory.used();
    let result = engine.dispatch(
        state,
        Command::PrepareSources {
            lock: token,
            retry: false,
        },
        Context::default(),
    );
    assert_eq!(result.unwrap_err().code, ErrorCode::ResourceLimit);
    assert_eq!(engine.memory.used(), used);
    let task = engine.states[&state].task.as_ref().unwrap();
    assert!(task.valid && task.cleanup.is_none() && task.prepared.is_none());
    drop(held);
    assert!(matches!(
        engine
            .dispatch(
                state,
                Command::PrepareSources {
                    lock: token,
                    retry: false
                },
                Context::default()
            )
            .unwrap(),
        Reply::Ready { .. }
    ));
}

#[test]
fn t_partial_task_own_removes_preserve_remaining_success_and_failure() {
    let (mut engine, state, _) = ancestry_fixture();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    let leaf = engine.source.id("a").unwrap();
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "failed".into(),
            parent: Some(src.into()),
            position: Position::Last,
            data: NodeData::leaf("failed"),
            completeness: Completeness::Complete,
        }],
    );
    let failed = engine.source.id("failed").unwrap();
    let (lock, cleanup) = prepare_subtree(&mut engine, state, src);
    for id in [leaf, lib] {
        let token = engine
            .authorize_task_update(
                state,
                lock,
                cleanup,
                vec![ExpectedChange::Remove { node: id }].into(),
            )
            .unwrap();
        engine
            .apply_task_batch(
                Batch {
                    base_revision: engine.source.revision(),
                    operations: vec![Operation::Remove { node: id.into() }],
                },
                token,
            )
            .unwrap();
    }
    let selection = engine.states[&state].state.selection_revision;
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![leaf, lib].into(),
            },
            Context::default(),
        )
        .unwrap();
    assert_eq!(engine.states[&state].state.selection_revision, selection);
    for id in [src, failed] {
        assert!(
            engine.states[&state]
                .state
                .selection
                .value(&engine.source, id)
                .unwrap()
        );
    }
    assert_eq!(
        engine
            .dispatch(
                state,
                Command::Unselect {
                    lock,
                    cleanup,
                    successful: vec![failed].into()
                },
                Context::default()
            )
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
}

#[test]
fn t_task_discovery_admits_only_prepared_unknown_slots_for_partial_cleanup() {
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
    let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
    engine
        .states
        .get_mut(&state)
        .unwrap()
        .task
        .as_mut()
        .unwrap()
        .native_job = Some(7);
    let Reply::Applied { effects, .. } = engine.request_children(&[root], false).unwrap() else {
        panic!("request")
    };
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    engine
        .children_page(
            token,
            1,
            vec![
                Record::new("success", NodeData::leaf("success")),
                Record::new("failed", NodeData::leaf("failed")),
            ],
            false,
        )
        .unwrap();
    engine.children_page(token, 2, Vec::new(), true).unwrap();
    let success = engine.source.id("success").unwrap();
    let failed = engine.source.id("failed").unwrap();
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![success].into(),
            },
            Context::default(),
        )
        .unwrap();
    let selection = &engine.states[&state].state.selection;
    assert!(!selection.value(&engine.source, success).unwrap());
    assert!(selection.value(&engine.source, failed).unwrap());
    assert!(selection.value(&engine.source, root).unwrap());
}

#[test]
fn t_job_discovery_invalidates_old_browse_pages_before_partial_cleanup() {
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
    let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
    engine
        .states
        .get_mut(&state)
        .unwrap()
        .task
        .as_mut()
        .unwrap()
        .native_job = Some(7);
    engine.request_children(&[root], false).unwrap();
    let old = engine
        .reads
        .values()
        .find(|read| !read.cancelled)
        .unwrap()
        .token;
    engine
        .apply_job_discovery(
            Batch {
                base_revision: engine.source.revision(),
                operations: vec![Operation::Insert {
                    key: "copied".into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                    data: NodeData::leaf("copied"),
                    completeness: Completeness::Complete,
                }],
            },
            JobDiscovery {
                state,
                job: 7,
                lock,
                cleanup,
                parent: root,
                root,
            },
        )
        .unwrap();
    let copied = engine.source.id("copied").unwrap();
    assert_ne!(engine.source.node(root).unwrap().request_epoch, old.epoch);
    assert_eq!(
        engine
            .children_page(old, 1, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert!(engine.source.contains(copied));
    assert!(engine.states[&state].task.as_ref().unwrap().valid);
    assert!(
        engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .needed
            .is_empty()
    );
    engine
        .dispatch(
            state,
            Command::Unselect {
                lock,
                cleanup,
                successful: vec![copied].into(),
            },
            Context::default(),
        )
        .unwrap();
    let selection = &engine.states[&state].state.selection;
    assert!(!selection.value(&engine.source, copied).unwrap());
    assert!(selection.value(&engine.source, root).unwrap());
}

#[test]
fn t_native_job_claiming_a_read_midway_keeps_its_starting_discovery_scope() {
    for complete in [true, false] {
        let (mut engine, state, root) = fixture(0);
        if !complete {
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
        }
        engine.request_children(&[root], false).unwrap();
        let token = engine
            .reads
            .values()
            .find(|read| !read.cancelled)
            .unwrap()
            .token;
        engine.children_page(token, 1, Vec::new(), false).unwrap();
        assert_eq!(
            engine.source.node(root).unwrap().completeness,
            Completeness::Partial
        );
        let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
        engine
            .states
            .get_mut(&state)
            .unwrap()
            .task
            .as_mut()
            .unwrap()
            .native_job = Some(7);
        engine
            .children_page(
                token,
                2,
                vec![Record::new("new", NodeData::leaf("new"))],
                true,
            )
            .unwrap();
        assert_eq!(
            engine.states[&state].task.as_ref().unwrap().valid,
            !complete
        );
        assert!(
            engine.states[&state]
                .task
                .as_ref()
                .unwrap()
                .needed
                .is_empty()
        );
        if !complete {
            let node = engine.source.id("new").unwrap();
            engine
                .dispatch(
                    state,
                    Command::Unselect {
                        lock,
                        cleanup,
                        successful: vec![node].into(),
                    },
                    Context::default(),
                )
                .unwrap();
            assert!(
                !engine.states[&state]
                    .state
                    .selection
                    .value(&engine.source, node)
                    .unwrap()
            );
            assert!(
                engine.states[&state]
                    .state
                    .selection
                    .value(&engine.source, root)
                    .unwrap()
            );
        }
    }
}

#[test]
fn t_native_discovery_does_not_reopen_after_completed_read_and_cancelled_refresh() {
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
    prepare_subtree(&mut engine, state, root);
    engine
        .states
        .get_mut(&state)
        .unwrap()
        .task
        .as_mut()
        .unwrap()
        .native_job = Some(7);
    engine.request_children(&[root], false).unwrap();
    let first = engine
        .reads
        .values()
        .find(|read| !read.cancelled)
        .unwrap()
        .token;
    engine
        .children_page(
            first,
            1,
            vec![Record::new("known", NodeData::leaf("known"))],
            true,
        )
        .unwrap();
    assert!(
        engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .native_status()
            .unwrap()
            .closed(root)
    );
    engine.request_children(&[root], false).unwrap();
    let refresh = engine
        .reads
        .values()
        .find(|read| !read.cancelled)
        .unwrap()
        .token;
    engine.children_page(refresh, 1, Vec::new(), false).unwrap();
    engine.children_cancelled(refresh).unwrap();
    assert_eq!(
        engine.source.node(root).unwrap().completeness,
        Completeness::Partial
    );
    engine.request_children(&[root], false).unwrap();
    let next = engine
        .reads
        .values()
        .find(|read| !read.cancelled)
        .unwrap()
        .token;
    assert_ne!(next, refresh);
    assert_eq!(
        engine
            .children_page(refresh, 2, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert!(
        engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .native_status()
            .unwrap()
            .closed(root)
    );
    engine
        .children_page(
            next,
            1,
            vec![
                Record::new("known", NodeData::leaf("known")),
                Record::new("new", NodeData::leaf("new")),
            ],
            true,
        )
        .unwrap();
    assert!(
        engine.source.id("new").is_some(),
        "ordinary browsing still publishes the new fact"
    );
    assert!(!engine.states[&state].task.as_ref().unwrap().valid);
}

#[test]
fn t_native_read_scope_remains_charged_after_automatic_admission() {
    let (mut engine, state, root) = fixture(0);
    prepare_subtree(&mut engine, state, root);
    engine
        .states
        .get_mut(&state)
        .unwrap()
        .task
        .as_mut()
        .unwrap()
        .native_job = Some(7);
    engine.manual_reads.insert(root);
    let budget = engine.memory.clone();
    engine.schedule_reads().unwrap();
    let status = engine.states[&state]
        .task
        .as_ref()
        .unwrap()
        .native_status()
        .unwrap();
    assert!(status.closed(root));
    drop(engine);
    assert!(
        budget.used() > 0,
        "a retained native scope must retain its allocation charge"
    );
    drop(status);
    assert_eq!(budget.used(), 0);
}

#[test]
fn t_automatic_read_capacity_failure_keeps_cancellation_and_rejects_phantom_work() {
    for cancel_old in [false, true] {
        let (mut engine, state, root) = fixture(0);
        prepare_subtree(&mut engine, state, root);
        engine
            .states
            .get_mut(&state)
            .unwrap()
            .task
            .as_mut()
            .unwrap()
            .native_job = Some(7);
        let old = if cancel_old {
            engine.request_children(&[root], false).unwrap();
            let token = engine.reads.values().next().unwrap().token;
            let _guard = engine.memory.enter();
            let mut source = (*engine.source).clone();
            let mut node = source.node(root).unwrap().clone();
            node.request_epoch += 1;
            source.nodes.insert(root, node);
            engine.source = Arc::new(source);
            Some(token)
        } else {
            engine.manual_reads.insert(root);
            None
        };
        let epoch = engine.source.node(root).unwrap().request_epoch;
        let closed = engine.states[&state]
            .task
            .as_ref()
            .unwrap()
            .native_status()
            .unwrap()
            .closed(root);
        let held = {
            let _guard = engine.memory.enter();
            super::super::memory::Charge::new(engine.limits.memory_bytes - engine.memory.used())
        };
        let effects = engine.schedule_reads().unwrap();
        assert!(
            effects
                .iter()
                .all(|effect| !matches!(effect, Effect::NeedChildren { .. }))
        );
        if let Some(old) = old {
            assert!(
                effects.iter().any(
                    |effect| matches!(effect, Effect::CancelChildren { token } if *token == old)
                )
            );
            assert!(engine.reads[&old.work].cancelled);
        }
        assert_eq!(engine.reads.len(), usize::from(cancel_old));
        assert_eq!(engine.source.node(root).unwrap().request_epoch, epoch);
        assert_eq!(
            engine
                .source
                .node(root)
                .unwrap()
                .error
                .as_ref()
                .unwrap()
                .code,
            ErrorCode::ResourceLimit
        );
        assert!(!engine.manual_reads.contains(&root));
        assert_eq!(
            engine.states[&state]
                .task
                .as_ref()
                .unwrap()
                .native_status()
                .unwrap()
                .closed(root),
            closed
        );
        drop(held);
        if let Some(old) = old {
            engine.children_cancelled(old).unwrap();
        }
        let retry = engine
            .request_children(&[root], true)
            .unwrap()
            .into_effects();
        assert!(
            retry
                .iter()
                .any(|effect| matches!(effect, Effect::NeedChildren { .. }))
        );
        assert_eq!(engine.reads.len(), 1);
        assert!(
            engine.states[&state]
                .task
                .as_ref()
                .unwrap()
                .native_status()
                .unwrap()
                .closed(root)
        );
    }
}

#[test]
fn t_job_discovery_rejects_wrong_job_complete_slots_and_non_insert_batches_atomically() {
    for invalid in ["job", "complete", "operation", "capacity"] {
        let (mut engine, state, root) = fixture(0);
        if invalid != "complete" {
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
        }
        let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
        engine
            .states
            .get_mut(&state)
            .unwrap()
            .task
            .as_mut()
            .unwrap()
            .native_job = Some(7);
        let before = engine.source.clone();
        let _guard = engine.memory.enter();
        let held = (invalid == "capacity")
            .then(|| super::super::memory::Charge::new(engine.limits.memory_bytes));
        let operation = if invalid == "operation" {
            Operation::Remove { node: root.into() }
        } else {
            Operation::Insert {
                key: "new".into(),
                parent: Some(root.into()),
                position: Position::Last,
                data: NodeData::leaf("new"),
                completeness: Completeness::Complete,
            }
        };
        let error = engine
            .apply_job_discovery(
                Batch {
                    base_revision: engine.source.revision(),
                    operations: vec![operation],
                },
                JobDiscovery {
                    state,
                    job: if invalid == "job" { 8 } else { 7 },
                    lock,
                    cleanup,
                    parent: root,
                    root,
                },
            )
            .unwrap_err();
        assert_eq!(
            error.code,
            match invalid {
                "operation" => ErrorCode::InvalidUpdate,
                "capacity" => ErrorCode::ResourceLimit,
                _ => ErrorCode::Stale,
            }
        );
        drop(held);
        assert!(Arc::ptr_eq(&engine.source, &before));
        assert!(engine.source.id("new").is_none());
        assert!(engine.states[&state].task.as_ref().unwrap().valid);
        assert!(
            engine.states[&state]
                .state
                .selection
                .value(&engine.source, root)
                .unwrap()
        );
    }
}

#[test]
fn t_unloaded_child_changes_invalidate_only_the_affected_task_scope() {
    let (mut engine, state, other) = ancestry_fixture();
    let src = engine.source.id("src").unwrap();
    let readme = engine.source.id("readme").unwrap();
    prepare_subtree(&mut engine, state, readme);
    prepare_subtree(&mut engine, other, src);
    let before = engine.source.clone();
    engine.unloaded_children_changed(src);
    assert!(engine.states[&state].task.as_ref().unwrap().valid);
    assert!(!engine.states[&other].task.as_ref().unwrap().valid);
    assert!(
        Arc::ptr_eq(&before, &engine.source),
        "an unmaterialized fact creates no phantom child"
    );
}

#[test]
fn t_task_discovery_does_not_authorize_new_members_in_an_already_complete_slot() {
    let (mut engine, state, root) = fixture(0);
    let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
    engine
        .states
        .get_mut(&state)
        .unwrap()
        .task
        .as_mut()
        .unwrap()
        .native_job = Some(7);
    let Reply::Applied { effects, .. } = engine.request_children(&[root], false).unwrap() else {
        panic!("request")
    };
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    engine.children_page(token, 1, Vec::new(), false).unwrap();
    assert!(
        engine.states[&state].task.as_ref().unwrap().valid,
        "request progress is not a membership change"
    );
    engine
        .children_page(
            token,
            2,
            vec![Record::new("external", NodeData::leaf("external"))],
            true,
        )
        .unwrap();
    assert!(!engine.states[&state].task.as_ref().unwrap().valid);
    assert!(
        engine
            .dispatch(
                state,
                Command::Unselect {
                    lock,
                    cleanup,
                    successful: vec![root].into()
                },
                Context::default()
            )
            .is_err()
    );
}

#[test]
fn t_task_read_retry_preserves_discovery_grants_without_expanding_them() {
    for queued in [false, true] {
        for complete in [false, true] {
            for cancelled in [false, true] {
                let (mut engine, state, root) = fixture(0);
                engine.limits.concurrent_reads = 1;
                apply(
                    &mut engine,
                    vec![
                        Operation::Update {
                            node: root.into(),
                            patch: NodePatch {
                                completeness: Some(if complete {
                                    Completeness::Complete
                                } else {
                                    Completeness::Unknown
                                }),
                                ..NodePatch::default()
                            },
                        },
                        Operation::Insert {
                            key: "busy".into(),
                            parent: None,
                            position: Position::Last,
                            data: NodeData::branch("busy"),
                            completeness: Completeness::Unknown,
                        },
                    ],
                );
                let busy = engine.source.id("busy").unwrap();
                let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
                if queued {
                    engine.request_children(&[busy], false).unwrap();
                }
                engine
                    .states
                    .get_mut(&state)
                    .unwrap()
                    .task
                    .as_mut()
                    .unwrap()
                    .native_job = Some(7);
                engine.request_children(&[root], false).unwrap();
                if !queued && cancelled {
                    let token = engine
                        .reads
                        .values()
                        .find(|read| read.token.node == root)
                        .unwrap()
                        .token;
                    engine.children_cancelled(token).unwrap();
                }
                /* Multiple dirty notifications may restart either an active or queued read. */
                engine.request_children(&[root], true).unwrap();
                engine.request_children(&[root], true).unwrap();
                let old: Vec<_> = engine
                    .reads
                    .values()
                    .filter(|read| read.cancelled || read.token.node == busy)
                    .map(|read| read.token)
                    .collect();
                for token in old {
                    engine.children_cancelled(token).unwrap();
                }
                engine.schedule_reads().unwrap();
                let token = engine
                    .reads
                    .values()
                    .find(|read| read.token.node == root && !read.cancelled)
                    .unwrap()
                    .token;
                engine
                    .children_page(
                        token,
                        1,
                        vec![Record::new("discovered", NodeData::leaf("discovered"))],
                        true,
                    )
                    .unwrap();
                assert_eq!(
                    engine.states[&state].task.as_ref().unwrap().valid,
                    !complete
                );
                if !complete {
                    let discovered = engine.source.id("discovered").unwrap();
                    engine
                        .dispatch(
                            state,
                            Command::Unselect {
                                lock,
                                cleanup,
                                successful: vec![discovered].into(),
                            },
                            Context::default(),
                        )
                        .unwrap();
                    assert!(
                        !engine.states[&state]
                            .state
                            .selection
                            .value(&engine.source, discovered)
                            .unwrap()
                    );
                }
            }
        }
    }
}
