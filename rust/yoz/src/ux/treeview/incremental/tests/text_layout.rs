use crate::ux::treeview::test_support::*;
use crate::ux::treeview::*;
use std::sync::Arc;

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
