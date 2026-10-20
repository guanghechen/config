use super::super::data::{NodeRef, Operation, Position};
use super::super::state::SelectAction;
use super::super::test_support::*;
use super::super::*;
use super::*;
use std::sync::Arc;

/// `r/{a/b/c, z}` and a compressed state over the children of `r`.
fn compressed_chain() -> (Arc<Source>, State) {
    let mut source = Source::empty().unwrap();
    for (key, parent, branch) in [
        ("r", None, true),
        ("a", Some("r"), true),
        ("b", Some("a"), true),
        ("c", Some("b"), false),
        ("z", Some("r"), false),
    ] {
        let mut data = if branch {
            NodeData::branch(key)
        } else {
            NodeData::leaf(key)
        };
        data.foldable = branch;
        source
            .apply(
                &Operation::Insert {
                    key: key.into(),
                    parent: parent.map(NodeRef::from),
                    position: Position::Last,
                    data,
                    completeness: Completeness::Complete,
                },
                Revision(1),
                &Limits::default(),
                None,
            )
            .unwrap();
    }
    let root = source.id("r").unwrap();
    let mut state = State::new(
        &source,
        Root::ChildrenOf(root),
        DisplayOptions {
            compress: true,
            ..DisplayOptions::default()
        },
    )
    .unwrap();
    state
        .set_expanded(&source, &[root], true, Scope::Subtree)
        .unwrap();
    (Arc::new(source), state)
}

#[test]
fn t_adjacent_leaves_follow_the_frame_order_and_skip_collapsed_branches() {
    let (source, mut state) = compressed_chain();
    let open = Snapshot::build(
        source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        Revision(1),
    )
    .unwrap();
    assert_eq!(open.adjacent_leaf(None, true), Some(1));
    assert_eq!(open.adjacent_leaf(None, false), Some(2));
    assert_eq!(open.adjacent_leaf(Some(0), true), Some(1));
    assert_eq!(open.adjacent_leaf(Some(1), false), None);
    assert_eq!(open.adjacent_leaf(Some(2), false), Some(1));
    assert_eq!(open.adjacent_leaf(Some(2), true), None);
    assert_eq!(open.adjacent_leaf(Some(usize::MAX), false), None);
    state
        .set_expanded(&source, &[source.id("a").unwrap()], false, Scope::SelfOnly)
        .unwrap();
    let closed = Snapshot::build(
        source.clone(),
        &mut state,
        Some(&open),
        false,
        Arc::new([]),
        Revision(2),
    )
    .unwrap();
    assert_eq!(closed.adjacent_leaf(None, true), Some(1));
    assert_eq!(closed.row(1).unwrap().id, source.id("z").unwrap());
    assert_eq!(closed.adjacent_leaf(Some(1), false), None);
    assert_eq!(
        open.row(open.adjacent_leaf(None, true).unwrap())
            .unwrap()
            .id,
        source.id("c").unwrap()
    );
    state.display.mode = Mode::List;
    let list = Snapshot::build(
        source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        Revision(3),
    )
    .unwrap();
    assert_eq!(
        list.row(list.adjacent_leaf(None, true).unwrap())
            .unwrap()
            .id,
        source.id("c").unwrap()
    );
    state.root = Root::Forest(Arc::new([]));
    let empty =
        Snapshot::build(source, &mut state, None, false, Arc::new([]), Revision(4)).unwrap();
    assert_eq!(empty.adjacent_leaf(None, true), None);
    assert_eq!(empty.adjacent_leaf(None, false), None);
}

