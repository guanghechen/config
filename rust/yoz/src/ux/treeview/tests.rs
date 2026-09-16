use super::*;
use std::sync::Arc;
use std::time::{Duration, Instant};

fn records(count: usize) -> Vec<Record> {
    let mut records = vec![Record::new("root", NodeData::branch("root"))];
    records.extend((0..count).map(|index| Record {
        key: format!("n{index}").into(),
        parent: Some("root".into()),
        data: NodeData::leaf(format!("node-{index:05}")),
        completeness: None,
    }));
    records
}

fn fixture(count: usize) -> (Engine, u64, NodeId) {
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: records(count),
        })
        .unwrap();
    let root = engine.source.id("root").unwrap();
    let state = engine
        .create_state(Root::ChildrenOf(root), DisplayOptions::default())
        .unwrap();
    (engine, state, root)
}

fn apply(engine: &mut Engine, operations: Vec<Operation>) -> Reply {
    engine
        .apply_batch(Batch {
            base_revision: engine.source.revision(),
            operations,
        })
        .unwrap()
}

fn project(engine: &mut Engine, state: u64) -> Arc<Snapshot> {
    for (_, result) in engine.project() {
        result.unwrap();
    }
    engine.snapshot(state).unwrap()
}

fn assert_projection(engine: &Engine, state: u64) {
    let frame = engine.snapshot(state).unwrap();
    let mut state = engine.states[&state].state.clone();
    let full = Snapshot::build(
        engine.source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        engine.commit,
    )
    .unwrap();
    assert_eq!(
        frame.rows.iter().collect::<Vec<_>>(),
        full.rows.iter().collect::<Vec<_>>()
    );
    assert_eq!(frame.last_root, full.last_root);
    for (id, children) in full.matched_children.iter() {
        assert_eq!(
            frame
                .matched_children
                .get(id)
                .map(|value| value.iter().copied().collect::<Vec<_>>()),
            Some(children.iter().copied().collect::<Vec<_>>()),
            "cached matches for {id:?}"
        );
    }
    let mut actual = frame.needed_children.to_vec();
    let mut expected = full.needed_children.to_vec();
    actual.sort();
    expected.sort();
    assert_eq!(actual, expected);
}

fn lines(frame: Arc<Snapshot>) -> Vec<String> {
    let plan = RenderPlan::new(None, frame.clone(), None, RenderContext::default(), false).unwrap();
    let mut lines = Vec::new();
    let mut at = 0;
    while at < frame.len() {
        let (chunk, next) = plan
            .lines(at, (at + 512).min(frame.len()), 1024 * 1024)
            .unwrap();
        lines.extend(chunk);
        at = next;
    }
    lines
}

fn apply_plan(mut body: Vec<String>, plan: &RenderPlan) -> Vec<String> {
    for splice in plan.splices.iter().rev() {
        let mut text = Vec::new();
        let mut at = splice.target_start;
        while at < splice.target_end {
            let (chunk, next) = plan
                .lines(at, (at + 512).min(splice.target_end), 1024 * 1024)
                .unwrap();
            text.extend(chunk);
            at = next;
        }
        body.splice(splice.old_start..splice.old_end, text);
    }
    body
}

#[test]
fn t_scoped_import_retains_children_identity_and_rejects_cross_scope_removal() {
    let (mut engine, _, root) = fixture(2);
    let a = engine.source.id("n0").unwrap();
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: a.into(),
                patch: NodePatch {
                    can_expand: Some(true),
                    ..NodePatch::default()
                },
            },
            Operation::Insert {
                key: "inside".into(),
                parent: Some(a.into()),
                position: Position::Last,
                data: NodeData::leaf("inside"),
                completeness: Completeness::Complete,
            },
        ],
    );
    let inner = engine.source.id("inside").unwrap();
    let parent_provider = engine.create_provider(DataScope::Children(root)).unwrap();
    let _nested = engine.create_provider(DataScope::Descendants(a)).unwrap();
    engine
        .provider_import(
            parent_provider,
            engine.source.revision(),
            vec![Record::new("n0", NodeData::branch("renamed"))],
        )
        .unwrap();
    assert_eq!(engine.source.id("n0"), Some(a));
    assert_eq!(engine.source.id("inside"), Some(inner));
    assert!(engine.source.id("n1").is_none());
    let old = engine.source.clone();
    let result = engine.provider_import(parent_provider, engine.source.revision(), Vec::new());
    assert_eq!(result.unwrap_err().code, ErrorCode::InvalidUpdate);
    assert!(Arc::ptr_eq(&old, &engine.source));
}

