use super::super::test_support::*;
use super::super::*;
use super::TextPath;
use std::sync::Arc;

#[test]
fn t_deep_shared_text_has_linear_storage_and_iterative_release() {
    let budget = super::super::memory::Budget::new(16 * 1024 * 1024);
    let _guard = budget.enter();
    let label: Arc<str> = "x".into();
    let mut path = None;
    for id in 1..=10_000 {
        path = Some(TextPath::new(NodeId(id), label.clone(), path).unwrap());
    }
    let path = path.unwrap();
    assert_eq!(path.bytes, 19_999);
    assert!(budget.used() < 2 * 1024 * 1024);
    let mut output = String::new();
    path.append(&mut output, &mut Vec::new());
    assert_eq!(output.len(), 19_999);
    assert!(output.starts_with("x/x/x/"));
    drop(path);
    assert_eq!(budget.used(), 0);
}

fn grouped_ancestry_fixture() -> (Engine, u64) {
    let (mut engine, state, _) = ancestry_fixture();
    let filter = ["src", "a", "readme"]
        .into_iter()
        .enumerate()
        .map(|(rank, key)| (engine.source.id(key).unwrap(), rank))
        .collect();
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            list_from_depth: Some(1),
            list_text: ListText::Ancestry,
            filter: Some(Arc::new(filter)),
            ..DisplayOptions::default()
        },
    );
    for (key, value, scope) in [
        ("root", true, Scope::Subtree),
        ("lib", false, Scope::SelfOnly),
    ] {
        let node = engine.source.id(key).unwrap();
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![node].into()),
                    value,
                    scope,
                },
                Context {
                    expected_state: Some(engine.states[&state].state.revision),
                    ..Context::default()
                },
            )
            .unwrap();
    }
    (engine, state)
}

#[test]
fn t_grouped_lists_preserve_source_and_expansion_while_flattening_only_group_contents() {
    let (mut engine, state) = grouped_ancestry_fixture();
    let directory = engine.source.id("lib").unwrap();
    let group = engine.source.id("src").unwrap();
    let leaf = engine.source.id("a").unwrap();
    let revision = engine.source.revision();
    let grouped = project(&mut engine, state);
    let rows = grouped.rows(0, grouped.len()).unwrap();
    assert_eq!(
        rows.iter()
            .map(|row| row.label.as_str())
            .collect::<Vec<_>>(),
        ["src", "lib/文.lua", "README"]
    );
    assert_eq!(rows[1].row.parent, Some(group));
    assert_eq!(rows[1].row.depth, 1);
    assert_eq!(grouped.navigate(1, Direction::Parent), Some(0));
    assert_eq!(grouped.source.node(leaf).unwrap().parent, Some(directory));
    assert!(
        !engine.states[&state]
            .state
            .expanded(&engine.source, directory)
            .unwrap()
    );
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![group].into()),
                value: false,
                scope: Scope::SelfOnly,
            },
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    assert_eq!(project(&mut engine, state).len(), 2);
    assert!(
        !engine.states[&state]
            .state
            .observes_children(&engine.source, directory)
    );
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(vec![group].into()),
                value: true,
                scope: Scope::SelfOnly,
            },
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    assert_eq!(project(&mut engine, state).len(), 3);
    assert!(
        engine.states[&state]
            .state
            .observes_children(&engine.source, directory)
    );
    set_display(&mut engine, state, DisplayOptions::default());
    let tree = project(&mut engine, state);
    assert_eq!(tree.len(), 3);
    assert!(tree.position(leaf).is_none());
    assert_eq!(tree.source.id("lib"), Some(directory));
    assert_eq!(tree.source.revision(), revision);
    assert!(
        !engine.states[&state]
            .state
            .observes_children(&engine.source, directory)
    );
}

#[test]
fn t_grouped_ancestry_renames_publish_updated_text_and_keep_retained_frames() {
    let (mut engine, state) = grouped_ancestry_fixture();
    let old = project(&mut engine, state);
    for (key, label, expected) in [
        ("lib", "core", "core/文.lua"),
        ("src", "renamed group", "core/文.lua"),
    ] {
        let base = project(&mut engine, state);
        let node = engine.source.id(key).unwrap();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: node.into(),
                patch: NodePatch {
                    label: Some(label.into()),
                    ..NodePatch::default()
                },
            }],
        );
        let current = project(&mut engine, state);
        assert_eq!(current.rows(1, 2).unwrap()[0].label, expected);
        let context = RenderContext::default();
        let plan = RenderPlan::new(
            Some(base.clone()),
            current.clone(),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        assert_eq!(apply_plan(lines(base), &plan), lines(current));
        assert_eq!(plan.work.written_rows, 1);
    }
    assert_eq!(old.rows(1, 2).unwrap()[0].label, "lib/文.lua");
}

