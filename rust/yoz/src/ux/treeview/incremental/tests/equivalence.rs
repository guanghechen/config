use crate::ux::treeview::test_support::*;
use crate::ux::treeview::*;
use std::sync::Arc;

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