#[test]
fn t_full_snapshot_reverses_ancestry_before_removing_obsolete_parents() {
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: vec![
                Record::new("a", NodeData::branch("A")),
                Record {
                    key: "b".into(),
                    parent: Some("a".into()),
                    data: NodeData::branch("B"),
                    completeness: None,
                },
            ],
        })
        .unwrap();
    let a = engine.source.id("a").unwrap();
    let b = engine.source.id("b").unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: vec![
                Record {
                    key: "a".into(),
                    parent: Some("b".into()),
                    data: NodeData::leaf("A"),
                    completeness: None,
                },
                Record::new("b", NodeData::branch("B")),
            ],
        })
        .unwrap();
    assert_eq!(engine.source.id("a"), Some(a));
    assert_eq!(engine.source.node(a).unwrap().parent, Some(b));
    assert_eq!(engine.source.node(b).unwrap().parent, None);
    assert!(!engine.source.node(a).unwrap().data.can_expand);
}

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
fn t_query_replacement_is_distinct_from_children_refresh_and_old_generation_is_stale() {
    let (mut engine, _, root) = fixture(3);
    engine.limits.concurrent_reads = 1;
    let provider = engine
        .create_provider(DataScope::Descendants(root))
        .unwrap();
    let query = engine.create_query(provider).unwrap();
    let Reply::Applied { effects, .. } = engine
        .accept_query(
            query,
            QueryInput {
                pattern: "a".into(),
                ..QueryInput::default()
            },
        )
        .unwrap()
    else {
        panic!("query");
    };
    let old_token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::Query { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    engine
        .accept_query(
            query,
            QueryInput {
                pattern: "ab".into(),
                ..QueryInput::default()
            },
        )
        .unwrap();
    engine
        .accept_query(
            query,
            QueryInput {
                pattern: "a".into(),
                ..QueryInput::default()
            },
        )
        .unwrap();
    assert_eq!(engine.query_work.len(), 1);
    assert_eq!(
        engine
            .query_page(old_token, 1, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert_eq!(engine.source.node(root).unwrap().child_count(), 3);
    let effect = engine.schedule_queries().unwrap().remove(0);
    let Effect::Query { token, .. } = effect else {
        panic!("replacement query");
    };
    assert!(token.generation > old_token.generation);
    let retained = engine.source.id("n0").unwrap();
    let removed = engine.source.id("n1").unwrap();
    engine
        .query_page(
            token,
            1,
            vec![Record::new("n0", NodeData::leaf("current"))],
            false,
        )
        .unwrap();
    assert_eq!(engine.source.id("n0"), Some(retained));
    assert!(!engine.source.contains(removed));
    engine
        .query_page(
            token,
            2,
            vec![Record::new("n1", NodeData::leaf("new occurrence"))],
            true,
        )
        .unwrap();
    assert_ne!(engine.source.id("n1"), Some(removed));
    assert_eq!(
        engine.query_info(query).unwrap().result_generation,
        Some(token.generation)
    );
    assert_eq!(
        engine
            .query_page(token, 2, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
}

#[test]
fn t_incremental_tree_and_render_match_full_rebuild_during_mixed_local_changes() {
    let (mut engine, state, root) = fixture(100);
    let a = engine.source.id("n5").unwrap();
    let b = engine.source.id("n20").unwrap();
    let baseline = project(&mut engine, state);
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: a.into(),
                patch: NodePatch {
                    can_expand: Some(true),
                    ..NodePatch::default()
                },
            },
            Operation::Reparent {
                node: b.into(),
                parent: Some(a.into()),
                position: Position::Last,
            },
        ],
    );
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![a].into()),
                value: true,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        )
        .unwrap();
    let middle = project(&mut engine, state);
    assert_projection(&engine, state);
    apply(
        &mut engine,
        vec![
            Operation::Insert {
                key: "head".into(),
                parent: Some(root.into()),
                position: Position::First,
                data: NodeData::leaf("head"),
                completeness: Completeness::Complete,
            },
            Operation::Update {
                node: b.into(),
                patch: NodePatch {
                    label: Some("renamed UTF-8 中文".into()),
                    ..NodePatch::default()
                },
            },
            Operation::Remove { node: "n8".into() },
        ],
    );
    let next = project(&mut engine, state);
    assert_projection(&engine, state);
    assert!(next.visited_nodes < 10);
    for base in [baseline, middle] {
        let plan = RenderPlan::new(
            Some(base.clone()),
            next.clone(),
            Some(&RenderContext::default()),
            RenderContext::default(),
            false,
        )
        .unwrap();
        assert_eq!(apply_plan(lines(base), &plan), lines(next.clone()));
    }
}

#[test]
fn t_head_insertion_and_single_text_edit_do_not_scan_fifty_thousand_rows() {
    let (mut engine, state, root) = fixture(50_000);
    let base = project(&mut engine, state);
    let tail = engine.source.id("n49999").unwrap();
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "head".into(),
            parent: Some(root.into()),
            position: Position::First,
            data: NodeData::leaf("head"),
            completeness: Completeness::Complete,
        }],
    );
    let next = project(&mut engine, state);
    assert!(
        next.visited_nodes < 5,
        "visited {} nodes",
        next.visited_nodes
    );
    assert_eq!(next.position(tail), Some(50_000));
    assert_eq!(base.position(tail), Some(49_999));
    let plan = RenderPlan::new(
        Some(base.clone()),
        next.clone(),
        Some(&RenderContext::default()),
        RenderContext::default(),
        false,
    )
    .unwrap();
    assert_eq!(plan.work.written_rows, 1);
    assert!(
        plan.work.compared_rows < 200,
        "compared {} rows",
        plan.work.compared_rows
    );
    assert!(plan.work.shared_rows > 49_000);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: tail.into(),
            patch: NodePatch {
                label: Some("tail changed".into()),
                ..NodePatch::default()
            },
        }],
    );
    let final_frame = project(&mut engine, state);
    let plan = RenderPlan::new(
        Some(next),
        final_frame.clone(),
        Some(&RenderContext::default()),
        RenderContext::default(),
        false,
    )
    .unwrap();
    assert_eq!(plan.work.written_rows, 1);
    assert_eq!(plan.work.compared_rows, 1);
    assert_eq!(final_frame.visited_nodes, 0);
}

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

#[test]
fn t_flat_reorder_hint_respects_the_reset_coverage_threshold() {
    for reverse in [false, true] {
        let (mut engine, state, _) = fixture(2000);
        apply(
            &mut engine,
            (0..2000)
                .map(|i| Operation::Update {
                    node: format!("n{i}").as_str().into(),
                    patch: NodePatch {
                        score: Some(if reverse {
                            i as f64
                        } else {
                            if i >= 1000 { 1.0 } else { 0.0 }
                        }),
                        ..NodePatch::default()
                    },
                })
                .collect(),
        );
        let base = project(&mut engine, state);
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    sort: Sort::Score,
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(base.state_revision()),
                    ..Context::default()
                },
            )
            .unwrap();
        let target = project(&mut engine, state);
        let plan = RenderPlan::new(
            Some(base.clone()),
            target.clone(),
            Some(&RenderContext::default()),
            RenderContext::default(),
            false,
        )
        .unwrap();
        assert_eq!(
            plan.mode,
            if reverse {
                PlanMode::Reset
            } else {
                PlanMode::Delta
            }
        );
        assert_eq!(apply_plan(lines(base), &plan), lines(target));
        if reverse {
            assert_eq!(plan.work.compared_rows, 0);
        }
    }
}