#[test]
fn t_grouped_cursor_reuses_boundaries_but_flat_forest_restores_its_ancestry_scope() {
    let (mut engine, state) = grouped_ancestry_fixture();
    let group = engine.source.id("src").unwrap();
    let leaf = engine.source.id("a").unwrap();
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(vec![group].into())),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    let before = project(&mut engine, state);
    engine
        .dispatch(
            state,
            Command::SetCursor(Some(leaf)),
            Context {
                frame: Some(before.clone()),
                ..Context::default()
            },
        )
        .unwrap();
    let moved = project(&mut engine, state);
    assert_eq!(moved.visited_nodes, 0);
    assert!(moved.text_roots.same_version(&before.text_roots));
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            mode: Mode::List,
            list_text: ListText::Ancestry,
            filter: Some(Arc::new([(leaf, 0)].into_iter().collect())),
            ..DisplayOptions::default()
        },
    );
    let flat = project(&mut engine, state);
    assert_eq!(flat.rows(0, 1).unwrap()[0].label, "src/lib/文.lua");
    assert_eq!(before.rows(1, 2).unwrap()[0].label, "lib/文.lua");
}

#[test]
fn t_zero_depth_forest_publishes_external_ancestor_expansion_without_replacing_rows() {
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: vec![
                Record::new("outer", NodeData::branch("outer")),
                Record {
                    key: "group".into(),
                    parent: Some("outer".into()),
                    data: NodeData::branch("group"),
                    completeness: None,
                },
                Record {
                    key: "file".into(),
                    parent: Some("group".into()),
                    data: NodeData::leaf("file"),
                    completeness: None,
                },
            ],
        })
        .unwrap();
    let outer = engine.source.id("outer").unwrap();
    let group = engine.source.id("group").unwrap();
    let state = engine
        .create_state(
            Root::Forest(vec![group].into()),
            DisplayOptions {
                list_from_depth: Some(0),
                list_text: ListText::Ancestry,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    let original = project(&mut engine, state);
    let mut before = original.clone();
    for value in [true, false, true] {
        engine
            .dispatch(
                state,
                Command::SetExpanded {
                    targets: Targets::Nodes(vec![outer].into()),
                    value,
                    scope: Scope::Subtree,
                },
                Context::default(),
            )
            .unwrap();
        let current = project(&mut engine, state);
        assert_eq!(
            current.state_revision(),
            engine.states[&state].state.revision
        );
        assert_eq!(current.visited_nodes, 0);
        assert!(current.rows.same_version(&before.rows));
        assert_eq!(
            current
                .rows(0, 2)
                .unwrap()
                .iter()
                .map(|row| row.label.as_str())
                .collect::<Vec<_>>(),
            ["group", "group/file"]
        );
        let reference = Snapshot::build(
            engine.source.clone(),
            &mut engine.states[&state].state.clone(),
            None,
            false,
            Arc::new([]),
            engine.commit,
        )
        .unwrap();
        assert_eq!(lines(current.clone()), lines(Arc::new(reference)));
        let context = RenderContext::default();
        let plan = RenderPlan::new(
            Some(before.clone()),
            current.clone(),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        assert_eq!(apply_plan(lines(before), &plan), lines(current.clone()));
        before = current;
    }
    assert_eq!(original.rows(0, 2).unwrap()[1].label, "group/file");
}

#[test]
fn t_grouped_expansion_work_is_independent_of_unrelated_expanded_files() {
    let count = 5_000;
    let mut engine = Engine::new(Limits::default()).unwrap();
    let mut records = vec![Record::new("root", NodeData::branch("root"))];
    for (key, parent, branch) in [
        ("tiny", "root", true),
        ("tiny-dir", "tiny", true),
        ("tiny-file", "tiny-dir", false),
        ("bulk", "root", true),
        ("bulk-dir", "bulk", true),
    ] {
        records.push(Record {
            key: key.into(),
            parent: Some(parent.into()),
            data: if branch {
                NodeData::branch(key)
            } else {
                NodeData::leaf(key)
            },
            completeness: None,
        });
    }
    records.extend((0..count).map(|index| Record {
        key: format!("f{index}").into(),
        parent: Some("bulk-dir".into()),
        data: NodeData::leaf(format!("file-{index}")),
        completeness: None,
    }));
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let root = engine.source.id("root").unwrap();
    let tiny = engine.source.id("tiny").unwrap();
    let keys = ["tiny", "tiny-file", "bulk"]
        .into_iter()
        .map(str::to_owned)
        .chain((0..count).map(|index| format!("f{index}")));
    let filter = keys
        .enumerate()
        .map(|(rank, key)| (engine.source.id(&key).unwrap(), rank))
        .collect();
    let state = engine
        .create_state(
            Root::ChildrenOf(root),
            DisplayOptions {
                list_from_depth: Some(1),
                list_text: ListText::Ancestry,
                filter: Some(Arc::new(filter)),
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    let mut before = project(&mut engine, state);
    for expanded in [false, true, false, true] {
        set_expanded(&mut engine, state, &[tiny], expanded, Scope::SelfOnly);
        let current = project(&mut engine, state);
        assert!(
            current.visited_nodes <= 4,
            "{count} unrelated files: visited {}",
            current.visited_nodes
        );
        assert_eq!(current.len(), count + 2 + usize::from(expanded));
        let shared: usize = before
            .rows
            .shared_spans(&current.rows)
            .iter()
            .map(|(_, _, len)| len)
            .sum();
        assert!(shared >= count - 256, "unrelated row blocks must survive");
        let context = RenderContext::default();
        let plan = RenderPlan::new(
            Some(before.clone()),
            current.clone(),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        assert!(plan.work.written_rows <= 2);
        assert_eq!(apply_plan(lines(before), &plan), lines(current.clone()));
        before = current;
    }
}

#[test]
fn t_grouped_local_expansion_matches_full_projection_for_nested_groups_and_inherited_marks() {
    for root_kind in ["children", "forest"] {
        let (mut engine, state) = grouped_ancestry_fixture();
        let src = engine.source.id("src").unwrap();
        let lib = engine.source.id("lib").unwrap();
        let leaf = engine.source.id("a").unwrap();
        if root_kind == "forest" {
            engine
                .dispatch(
                    state,
                    Command::SetRoot(Root::Forest(vec![src].into())),
                    Context {
                        expected_state: Some(engine.states[&state].state.revision),
                        ..Context::default()
                    },
                )
                .unwrap();
        }
        set_display(
            &mut engine,
            state,
            DisplayOptions {
                list_from_depth: Some(2),
                list_text: ListText::Ancestry,
                filter: Some(Arc::new(
                    [(src, 0), (lib, 1), (leaf, 2)].into_iter().collect(),
                )),
                ..DisplayOptions::default()
            },
        );
        project(&mut engine, state);
        for (nodes, value, scope) in [
            (vec![lib], true, Scope::SelfOnly),
            (vec![lib], false, Scope::SelfOnly),
            (vec![src], false, Scope::Subtree),
            (vec![src], true, Scope::Subtree),
            (vec![src, lib], false, Scope::SelfOnly),
            (vec![src, lib], true, Scope::SelfOnly),
        ] {
            engine
                .dispatch(
                    state,
                    Command::SetExpanded {
                        targets: Targets::Nodes(nodes.into()),
                        value,
                        scope,
                    },
                    Context::default(),
                )
                .unwrap();
            let current = project(&mut engine, state);
            let reference = Snapshot::build(
                engine.source.clone(),
                &mut engine.states[&state].state.clone(),
                None,
                false,
                Arc::new([]),
                engine.commit,
            )
            .unwrap();
            assert_eq!(current.len(), reference.len());
            for (actual, expected) in current
                .rows(0, current.len())
                .unwrap()
                .iter()
                .zip(reference.rows(0, reference.len()).unwrap())
            {
                assert!(actual.row.same_layout(&expected.row));
                assert_eq!(actual.row.connector_last, expected.row.connector_last);
                assert_eq!(actual.label, expected.label);
            }
        }
    }
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
        set_display(
            &mut engine,
            outer,
            DisplayOptions {
                mode: Mode::List,
                list_text: ListText::Ancestry,
                show_hidden: false,
                pattern: pattern.into(),
                ..DisplayOptions::default()
            },
        );
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

    set_display(
        &mut engine,
        state,
        DisplayOptions {
            pattern: "changed".into(),
            ..display.clone()
        },
    );
    let filtered = project(&mut engine, state);
    assert!(renamed.text_roots.same_version(&filtered.text_roots));
    assert_eq!(lines(filtered), ["  src/lib/changed"]);
    set_display(&mut engine, state, display.clone());
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
        set_display(
            &mut engine,
            state,
            DisplayOptions {
                list_text,
                ..display.clone()
            },
        );
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
                        1..=4 => {
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
