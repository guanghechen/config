//! Release-mode scaling measurements of the Treeview engine; each prints its samples and asserts only
//! correctness. Run one with
//! `cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib <name> -- --exact --ignored --nocapture`.

use super::test_support::*;
use super::*;
use crate::test_support::percentile;
use std::sync::Arc;
use std::time::Instant;

#[test]
#[ignore = "explicit release-mode unrelated-subtree scaling measurement"]
fn t_ancestry_unrelated_subtree_performance() {
    let (mut engine, initial, root) = fixture(50_000);
    engine.release_state(initial);
    let mut scopes = Vec::new();
    for i in 0..6 {
        let key = format!("scope{i}");
        apply(
            &mut engine,
            vec![
                Operation::Insert {
                    key: key.clone().into(),
                    parent: None,
                    position: Position::Last,
                    data: NodeData::branch(key.as_str()),
                    completeness: Completeness::Complete,
                },
                Operation::Insert {
                    key: format!("file{i}").into(),
                    parent: Some(key.as_str().into()),
                    position: Position::Last,
                    data: NodeData::leaf("file"),
                    completeness: Completeness::Complete,
                },
            ],
        );
        let id = engine.source.id(&key).unwrap();
        scopes.push(
            engine
                .create_state(
                    if i % 2 == 0 {
                        Root::ChildrenOf(id)
                    } else {
                        Root::Forest(vec![id].into())
                    },
                    DisplayOptions {
                        mode: Mode::List,
                        pattern: "file".into(),
                        ..DisplayOptions::default()
                    },
                )
                .unwrap(),
        );
    }
    for style in [ListText::Label, ListText::Ancestry] {
        for &state in &scopes {
            set_display(
                &mut engine,
                state,
                DisplayOptions {
                    mode: Mode::List,
                    pattern: "file".into(),
                    list_text: style,
                    ..DisplayOptions::default()
                },
            );
        }
        project(&mut engine, scopes[0]);
        let mut samples = Vec::new();
        for i in 0..102 {
            let old: Vec<_> = scopes
                .iter()
                .map(|id| engine.snapshot(*id).unwrap())
                .collect();
            let start = Instant::now();
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: root.into(),
                    patch: NodePatch {
                        label: Some(format!("outside-{i}").into()),
                        ..NodePatch::default()
                    },
                }],
            );
            project(&mut engine, scopes[0]);
            for (id, old) in scopes.iter().zip(old) {
                let current = engine.snapshot(*id).unwrap();
                assert_eq!(current.len(), 1);
                assert!(old.rows.same_version(&current.rows));
                assert_eq!(old.text_revision, current.text_revision);
            }
            if i >= 2 {
                samples.push(start.elapsed().as_secs_f64() * 1000.0);
            }
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "unrelated_subtree: style={style:?}, outside=50001, states=6, n=100, p50_ms={:.3}, p95_ms={:.3}",
            percentile(&samples, 0.5),
            percentile(&samples, 0.95)
        );
    }
}