#[test]
fn t_local_leaf_changes_match_full_list_selected_and_compressed_projection() {
    for display in [
        DisplayOptions {
            mode: Mode::List,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            selected_only: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            compress: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            pattern: "node-".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            selected_only: true,
            pattern: "node-".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            compress: true,
            pattern: "node-".into(),
            ..DisplayOptions::default()
        },
    ] {
        let (mut engine, state, root) = fixture(1000);
        if display.selected_only {
            engine
                .dispatch(
                    state,
                    Command::Select {
                        targets: Targets::Nodes(vec![root].into()),
                        action: SelectAction::Select,
                        scope: Scope::Subtree,
                    },
                    Context::default(),
                )
                .unwrap();
        }
        let before = project(&mut engine, state);
        engine
            .dispatch(
                state,
                Command::SetDisplay(display.clone()),
                Context {
                    expected_state: Some(before.state_revision()),
                    ..Context::default()
                },
            )
            .unwrap();
        project(&mut engine, state);
        apply(
            &mut engine,
            vec![Operation::Insert {
                key: "inserted".into(),
                parent: Some(root.into()),
                position: Position::First,
                data: NodeData::leaf("inserted"),
                completeness: Completeness::Complete,
            }],
        );
        let frame = project(&mut engine, state);
        assert!(frame.visited_nodes < 5);
        assert_projection(&engine, state);
        if display.selected_only {
            let id = engine.source.id("n500").unwrap();
            engine
                .dispatch(
                    state,
                    Command::Select {
                        targets: Targets::Nodes(vec![id].into()),
                        action: SelectAction::Deselect,
                        scope: Scope::SelfOnly,
                    },
                    Context::default(),
                )
                .unwrap();
            assert!(project(&mut engine, state).visited_nodes < 5);
            assert_projection(&engine, state);
        }
        apply(
            &mut engine,
            vec![Operation::Remove {
                node: "inserted".into(),
            }],
        );
        project(&mut engine, state);
        assert_projection(&engine, state);
        if !display.pattern.is_empty() {
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: "n500".into(),
                    patch: NodePatch {
                        label: Some("excluded".into()),
                        ..NodePatch::default()
                    },
                }],
            );
            project(&mut engine, state);
            assert_projection(&engine, state);
        }
    }
}

#[test]
fn t_compressed_chain_edits_preserve_unaffected_fifty_thousand_row_blocks() {
    let (mut engine, state, root) = fixture(50_000);
    let parent = engine.source.id("n0").unwrap();
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: parent.into(),
                patch: NodePatch {
                    can_expand: Some(true),
                    foldable: Some(true),
                    ..NodePatch::default()
                },
            },
            Operation::Insert {
                key: "chain".into(),
                parent: Some(parent.into()),
                position: Position::Last,
                data: NodeData {
                    foldable: true,
                    ..NodeData::branch("chain")
                },
                completeness: Completeness::Complete,
            },
        ],
    );
    let chain = engine.source.id("chain").unwrap();
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                compress: true,
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![root].into()),
                value: true,
                scope: Scope::Subtree,
            },
            Context::default(),
        )
        .unwrap();
    let base = project(&mut engine, state);
    assert_eq!(base.position(parent), base.position(chain));
    let tail = engine.source.id("n49999").unwrap();
    for inserted in [true, false, true, false] {
        let before = engine.snapshot(state).unwrap();
        apply(
            &mut engine,
            vec![if inserted {
                Operation::Insert {
                    key: "sibling".into(),
                    parent: Some(parent.into()),
                    position: Position::First,
                    data: NodeData::leaf("sibling"),
                    completeness: Completeness::Complete,
                }
            } else {
                Operation::Remove {
                    node: "sibling".into(),
                }
            }],
        );
        let next = project(&mut engine, state);
        assert_projection(&engine, state);
        assert!(
            next.visited_nodes < 20,
            "visited {} nodes",
            next.visited_nodes
        );
        let shared: usize = before
            .rows
            .shared_spans(&next.rows)
            .iter()
            .map(|(_, _, len)| len)
            .sum();
        assert!(shared >= 49_900, "only {shared} rows shared");
        let plan = RenderPlan::new(
            Some(before.clone()),
            next.clone(),
            Some(&RenderContext::default()),
            RenderContext::default(),
            false,
        )
        .unwrap();
        assert_eq!(plan.mode, PlanMode::Delta);
        assert!(plan.work.compared_rows < 150);
        assert_eq!(apply_plan(lines(before), &plan), lines(next.clone()));
        assert_eq!(base.position(tail), Some(49_999));
        assert_eq!(base.position(parent), base.position(chain));
        assert_eq!(next.position(parent) == next.position(chain), !inserted);
    }
}

