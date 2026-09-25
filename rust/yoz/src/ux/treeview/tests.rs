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

fn ancestry_fixture() -> (Engine, u64, u64) {
    let mut engine = Engine::new(Limits::default()).unwrap();
    let records = [
        ("root", None, "root", true),
        ("src", Some("root"), "src", true),
        ("lib", Some("src"), "lib", true),
        ("a", Some("lib"), "文.lua", false),
        ("readme", Some("root"), "README", false),
    ]
    .into_iter()
    .map(|(key, parent, label, branch)| Record {
        key: key.into(),
        parent: parent.map(Into::into),
        data: if branch {
            NodeData::branch(label)
        } else {
            NodeData::leaf(label)
        },
        completeness: None,
    })
    .collect();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let options = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        ..DisplayOptions::default()
    };
    let outer = engine
        .create_state(
            Root::ChildrenOf(engine.source.id("root").unwrap()),
            options.clone(),
        )
        .unwrap();
    let inner = engine
        .create_state(Root::ChildrenOf(engine.source.id("src").unwrap()), options)
        .unwrap();
    (engine, outer, inner)
}

fn prepare_subtree(engine: &mut Engine, state: u64, node: NodeId) -> (LockToken, CleanupToken) {
    engine
        .dispatch(
            state,
            Command::Select {
                targets: Targets::Nodes(vec![node].into()),
                action: SelectAction::Select,
                scope: Scope::Subtree,
            },
            Context::default(),
        )
        .unwrap();
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
    engine
        .dispatch(
            state,
            Command::Select {
                targets: Targets::Nodes(vec![src].into()),
                action: SelectAction::Select,
                scope: Scope::Subtree,
            },
            Context::default(),
        )
        .unwrap();
    let Reply::Locked { token, .. } = engine
        .lock_selection(state, engine.states[&state].state.selection_revision, None)
        .unwrap()
    else {
        panic!("lock")
    };
    let _guard = engine.memory.enter();
    let held = super::memory::Charge::new(engine.limits.memory_bytes - engine.memory.used() - 32);
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
fn t_ancestry_text_is_frame_owned_and_relative_to_each_state_root() {
    let (mut engine, outer, inner) = ancestry_fixture();
    let old = engine.snapshot(outer).unwrap();
    let inner_old = engine.snapshot(inner).unwrap();
    assert_eq!(
        lines(old.clone()),
        ["  src", "  src/lib", "  src/lib/文.lua", "  README"]
    );
    assert_eq!(lines(inner_old.clone()), ["  lib", "  lib/文.lua"]);
    let src = engine.source.id("src").unwrap();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: src.into(),
            patch: NodePatch {
                label: Some("renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    let current = project(&mut engine, outer);
    let inner_current = engine.snapshot(inner).unwrap();
    let context = RenderContext::default();
    let plan = RenderPlan::new(
        Some(old.clone()),
        current.clone(),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(
        apply_plan(lines(old.clone()), &plan),
        lines(current.clone())
    );
    assert_eq!(plan.work.written_rows, 3);
    assert_eq!(current.layout_revision, old.layout_revision);
    let inner_plan = RenderPlan::new(
        Some(inner_old.clone()),
        inner_current.clone(),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(inner_plan.mode, PlanMode::Swap);
    assert_eq!(inner_old.text_revision, inner_current.text_revision);
    assert_eq!(
        lines(old),
        ["  src", "  src/lib", "  src/lib/文.lua", "  README"]
    );
    assert_eq!(
        engine
            .source
            .node(engine.source.id("a").unwrap())
            .unwrap()
            .data
            .label
            .as_ref(),
        "文.lua"
    );
}

#[test]
fn t_ancestry_text_updates_from_nonadjacent_frames_and_checks_utf8_spans() {
    let (mut engine, outer, _) = ancestry_fixture();
    let old = engine.snapshot(outer).unwrap();
    let lib = engine.source.id("lib").unwrap();
    let leaf = engine.source.id("a").unwrap();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: lib.into(),
            patch: NodePatch {
                label: Some("core".into()),
                ..NodePatch::default()
            },
        }],
    );
    project(&mut engine, outer);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: leaf.into(),
            patch: NodePatch {
                icon: Some(Some("x".into())),
                ..NodePatch::default()
            },
        }],
    );
    let current = project(&mut engine, outer);
    let context = RenderContext::default();
    let plan = RenderPlan::new(
        Some(old.clone()),
        current.clone(),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(apply_plan(lines(old), &plan), lines(current));
    let filtered = engine
        .create_state(
            Root::ChildrenOf(engine.source.id("root").unwrap()),
            DisplayOptions {
                mode: Mode::List,
                list_text: ListText::Ancestry,
                pattern: "文".into(),
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    let frame = engine.snapshot(filtered).unwrap();
    let rows = frame.rows(0, frame.len()).unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0].label, "src/core/文.lua");
    assert_eq!(rows[0].matches, [(9, 12)]);
    let plan = RenderPlan::new(None, frame, None, RenderContext::default(), false).unwrap();
    assert_eq!(plan.work.text_bytes, "  src/core/文.lua\n".len());
    assert_eq!(
        plan.lines(0, 1, 5).unwrap_err().code,
        ErrorCode::ResourceLimit
    );
}

