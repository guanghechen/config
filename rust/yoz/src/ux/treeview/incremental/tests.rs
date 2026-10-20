use super::super::test_support::*;
use super::super::*;
use std::sync::Arc;
use std::time::Instant;

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
fn t_nested_page_insertions_preserve_ancestors_order_and_pinned_frames() {
    for (mode, compress, sort) in [
        (Mode::Tree, false, Sort::Source),
        (Mode::Tree, true, Sort::Source),
        (Mode::List, false, Sort::Source),
        (Mode::List, false, Sort::Name),
    ] {
        for rename_parent in [false, true] {
            let mut engine = Engine::new(Limits::default()).unwrap();
            let mut records = Vec::new();
            for (key, parent) in [
                ("root", None),
                ("left", Some("root")),
                ("right", Some("root")),
                ("deep", Some("right")),
            ] {
                records.push(Record {
                    key: key.into(),
                    parent: parent.map(Into::into),
                    data: NodeData {
                        foldable: true,
                        ..NodeData::branch(key)
                    },
                    completeness: Some(Completeness::Complete),
                });
            }
            for parent in ["left", "deep"] {
                records.extend((0..1024).map(|index| {
                    let name = format!("{parent}-{index:04}");
                    Record {
                        key: name.clone().into(),
                        parent: Some(parent.into()),
                        data: NodeData::leaf(name),
                        completeness: Some(Completeness::Complete),
                    }
                }));
            }
            engine
                .import(Import {
                    base_revision: engine.source.revision(),
                    scope: DataScope::Forest,
                    records,
                })
                .unwrap();
            let root = engine.source.id("root").unwrap();
            let state = engine
                .create_state(
                    Root::ChildrenOf(root),
                    DisplayOptions {
                        mode,
                        compress,
                        sort,
                        list_text: ListText::Ancestry,
                        ..DisplayOptions::default()
                    },
                )
                .unwrap();
            set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
            let pinned = project(&mut engine, state);
            let original = lines(pinned.clone());
            for page in 0..2 {
                let before = engine.snapshot(state).unwrap();
                let mut operations = vec![Operation::Insert {
                    key: format!("top-{page}").into(),
                    parent: Some(root.into()),
                    position: Position::Before("right".into()),
                    data: NodeData::leaf(format!("top-{page}")),
                    completeness: Completeness::Complete,
                }];
                for parent in ["left", "deep"] {
                    let id = engine.source.id(parent).unwrap();
                    for index in (0..1024).step_by(4) {
                        operations.push(Operation::Insert {
                            key: format!("page-{page}-{parent}-{index}").into(),
                            parent: Some(id.into()),
                            position: Position::Before(
                                format!("{parent}-{index:04}").as_str().into(),
                            ),
                            data: NodeData::leaf(format!("inserted-{page}-{index}")),
                            completeness: Completeness::Complete,
                        });
                    }
                }
                if rename_parent {
                    operations.push(Operation::Update {
                        node: "left".into(),
                        patch: NodePatch {
                            label: Some(format!("renamed-{page}").into()),
                            ..NodePatch::default()
                        },
                    });
                }
                apply(&mut engine, operations);
                let after = project(&mut engine, state);
                assert_projection(&engine, state);
                if !rename_parent && !compress {
                    assert!(after.visited_nodes <= 520, "{}", after.visited_nodes);
                }
                let plan = RenderPlan::new(
                    Some(before.clone()),
                    after.clone(),
                    Some(&RenderContext::default()),
                    RenderContext::default(),
                    false,
                )
                .unwrap();
                assert_eq!(apply_plan(lines(before), &plan), lines(after));
                assert_eq!(lines(pinned.clone()), original);
            }
        }
    }
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
    set_expanded(&mut engine, state, &[a], true, Scope::SelfOnly);
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
            select(
                &mut engine,
                state,
                &[root],
                SelectAction::Select,
                Scope::Subtree,
            );
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
            select(
                &mut engine,
                state,
                &[id],
                SelectAction::Deselect,
                Scope::SelfOnly,
            );
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
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            compress: true,
            ..DisplayOptions::default()
        },
    );
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
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
fn t_filtered_compression_updates_preserve_unaffected_rows_and_old_frames() {
    let (mut engine, state, root) = fixture(50_000);
    let operations = [
        ("a", "root", true),
        ("b", "a", true),
        ("wanted", "b", false),
        ("other", "a", true),
        ("hidden", "other", false),
        ("ignored", "a", false),
    ]
    .into_iter()
    .map(|(key, parent, branch)| Operation::Insert {
        key: key.into(),
        parent: Some(parent.into()),
        position: Position::First,
        data: NodeData {
            can_expand: branch,
            foldable: branch,
            ..NodeData::leaf(if key == "wanted" { "node-wanted" } else { key })
        },
        completeness: Completeness::Complete,
    })
    .collect();
    apply(&mut engine, operations);
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            compress: true,
            pattern: "node-".into(),
            ..DisplayOptions::default()
        },
    );
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    let parent = engine.source.id("a").unwrap();
    let child = engine.source.id("b").unwrap();
    let base = project(&mut engine, state);
    assert_eq!(base.len(), 50_002);
    assert_eq!(base.rows(0, 1).unwrap()[0].label, "a/b");
    assert_eq!(base.position(parent), base.position(child));

    for label in ["node-wanted", "hidden", "node-wanted", "hidden"] {
        let before = engine.snapshot(state).unwrap();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: "hidden".into(),
                patch: NodePatch {
                    label: Some(label.into()),
                    ..NodePatch::default()
                },
            }],
        );
        let next = project(&mut engine, state);
        assert_projection(&engine, state);
        assert_eq!(
            next.position(parent) == next.position(child),
            label == "hidden"
        );
        assert!(
            next.visited_nodes < 50,
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
        assert_eq!(base.len(), 50_002);
        assert_eq!(base.position(parent), base.position(child));
    }

    for selected in [true, false] {
        select(
            &mut engine,
            state,
            &[child],
            if selected {
                SelectAction::Select
            } else {
                SelectAction::Deselect
            },
            Scope::SelfOnly,
        );
        let next = project(&mut engine, state);
        assert_projection(&engine, state);
        assert_eq!(next.position(parent) == next.position(child), !selected);
    }
    select(
        &mut engine,
        state,
        &[root],
        SelectAction::Select,
        Scope::Subtree,
    );
    let mut display = engine.states[&state].state.display.clone();
    display.selected_only = true;
    set_display(&mut engine, state, display);
    let selected = project(&mut engine, state);
    assert_ne!(selected.position(parent), selected.position(child));
    assert_projection(&engine, state);
}