#[test]
fn t_compressed_local_changes_match_full_projection_with_old_frames() {
    for display in [
        DisplayOptions {
            compress: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            pattern: "node-0002".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            compress: true,
            pattern: "node-0002".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            selected_only: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            compress: true,
            selected_only: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            compress: true,
            selected_only: true,
            pattern: "node-0002".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            pattern: "node-0002".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            selected_only: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            selected_only: true,
            pattern: "node-0002".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            sort: Sort::Name,
            compress: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            sort: Sort::Score,
            compress: true,
            selected_only: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            branches_first: true,
            compress: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            sort: Sort::Name,
            pattern: "node-0002".into(),
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            sort: Sort::Score,
            selected_only: true,
            ..DisplayOptions::default()
        },
        DisplayOptions {
            mode: Mode::List,
            branches_first: true,
            ..DisplayOptions::default()
        },
    ] {
        let (mut engine, state, root) = fixture(64);
        let ids: Vec<_> = (0..64)
            .map(|at| engine.source.id(&format!("n{at}")).unwrap())
            .collect();
        let mut operations: Vec<_> = ids[..24]
            .iter()
            .map(|&id| Operation::Update {
                node: id.into(),
                patch: NodePatch {
                    can_expand: Some(true),
                    foldable: Some(true),
                    ..NodePatch::default()
                },
            })
            .collect();
        operations.extend((0..12).map(|at| Operation::Reparent {
            node: ids[12 + at].into(),
            parent: Some(ids[at].into()),
            position: Position::Last,
        }));
        apply(&mut engine, operations);
        engine
            .dispatch(
                state,
                Command::SetDisplay(display.clone()),
                Context {
                    expected_state: Some(engine.states[&state].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![root].into()),
                    value: true,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        let pinned = project(&mut engine, state);
        let old_lines = lines(pinned.clone());
        let mut seed = 173_u64;
        for iteration in 0..300 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let id = ids[(seed as usize >> 8) % 24];
            let flag = seed & 128 != 0;
            match iteration % 6 {
                0 => {
                    apply(
                        &mut engine,
                        vec![Operation::Update {
                            node: id.into(),
                            patch: NodePatch {
                                hidden: Some(flag),
                                ..NodePatch::default()
                            },
                        }],
                    );
                }
                1 => {
                    apply(
                        &mut engine,
                        vec![Operation::Update {
                            node: id.into(),
                            patch: NodePatch {
                                foldable: Some(flag),
                                ..NodePatch::default()
                            },
                        }],
                    );
                }
                2 => {
                    engine
                        .dispatch(
                            state,
                            Command::SetExpanded {
                                targets: Targets::Nodes(vec![id].into()),
                                value: flag,
                                scope: Scope::SelfOnly,
                            },
                            Context::default(),
                        )
                        .unwrap();
                }
                3 => {
                    engine
                        .dispatch(
                            state,
                            Command::Select {
                                targets: Targets::Nodes(vec![id].into()),
                                action: if flag {
                                    SelectAction::Select
                                } else {
                                    SelectAction::Deselect
                                },
                                scope: Scope::SelfOnly,
                            },
                            Context::default(),
                        )
                        .unwrap();
                }
                4 => {
                    apply(
                        &mut engine,
                        vec![Operation::Update {
                            node: id.into(),
                            patch: NodePatch {
                                label: Some(if flag { "node-00020" } else { "excluded" }.into()),
                                score: Some(((seed >> 32) % 11) as f64),
                                ..NodePatch::default()
                            },
                        }],
                    );
                }
                _ => {
                    apply(
                        &mut engine,
                        vec![Operation::Reparent {
                            node: ids[12 + (seed as usize >> 16) % 12].into(),
                            parent: Some(ids[(seed as usize >> 24) % 12].into()),
                            position: if flag {
                                Position::First
                            } else {
                                Position::Last
                            },
                        }],
                    );
                }
            }
            project(&mut engine, state);
            assert_projection(&engine, state);
        }
        assert_eq!(lines(pinned), old_lines);
    }
}

#[test]
fn t_sparse_membership_updates_do_not_scan_fifty_thousand_siblings() {
    let mut engine = Engine::new(Limits::default()).unwrap();
    let mut input = vec![
        Record::new("root", NodeData::branch("root")),
        Record {
            parent: Some("root".into()),
            ..Record::new("bucket", NodeData::branch("bucket"))
        },
    ];
    input.extend((0..50_000).map(|at| Record {
        parent: Some("bucket".into()),
        ..Record::new(
            format!("n{at}"),
            NodeData::leaf(if at == 49_999 { "needle" } else { "noise" }),
        )
    }));
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: input,
        })
        .unwrap();
    let root = engine.source.id("root").unwrap();
    let bucket = engine.source.id("bucket").unwrap();
    let head = engine.source.id("n0").unwrap();
    let mut states = Vec::new();
    for mode in [Mode::Tree, Mode::List] {
        for selected_only in [false, true] {
            let state = engine
                .create_state(
                    Root::ChildrenOf(root),
                    DisplayOptions {
                        mode,
                        selected_only,
                        pattern: if selected_only { "" } else { "needle" }.into(),
                        ..DisplayOptions::default()
                    },
                )
                .unwrap();
            engine
                .dispatch(
                    state,
                    Command::SetExpanded {
                        targets: Targets::Nodes(vec![root].into()),
                        value: true,
                        scope: Scope::Subtree,
                    },
                    Context::default(),
                )
                .unwrap();
            if selected_only {
                engine
                    .dispatch(
                        state,
                        Command::Select {
                            targets: Targets::Nodes(vec![root].into()),
                            action: SelectAction::Select,
                            scope: Scope::Subtree,
                        },
                        Context::default(),
                    )
                    .unwrap();
            }
            project(&mut engine, state);
            states.push((state, selected_only, engine.snapshot(state).unwrap()));
        }
    }
    let mut sorted_states = Vec::new();
    for sort in [Sort::Name, Sort::Score] {
        let id = engine
            .create_state(
                Root::ChildrenOf(root),
                DisplayOptions {
                    mode: Mode::List,
                    sort,
                    ..DisplayOptions::default()
                },
            )
            .unwrap();
        sorted_states.push((id, engine.snapshot(id).unwrap()));
    }
    apply(
        &mut engine,
        vec![Operation::Update {
            node: head.into(),
            patch: NodePatch {
                label: Some("needle".into()),
                ..NodePatch::default()
            },
        }],
    );
    let selected_tree = states
        .iter()
        .find(|(id, selected, _)| *selected && engine.states[id].state.display.mode == Mode::Tree)
        .unwrap()
        .0;
    for (state, selected_only, pinned) in states {
        if selected_only {
            engine
                .dispatch(
                    state,
                    Command::Select {
                        targets: Targets::Nodes(vec![head].into()),
                        action: SelectAction::Deselect,
                        scope: Scope::SelfOnly,
                    },
                    Context::default(),
                )
                .unwrap();
        }
        let frame = project(&mut engine, state);
        assert_projection(&engine, state);
        assert!(frame.visited_nodes < 20, "visited {}", frame.visited_nodes);
        if selected_only {
            let shared: usize = pinned
                .rows
                .shared_spans(&frame.rows)
                .iter()
                .map(|(_, _, len)| len)
                .sum();
            assert!(shared > 49_800, "shared {shared}");
            let old = pinned.matched_children.get(&bucket).unwrap();
            let new = frame.matched_children.get(&bucket).unwrap();
            assert!(
                old.shared_spans(new)
                    .iter()
                    .map(|(_, _, len)| len)
                    .sum::<usize>()
                    > 49_800
            );
        }
        assert_eq!(
            pinned.source.node(head).unwrap().data.label.as_ref(),
            "noise"
        );
    }
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: bucket.into(),
                patch: NodePatch {
                    label: Some("zzzz".into()),
                    score: Some(-1.0),
                    ..NodePatch::default()
                },
            },
            Operation::Update {
                node: head.into(),
                patch: NodePatch {
                    label: Some("aaaa".into()),
                    score: Some(1.0),
                    ..NodePatch::default()
                },
            },
        ],
    );
    for (state, pinned) in sorted_states {
        let frame = project(&mut engine, state);
        assert_projection(&engine, state);
        assert!(
            frame.visited_nodes < 20,
            "sorted List visited {}",
            frame.visited_nodes
        );
        assert_eq!(frame.position(bucket), Some(50_000));
        assert_eq!(
            frame
                .row(frame.position(head).unwrap())
                .unwrap()
                .source_ancestor,
            Some(bucket)
        );
        assert!(
            pinned
                .rows
                .shared_spans(&frame.rows)
                .iter()
                .map(|(_, _, len)| len)
                .sum::<usize>()
                > 49_800
        );
    }
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: bucket.into(),
                patch: NodePatch {
                    label: Some("renamed".into()),
                    ..NodePatch::default()
                },
            },
            Operation::Insert {
                key: "extra".into(),
                parent: Some(bucket.into()),
                position: Position::Last,
                data: NodeData::leaf("extra"),
                completeness: Completeness::Complete,
            },
        ],
    );
    let frame = project(&mut engine, selected_tree);
    assert_projection(&engine, selected_tree);
    assert!(
        frame.visited_nodes < 20,
        "metadata enlarged another local change: {}",
        frame.visited_nodes
    );
}