#[test]
#[ignore = "explicit release-mode Forest boundary scaling measurement"]
fn t_ancestry_forest_leaf_performance() {
    let mut engine = Engine::new(Limits::default()).unwrap();
    let (depth, width) = (1000, 2000);
    let mut records: Vec<_> = (0..depth)
        .map(|i| Record {
            key: format!("p{i}").into(),
            parent: (i > 0).then(|| format!("p{}", i - 1).as_str().into()),
            data: NodeData::branch("p"),
            completeness: None,
        })
        .collect();
    records.extend((0..width).map(|i| Record {
        key: format!("f{i}").into(),
        parent: Some(format!("p{}", depth - 1).as_str().into()),
        data: NodeData::leaf("file"),
        completeness: None,
    }));
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let roots: Arc<[_]> = (0..width)
        .map(|i| engine.source.id(&format!("f{i}")).unwrap())
        .collect();
    let leaf = roots[width / 2];
    let state = engine
        .create_state(
            Root::Forest(roots),
            DisplayOptions {
                mode: Mode::List,
                ..DisplayOptions::default()
            },
        )
        .unwrap();
    for list_text in [ListText::Label, ListText::Ancestry] {
        set_display(
            &mut engine,
            state,
            DisplayOptions {
                mode: Mode::List,
                list_text,
                ..DisplayOptions::default()
            },
        );
        project(&mut engine, state);
        let mut samples = Vec::new();
        for i in 0..102 {
            let old = engine.snapshot(state).unwrap();
            let start = Instant::now();
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: leaf.into(),
                    patch: NodePatch {
                        label: Some(format!("file-{i}").into()),
                        ..NodePatch::default()
                    },
                }],
            );
            let current = project(&mut engine, state);
            assert!(old.text_roots.same_version(&current.text_roots));
            let context = RenderContext::default();
            let plan = RenderPlan::new(Some(old), current, Some(&context), context.clone(), false)
                .unwrap();
            assert_eq!(plan.work.written_rows, 1);
            assert_eq!(plan.work.compared_rows, 1);
            drop(plan);
            if i >= 2 {
                samples.push(start.elapsed().as_secs_f64() * 1000.0);
            }
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "forest_leaf: style={list_text:?}, roots={width}, excluded_depth={depth}, n=100, p50_ms={:.3}, p95_ms={:.3}",
            percentile(&samples, 0.5),
            percentile(&samples, 0.95)
        );
    }
}

#[test]
#[ignore = "explicit release-mode ancestry scaling measurement"]
fn t_ancestry_deep_rename_performance() {
    for count in [1_000, 2_000, 4_000, 8_000] {
        let mut engine = Engine::new(Limits::default()).unwrap();
        engine
            .import(Import {
                base_revision: engine.source.revision(),
                scope: DataScope::Forest,
                records: (0..count)
                    .map(|i| Record {
                        key: format!("n{i}").into(),
                        parent: (i != 0).then(|| format!("n{}", i - 1).as_str().into()),
                        data: NodeData::branch("x"),
                        completeness: None,
                    })
                    .collect(),
            })
            .unwrap();
        let root = engine.source.id("n0").unwrap();
        let state = engine
            .create_state(
                Root::Forest(vec![root].into()),
                DisplayOptions {
                    mode: Mode::List,
                    list_text: ListText::Ancestry,
                    ..DisplayOptions::default()
                },
            )
            .unwrap();
        let mut samples = Vec::new();
        for i in 0..10 {
            let previous = engine.snapshot(state).unwrap();
            let start = Instant::now();
            apply(
                &mut engine,
                vec![Operation::Update {
                    node: root.into(),
                    patch: NodePatch {
                        label: Some(format!("root-{i}").into()),
                        ..NodePatch::default()
                    },
                }],
            );
            let current = project(&mut engine, state);
            let context = RenderContext::default();
            let plan = RenderPlan::new(
                Some(previous),
                current,
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, count);
            drop(plan);
            samples.push(start.elapsed().as_secs_f64() * 1_000.0);
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "ancestry_deep_rename: nodes={count}, n=10, p50_ms={:.3}, p95_ms={:.3}, retained_bytes={}",
            percentile(&samples, 0.5),
            percentile(&samples, 0.95),
            engine.memory.used()
        );
        let leaf = engine.source.id(&format!("n{}", count - 1)).unwrap();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: leaf.into(),
                patch: NodePatch {
                    label: Some("target".into()),
                    ..NodePatch::default()
                },
            }],
        );
        set_display(
            &mut engine,
            state,
            DisplayOptions {
                mode: Mode::List,
                list_text: ListText::Ancestry,
                pattern: "target".into(),
                ..DisplayOptions::default()
            },
        );
        project(&mut engine, state);
        let mut samples = Vec::new();
        for i in 0..10 {
            let label = if i % 2 == 0 { "y" } else { "x" };
            let operations = (0..count - 1)
                .map(|i| Operation::Update {
                    node: format!("n{i}").as_str().into(),
                    patch: NodePatch {
                        label: Some(label.into()),
                        ..NodePatch::default()
                    },
                })
                .collect();
            let old = engine.snapshot(state).unwrap();
            let expected_old = lines(old.clone());
            let start = Instant::now();
            apply(&mut engine, operations);
            let current = project(&mut engine, state);
            let context = RenderContext::default();
            let plan = RenderPlan::new(
                Some(old.clone()),
                current.clone(),
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, 1);
            let expected = vec![format!("  {}target", format!("{label}/").repeat(count - 1))];
            assert_eq!(apply_plan(expected_old.clone(), &plan), expected);
            assert_eq!(lines(current), expected);
            drop(plan);
            assert_eq!(lines(old), expected_old);
            samples.push(start.elapsed().as_secs_f64() * 1000.0);
        }
        samples.sort_by(f64::total_cmp);
        println!(
            "ancestry_filtered_batch: nodes={count}, visible=1, n=10, p50_ms={:.3}, p95_ms={:.3}",
            percentile(&samples, 0.5),
            percentile(&samples, 0.95)
        );
    }
}