fn filtered_compression_fixture(count: usize, id_filter: bool) -> (Engine, u64) {
    let mut engine = Engine::new(Limits::default()).unwrap();
    let mut records: Vec<_> = [
        ("root", None, true),
        ("a", Some("root"), true),
        ("b", Some("a"), true),
        ("other", Some("a"), true),
        ("excluded", Some("other"), false),
    ]
    .into_iter()
    .map(|(key, parent, branch)| Record {
        key: key.into(),
        parent: parent.map(Into::into),
        data: NodeData {
            can_expand: branch,
            foldable: branch,
            ..NodeData::leaf(key)
        },
        completeness: Some(Completeness::Complete),
    })
    .collect();
    records.extend((0..count).map(|at| Record {
        parent: Some("b".into()),
        ..Record::new(format!("n{at}"), NodeData::leaf(format!("needle-{at}")))
    }));
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let root = engine.source.id("root").unwrap();
    let state = engine
        .create_state(
            Root::ChildrenOf(root),
            DisplayOptions {
                compress: true,
                show_hidden: false,
                pattern: if id_filter { "" } else { "needle" }.into(),
                filter: id_filter.then(|| {
                    Arc::new(
                        (0..count)
                            .map(|at| (engine.source.id(&format!("n{at}")).unwrap(), at))
                            .collect(),
                    )
                }),
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    project(&mut engine, state);
    (engine, state)
}

#[test]
fn t_filtered_compression_keeps_large_unchanged_descendants_shared() {
    let count = 5_000;
    for id_filter in [false, true] {
        let (mut engine, state) = filtered_compression_fixture(count, id_filter);
        let parent = engine.source.id("a").unwrap();
        let child = engine.source.id("b").unwrap();
        let removed = engine.source.id("n2").unwrap();
        let base = engine.snapshot(state).unwrap();
        assert_eq!(base.len(), count + 1);
        assert_eq!(base.rows(0, 1).unwrap()[0].label, "a/b");
        let operations = [
            Operation::Remove {
                node: "excluded".into(),
            },
            Operation::Insert {
                key: "unmatched".into(),
                parent: Some("other".into()),
                position: Position::Last,
                data: NodeData::leaf("unmatched"),
                completeness: Completeness::Complete,
            },
            Operation::Remove {
                node: "other".into(),
            },
            Operation::Insert {
                key: "ignored".into(),
                parent: Some("a".into()),
                position: Position::Last,
                data: NodeData::leaf("ignored"),
                completeness: Completeness::Complete,
            },
            Operation::Update {
                node: "n0".into(),
                patch: NodePatch {
                    label: Some("unmatched".into()),
                    ..NodePatch::default()
                },
            },
            Operation::Update {
                node: "n0".into(),
                patch: NodePatch {
                    label: Some("needle-0".into()),
                    ..NodePatch::default()
                },
            },
            Operation::Update {
                node: "n1".into(),
                patch: NodePatch {
                    hidden: Some(true),
                    ..NodePatch::default()
                },
            },
            Operation::Update {
                node: "n1".into(),
                patch: NodePatch {
                    hidden: Some(false),
                    ..NodePatch::default()
                },
            },
            Operation::Remove {
                node: removed.into(),
            },
        ];
        for (at, operation) in operations.into_iter().enumerate() {
            let before = engine.snapshot(state).unwrap();
            apply(&mut engine, vec![operation]);
            let next = project(&mut engine, state);
            assert_projection(&engine, state);
            assert_eq!(next.position(parent), next.position(child));
            let missing = match at {
                4 if !id_filter => 1,
                6 | 8 => 1,
                _ => 0,
            };
            assert_eq!(next.len(), count + 1 - missing);
            assert!(
                next.visited_nodes < 32,
                "count={count}, id_filter={id_filter}, operation={at}: visited {} nodes",
                next.visited_nodes
            );
            let shared: usize = before
                .rows
                .shared_spans(&next.rows)
                .iter()
                .map(|(_, _, len)| len)
                .sum();
            assert!(shared >= count - 128, "only {shared} rows shared");
            if at < 4 {
                assert_eq!(next.layout_revision, before.layout_revision);
                assert!(next.rows.same_version(&before.rows));
            }
            assert_eq!(base.len(), count + 1);
            assert_eq!(base.position(parent), base.position(child));
            assert_eq!(base.rows(0, 1).unwrap()[0].label, "a/b");
            assert!(base.source.contains(removed));
        }
    }
}

#[test]
fn t_filtered_compression_rechecks_selection_expansion_and_child_identity() {
    for id_filter in [false, true] {
        let (mut engine, state) = filtered_compression_fixture(3, id_filter);
        let parent = engine.source.id("a").unwrap();
        let child = engine.source.id("b").unwrap();
        let other = engine.source.id("other").unwrap();
        let base = engine.snapshot(state).unwrap();
        let check = |engine: &mut Engine, joined: bool| {
            let frame = project(engine, state);
            assert_projection(engine, state);
            assert_eq!(frame.position(parent) == frame.position(child), joined);
        };
        for (key, selected, joined) in [
            ("root", true, true),
            ("excluded", false, false),
            ("n0", false, true),
            ("n0", true, false),
        ] {
            let id = engine.source.id(key).unwrap();
            select(
                &mut engine,
                state,
                &[id],
                if selected {
                    SelectAction::Select
                } else {
                    SelectAction::Deselect
                },
                Scope::Subtree,
            );
            check(&mut engine, joined);
        }
        apply(
            &mut engine,
            vec![Operation::Remove {
                node: "excluded".into(),
            }],
        );
        check(&mut engine, true);

        for foldable in [false, true] {
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: child.into(),
                    patch: NodePatch {
                        foldable: Some(foldable),
                        ..NodePatch::default()
                    },
                }],
            );
            check(&mut engine, foldable);
        }
        for expanded in [false, true] {
            set_expanded(&mut engine, state, &[parent], expanded, Scope::SelfOnly);
            check(&mut engine, expanded);
        }
        apply(
            &mut engine,
            (0..3)
                .map(|at| Operation::Reparent {
                    node: format!("n{at}").as_str().into(),
                    parent: Some(other.into()),
                    position: Position::Last,
                })
                .collect(),
        );
        let swapped = project(&mut engine, state);
        assert_projection(&engine, state);
        assert_eq!(swapped.position(parent), swapped.position(other));
        assert_eq!(swapped.position(child), None);
        assert_eq!(swapped.rows(0, 1).unwrap()[0].label, "a/other");
        for at in 0..3 {
            apply(
                &mut engine,
                vec![Operation::Reparent {
                    node: format!("n{at}").as_str().into(),
                    parent: Some(child.into()),
                    position: Position::Last,
                }],
            );
            check(&mut engine, at == 2);
        }
        assert_eq!(base.rows(0, 1).unwrap()[0].label, "a/b");
        assert_eq!(base.position(parent), base.position(child));
        assert_eq!(swapped.rows(0, 1).unwrap()[0].label, "a/other");
        assert_eq!(swapped.position(parent), swapped.position(other));
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
        set_display(&mut engine, state, display.clone());
        set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
        let pinned = project(&mut engine, state);
        let old_lines = lines(pinned.clone());
        let mut seed = 173_u64;
        let mut inserted: Vec<String> = Vec::new();
        for iteration in 0..400 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let id = ids[(seed as usize >> 8) % 24];
            let flag = seed & 128 != 0;
            match iteration % 8 {
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
                    set_expanded(&mut engine, state, &[id], flag, Scope::SelfOnly);
                }
                3 => {
                    select(
                        &mut engine,
                        state,
                        &[id],
                        if flag {
                            SelectAction::Select
                        } else {
                            SelectAction::Deselect
                        },
                        Scope::SelfOnly,
                    );
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
                5 => {
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
                6 => {
                    let key = format!("x{iteration}");
                    apply(
                        &mut engine,
                        vec![Operation::Insert {
                            key: key.as_str().into(),
                            parent: Some(id.into()),
                            position: if flag {
                                Position::First
                            } else {
                                Position::Last
                            },
                            data: NodeData::leaf(if flag { "node-00021" } else { "inserted" }),
                            completeness: Completeness::Complete,
                        }],
                    );
                    inserted.push(key);
                }
                _ => {
                    if !inserted.is_empty() {
                        let key = inserted.swap_remove((seed as usize >> 16) % inserted.len());
                        apply(
                            &mut engine,
                            vec![Operation::Remove {
                                node: key.as_str().into(),
                            }],
                        );
                    }
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
            set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
            if selected_only {
                select(
                    &mut engine,
                    state,
                    &[root],
                    SelectAction::Select,
                    Scope::Subtree,
                );
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
            select(
                &mut engine,
                state,
                &[head],
                SelectAction::Deselect,
                Scope::SelfOnly,
            );
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
    select(
        &mut engine,
        state,
        &[selected],
        SelectAction::Select,
        Scope::SelfOnly,
    );
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
        set_expanded(&mut engine, state, &[a], true, Scope::Subtree);
        select(
            &mut engine,
            state,
            &[a],
            SelectAction::Select,
            Scope::Subtree,
        );
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
        set_expanded(&mut engine, state, &[ids[0], ids[2]], true, Scope::SelfOnly);
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
fn t_ordered_result_filter_keeps_tree_connections_and_list_membership_after_mutations() {
    let (mut engine, state, _) = ancestry_fixture();
    let root = engine.source.id("root").unwrap();
    let src = engine.source.id("src").unwrap();
    let lib = engine.source.id("lib").unwrap();
    let a = engine.source.id("a").unwrap();
    let readme = engine.source.id("readme").unwrap();
    let filter = Arc::new([(readme, 0), (a, 1)].into_iter().collect());
    let mut display = DisplayOptions {
        mode: Mode::Tree,
        filter: Some(filter),
        ..DisplayOptions::default()
    };
    let set_display = |engine: &mut Engine, display: DisplayOptions| {
        let expected_state = Some(engine.states[&state].state.revision);
        engine
            .dispatch(
                state,
                Command::SetDisplay(display),
                Context {
                    expected_state,
                    ..Context::default()
                },
            )
            .unwrap();
        project(engine, state);
        assert_projection(engine, state);
    };
    set_display(&mut engine, display.clone());
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    let tree = project(&mut engine, state);
    assert_eq!(
        tree.rows.iter().map(|row| row.id).collect::<Vec<_>>(),
        [src, lib, a, readme]
    );
    select(
        &mut engine,
        state,
        &[root],
        SelectAction::Select,
        Scope::Subtree,
    );
    display.mode = Mode::List;
    display.selected_only = true;
    display.branches_first = true;
    display.list_text = ListText::Ancestry;
    set_display(&mut engine, display.clone());
    let list = engine.snapshot(state).unwrap();
    assert_eq!(
        list.rows.iter().map(|row| row.id).collect::<Vec<_>>(),
        [readme, a]
    );
    assert_eq!(list.rows(0, 2).unwrap()[1].label, "src/lib/文.lua");
    assert_eq!(&*list.marked_nodes(true).unwrap(), &[readme, a]);
    let mut selected = list.marked_nodes(false).unwrap().to_vec();
    selected.sort();
    let mut expected = vec![root, src, lib, a, readme];
    expected.sort();
    assert_eq!(selected, expected);
    apply(
        &mut engine,
        vec![Operation::Update {
            node: lib.into(),
            patch: NodePatch {
                label: Some("nested".into()),
                ..NodePatch::default()
            },
        }],
    );
    let renamed = project(&mut engine, state);
    assert_eq!(renamed.rows(0, 2).unwrap()[1].label, "src/nested/文.lua");
    assert_projection(&engine, state);
    apply(
        &mut engine,
        vec![Operation::Remove {
            node: readme.into(),
        }],
    );
    let removed = project(&mut engine, state);
    assert_eq!(
        removed.rows.iter().map(|row| row.id).collect::<Vec<_>>(),
        [a]
    );
    assert_projection(&engine, state);
    assert_eq!(&*removed.marked_nodes(true).unwrap(), &[a]);
    assert_eq!(&*list.marked_nodes(true).unwrap(), &[readme, a]);
    assert_eq!(
        list.rows.iter().map(|row| row.id).collect::<Vec<_>>(),
        [readme, a]
    );
}