#[test]
fn t_list_branch_suffix_is_matched_rendered_and_accounted_without_changing_source_labels() {
    let (source, mut state) = compressed_chain();
    state.display = DisplayOptions {
        mode: Mode::List,
        list_depth: Some(0),
        branch_suffix: "/".into(),
        pattern: "^a/$".into(),
        regex: true,
        ..DisplayOptions::default()
    };
    let first = Snapshot::build(
        source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        Revision(1),
    )
    .unwrap();
    assert_eq!(first.len(), 1);
    let row = &first.rows(0, 1).unwrap()[0];
    assert_eq!(row.label, "a/");
    assert_eq!(row.matches, [(0, 2)]);
    assert!(row.row.label_payload.is_some());
    assert_eq!(
        source
            .node(source.id("a").unwrap())
            .unwrap()
            .data
            .label
            .as_ref(),
        "a"
    );
    state.display.pattern = "".into();
    state.display.branch_suffix = "中/".into();
    let before = Snapshot::build(
        source.clone(),
        &mut state,
        Some(&first),
        false,
        Arc::new([]),
        Revision(2),
    )
    .unwrap();
    state.display.branch_suffix = "".into();
    let after = Snapshot::build(
        source,
        &mut state,
        Some(&before),
        false,
        Arc::new([]),
        Revision(3),
    )
    .unwrap();
    let context = super::super::render::RenderContext::default();
    let plan = super::super::render::RenderPlan::new(
        Some(Arc::new(before)),
        Arc::new(after),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(plan.lines(0, 2, 1024).unwrap().0, ["  a", "  z"]);
    assert_eq!(plan.work.written_rows, 1);
}

#[test]
fn t_bounded_list_filters_only_its_scope_and_keeps_context_identity() {
    let (source, mut state) = compressed_chain();
    state.display = DisplayOptions {
        mode: Mode::List,
        list_depth: Some(0),
        context_label: Some("../".into()),
        ..DisplayOptions::default()
    };
    let build = |state: &mut State, before: Option<&Snapshot>| {
        Snapshot::build(
            source.clone(),
            state,
            before,
            false,
            Arc::new([]),
            Revision(1),
        )
        .unwrap()
    };
    let frame = build(&mut state, None);
    assert_eq!(
        frame
            .rows(0, frame.len())
            .unwrap()
            .iter()
            .map(|row| row.label.as_str())
            .collect::<Vec<_>>(),
        ["../", "a", "z"]
    );
    assert_eq!(frame.row(0).unwrap().id, source.id("r").unwrap());
    assert!(state.demands_children(&source, source.id("r").unwrap()));
    assert!(!state.demands_children(&source, source.id("a").unwrap()));
    assert_eq!(frame.visited_nodes, 2);
    state.display.pattern = "c".into();
    assert_eq!(build(&mut state, Some(&frame)).len(), 0);
    state.display.pattern = "../".into();
    let filtered = build(&mut state, Some(&frame));
    assert_eq!(filtered.len(), 1);
    assert_eq!(filtered.rows(0, 1).unwrap()[0].matches, [(0, 3)]);
    state.display.pattern = "".into();
    state.display.context_label = Some("up".into());
    let changed = build(&mut state, Some(&frame));
    let context = super::super::render::RenderContext::default();
    let plan = super::super::render::RenderPlan::new(
        Some(Arc::new(frame)),
        Arc::new(changed),
        Some(&context),
        context.clone(),
        false,
    )
    .unwrap();
    assert_eq!(plan.lines(0, 1, 1024).unwrap().0, ["  up"]);
    assert!(plan.work.written_rows > 0);
}

#[test]
fn t_folded_navigation_uses_visible_parents_and_direct_children() {
    let (source, mut state) = compressed_chain();
    let frame = Snapshot::build(
        source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        Revision(1),
    )
    .unwrap();
    assert_eq!(
        frame
            .rows(0, frame.len())
            .unwrap()
            .iter()
            .map(|row| row.label.as_str())
            .collect::<Vec<_>>(),
        ["a/b", "c", "z"]
    );
    assert_eq!(frame.position(source.id("a").unwrap()), Some(0));
    assert_eq!(frame.navigate(0, Direction::LastChildOrSibling), Some(1));
    assert_eq!(frame.navigate(1, Direction::Parent), Some(0));
    assert_eq!(frame.navigate(2, Direction::LastChildOrSibling), Some(2));
}

#[test]
fn t_list_filters_existing_descendants_and_sorts_across_parents() {
    let (source, mut state) = compressed_chain();
    state.display.mode = Mode::List;
    state.display.pattern = "c".into();
    let frame = Snapshot::build(
        source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        Revision(1),
    )
    .unwrap();
    assert_eq!(frame.len(), 1);
    assert_eq!(frame.row(0).unwrap().id, source.id("c").unwrap());
    assert_eq!(frame.navigate(0, Direction::Parent), None);
    state.display.mode = Mode::Tree;
    let frame = Snapshot::build(
        source.clone(),
        &mut state,
        Some(&frame),
        false,
        Arc::new([]),
        Revision(2),
    )
    .unwrap();
    assert_eq!(
        frame
            .rows(0, frame.len())
            .unwrap()
            .iter()
            .map(|row| row.label.as_str())
            .collect::<Vec<_>>(),
        ["a/b", "c"]
    );
}

#[test]
fn t_selection_boundaries_split_chains_and_old_frames_keep_their_mapping() {
    let (source, mut state) = compressed_chain();
    let old = Snapshot::build(
        source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        Revision(1),
    )
    .unwrap();
    state
        .select(
            &source,
            &[source.id("b").unwrap()],
            SelectAction::Select,
            Scope::Subtree,
        )
        .unwrap();
    let new = Snapshot::build(
        source.clone(),
        &mut state,
        Some(&old),
        false,
        Arc::new([]),
        Revision(2),
    )
    .unwrap();
    assert_eq!(old.len(), 3);
    assert_eq!(new.len(), 4);
    assert!(new.layout_revision > old.layout_revision);
    assert!(!old.rows(0, 1).unwrap()[0].marked);
    assert!(new.rows(1, 2).unwrap()[0].full);
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
            // Regex ranges list every occurrence; fuzzy ranges are one alignment per label.
            Command::SetDisplay(DisplayOptions {
                pattern: "a".into(),
                regex: true,
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
fn t_guide_path_clips_segments_and_stops_at_each_forest_root() {
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: [
                ("root", None, true),
                ("prior", Some("root"), true),
                ("prior-child", Some("prior"), false),
                ("src", Some("root"), true),
                ("lib", Some("src"), true),
                ("helper", Some("lib"), true),
                ("nested", Some("helper"), false),
                ("target", Some("lib"), false),
                ("other", Some("src"), false),
                ("docs", Some("root"), false),
            ]
            .into_iter()
            .map(|(key, parent, branch)| Record {
                key: key.into(),
                parent: parent.map(Into::into),
                data: if branch {
                    NodeData::branch(key)
                } else {
                    NodeData::leaf(key)
                },
                completeness: None,
            })
            .collect(),
        })
        .unwrap();
    let root = engine.source.id("root").unwrap();
    let state = engine
        .create_state(Root::ChildrenOf(root), DisplayOptions::default())
        .unwrap();
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    let frame = project(&mut engine, state);
    let segments = vec![
        GuideSegment {
            first: 0,
            last: 3,
            depth: 0,
        },
        GuideSegment {
            first: 3,
            last: 4,
            depth: 1,
        },
        GuideSegment {
            first: 4,
            last: 7,
            depth: 2,
        },
    ];
    assert_eq!(frame.guide_path(6, 0, 9).unwrap(), segments);
    assert_eq!(
        frame.guide_path(6, 5, 9).unwrap(),
        vec![GuideSegment {
            first: 5,
            last: 7,
            depth: 2
        }]
    );
    assert!(frame.guide_path(6, 0, 5).unwrap().is_empty());
    assert!(frame.guide_path(9, 0, 9).unwrap().is_empty());
    assert!(frame.guide_path(0, 0, 0).unwrap().is_empty());
    assert!(frame.guide_path(6, 0, 10).is_err());

    let roots = ["prior", "src", "docs"].map(|key| engine.source.id(key).unwrap());
    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(roots.into())),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap();
    let forest = project(&mut engine, state);
    let mut forest_segments = segments.clone();
    forest_segments[0].first = 2;
    assert_eq!(forest.guide_path(6, 0, 9).unwrap(), forest_segments);
    assert_eq!(
        frame.guide_path(6, 0, 9).unwrap(),
        segments,
        "retained frame owns its path"
    );

    let lib = engine.source.id("lib").unwrap();
    set_expanded(&mut engine, state, &[lib], false, Scope::SelfOnly);
    let folded = project(&mut engine, state);
    assert_eq!(
        folded.guide_path(3, 0, folded.len()).unwrap(),
        forest_segments[..2]
    );
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            mode: Mode::List,
            ..DisplayOptions::default()
        },
    );
    let list = project(&mut engine, state);
    assert!(list.guide_path(0, 0, list.len()).unwrap().is_empty());
}

