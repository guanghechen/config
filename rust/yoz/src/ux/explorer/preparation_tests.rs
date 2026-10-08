use super::*;
use crate::ux::filetree::Kind;

fn fixture() -> (Engine, u64, NodeId, NodeId) {
    let entry = Entry::read(&std::env::temp_dir()).unwrap();
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source().revision(),
            scope: DataScope::Forest,
            records: [
                ("root", None, true),
                ("a", Some("root"), false),
                ("branch", Some("root"), true),
                ("excluded", Some("branch"), false),
            ]
            .into_iter()
            .map(|(key, parent, directory)| {
                let mut entry = entry.clone();
                entry.name = key.into();
                entry.kind = if directory {
                    Kind::Directory
                } else {
                    Kind::File
                };
                entry.anchor = parent.is_none().then(std::env::temp_dir);
                Record {
                    key: key.into(),
                    parent: parent.map(Into::into),
                    data: entry.node_data(),
                    completeness: None,
                }
            })
            .collect(),
        })
        .unwrap();
    let a = engine.source().id("a").unwrap();
    let branch = engine.source().id("branch").unwrap();
    let state = engine
        .create_state(
            Root::ChildrenOf(engine.source().id("root").unwrap()),
            DisplayOptions::default(),
        )
        .unwrap();
    (engine, state, a, branch)
}

#[test]
fn t_cursor_preparation_ignores_unrelated_structure_but_rejects_selection_aba() {
    let (mut engine, state, a, branch) = fixture();
    let frame = engine.snapshot(state).unwrap();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Insert {
                key: "new".into(),
                parent: Some(branch.into()),
                position: Position::Last,
                data: NodeData::leaf("new"),
                completeness: Completeness::Complete,
            }],
        })
        .unwrap();
    assert_ne!(
        frame.selection_revision(),
        engine.states[&state].state.selection_revision
    );
    let Reply::Locked { token, .. } = Box::new(PrepareCursor {
        state,
        frame: frame.clone(),
        node: a,
    })
    .apply(&mut engine)
    .unwrap() else {
        panic!("lock");
    };
    engine.unlock_selection(state, token).unwrap();
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
    engine
        .dispatch(state, Command::ClearSelection, Context::default())
        .unwrap();
    let result = Box::new(PrepareCursor {
        state,
        frame,
        node: a,
    })
    .apply(&mut engine);
    assert_eq!(result.unwrap_err().code, ErrorCode::Stale);
    assert!(engine.states[&state].task.is_none());
}

#[test]
fn t_cursor_preparation_rejects_reparenting_and_foreign_frames_without_locking() {
    let (mut engine, state, a, branch) = fixture();
    let frame = engine.snapshot(state).unwrap();
    let other = engine
        .create_state(Root::ChildrenOf(branch), DisplayOptions::default())
        .unwrap();
    let result = Box::new(PrepareCursor {
        state,
        frame: engine.snapshot(other).unwrap(),
        node: a,
    })
    .apply(&mut engine);
    assert_eq!(result.unwrap_err().code, ErrorCode::Stale);
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Reparent {
                node: a.into(),
                parent: Some(branch.into()),
                position: Position::Last,
            }],
        })
        .unwrap();
    let result = Box::new(PrepareCursor {
        state,
        frame,
        node: a,
    })
    .apply(&mut engine);
    assert_eq!(result.unwrap_err().code, ErrorCode::Stale);
    assert!(engine.states[&state].task.is_none());
}

#[test]
fn t_range_inspection_keeps_the_input_resource_after_a_same_node_rename() {
    let (mut engine, state, node, _) = fixture();
    let frame = engine.snapshot(state).unwrap();
    let position = frame.position(node).unwrap();
    let captured = Resource {
        source: frame.source.clone(),
        node,
    };
    let mut renamed = captured.entry().unwrap();
    renamed.name = "renamed".into();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Update {
                node: node.into(),
                patch: NodePatch {
                    payload: Some(renamed.node_data().payload),
                    label: Some("renamed".into()),
                    ..NodePatch::default()
                },
            }],
        })
        .unwrap();
    let Reply::Inspected {
        revisions,
        sources,
        source,
    } = Box::new(InspectRange {
        state,
        frame,
        start: position,
        end: position + 1,
    })
    .apply(&mut engine)
    .unwrap()
    else {
        panic!("range inspection");
    };
    assert_eq!(&*sources.subtree_roots, &[node]);
    assert_eq!(source.revision(), sources.data_revision);
    assert_ne!(source.revision(), revisions.data);
    assert_eq!(
        Resource { source, node }.path().unwrap(),
        captured.path().unwrap()
    );
    assert_ne!(
        Resource {
            source: engine.source().clone(),
            node
        }
        .path()
        .unwrap(),
        captured.path().unwrap()
    );
}

#[test]
fn t_selection_preparation_locks_pending_sources_before_the_next_owner_action() {
    let (mut engine, state, _, branch) = fixture();
    engine
        .apply_batch(Batch {
            base_revision: engine.source().revision(),
            operations: vec![Operation::Update {
                node: branch.into(),
                patch: NodePatch {
                    completeness: Some(Completeness::Partial),
                    ..NodePatch::default()
                },
            }],
        })
        .unwrap();
    let excluded = engine.source().id("excluded").unwrap();
    for (node, action) in [
        (branch, SelectAction::Select),
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
    let Reply::Locked { token, .. } = Box::new(PrepareSelection { state })
        .apply(&mut engine)
        .unwrap()
    else {
        panic!("pending selection must lock");
    };
    assert_eq!(
        engine
            .dispatch(state, Command::ClearSelection, Context::default())
            .unwrap_err()
            .code,
        ErrorCode::Busy
    );
    engine.unlock_selection(state, token).unwrap();
    engine
        .dispatch(state, Command::ClearSelection, Context::default())
        .unwrap();
    let Reply::Inspected {
        source, sources, ..
    } = Box::new(PrepareSelection { state })
        .apply(&mut engine)
        .unwrap()
    else {
        panic!("complete selection must not lock");
    };
    assert!(sources.summary.is_empty());
    assert_eq!(sources.data_revision, source.revision());
    assert!(engine.states[&state].task.is_none());
}