#[test]
fn t_ancestry_text_uses_derived_forest_roots_and_tracks_reparent() {
    let (mut engine, outer, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    let forest = engine
        .create_state(
            Root::Forest(vec![root, src].into()),
            DisplayOptions {
                mode: Mode::List,
                list_text: ListText::Ancestry,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    assert_eq!(
        lines(engine.snapshot(forest).unwrap()),
        [
            "  root",
            "  root/src",
            "  root/src/lib",
            "  root/src/lib/文.lua",
            "  root/README",
        ]
    );
    let old = engine.snapshot(outer).unwrap();
    apply(
        &mut engine,
        vec![Operation::Reparent {
            node: lib.into(),
            parent: Some(root.into()),
            position: Position::Last,
        }],
    );
    let frame = project(&mut engine, outer);
    assert_eq!(
        lines(frame.clone()),
        ["  src", "  README", "  lib", "  lib/文.lua"]
    );
    let context = RenderContext::default();
    let plan = RenderPlan::new(
        Some(old.clone()),
        frame.clone(),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(apply_plan(lines(old), &plan), lines(frame));
}

#[test]
fn t_ancestry_rename_refreshes_descendants_of_reinitialized_rows() {
    for (import, pattern) in [false, true]
        .into_iter()
        .flat_map(|import| ["", "文"].map(|pattern| (import, pattern)))
    {
        let (mut engine, outer, inner) = ancestry_fixture();
        engine
            .dispatch(
                outer,
                Command::SetDisplay(DisplayOptions {
                    mode: Mode::List,
                    list_text: ListText::Ancestry,
                    show_hidden: false,
                    pattern: pattern.into(),
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(engine.states[&outer].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
        let old = project(&mut engine, outer);
        if import {
            let records = engine
                .source
                .nodes
                .iter()
                .map(|(_, node)| {
                    let mut data = (*node.data).clone();
                    match node.key.as_ref() {
                        "src" => data.label = "after".into(),
                        "lib" => data.label = "core".into(),
                        _ => {}
                    }
                    Record {
                        key: node.key.clone(),
                        parent: node.parent.map(Into::into),
                        data,
                        completeness: Some(node.completeness),
                    }
                })
                .collect();
            engine
                .import(Import {
                    base_revision: engine.source.revision(),
                    scope: DataScope::Forest,
                    records,
                })
                .unwrap();
        } else {
            apply(
                &mut engine,
                ["src", "lib"]
                    .into_iter()
                    .zip(["after", "core"])
                    .map(|(key, label)| Operation::Update {
                        node: key.into(),
                        patch: NodePatch {
                            label: Some(label.into()),
                            hidden: Some(false),
                            ..NodePatch::default()
                        },
                    })
                    .collect(),
            );
        }
        let current = project(&mut engine, outer);
        assert_eq!(
            lines(current.clone()),
            if pattern.is_empty() {
                vec!["  after", "  after/core", "  after/core/文.lua", "  README"]
            } else {
                vec!["  after/core/文.lua"]
            }
        );
        assert_eq!(
            lines(engine.snapshot(inner).unwrap()),
            ["  core", "  core/文.lua"]
        );
        let context = RenderContext::default();
        let plan = RenderPlan::new(
            Some(old.clone()),
            current.clone(),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        assert_eq!(apply_plan(lines(old.clone()), &plan), lines(current));
        assert_eq!(
            lines(old),
            if pattern.is_empty() {
                vec!["  src", "  src/lib", "  src/lib/文.lua", "  README"]
            } else {
                vec!["  src/lib/文.lua"]
            }
        );
    }
}

#[test]
fn t_ancestry_text_scope_excludes_outside_updates_but_keeps_filtered_ancestors() {
    let (mut engine, _, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    apply(
        &mut engine,
        vec![
            Operation::Insert {
                key: "outside".into(),
                parent: Some(root.into()),
                position: Position::Last,
                data: NodeData::branch("outside"),
                completeness: Completeness::Complete,
            },
            Operation::Insert {
                key: "other".into(),
                parent: Some("outside".into()),
                position: Position::Last,
                data: NodeData::leaf("文-other"),
                completeness: Completeness::Complete,
            },
        ],
    );
    let display = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        pattern: "文".into(),
        ..DisplayOptions::default()
    };
    let children = engine
        .create_state(Root::ChildrenOf(src), display.clone())
        .unwrap();
    let forest = engine
        .create_state(Root::Forest(vec![src, lib].into()), display)
        .unwrap();
    let old = [
        engine.snapshot(children).unwrap(),
        engine.snapshot(forest).unwrap(),
    ];
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: root.into(),
                patch: NodePatch {
                    label: Some("filesystem".into()),
                    ..NodePatch::default()
                },
            },
            Operation::Update {
                node: "outside".into(),
                patch: NodePatch {
                    label: Some("changed-outside".into()),
                    ..NodePatch::default()
                },
            },
        ],
    );
    project(&mut engine, children);
    for (id, old) in [children, forest].into_iter().zip(&old) {
        let current = engine.snapshot(id).unwrap();
        assert!(old.rows.same_version(&current.rows));
        assert_eq!(old.text_revision, current.text_revision);
    }
    apply(
        &mut engine,
        vec![Operation::Update {
            node: src.into(),
            patch: NodePatch {
                label: Some("renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    assert_eq!(lines(project(&mut engine, children)), ["  lib/文.lua"]);
    assert_eq!(
        lines(engine.snapshot(forest).unwrap()),
        ["  renamed/lib/文.lua"]
    );
    apply(
        &mut engine,
        vec![Operation::Update {
            node: lib.into(),
            patch: NodePatch {
                label: Some("core".into()),
                ..NodePatch::default()
            },
        }],
    );
    assert_eq!(lines(project(&mut engine, children)), ["  core/文.lua"]);
    assert_eq!(
        lines(engine.snapshot(forest).unwrap()),
        ["  renamed/core/文.lua"]
    );
    apply(
        &mut engine,
        vec![Operation::Reparent {
            node: lib.into(),
            parent: Some("outside".into()),
            position: Position::Last,
        }],
    );
    assert!(project(&mut engine, children).is_empty());
    assert_eq!(lines(engine.snapshot(forest).unwrap()), ["  core/文.lua"]);
    assert_eq!(lines(old[0].clone()), ["  lib/文.lua"]);
    assert_eq!(lines(old[1].clone()), ["  src/lib/文.lua"]);
}

#[test]
#[ignore = "explicit release-mode unrelated-subtree scaling measurement"]
fn t_ancestry_unrelated_subtree_performance() {
    let (mut engine, initial, root) = fixture(50_000);
    engine.release_state(initial);
    let mut scopes = Vec::new();
    for i in 0..6 {
        let key = format!("scope{i}");
        apply(
            &mut engine,
            vec![
                Operation::Insert {
                    key: key.clone().into(),
                    parent: None,
                    position: Position::Last,
                    data: NodeData::branch(key.as_str()),
                    completeness: Completeness::Complete,
                },
                Operation::Insert {
                    key: format!("file{i}").into(),
                    parent: Some(key.as_str().into()),
                    position: Position::Last,
                    data: NodeData::leaf("file"),
                    completeness: Completeness::Complete,
                },
            ],
        );
        let id = engine.source.id(&key).unwrap();
        scopes.push(
            engine
                .create_state(
                    if i % 2 == 0 {
                        Root::ChildrenOf(id)
                    } else {
                        Root::Forest(vec![id].into())
                    },
                    DisplayOptions {
                        mode: Mode::List,
                        pattern: "file".into(),
                        ..DisplayOptions::default()
                    },
                )
                .unwrap(),
        );
    }
    for style in [ListText::Label, ListText::Ancestry] {
        for &state in &scopes {
            engine
                .dispatch(
                    state,
                    Command::SetDisplay(DisplayOptions {
                        mode: Mode::List,
                        pattern: "file".into(),
                        list_text: style,
                        ..DisplayOptions::default()
                    }),
                    Context {
                        expected_state: Some(engine.states[&state].state.revision),
                        ..Context::default()
                    },
                )
                .unwrap();
        }
        project(&mut engine, scopes[0]);
        let mut samples = Vec::new();
        for i in 0..102 {
            let old: Vec<_> = scopes
                .iter()
                .map(|id| engine.snapshot(*id).unwrap())
                .collect();
            let start = Instant::now();
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: root.into(),
                    patch: NodePatch {
                        label: Some(format!("outside-{i}").into()),
                        ..NodePatch::default()
                    },
                }],
            );
            project(&mut engine, scopes[0]);
            for (id, old) in scopes.iter().zip(old) {
                let current = engine.snapshot(*id).unwrap();
                assert_eq!(current.len(), 1);
                assert!(old.rows.same_version(&current.rows));
                assert_eq!(old.text_revision, current.text_revision);
            }
            if i >= 2 {
                samples.push(start.elapsed().as_secs_f64() * 1000.0);
            }
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "unrelated_subtree: style={style:?}, outside=50001, states=6, n=100, p50_ms={:.3}, p95_ms={:.3}",
            samples[49], samples[94]
        );
    }
}

#[test]
fn t_ancestry_forest_boundaries_follow_topology_and_root_changes() {
    let (mut engine, _, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let display = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        show_hidden: false,
        ..DisplayOptions::default()
    };
    let state = engine
        .create_state(Root::Forest(vec![src, lib].into()), display.clone())
        .unwrap();
    let old = engine.snapshot(state).unwrap();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: leaf.into(),
            patch: NodePatch {
                label: Some("changed".into()),
                hidden: Some(false),
                ..NodePatch::default()
            },
        }],
    );
    let renamed = project(&mut engine, state);
    assert!(old.text_roots.same_version(&renamed.text_roots));
    assert_eq!(
        lines(renamed.clone()),
        ["  src", "  src/lib", "  src/lib/changed"]
    );

    engine
        .dispatch(
            state,
            Command::SetDisplay(DisplayOptions {
                pattern: "changed".into(),
                ..display.clone()
            }),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    let filtered = project(&mut engine, state);
    assert!(renamed.text_roots.same_version(&filtered.text_roots));
    assert_eq!(lines(filtered), ["  src/lib/changed"]);
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
    project(&mut engine, state);

    apply(
        &mut engine,
        vec![Operation::Reparent {
            node: lib.into(),
            parent: Some(root.into()),
            position: Position::Last,
        }],
    );
    let moved = project(&mut engine, state);
    assert_eq!(lines(moved), ["  src", "  lib", "  lib/changed"]);
    assert_eq!(lines(renamed), ["  src", "  src/lib", "  src/lib/changed"]);
    assert_eq!(lines(old), ["  src", "  src/lib", "  src/lib/文.lua"]);

    for list_text in [ListText::Label, ListText::Ancestry] {
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    list_text,
                    ..display.clone()
                }),
                Context {
                    expected_state: Some(engine.states[&state].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
        project(&mut engine, state);
    }
    assert_eq!(
        lines(engine.snapshot(state).unwrap()),
        ["  src", "  lib", "  lib/changed"]
    );
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(vec![leaf].into())),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    assert_eq!(lines(project(&mut engine, state)), ["  changed"]);
    apply(&mut engine, vec![Operation::Remove { node: leaf.into() }]);
    assert!(project(&mut engine, state).is_empty());
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "a".into(),
            parent: Some(lib.into()),
            position: Position::Last,
            data: NodeData::leaf("replacement"),
            completeness: Completeness::Complete,
        }],
    );
    assert!(project(&mut engine, state).is_empty());
}

#[test]
#[ignore = "explicit release-mode Forest boundary scaling measurement"]
fn t_ancestry_forest_leaf_performance() {
    let mut engine = Engine::new(Limits::default()).unwrap();
    let (depth, width) = (1000, 2000);
    let mut records: Vec<_> = (0..depth)
        .map(|i| Record {
            key: format!("p{i}").into(),
            parent: (i > 0).then(|| format!("p{}", i - 1).as_str().into()),
            data: NodeData::branch("p"),
            completeness: None,
        })
        .collect();
    records.extend((0..width).map(|i| Record {
        key: format!("f{i}").into(),
        parent: Some(format!("p{}", depth - 1).as_str().into()),
        data: NodeData::leaf("file"),
        completeness: None,
    }));
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let roots: Arc<[_]> = (0..width)
        .map(|i| engine.source.id(&format!("f{i}")).unwrap())
        .collect();
    let leaf = roots[width / 2];
    let state = engine
        .create_state(
            Root::Forest(roots),
            DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    for list_text in [ListText::Label, ListText::Ancestry] {
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    mode: Mode::List,
                    list_text,
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(engine.states[&state].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
        project(&mut engine, state);
        let mut samples = Vec::new();
        for i in 0..102 {
            let old = engine.snapshot(state).unwrap();
            let start = Instant::now();
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: leaf.into(),
                    patch: NodePatch {
                        label: Some(format!("file-{i}").into()),
                        ..NodePatch::default()
                    },
                }],
            );
            let current = project(&mut engine, state);
            assert!(old.text_roots.same_version(&current.text_roots));
            let context = RenderContext::default();
            let plan = RenderPlan::new(Some(old), current, Some(&context), context.clone(), false)
                .unwrap();
            assert_eq!(plan.work.written_rows, 1);
            assert_eq!(plan.work.compared_rows, 1);
            drop(plan);
            if i >= 2 {
                samples.push(start.elapsed().as_secs_f64() * 1000.0);
            }
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "forest_leaf: style={list_text:?}, roots={width}, excluded_depth={depth}, n=100, p50_ms={:.3}, p95_ms={:.3}",
            samples[49], samples[94]
        );
    }
}

#[test]
fn t_ancestry_text_leaf_edit_keeps_wide_directory_shared() {
    let (mut engine, _, root) = fixture(50_000);
    let state = engine
        .create_state(
            Root::ChildrenOf(root),
            DisplayOptions {
                mode: Mode::List,
                list_text: ListText::Ancestry,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    let old = engine.snapshot(state).unwrap();
    let id = engine.source.id("n25000").unwrap();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: id.into(),
            patch: NodePatch {
                label: Some("changed".into()),
                ..NodePatch::default()
            },
        }],
    );
    let frame = project(&mut engine, state);
    let shared: usize = old
        .rows
        .shared_spans(&frame.rows)
        .iter()
        .map(|(_, _, len)| len)
        .sum();
    assert!(shared >= 49_800, "shared only {shared}");
    let context = RenderContext::default();
    let plan = RenderPlan::new(
        Some(old.clone()),
        frame.clone(),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(plan.work.compared_rows, 1);
    assert_eq!(plan.work.written_rows, 1);
    assert_eq!(frame.rows(25_000, 25_001).unwrap()[0].label, "changed");
    assert_eq!(old.rows(25_000, 25_001).unwrap()[0].label, "node-25000");
}

#[test]
fn t_ancestry_incremental_text_matches_rebuild_across_display_changes() {
    for sort in [Sort::Source, Sort::Name, Sort::Score] {
        for branches_first in [false, true] {
            for pattern in ["", "文", "lib"] {
                let (mut engine, state, _) = ancestry_fixture();
                let root = engine.source.id("root").unwrap();
                let src = engine.source.id("src").unwrap();
                let lib = engine.source.id("lib").unwrap();
                let leaf = engine.source.id("a").unwrap();
                let display = DisplayOptions {
                    mode: Mode::List,
                    list_text: ListText::Ancestry,
                    sort,
                    branches_first,
                    pattern: pattern.into(),
                    show_hidden: false,
                    ..DisplayOptions::default()
                };
                let mut retained = vec![engine.snapshot(state).unwrap()];
                for step in 0..13 {
                    let command = match step {
                        0 => Some(Command::SetDisplay(display.clone())),
                        1 | 2 | 3 | 4 => {
                            let (node, patch) = match step {
                                1 => (
                                    src,
                                    NodePatch {
                                        label: Some("renamed".into()),
                                        ..NodePatch::default()
                                    },
                                ),
                                2 => (
                                    src,
                                    NodePatch {
                                        hidden: Some(true),
                                        ..NodePatch::default()
                                    },
                                ),
                                3 => (
                                    src,
                                    NodePatch {
                                        hidden: Some(false),
                                        ..NodePatch::default()
                                    },
                                ),
                                _ => (
                                    leaf,
                                    NodePatch {
                                        label: Some("文-new".into()),
                                        ..NodePatch::default()
                                    },
                                ),
                            };
                            apply(
                                &mut engine,
                                vec![Operation::Update {
                                    node: node.into(),
                                    patch,
                                }],
                            );
                            None
                        }
                        5 => {
                            apply(
                                &mut engine,
                                vec![Operation::Reparent {
                                    node: lib.into(),
                                    parent: Some(root.into()),
                                    position: Position::First,
                                }],
                            );
                            None
                        }
                        6 => Some(Command::SetRoot(Root::Forest(vec![root, lib].into()))),
                        7 => Some(Command::SetDisplay(DisplayOptions {
                            list_text: ListText::Label,
                            ..display.clone()
                        })),
                        8 => Some(Command::SetDisplay(display.clone())),
                        9 => Some(Command::SetDisplay(DisplayOptions {
                            mode: Mode::Tree,
                            compress: true,
                            ..display.clone()
                        })),
                        10 => Some(Command::SetDisplay(display.clone())),
                        11 => Some(Command::SetRoot(Root::ChildrenOf(lib))),
                        _ => Some(Command::SetRoot(Root::ChildrenOf(root))),
                    };
                    if let Some(command) = command {
                        engine
                            .dispatch(
                                state,
                                command,
                                Context {
                                    expected_state: Some(engine.states[&state].state.revision),
                                    ..Context::default()
                                },
                            )
                            .unwrap();
                    }
                    let current = project(&mut engine, state);
                    let mut input = engine.states[&state].state.clone();
                    let full = Arc::new(
                        Snapshot::build(
                            engine.source.clone(),
                            &mut input,
                            None,
                            false,
                            Arc::new([]),
                            engine.commit,
                        )
                        .unwrap(),
                    );
                    assert_eq!(
                        lines(current.clone()),
                        lines(full),
                        "sort={sort:?}, branches={branches_first}, pattern={pattern}, step={step}"
                    );
                    for old in &retained {
                        let context = RenderContext::default();
                        let plan = RenderPlan::new(
                            Some(old.clone()),
                            current.clone(),
                            Some(&context),
                            context.clone(),
                            false,
                        )
                        .unwrap();
                        assert_eq!(
                            apply_plan(lines(old.clone()), &plan),
                            lines(current.clone()),
                            "render step={step}"
                        );
                    }
                    retained.push(current);
                }
            }
        }
    }
}

#[test]
#[ignore = "explicit release-mode ancestry scaling measurement"]
fn t_ancestry_deep_rename_performance() {
    for count in [1_000, 2_000, 4_000, 8_000] {
        let mut engine = Engine::new(Limits::default()).unwrap();
        engine
            .import(Import {
                base_revision: engine.source.revision(),
                scope: DataScope::Forest,
                records: (0..count)
                    .map(|i| Record {
                        key: format!("n{i}").into(),
                        parent: (i != 0).then(|| format!("n{}", i - 1).as_str().into()),
                        data: NodeData::branch("x"),
                        completeness: None,
                    })
                    .collect(),
            })
            .unwrap();
        let root = engine.source.id("n0").unwrap();
        let state = engine
            .create_state(
                Root::Forest(vec![root].into()),
                DisplayOptions {
                    mode: Mode::List,
                    list_text: ListText::Ancestry,
                    ..DisplayOptions::default()
                },
            )
            .unwrap();
        let mut samples = Vec::new();
        for i in 0..10 {
            let previous = engine.snapshot(state).unwrap();
            let start = Instant::now();
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: root.into(),
                    patch: NodePatch {
                        label: Some(format!("root-{i}").into()),
                        ..NodePatch::default()
                    },
                }],
            );
            let current = project(&mut engine, state);
            let context = RenderContext::default();
            let plan = RenderPlan::new(
                Some(previous),
                current,
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, count);
            drop(plan);
            samples.push(start.elapsed().as_secs_f64() * 1_000.0);
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "ancestry_deep_rename: nodes={count}, n=10, p50_ms={:.3}, p95_ms={:.3}, retained_bytes={}",
            samples[4],
            samples[9],
            engine.memory.used()
        );
        let leaf = engine.source.id(&format!("n{}", count - 1)).unwrap();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: leaf.into(),
                patch: NodePatch {
                    label: Some("target".into()),
                    ..NodePatch::default()
                },
            }],
        );
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    mode: Mode::List,
                    list_text: ListText::Ancestry,
                    pattern: "target".into(),
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(engine.states[&state].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
        project(&mut engine, state);
        let mut samples = Vec::new();
        for i in 0..10 {
            let label = if i % 2 == 0 { "y" } else { "x" };
            let operations = (0..count - 1)
                .map(|i| Operation::Update {
                    node: format!("n{i}").as_str().into(),
                    patch: NodePatch {
                        label: Some(label.into()),
                        ..NodePatch::default()
                    },
                })
                .collect();
            let old = engine.snapshot(state).unwrap();
            let expected_old = lines(old.clone());
            let start = Instant::now();
            apply(&mut engine, operations);
            let current = project(&mut engine, state);
            let context = RenderContext::default();
            let plan = RenderPlan::new(
                Some(old.clone()),
                current.clone(),
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, 1);
            let expected = vec![format!("  {}target", format!("{label}/").repeat(count - 1))];
            assert_eq!(apply_plan(expected_old.clone(), &plan), expected);
            assert_eq!(lines(current), expected);
            drop(plan);
            assert_eq!(lines(old), expected_old);
            samples.push(start.elapsed().as_secs_f64() * 1000.0);
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "ancestry_filtered_batch: nodes={count}, visible=1, n=10, p50_ms={:.3}, p95_ms={:.3}",
            samples[4], samples[9]
        );
    }
}