#[test]
fn t_guide_path_follows_compressed_display_parents() {
    let (mut engine, state, _) = ancestry_fixture();
    for key in ["src", "lib"] {
        apply(
            &mut engine,
            vec![Operation::Update {
                node: key.into(),
                patch: NodePatch {
                    foldable: Some(true),
                    ..NodePatch::default()
                },
            }],
        );
    }
    set_display(
        &mut engine,
        state,
        DisplayOptions {
            compress: true,
            ..DisplayOptions::default()
        },
    );
    let root = engine.source.id("root").unwrap();
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    let frame = project(&mut engine, state);
    assert_eq!(frame.len(), 3);
    assert_eq!(
        frame.guide_path(1, 0, 3).unwrap(),
        vec![
            GuideSegment {
                first: 0,
                last: 1,
                depth: 0
            },
            GuideSegment {
                first: 1,
                last: 2,
                depth: 1
            },
        ]
    );
}

#[test]
fn t_guide_path_bounds_wide_and_deep_viewports() {
    let (engine, state, _) = fixture(50_000);
    let frame = engine.snapshot(state).unwrap();
    assert_eq!(
        frame.guide_path(49_990, 49_950, 50_000).unwrap(),
        vec![GuideSegment {
            first: 49_950,
            last: 49_991,
            depth: 0
        },]
    );
    assert_eq!(
        frame.guide_path(0, 0, 513).unwrap_err().code,
        ErrorCode::ResourceLimit
    );

    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: (0usize..10_000)
                .map(|index| Record {
                    key: format!("n{index}").into(),
                    parent: index
                        .checked_sub(1)
                        .map(|parent| NodeRef::Key(format!("n{parent}").into())),
                    data: NodeData::branch("branch"),
                    completeness: None,
                })
                .collect(),
        })
        .unwrap();
    let root = engine.source.id("n0").unwrap();
    let state = engine
        .create_state(Root::Forest(vec![root].into()), DisplayOptions::default())
        .unwrap();
    set_expanded(&mut engine, state, &[root], true, Scope::Subtree);
    let frame = project(&mut engine, state);
    let segments = frame.guide_path(9_999, 9_950, 10_000).unwrap();
    assert_eq!(segments.len(), 50);
    for (index, segment) in segments.iter().enumerate() {
        assert_eq!(
            *segment,
            GuideSegment {
                first: 9_950 + index,
                last: 9_951 + index,
                depth: 9_950 + index
            }
        );
    }
}