#[test]
fn t_equal_text_releases_superseded_label_storage_without_a_body_write() {
    let (mut engine, state, _) = fixture(1);
    let id = engine.source.id("n0").unwrap();
    let before = project(&mut engine, state);
    let old_label = Arc::downgrade(&before.source.node(id).unwrap().data.label);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: id.into(),
            patch: NodePatch {
                label: Some(Arc::from("node-00000")),
                ..NodePatch::default()
            },
        }],
    );
    let after = project(&mut engine, state);
    assert_projection(&engine, state);
    assert_eq!(after.layout_revision, before.layout_revision);
    let plan = RenderPlan::new(
        Some(before.clone()),
        after.clone(),
        Some(&RenderContext::default()),
        RenderContext::default(),
        false,
    )
    .unwrap();
    assert!(plan.splices.is_empty());
    drop(plan);
    drop(before);
    assert!(
        old_label.upgrade().is_none(),
        "an equal-text row retained superseded uncharged storage"
    );
    assert_eq!(lines(after), vec!["      node-00000"]);
}

#[test]
fn t_connector_only_change_preserves_the_layout_revision() {
    let (mut engine, _, root) = fixture(1);
    let state = engine
        .create_state(
            Root::ChildrenOf(root),
            DisplayOptions {
                selected_only: true,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    let selected = engine.source.id("n0").unwrap();
    engine
        .dispatch(
            state,
            Command::Select {
                targets: Targets::Nodes(vec![selected].into()),
                action: SelectAction::Select,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        )
        .unwrap();
    let before = project(&mut engine, state);
    assert!(before.row(0).unwrap().connector_last);
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "unselected".into(),
            parent: Some(root.into()),
            position: Position::Last,
            data: NodeData::leaf("unselected"),
            completeness: Completeness::Complete,
        }],
    );
    let after = project(&mut engine, state);
    assert_projection(&engine, state);
    assert_eq!(after.layout_revision, before.layout_revision);
    assert!(!after.row(0).unwrap().connector_last);
    assert!(before.row(0).unwrap().connector_last);
    let plan = RenderPlan::new(
        Some(before),
        after,
        Some(&RenderContext::default()),
        RenderContext::default(),
        false,
    )
    .unwrap();
    assert!(plan.splices.is_empty());
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
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                mode: Mode::List,
                pattern: "needle".into(),
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
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
fn t_explicit_roots_follow_inherited_changes_outside_their_display_range() {
    for selected_only in [false, true] {
        let (mut engine, _, root) = fixture(0);
        apply(
            &mut engine,
            vec![
                Operation::Insert {
                    key: "a".into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                    data: NodeData::branch("a"),
                    completeness: Completeness::Complete,
                },
                Operation::Insert {
                    key: "b".into(),
                    parent: Some("a".into()),
                    position: Position::Last,
                    data: NodeData::branch("b"),
                    completeness: Completeness::Complete,
                },
                Operation::Insert {
                    key: "c".into(),
                    parent: Some("b".into()),
                    position: Position::Last,
                    data: NodeData::leaf("c"),
                    completeness: Completeness::Complete,
                },
            ],
        );
        let a = engine.source.id("a").unwrap();
        let b = engine.source.id("b").unwrap();
        let state = engine
            .create_state(
                Root::Forest(vec![b].into()),
                DisplayOptions {
                    selected_only,
                    ..DisplayOptions::default()
                },
            )
            .unwrap();
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![a].into()),
                    value: true,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        engine
            .dispatch(
                state,
                Command::Select {
                    targets: Targets::Nodes(vec![a].into()),
                    action: SelectAction::Select,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        assert_eq!(project(&mut engine, state).len(), 2);
        assert_projection(&engine, state);
        apply(&mut engine, vec![Operation::Remove { node: "a".into() }]);
        assert!(project(&mut engine, state).is_empty());
    }
}

#[test]
fn t_reparenting_an_outer_ancestor_reconciles_covered_display_roots() {
    for mode in [Mode::Tree, Mode::List] {
        let (mut engine, state, root) = fixture(0);
        apply(
            &mut engine,
            vec![
                Operation::Insert {
                    key: "x".into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                    data: NodeData::branch("x"),
                    completeness: Completeness::Complete,
                },
                Operation::Insert {
                    key: "a".into(),
                    parent: Some("x".into()),
                    position: Position::Last,
                    data: NodeData::leaf("a"),
                    completeness: Completeness::Complete,
                },
                Operation::Insert {
                    key: "b".into(),
                    parent: Some(root.into()),
                    position: Position::Last,
                    data: NodeData::branch("b"),
                    completeness: Completeness::Complete,
                },
            ],
        );
        let ids = ["x", "a", "b"].map(|key| engine.source.id(key).unwrap());
        let before = project(&mut engine, state);
        engine
            .dispatch(
                state,
                Command::SetRoot(Root::Forest(vec![ids[1], ids[2]].into())),
                Context {
                    expected_state: Some(before.state_revision()),
                    ..Context::default()
                },
            )
            .unwrap();
        let before = project(&mut engine, state);
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    mode,
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(before.state_revision()),
                    ..Context::default()
                },
            )
            .unwrap();
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![ids[0], ids[2]].into()),
                    value: true,
                    scope: Scope::SelfOnly,
                },
                Context::default(),
            )
            .unwrap();
        project(&mut engine, state);
        apply(
            &mut engine,
            vec![Operation::Reparent {
                node: ids[0].into(),
                parent: Some(ids[2].into()),
                position: Position::Last,
            }],
        );
        assert_eq!(project(&mut engine, state).len(), 3);
        assert_projection(&engine, state);
    }
}