#[test]
#[ignore = "explicit release-mode wide-tree and task scaling measurement"]
fn t_filetree_support_performance() {
    let (mut engine, tree, root) = fixture(50_000);
    let options = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        ..DisplayOptions::default()
    };
    let list = engine
        .create_state(Root::ChildrenOf(root), options.clone())
        .unwrap();
    let forest = engine
        .create_state(Root::Forest(vec![root].into()), options)
        .unwrap();
    let states = [tree, list, forest];
    let leaf = engine.source.id("n25000").unwrap();
    let mut samples = Vec::new();
    for i in 0..110 {
        let previous: Vec<_> = states
            .iter()
            .map(|id| engine.snapshot(*id).unwrap())
            .collect();
        let start = Instant::now();
        apply(
            &mut engine,
            vec![Operation::Update {
                node: leaf.into(),
                patch: NodePatch {
                    label: Some(format!("changed-{i:03}").into()),
                    ..NodePatch::default()
                },
            }],
        );
        project(&mut engine, tree);
        for (id, previous) in states.into_iter().zip(previous) {
            let context = RenderContext::default();
            let plan = RenderPlan::new(
                Some(previous),
                engine.snapshot(id).unwrap(),
                Some(&context),
                context.clone(),
                false,
            )
            .unwrap();
            assert_eq!(plan.work.written_rows, 1);
            assert_eq!(plan.work.compared_rows, 1);
        }
        if i >= 10 {
            samples.push(start.elapsed().as_secs_f64() * 1_000.0);
        }
    }
    samples.sort_by(f64::total_cmp);
    println!(
        "ancestry_wide_leaf: nodes=50000, states=3, n=100, p50_ms={:.3}, p95_ms={:.3}, retained_bytes={}",
        percentile(&samples, 0.5),
        percentile(&samples, 0.95),
        engine.memory.used()
    );

    select(
        &mut engine,
        tree,
        &[root],
        SelectAction::Select,
        Scope::Subtree,
    );
    select(
        &mut engine,
        tree,
        &[root],
        SelectAction::Deselect,
        Scope::SelfOnly,
    );
    let mut prepare = Vec::new();
    for _ in 0..10 {
        let start = Instant::now();
        let Reply::Locked { token, .. } = engine
            .lock_selection(tree, engine.states[&tree].state.selection_revision, None)
            .unwrap()
        else {
            panic!("lock")
        };
        let Reply::Ready { sources, .. } = engine
            .dispatch(
                tree,
                Command::PrepareSources {
                    lock: token,
                    retry: false,
                },
                Context::default(),
            )
            .unwrap()
        else {
            panic!("ready")
        };
        assert_eq!(sources.subtree_roots.len(), 50_000);
        prepare.push(start.elapsed().as_secs_f64() * 1_000.0);
        engine.unlock_selection(tree, token).unwrap();
    }
    prepare.sort_by(f64::total_cmp);
    println!(
        "task_prepare: roots=50000, n=10, p50_ms={:.3}, p95_ms={:.3}",
        percentile(&prepare, 0.5),
        percentile(&prepare, 0.95)
    );

    let Reply::Locked { token, .. } = engine
        .lock_selection(tree, engine.states[&tree].state.selection_revision, None)
        .unwrap()
    else {
        panic!("lock")
    };
    engine
        .dispatch(
            tree,
            Command::PrepareSources {
                lock: token,
                retry: false,
            },
            Context::default(),
        )
        .unwrap();
    let mut unrelated = Vec::new();
    for i in 0..100 {
        let start = Instant::now();
        apply(
            &mut engine,
            vec![Operation::Insert {
                key: format!("outside-{i}").into(),
                parent: None,
                position: Position::Last,
                data: NodeData::leaf("outside"),
                completeness: Completeness::Complete,
            }],
        );
        assert!(engine.states[&tree].task.as_ref().unwrap().valid);
        unrelated.push(start.elapsed().as_secs_f64() * 1_000.0);
    }
    unrelated.sort_by(f64::total_cmp);
    println!(
        "task_unrelated_insert: roots=50000, n=100, p50_ms={:.3}, p95_ms={:.3}",
        percentile(&unrelated, 0.5),
        percentile(&unrelated, 0.95)
    );
}