#[test]
fn t_all_marked_preserves_inheritance_and_immutable_frame_membership() {
    let (mut engine, state, _) = ancestry_fixture();
    let [root, src, lib, a, readme] =
        ["root", "src", "lib", "a", "readme"].map(|key| engine.source.id(key).unwrap());
    let empty = project(&mut engine, state);
    assert!(empty.all_marked(&[]).unwrap());
    assert!(!empty.all_marked(&[a]).unwrap());
    assert!(!empty.all_marked(&[a, a]).unwrap());

    select(
        &mut engine,
        state,
        &[root],
        SelectAction::Select,
        Scope::Subtree,
    );
    let selected = project(&mut engine, state);
    assert!(selected.all_marked(&[root, src, lib, a, readme]).unwrap());
    assert!(selected.all_marked(&[a, a]).unwrap());
    assert!(!empty.all_marked(&[a]).unwrap());

    select(
        &mut engine,
        state,
        &[lib],
        SelectAction::Deselect,
        Scope::SelfOnly,
    );
    let mixed = project(&mut engine, state);
    assert!(!mixed.all_marked(&[lib]).unwrap());
    assert!(!mixed.all_marked(&[a, lib]).unwrap());
    assert!(!mixed.all_marked(&[lib, a]).unwrap());
    assert!(mixed.all_marked(&[src, a, readme]).unwrap());

    for display in [
        DisplayOptions::default(),
        DisplayOptions {
            mode: Mode::List,
            filter: Some(Arc::new([(readme, 0)].into_iter().collect())),
            ..DisplayOptions::default()
        },
    ] {
        set_display(&mut engine, state, display);
        let hidden = project(&mut engine, state);
        assert_eq!(hidden.position(a), None);
        assert!(hidden.all_marked(&[root, src, a, readme]).unwrap());
        assert!(!hidden.all_marked(&[lib, a]).unwrap());
    }

    engine
        .dispatch(state, Command::ClearSelection, Context::default())
        .unwrap();
    let cleared = project(&mut engine, state);
    assert!(!cleared.all_marked(&[a, readme]).unwrap());
    assert!(selected.all_marked(&[lib, a]).unwrap());
    assert!(mixed.all_marked(&[a]).unwrap());
    apply(&mut engine, vec![Operation::Remove { node: a.into() }]);
    let removed = project(&mut engine, state);
    let error = removed.all_marked(&[readme, a]).unwrap_err();
    assert_eq!(error.code, ErrorCode::MissingNode);
    assert_eq!(error.node, Some(a));
    assert!(selected.all_marked(&[a]).unwrap());
    assert!(mixed.all_marked(&[a, readme]).unwrap());

    let missing = NodeId(u64::MAX);
    for frame in [empty, selected, mixed, cleared, removed] {
        for nodes in [vec![missing], vec![readme, missing], vec![missing, readme]] {
            let error = frame.all_marked(&nodes).unwrap_err();
            assert_eq!(error.code, ErrorCode::MissingNode);
            assert_eq!(error.node, Some(missing));
        }
    }
}