#[test]
fn t_list_subtree_moves_keep_descendants_contiguous_without_expansion() {
    let (mut engine, state, root) = fixture(100);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: "n0".into(),
            patch: NodePatch {
                can_expand: Some(true),
                ..NodePatch::default()
            },
        }],
    );
    let before = project(&mut engine, state);
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(before.state_revision()),
                ..Context::default()
            },
        )
        .unwrap();
    project(&mut engine, state);
    for i in 1..10 {
        apply(
            &mut engine,
            vec![Operation::Reparent {
                node: format!("n{i}").as_str().into(),
                parent: Some("n0".into()),
                position: Position::Last,
            }],
        );
        project(&mut engine, state);
        assert_projection(&engine, state);
    }
    apply(
        &mut engine,
        vec![Operation::Reparent {
            node: "n0".into(),
            parent: Some(root.into()),
            position: Position::Last,
        }],
    );
    project(&mut engine, state);
    assert_projection(&engine, state);
    apply(&mut engine, vec![Operation::Remove { node: "n0".into() }]);
    project(&mut engine, state);
    assert_projection(&engine, state);
}

#[test]
fn t_tree_list_format_change_rewrites_shared_single_row() {
    let (mut engine, state, _) = fixture(1);
    let tree = project(&mut engine, state);
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(tree.state_revision()),
                ..Context::default()
            },
        )
        .unwrap();
    let list = project(&mut engine, state);
    let plan = RenderPlan::new(
        Some(tree),
        list,
        Some(&RenderContext::default()),
        RenderContext::default(),
        false,
    )
    .unwrap();
    assert_eq!(plan.mode, PlanMode::Reset);
    assert_eq!(plan.lines(0, 1, 1024).unwrap().0, ["    node-00000"]);
}

#[test]
fn t_query_result_origin_outlives_session_and_replaces_by_scope() {
    let (mut engine, state, root) = fixture(0);
    let scope = DataScope::Children(root);
    let provider = engine.create_provider(scope).unwrap();
    let mut previous = None;
    for pattern in ["first", "second"] {
        let session = engine.create_query(provider).unwrap();
        let reply = engine
            .accept_query(
                session,
                QueryInput {
                    pattern: pattern.into(),
                    ..QueryInput::default()
                },
            )
            .unwrap();
        let Reply::Applied { effects, .. } = reply else {
            panic!()
        };
        let token = effects
            .iter()
            .find_map(|effect| match effect {
                Effect::Query { token, .. } => Some(*token),
                _ => None,
            })
            .unwrap();
        engine
            .query_page(
                token,
                1,
                vec![Record::new("result", NodeData::leaf(pattern))],
                true,
            )
            .unwrap();
        engine.release_query(session).unwrap();
        let frame = project(&mut engine, state);
        assert!(frame.queries.is_empty());
        let results = frame.source().query_results().collect::<Vec<_>>();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0, scope);
        assert_eq!(results[0].1.session, session);
        assert_eq!(results[0].1.input.pattern.as_ref(), pattern);
        if let Some(previous) = previous.as_ref() {
            let previous: &Arc<Snapshot> = previous;
            assert_eq!(
                previous
                    .source()
                    .query_results()
                    .next()
                    .unwrap()
                    .1
                    .input
                    .pattern
                    .as_ref(),
                "first"
            );
        }
        previous = Some(frame);
    }
    apply(&mut engine, vec![Operation::Remove { node: root.into() }]);
    assert_eq!(engine.source().query_results().count(), 0);
}

