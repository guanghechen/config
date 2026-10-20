use super::super::test_support::*;
use super::super::*;
use std::sync::Arc;

#[test]
fn t_query_replacement_is_distinct_from_children_refresh_and_old_generation_is_stale() {
    let (mut engine, _, root) = fixture(3);
    engine.limits.concurrent_reads = 1;
    let provider = engine
        .create_provider(DataScope::Descendants(root))
        .unwrap();
    let query = engine.create_query(provider).unwrap();
    let Reply::Applied { effects, .. } = engine
        .accept_query(
            query,
            QueryInput {
                pattern: "a".into(),
                ..QueryInput::default()
            },
        )
        .unwrap()
    else {
        panic!("query");
    };
    let old_token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::Query { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    engine
        .accept_query(
            query,
            QueryInput {
                pattern: "ab".into(),
                ..QueryInput::default()
            },
        )
        .unwrap();
    engine
        .accept_query(
            query,
            QueryInput {
                pattern: "a".into(),
                ..QueryInput::default()
            },
        )
        .unwrap();
    assert_eq!(engine.query_work.len(), 1);
    assert_eq!(
        engine
            .query_page(old_token, 1, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
    assert_eq!(engine.source.node(root).unwrap().child_count(), 3);
    let effect = engine.schedule_queries().unwrap().remove(0);
    let Effect::Query { token, .. } = effect else {
        panic!("replacement query");
    };
    assert!(token.generation > old_token.generation);
    let retained = engine.source.id("n0").unwrap();
    let removed = engine.source.id("n1").unwrap();
    engine
        .query_page(
            token,
            1,
            vec![Record::new("n0", NodeData::leaf("current"))],
            false,
        )
        .unwrap();
    assert_eq!(engine.source.id("n0"), Some(retained));
    assert!(!engine.source.contains(removed));
    engine
        .query_page(
            token,
            2,
            vec![Record::new("n1", NodeData::leaf("new occurrence"))],
            true,
        )
        .unwrap();
    assert_ne!(engine.source.id("n1"), Some(removed));
    assert_eq!(
        engine.query_info(query).unwrap().result_generation,
        Some(token.generation)
    );
    assert_eq!(
        engine
            .query_page(token, 2, Vec::new(), true)
            .unwrap_err()
            .code,
        ErrorCode::Stale
    );
}

#[test]
fn t_query_result_origin_outlives_session_and_replaces_by_scope() {
    let (mut engine, state, root) = fixture(0);
    let scope = DataScope::Children(root);
    let provider = engine.create_provider(scope).unwrap();
    let mut previous = None;
    for pattern in ["first", "second"] {
        let session = engine.create_query(provider).unwrap();
        let reply = engine
            .accept_query(
                session,
                QueryInput {
                    pattern: pattern.into(),
                    ..QueryInput::default()
                },
            )
            .unwrap();
        let Reply::Applied { effects, .. } = reply else {
            panic!()
        };
        let token = effects
            .iter()
            .find_map(|effect| match effect {
                Effect::Query { token, .. } => Some(*token),
                _ => None,
            })
            .unwrap();
        engine
            .query_page(
                token,
                1,
                vec![Record::new("result", NodeData::leaf(pattern))],
                true,
            )
            .unwrap();
        engine.release_query(session).unwrap();
        let frame = project(&mut engine, state);
        assert!(frame.queries.is_empty());
        let results = frame.source().query_results().collect::<Vec<_>>();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0, scope);
        assert_eq!(results[0].1.session, session);
        assert_eq!(results[0].1.input.pattern.as_ref(), pattern);
        if let Some(previous) = previous.as_ref() {
            let previous: &Arc<Snapshot> = previous;
            assert_eq!(
                previous
                    .source()
                    .query_results()
                    .next()
                    .unwrap()
                    .1
                    .input
                    .pattern
                    .as_ref(),
                "first"
            );
        }
        previous = Some(frame);
    }
    apply(&mut engine, vec![Operation::Remove { node: root.into() }]);
    assert_eq!(engine.source().query_results().count(), 0);
}

#[test]
fn t_removed_query_anchor_retires_only_its_late_work() {
    let (mut engine, _, root) = fixture(0);
    let provider = engine.create_provider(DataScope::Children(root)).unwrap();
    let session = engine.create_query(provider).unwrap();
    let Reply::Applied { effects, .. } =
        engine.accept_query(session, QueryInput::default()).unwrap()
    else {
        panic!("query");
    };
    let token = effects
        .iter()
        .find_map(|effect| match effect {
            Effect::Query { token, .. } => Some(*token),
            _ => None,
        })
        .unwrap();
    apply(&mut engine, vec![Operation::Remove { node: root.into() }]);
    assert!(engine.query_page(token, 1, Vec::new(), true).is_err());
    assert!(engine.query_work.is_empty());
    engine.schedule_queries().unwrap();
    assert_eq!(
        engine.query_info(session).unwrap().load_state,
        LoadState::Error
    );
}

#[test]
fn t_cancel_query_ends_its_slot_and_old_ack_preserves_the_replacement() {
    let (mut engine, _, root) = fixture(0);
    let provider = engine.create_provider(DataScope::Children(root)).unwrap();
    let session = engine.create_query(provider).unwrap();
    let request = |engine: &mut Engine| {
        let Reply::Applied { effects, .. } =
            engine.accept_query(session, QueryInput::default()).unwrap()
        else {
            panic!("query");
        };
        effects
            .iter()
            .find_map(|effect| match effect {
                Effect::Query { token, .. } => Some(*token),
                _ => None,
            })
            .unwrap()
    };
    let old = request(&mut engine);
    engine
        .query_page(
            old,
            1,
            vec![Record::new("one", NodeData::leaf("one"))],
            false,
        )
        .unwrap();
    engine.cancel_query(session).unwrap();
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Idle
    );
    assert_eq!(
        engine.source.node(root).unwrap().completeness,
        Completeness::Partial
    );
    let new = request(&mut engine);
    engine.query_page(new, 1, Vec::new(), false).unwrap();
    engine.query_cancelled(old).unwrap();
    assert_eq!(
        engine.source.node(root).unwrap().load_state,
        LoadState::Loading
    );
    engine.query_page(new, 2, Vec::new(), true).unwrap();
}