#[test]
#[ignore = "explicit release-mode filter stage measurement"]
fn t_ancestry_filter_performance() {
    let (mut engine, state, root) = fixture(50_000);
    apply(
        &mut engine,
        (0..50_000)
            .map(|i| Operation::Update {
                node: format!("n{i}").as_str().into(),
                patch: NodePatch {
                    label: Some(format!("node-{i:05}{}", "x".repeat(86)).into()),
                    ..NodePatch::default()
                },
            })
            .collect(),
    );
    engine
        .dispatch(
            state,
            Command::SetRoot(Root::Forest(vec![root].into())),
            Context {
                expected_state: Some(engine.states[&state].state.revision),
                ..Context::default()
            },
        )
        .unwrap();
    let mut samples = [Vec::new(), Vec::new(), Vec::new()];
    for index in 0..100 {
        let old = engine.snapshot(state).unwrap();
        set_display(
            &mut engine,
            state,
            DisplayOptions {
                mode: Mode::List,
                list_text: ListText::Ancestry,
                pattern: if index % 2 == 0 { "node-000" } else { "node-" }.into(),
                ..DisplayOptions::default()
            },
        );
        let start = Instant::now();
        let frame = project(&mut engine, state);
        let projection = start.elapsed().as_secs_f64() * 1000.0;
        let start = Instant::now();
        let context = RenderContext::default();
        let plan = RenderPlan::new(
            Some(old),
            frame.clone(),
            Some(&context),
            context.clone(),
            false,
        )
        .unwrap();
        let planning = start.elapsed().as_secs_f64() * 1000.0;
        let start = Instant::now();
        for splice in plan.splices.iter() {
            let mut at = splice.target_start;
            while at < splice.target_end {
                at = plan
                    .write_lines(at, (at + 512).min(splice.target_end), 64 * 1024, |text| {
                        std::hint::black_box(text);
                        Ok(())
                    })
                    .unwrap();
            }
        }
        if index % 2 == 1 {
            for (values, time) in samples.iter_mut().zip([
                projection,
                planning,
                start.elapsed().as_secs_f64() * 1000.0,
            ]) {
                values.push(time);
            }
        }
    }
    for (name, mut values) in ["projection", "plan", "export"].into_iter().zip(samples) {
        values.sort_by(f64::total_cmp);
        println!(
            "ancestry_filter_expand: stage={name}, rows=50000, n=50, p50_ms={:.3}, p95_ms={:.3}",
            percentile(&values, 0.5),
            percentile(&values, 0.95)
        );
    }
}