#[test]
fn t_expansion_toggle_checks_its_displayed_value_not_unrelated_metadata() {
    let (mut engine, state, root) = fixture(0);
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "branch".into(),
            parent: Some(root.into()),
            position: Position::Last,
            data: NodeData::branch("branch"),
            completeness: Completeness::Complete,
        }],
    );
    let frame = project(&mut engine, state);
    let node = engine.source().id("branch").unwrap();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: node.into(),
            patch: NodePatch {
                label: Some("renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    let command = Command::ToggleExpanded {
        node,
        scope: Scope::SelfOnly,
    };
    let context = Context {
        frame: Some(frame),
        ..Context::default()
    };
    engine
        .dispatch(state, command.clone(), context.clone())
        .unwrap();
    let revision = engine.states[&state].state.revision;
    assert_eq!(
        engine.dispatch(state, command, context).unwrap_err().code,
        ErrorCode::Stale
    );
    assert_eq!(engine.states[&state].state.revision, revision);
}

#[test]
fn t_recursive_expansion_of_hidden_anchor_updates_descendant_layout() {
    let (mut engine, state, root) = fixture(0);
    apply(
        &mut engine,
        vec![
            Operation::Insert {
                key: "branch".into(),
                parent: Some(root.into()),
                position: Position::Last,
                data: NodeData::branch("branch"),
                completeness: Completeness::Complete,
            },
            Operation::Insert {
                key: "leaf".into(),
                parent: Some("branch".into()),
                position: Position::Last,
                data: NodeData::leaf("leaf"),
                completeness: Completeness::Complete,
            },
        ],
    );
    assert_eq!(project(&mut engine, state).len(), 1);
    for (value, count) in [(true, 2), (false, 1)] {
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![root].into()),
                    value,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        assert_eq!(project(&mut engine, state).len(), count);
        assert_projection(&engine, state);
    }
}

#[test]
fn t_viewport_reads_bound_bytes_and_match_expansion() {
    let (mut engine, state, _) = fixture(2);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: "n0".into(),
            patch: NodePatch {
                right_text: Some(Some("x".repeat(1024 * 1024).into())),
                ..NodePatch::default()
            },
        }],
    );
    let frame = project(&mut engine, state);
    assert_eq!(frame.rows(0, 1).unwrap_err().code, ErrorCode::ResourceLimit);
    assert_eq!(frame.rows(1, 2).unwrap().len(), 1);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: "n0".into(),
            patch: NodePatch {
                label: Some("a".repeat(8193).into()),
                right_text: Some(None),
                ..NodePatch::default()
            },
        }],
    );
    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                pattern: "a".into(),
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap();
    let frame = project(&mut engine, state);
    assert_eq!(frame.len(), 1);
    assert_eq!(frame.rows(0, 1).unwrap_err().code, ErrorCode::ResourceLimit);
}

