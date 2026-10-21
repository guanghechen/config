use crate::ux::treeview::test_support::*;
use crate::ux::treeview::*;
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