#[test]
#[ignore = "explicit release-mode wide-tree and task scaling measurement"]
fn t_filetree_support_performance() {
    let (mut engine, tree, root) = fixture(50_000);
    let options = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        ..DisplayOptions::default()
    };
    let list = engine
        .create_state(Root::ChildrenOf(root), options.clone())
        .unwrap();
    let forest = engine
        .create_state(Root::Forest(vec![root].into()), options)
        .unwrap();
    let states = [tree, list, forest];
    let leaf = engine.source.id("n25000").unwrap();
    let mut samples = Vec::new();
    for i in 0..110 {
        let previous: Vec<_> = states
            .iter()
            .map(|id| engine.snapshot(*id).unwrap())
            .collect();
        let start = Instant::now();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: leaf.into(),
                patch: NodePatch {
                    label: Some(format!("changed-{i:03}").into()),
                    ..NodePatch::default()
                },
            }],
        );
        project(&mut engine, tree);
        for (id, previous) in states.into_iter().zip(previous) {
            let context = RenderContext::default();
            let plan = RenderPlan::new(
                Some(previous),
                engine.snapshot(id).unwrap(),
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, 1);
            assert_eq!(plan.work.compared_rows, 1);
        }
        if i >= 10 {
            samples.push(start.elapsed().as_secs_f64() * 1_000.0);
        }
    }
    samples.sort_by(f64::total_cmp);
    println!(
        "ancestry_wide_leaf: nodes=50000, states=3, n=100, p50_ms={:.3}, p95_ms={:.3}, retained_bytes={}",
        samples[49],
        samples[94],
        engine.memory.used()
    );

    engine
        .dispatch(
            tree,
            Command::Select {
                targets: Targets::Nodes(vec![root].into()),
                action: SelectAction::Select,
                scope: Scope::Subtree,
            },
            Context::default(),
        )
        .unwrap();
    engine
        .dispatch(
            tree,
            Command::Select {
                targets: Targets::Nodes(vec![root].into()),
                action: SelectAction::Deselect,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        )
        .unwrap();
    let mut prepare = Vec::new();
    for _ in 0..10 {
        let start = Instant::now();
        let Reply::Locked { token, .. } = engine
            .lock_selection(tree, engine.states[&tree].state.selection_revision, None)
            .unwrap()
        else {
            panic!("lock")
        };
        let Reply::Ready { sources, .. } = engine
            .dispatch(
                tree,
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
        assert_eq!(sources.subtree_roots.len(), 50_000);
        prepare.push(start.elapsed().as_secs_f64() * 1_000.0);
        engine.unlock_selection(tree, token).unwrap();
    }
    prepare.sort_by(f64::total_cmp);
    println!(
        "task_prepare: roots=50000, n=10, p50_ms={:.3}, p95_ms={:.3}",
        prepare[4], prepare[9]
    );

    let Reply::Locked { token, .. } = engine
        .lock_selection(tree, engine.states[&tree].state.selection_revision, None)
        .unwrap()
    else {
        panic!("lock")
    };
    engine
        .dispatch(
            tree,
            Command::PrepareSources {
                lock: token,
                retry: false,
            },
            Context::default(),
        )
        .unwrap();
    let mut unrelated = Vec::new();
    for i in 0..100 {
        let start = Instant::now();
        apply(
            &mut engine,
            vec![Operation::Insert {
                key: format!("outside-{i}").into(),
                parent: None,
                position: Position::Last,
                data: NodeData::leaf("outside"),
                completeness: Completeness::Complete,
            }],
        );
        assert!(engine.states[&tree].task.as_ref().unwrap().valid);
        unrelated.push(start.elapsed().as_secs_f64() * 1_000.0);
    }
    unrelated.sort_by(f64::total_cmp);
    println!(
        "task_unrelated_insert: roots=50000, n=100, p50_ms={:.3}, p95_ms={:.3}",
        unrelated[49], unrelated[94]
    );
}

#[test]
#[ignore = "explicit 200k-node multi-state stress with a 2 GiB budget"]
fn t_large_multi_root_mutations_keep_retained_frames() {
    let limits = Limits {
        memory_bytes: 2 * 1024 * 1024 * 1024,
        batch_nodes: 200_010,
        ..Limits::default()
    };
    let mut engine = Engine::new(limits).unwrap();
    let memory = engine.memory.clone();
    let mut records = vec![Record::new("workspace", NodeData::branch("workspace"))];
    for group in 0..4 {
        records.push(Record {
            key: format!("g{group}").into(),
            parent: Some("workspace".into()),
            data: NodeData::branch(format!("group-{group}")),
            completeness: None,
        });
    }
    records.extend((0..200_000).map(|index| Record {
        key: format!("n{index}").into(),
        parent: Some(format!("g{}", index / 50_000).as_str().into()),
        data: NodeData::leaf(format!("file-{index:06}")),
        completeness: None,
    }));
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let workspace = engine.source.id("workspace").unwrap();
    let groups: Vec<_> = (0..4)
        .map(|index| engine.source.id(&format!("g{index}")).unwrap())
        .collect();
    let tree = engine
        .create_state(Root::ChildrenOf(workspace), DisplayOptions::default())
        .unwrap();
    engine
        .dispatch(
            tree,
            Command::SetExpanded {
                targets: Targets::Nodes(groups.clone().into()),
                value: true,
                scope: Scope::SelfOnly,
            },
            Context::default(),
        )
        .unwrap();
    project(&mut engine, tree);
    let options = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        ..DisplayOptions::default()
    };
    let children = engine
        .create_state(Root::ChildrenOf(groups[0]), options.clone())
        .unwrap();
    let forest = engine
        .create_state(Root::Forest(groups[..2].to_vec().into()), options)
        .unwrap();
    let old: Vec<_> = [tree, children, forest]
        .into_iter()
        .map(|state| engine.snapshot(state).unwrap())
        .collect();
    assert_eq!(old[0].len(), 200_004);
    assert_eq!(old[1].len(), 50_000);
    assert_eq!(old[2].len(), 100_002);
    let leaf = engine.source.id("n25000").unwrap();
    let began = Instant::now();
    apply(
        &mut engine,
        vec![Operation::Update {
            node: leaf.into(),
            patch: NodePatch {
                label: Some("renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    project(&mut engine, tree);
    for state in [tree, children, forest] {
        let frame = engine.snapshot(state).unwrap();
        assert_eq!(
            frame
                .row(frame.position(leaf).unwrap())
                .unwrap()
                .label
                .as_ref(),
            "renamed"
        );
    }
    let before = engine.snapshot(children).unwrap().text_revision;
    apply(
        &mut engine,
        vec![Operation::Update {
            node: groups[0].into(),
            patch: NodePatch {
                label: Some("directory-renamed".into()),
                ..NodePatch::default()
            },
        }],
    );
    project(&mut engine, tree);
    assert_eq!(engine.snapshot(children).unwrap().text_revision, before);
    let frame = engine.snapshot(forest).unwrap();
    let at = frame.position(leaf).unwrap();
    assert_eq!(
        frame.rows(at, at + 1).unwrap()[0].label,
        "directory-renamed/renamed"
    );
    drop(frame);
    apply(
        &mut engine,
        vec![Operation::Reparent {
            node: groups[0].into(),
            parent: Some(groups[2].into()),
            position: Position::First,
        }],
    );
    project(&mut engine, tree);
    assert_eq!(engine.snapshot(children).unwrap().len(), 50_000);
    apply(
        &mut engine,
        vec![Operation::Insert {
            key: "inserted".into(),
            parent: Some(groups[0].into()),
            position: Position::First,
            data: NodeData::leaf("inserted"),
            completeness: Completeness::Complete,
        }],
    );
    project(&mut engine, tree);
    assert_eq!(engine.snapshot(children).unwrap().len(), 50_001);
    apply(
        &mut engine,
        vec![
            Operation::Update {
                node: leaf.into(),
                patch: NodePatch {
                    score: Some(4.0),
                    ..NodePatch::default()
                },
            },
            Operation::Remove {
                node: "inserted".into(),
            },
        ],
    );
    project(&mut engine, tree);
    assert_eq!(engine.snapshot(children).unwrap().len(), 50_000);
    assert_eq!(
        old[0].source().node(groups[0]).unwrap().parent,
        Some(workspace)
    );
    assert_eq!(
        old[1]
            .row(old[1].position(leaf).unwrap())
            .unwrap()
            .label
            .as_ref(),
        "file-025000"
    );
    println!(
        "multi-root stress: nodes=200005 states=3 old_frames=3 mutations_ms={:.3} retained_bytes={}",
        began.elapsed().as_secs_f64() * 1000.0,
        memory.used()
    );
    drop(old);
    drop(engine);
    assert_eq!(memory.used(), 0);
}

#[test]
#[ignore = "explicit release-mode filter stage measurement"]
fn t_ancestry_filter_performance() {
    let (mut engine, state, root) = fixture(50_000);
    apply(
        &mut engine,
        (0..50_000)
            .map(|i| Operation::Update {
                node: format!("n{i}").as_str().into(),
                patch: NodePatch {
                    label: Some(format!("node-{i:05}{}", "x".repeat(86)).into()),
                    ..NodePatch::default()
                },
            })
            .collect(),
    );
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(vec![root].into())),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    let mut samples = [Vec::new(), Vec::new(), Vec::new()];
    for index in 0..100 {
        let old = engine.snapshot(state).unwrap();
        engine
            .dispatch(
                state,
                Command::SetDisplay(DisplayOptions {
                    mode: Mode::List,
                    list_text: ListText::Ancestry,
                    pattern: if index % 2 == 0 { "node-000" } else { "node-" }.into(),
                    ..DisplayOptions::default()
                }),
                Context {
                    expected_state: Some(engine.states[&state].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
        let start = Instant::now();
        let frame = project(&mut engine, state);
        let projection = start.elapsed().as_secs_f64() * 1000.0;
        let start = Instant::now();
        let context = RenderContext::default();
        let plan = RenderPlan::new(
            Some(old),
            frame.clone(),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        let planning = start.elapsed().as_secs_f64() * 1000.0;
        let start = Instant::now();
        for splice in plan.splices.iter() {
            let mut at = splice.target_start;
            while at < splice.target_end {
                at = plan
                    .write_lines(at, (at + 512).min(splice.target_end), 64 * 1024, |text| {
                        std::hint::black_box(text);
                        Ok(())
                    })
                    .unwrap();
            }
        }
        if index % 2 == 1 {
            for (values, time) in samples.iter_mut().zip([
                projection,
                planning,
                start.elapsed().as_secs_f64() * 1000.0,
            ]) {
                values.push(time);
            }
        }
    }
    for (name, mut values) in ["projection", "plan", "export"].into_iter().zip(samples) {
        values.sort_by(f64::total_cmp);
        println!(
            "ancestry_filter_expand: stage={name}, rows=50000, n=50, p50_ms={:.3}, p95_ms={:.3}",
            values[24], values[47]
        );
    }
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
fn t_render_interleaved_page_insertions_and_text_changes_match_full_body() {
    for rename in [false, true] {
        let (mut engine, state, root) = fixture(4096);
        let old = project(&mut engine, state);
        let mut operations = Vec::new();
        for index in (0..4096).step_by(8) {
            operations.push(Operation::Insert {
                key: format!("inserted-{index}").into(),
                parent: Some(root.into()),
                position: Position::Before(engine.source.id(&format!("n{index}")).unwrap().into()),
                data: NodeData::leaf(format!("page-{index}")),
                completeness: Completeness::Complete,
            });
        }
        if rename {
            operations.push(Operation::Update {
                node: engine.source.id("n2048").unwrap().into(),
                patch: NodePatch {
                    label: Some("changed middle".into()),
                    ..NodePatch::default()
                },
            });
        }
        apply(&mut engine, operations);
        let next = project(&mut engine, state);
        let plan = RenderPlan::new(
            Some(old.clone()),
            next.clone(),
            Some(&RenderContext::default()),
            RenderContext::default(),
            false,
        )
        .unwrap();
        if !rename {
            assert_eq!(plan.mode, PlanMode::Delta);
        }
        assert_eq!(apply_plan(lines(old), &plan), lines(next));
    }
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
    assert_eq!(lines(after), vec!["    node-00000"]);
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
    assert_eq!(plan.lines(0, 1, 1024).unwrap().0, ["  node-00000"]);
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
    let Reply::Applied { effects, .. } = engine
        .prepare_task_read(state, lock, cleanup, root)
        .unwrap()
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
fn t_task_discovery_does_not_authorize_new_members_in_an_already_complete_slot() {
    let (mut engine, state, root) = fixture(0);
    let (lock, cleanup) = prepare_subtree(&mut engine, state, root);
    let Reply::Applied { effects, .. } = engine
        .prepare_task_read(state, lock, cleanup, root)
        .unwrap()
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
fn t_source_retry_only_restarts_required_errors_and_keeps_task_read_ownership() {
    for outcome in ["cancel", "failure", "ready"] {
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

        match outcome {
            "cancel" => {
                engine.unlock_selection(state, current).unwrap();
                assert!(!engine.needed(root));
                engine.children_cancelled(read).unwrap();
                assert!(engine.reads.is_empty());
            }
            "failure" => {
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
            _ => {
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
        }
    }
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
    let held = super::memory::Charge::new(engine.limits.memory_bytes - engine.memory.used() - 32);
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
    assert!(
        engine.manual_reads.is_empty()
            && engine.observed_reads.is_empty()
            && engine.leased_reads.is_empty()
    );
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
                    .prepare_task_read(state, lock, cleanup, root)
                    .unwrap();
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
                engine.request_observed_children(&[root], true).unwrap();
                engine.request_observed_children(&[root], true).unwrap();
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
