use super::super::test_support::*;
use super::super::*;
use std::sync::Arc;

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
fn t_staged_list_plan_rejects_branch_suffix_changes_when_expandability_changes() {
    for suffix in ["", "/"] {
        let (mut engine, state, _) = fixture(2);
        set_display(
            &mut engine,
            state,
            DisplayOptions {
                mode: Mode::List,
                list_depth: Some(0),
                branch_suffix: suffix.into(),
                ..DisplayOptions::default()
            },
        );
        let context = RenderContext::default();
        let mut before = project(&mut engine, state);
        for can_expand in [true, false] {
            let plan = RenderPlan::new(
                Some(before.clone()),
                before.clone(),
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, 0);
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: "n0".into(),
                    patch: NodePatch {
                        can_expand: Some(can_expand),
                        ..NodePatch::default()
                    },
                }],
            );
            let after = project(&mut engine, state);
            assert_eq!(after.layout_revision, before.layout_revision);
            if suffix.is_empty() {
                assert!(plan.retarget(after.clone()).is_some());
            } else {
                assert!(plan.retarget(after.clone()).is_none());
                assert_ne!(after.text_revision, before.text_revision);
                let updated = RenderPlan::new(
                    Some(before.clone()),
                    after.clone(),
                    Some(&context),
                    context.clone(),
                    false,
                )
                .unwrap();
                assert_eq!(updated.work.written_rows, 1);
                assert_eq!(apply_plan(lines(before), &updated), lines(after.clone()));
            }
            before = after;
        }
    }
}

#[test]
fn t_same_rows_proves_cursor_reuse_but_rejects_other_decoration_changes() {
    let (mut engine, state, root) = fixture(2);
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
    let base = project(&mut engine, state);
    let node = engine.source.id("n1").unwrap();
    engine
        .dispatch(state, Command::SetCursor(Some(node)), Context::default())
        .unwrap();
    let cursor = project(&mut engine, state);
    assert_ne!(base.id, cursor.id);
    assert!(base.same_rows(&cursor));
    assert!(cursor.same_rows(&base));
    assert!(cursor.same_rows(&cursor));
    let other = engine
        .create_state(Root::ChildrenOf(root), DisplayOptions::default())
        .unwrap();
    assert!(!cursor.same_rows(&engine.snapshot(other).unwrap()));

    let empty = engine.source.id("n0").unwrap();
    set_expanded(&mut engine, state, &[empty], true, Scope::SelfOnly);
    let expanded = project(&mut engine, state);
    assert_eq!(cursor.layout_revision, expanded.layout_revision);
    assert!(!cursor.rows(0, 1).unwrap()[0].expanded);
    assert!(expanded.rows(0, 1).unwrap()[0].expanded);
    assert!(!cursor.same_rows(&expanded));

    select(
        &mut engine,
        state,
        &[node],
        SelectAction::Select,
        Scope::SelfOnly,
    );
    let selected = project(&mut engine, state);
    assert_eq!(selected.layout_revision, expanded.layout_revision);
    assert!(!selected.same_rows(&expanded));

    set_display(
        &mut engine,
        state,
        DisplayOptions {
            pattern: "node".into(),
            ..DisplayOptions::default()
        },
    );
    let matched = project(&mut engine, state);
    assert_eq!(matched.len(), selected.len());
    assert!(!matched.rows(0, 1).unwrap()[0].matches.is_empty());
    assert!(!matched.same_rows(&selected));

    apply(
        &mut engine,
        vec![Operation::Update {
            node: node.into(),
            patch: NodePatch {
                highlight: Some(Some("DiagnosticError".into())),
                ..NodePatch::default()
            },
        }],
    );
    let metadata = project(&mut engine, state);
    assert_eq!(metadata.layout_revision, matched.layout_revision);
    assert!(!metadata.same_rows(&matched));
    assert!(
        base.same_rows(&cursor),
        "retained frames retain their proof after later mutations"
    );
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
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            pattern: "node-".into(),
            ..DisplayOptions::default()
        },
    );
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
