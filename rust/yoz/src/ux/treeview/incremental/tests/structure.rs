use crate::ux::treeview::test_support::*;
use crate::ux::treeview::*;

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
