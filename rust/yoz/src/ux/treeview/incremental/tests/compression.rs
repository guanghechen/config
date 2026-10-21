use crate::ux::treeview::test_support::*;
use crate::ux::treeview::*;
use std::sync::Arc;

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