#[test]
fn t_staged_plan_retargets_metadata_but_rejects_changed_text_or_layout() {
    let (mut engine, state, _) = fixture(2);
    let original = project(&mut engine, state);
    let plan = RenderPlan::new(
        None,
        original.clone(),
        None,
        RenderContext::default(),
        false,
    )
    .unwrap();
    let node = engine.source.id("n1").unwrap();
    engine
        .dispatch(state, Command::SetCursor(Some(node)), Context::default())
        .unwrap();
    let current = project(&mut engine, state);
    let updated = plan.retarget(current.clone()).unwrap();
    assert!(Arc::ptr_eq(&updated.target, &current));
    assert!(Arc::ptr_eq(&updated.splices, &plan.splices));
    assert_eq!(
        updated.lines(0, 2, 1024).unwrap(),
        plan.lines(0, 2, 1024).unwrap()
    );

    apply(
        &mut engine,
        vec![Operation::Update {
            node: node.into(),
            patch: NodePatch {
                label: Some("renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    let renamed = project(&mut engine, state);
    assert_eq!(renamed.layout_revision, current.layout_revision);
    assert!(plan.retarget(renamed).is_none());

    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(vec![node].into())),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap();
    assert!(plan.retarget(project(&mut engine, state)).is_none());
    assert_eq!(plan.lines(0, 2, 1024).unwrap().0, lines(original));
}

#[test]
fn t_same_expansion_intent_and_matching_label_reuse_the_layout() {
    let (mut engine, state, root) = fixture(1000);
    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(vec![root].into())),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap();
    let command = Command::SetExpanded {
        targets: Targets::Nodes(vec![root].into()),
        value: true,
        scope: Scope::Subtree,
    };
    engine
        .dispatch(state, command.clone(), Context::default())
        .unwrap();
    let before = project(&mut engine, state);
    engine.dispatch(state, command, Context::default()).unwrap();
    let after = project(&mut engine, state);
    assert_eq!(after.visited_nodes, 0);
    assert_eq!(before.layout_revision, after.layout_revision);
    assert!(after.state_revision() > before.state_revision());
    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                pattern: "node-".into(),
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap();
    let before = project(&mut engine, state);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: "n20".into(),
            patch: NodePatch {
                label: Some("node-renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    let after = project(&mut engine, state);
    assert_eq!(after.visited_nodes, 0);
    assert_eq!(before.layout_revision, after.layout_revision);
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
    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                compress: true,
                ..DisplayOptions::default()
            }),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap();
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![a].into()),
                value: true,
                scope: Scope::Subtree,
            },
            Context::default(),
        )
        .unwrap();
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
fn t_removed_query_anchor_retires_only_its_late_work() {
    let (mut engine, _, root) = fixture(0);
    let provider = engine.create_provider(DataScope::Children(root)).unwrap();
    let session = engine.create_query(provider).unwrap();
    let Reply::Applied { effects, .. } =
        engine.accept_query(session, QueryInput::default()).unwrap()
    else {
        panic!("query");
    };
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::Query { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    apply(&mut engine, vec![Operation::Remove { node: root.into() }]);
    assert!(engine.query_page(token, 1, Vec::new(), true).is_err());
    assert!(engine.query_work.is_empty());
    engine.schedule_queries().unwrap();
    assert_eq!(
        engine.query_info(session).unwrap().load_state,
        LoadState::Error
    );
}

#[test]
fn t_cancel_query_ends_its_slot_and_old_ack_preserves_the_replacement() {
    let (mut engine, _, root) = fixture(0);
    let provider = engine.create_provider(DataScope::Children(root)).unwrap();
    let session = engine.create_query(provider).unwrap();
    let request = |engine: &mut Engine| {
        let Reply::Applied { effects, .. } =
            engine.accept_query(session, QueryInput::default()).unwrap()
        else {
            panic!("query");
        };
        effects
            .iter()
            .find_map(|effect| match effect {
                Effect::Query { token, .. } => Some(*token),
                _ => None,
            })
            .unwrap()
    };
    let old = request(&mut engine);
    engine
        .query_page(
            old,
            1,
            vec![Record::new("one", NodeData::leaf("one"))],
            false,
        )
        .unwrap();
    engine.cancel_query(session).unwrap();
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Idle
    );
    assert_eq!(
        engine.source.node(root).unwrap().completeness,
        Completeness::Partial
    );
    let new = request(&mut engine);
    engine.query_page(new, 1, Vec::new(), false).unwrap();
    engine.query_cancelled(old).unwrap();
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Loading
    );
    engine.query_page(new, 2, Vec::new(), true).unwrap();
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
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![branch].into()),
                value: true,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        )
        .unwrap();
    project(&mut engine, state);
    let effects = engine.schedule_reads().unwrap();
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::NeedChildren { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![branch].into()),
                value: false,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        )
        .unwrap();
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
fn t_retained_frames_consume_memory_and_releasing_them_restores_capacity() {
    let mut engine = Engine::new(Limits {
        memory_bytes: 3 * 1024 * 1024,
        ..Limits::default()
    })
    .unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: vec![Record::new("one", NodeData::leaf("initial"))],
        })
        .unwrap();
    let id = engine.source.id("one").unwrap();
    let state = engine
        .create_state(Root::Forest(vec![id].into()), DisplayOptions::default())
        .unwrap();
    let mut retained = Vec::new();
    let mut failed = false;
    for index in 0..12 {
        retained.push(engine.snapshot(state).unwrap());
        let source = engine.source.clone();
        let result = engine.apply_batch(Batch {
            base_revision: source.revision(),
            operations: vec![Operation::Update {
                node: id.into(),
                patch: NodePatch {
                    label: Some(format!("{index}{}", "x".repeat(512 * 1024)).into()),
                    ..NodePatch::default()
                },
            }],
        });
        if let Err(error) = result {
            assert_eq!(error.code, ErrorCode::ResourceLimit);
            assert!(Arc::ptr_eq(&source, &engine.source));
            failed = true;
            break;
        }
        project(&mut engine, state);
    }
    assert!(failed);
    let before = engine.memory.used();
    retained.clear();
    assert!(engine.memory.used() < before);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: id.into(),
            patch: NodePatch {
                label: Some("recovered".into()),
                ..NodePatch::default()
            },
        }],
    );
    project(&mut engine, state);
}

#[test]
#[ignore = "explicit release-mode performance sampling"]
fn t_release_performance_sample() {
    let (mut engine, state, _) = fixture(50_000);
    let _memory = engine.memory.enter();
    apply(
        &mut engine,
        (0..50_000)
            .map(|index| Operation::Update {
                node: format!("n{index}").as_str().into(),
                patch: NodePatch {
                    label: Some(format!("node-{index:05}{}", "x".repeat(86)).into()),
                    ..NodePatch::default()
                },
            })
            .collect(),
    );
    project(&mut engine, state);
    let id = engine.source.id("n25000").unwrap();
    let mut layout = Vec::new();
    let mut metadata = Vec::new();
    let mut filtering = Vec::new();
    for index in 0..100 {
        let mut state_input = engine.states[&state].state.clone();
        let started = Instant::now();
        let full = Snapshot::build(
            engine.source.clone(),
            &mut state_input,
            None,
            false,
            Arc::new([]),
            engine.commit,
        )
        .unwrap();
        drop(full);
        layout.push(started.elapsed().as_secs_f64() * 1000.0);
        let previous = engine.snapshot(state).unwrap();
        let started = Instant::now();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: id.into(),
                patch: NodePatch {
                    label: Some(format!("changed-{index}").into()),
                    ..NodePatch::default()
                },
            }],
        );
        let next = project(&mut engine, state);
        let plan = RenderPlan::new(
            Some(previous),
            next,
            Some(&RenderContext::default()),
            RenderContext::default(),
            false,
        )
        .unwrap();
        drop(plan);
        metadata.push(started.elapsed().as_secs_f64() * 1000.0);
        let started = Instant::now();
        let expected = engine.states[&state].state.revision;
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    pattern: if index % 2 == 0 {
                        "node-0".into()
                    } else {
                        "node-".into()
                    },
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(expected),
                    ..Context::default()
                },
            )
            .unwrap();
        project(&mut engine, state);
        filtering.push(started.elapsed().as_secs_f64() * 1000.0);
        let expected = engine.states[&state].state.revision;
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions::default()),
                Context {
                    expected_state: Some(expected),
                    ..Context::default()
                },
            )
            .unwrap();
        project(&mut engine, state);
    }
    for (name, mut samples) in [
        ("full_layout_and_release_ms", layout),
        ("local_edit_projection_plan_ms", metadata),
        ("filter_projection_ms", filtering),
    ] {
        samples.sort_by(f64::total_cmp);
        println!(
            "{name}: n={}, p50={:.3}, p95={:.3}, max={:.3}",
            samples.len(),
            samples[49],
            samples[94],
            samples[99]
        );
    }
}
