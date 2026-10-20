//! Support shared by Treeview tests and by tests of its providers.

use super::runtime::Listener;
use super::*;
use crate::test_support::eventually;
use std::sync::{Arc, mpsc};

/// A root branch with `count` leaves `n{index}` labelled `node-{index:05}`.
pub(super) fn records(count: usize) -> Vec<Record> {
    let mut records = vec![Record::new("root", NodeData::branch("root"))];
    records.extend((0..count).map(|index| Record {
        key: format!("n{index}").into(),
        parent: Some("root".into()),
        data: NodeData::leaf(format!("node-{index:05}")),
        completeness: None,
    }));
    records
}

/// An engine holding [`records`] and a default state over the root's children.
pub(super) fn fixture(count: usize) -> (Engine, u64, NodeId) {
    let mut engine = Engine::new(Limits::default()).unwrap();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records: records(count),
        })
        .unwrap();
    let root = engine.source.id("root").unwrap();
    let state = engine
        .create_state(Root::ChildrenOf(root), DisplayOptions::default())
        .unwrap();
    (engine, state, root)
}

/// `root/{src/lib/文.lua, README}` with two ancestry-text lists, over the children of `root` and of
/// `src`.
pub(super) fn ancestry_fixture() -> (Engine, u64, u64) {
    let mut engine = Engine::new(Limits::default()).unwrap();
    let records = [
        ("root", None, "root", true),
        ("src", Some("root"), "src", true),
        ("lib", Some("src"), "lib", true),
        ("a", Some("lib"), "文.lua", false),
        ("readme", Some("root"), "README", false),
    ]
    .into_iter()
    .map(|(key, parent, label, branch)| Record {
        key: key.into(),
        parent: parent.map(Into::into),
        data: if branch {
            NodeData::branch(label)
        } else {
            NodeData::leaf(label)
        },
        completeness: None,
    })
    .collect();
    engine
        .import(Import {
            base_revision: engine.source.revision(),
            scope: DataScope::Forest,
            records,
        })
        .unwrap();
    let options = DisplayOptions {
        mode: Mode::List,
        list_text: ListText::Ancestry,
        ..DisplayOptions::default()
    };
    let outer = engine
        .create_state(
            Root::ChildrenOf(engine.source.id("root").unwrap()),
            options.clone(),
        )
        .unwrap();
    let inner = engine
        .create_state(Root::ChildrenOf(engine.source.id("src").unwrap()), options)
        .unwrap();
    (engine, outer, inner)
}

/// Applies `operations` as one batch at the current source revision.
pub(super) fn apply(engine: &mut Engine, operations: Vec<Operation>) -> Reply {
    engine
        .apply_batch(Batch {
            base_revision: engine.source.revision(),
            operations,
        })
        .unwrap()
}

/// Projects every state and returns the frame of `state`.
pub(super) fn project(engine: &mut Engine, state: u64) -> Arc<Snapshot> {
    for (_, result) in engine.project() {
        result.unwrap();
    }
    engine.snapshot(state).unwrap()
}

/// Sets the display options of `state` at its current revision.
pub(super) fn set_display(engine: &mut Engine, state: u64, display: DisplayOptions) -> Reply {
    let expected = engine.states[&state].state.revision;
    engine
        .dispatch(
            state,
            Command::SetDisplay(display),
            Context {
                expected_state: Some(expected),
                ..Context::default()
            },
        )
        .unwrap()
}

pub(super) fn set_expanded(
    engine: &mut Engine,
    state: u64,
    nodes: &[NodeId],
    value: bool,
    scope: Scope,
) -> Reply {
    engine
        .dispatch(
            state,
            Command::SetExpanded {
                targets: Targets::Nodes(nodes.into()),
                value,
                scope,
            },
            Context::default(),
        )
        .unwrap()
}

pub(super) fn select(
    engine: &mut Engine,
    state: u64,
    nodes: &[NodeId],
    action: SelectAction,
    scope: Scope,
) -> Reply {
    engine
        .dispatch(
            state,
            Command::Select {
                targets: Targets::Nodes(nodes.into()),
                action,
                scope,
            },
            Context::default(),
        )
        .unwrap()
}

/// Asserts that the incremental frame of `state` equals a full rebuild from the same source and state.
pub(super) fn assert_projection(engine: &Engine, state: u64) {
    let frame = engine.snapshot(state).unwrap();
    let mut state = engine.states[&state].state.clone();
    let full = Snapshot::build(
        engine.source.clone(),
        &mut state,
        None,
        false,
        Arc::new([]),
        engine.commit,
    )
    .unwrap();
    assert_eq!(frame.len(), full.len());
    for (at, (actual, expected)) in frame.rows.iter().zip(full.rows.iter()).enumerate() {
        assert!(
            actual.same_layout(expected),
            "row {at}: {actual:?} != {expected:?}"
        );
        assert_eq!(actual.connector_last, expected.connector_last, "row {at}");
        assert!(Arc::ptr_eq(&actual.label, &expected.label), "row {at}");
    }
    assert_eq!(frame.last_root, full.last_root);
    for (id, children) in full.matched_children.iter() {
        assert_eq!(
            frame
                .matched_children
                .get(id)
                .map(|value| value.iter().copied().collect::<Vec<_>>()),
            Some(children.iter().copied().collect::<Vec<_>>()),
            "cached matches for {id:?}"
        );
    }
    let mut actual = frame.needed_children.to_vec();
    let mut expected = full.needed_children.to_vec();
    actual.sort();
    expected.sort();
    assert_eq!(actual, expected);
    /* Independent ancestry builders own different prefix allocations. Compare
     * their rendered text, while still checking label ownership above. */
    if frame.ancestry_text() {
        for (at, (actual, expected)) in lines(frame).iter().zip(lines(Arc::new(full))).enumerate() {
            assert_eq!(*actual, expected, "row {at}");
        }
    }
}

/// The rendered text of every row.
pub(super) fn lines(frame: Arc<Snapshot>) -> Vec<String> {
    let plan = RenderPlan::new(None, frame.clone(), None, RenderContext::default(), false).unwrap();
    let mut lines = Vec::new();
    let mut at = 0;
    while at < frame.len() {
        let (chunk, next) = plan
            .lines(at, (at + 512).min(frame.len()), 1024 * 1024)
            .unwrap();
        lines.extend(chunk);
        at = next;
    }
    lines
}

/// `body` after applying the splices of `plan`.
pub(super) fn apply_plan(mut body: Vec<String>, plan: &RenderPlan) -> Vec<String> {
    for splice in plan.splices.iter().rev() {
        let mut text = Vec::new();
        let mut at = splice.target_start;
        while at < splice.target_end {
            let (chunk, next) = plan
                .lines(at, (at + 512).min(splice.target_end), 1024 * 1024)
                .unwrap();
            text.extend(chunk);
            at = next;
        }
        body.splice(splice.old_start..splice.old_end, text);
    }
    body
}

/// Keeps a listener registered with a data handle while alive.
pub(crate) struct Listening {
    _listener: Arc<dyn Listener>,
}

/// Calls `wake` whenever `data` wakes its listeners, until the returned value is dropped.
pub(crate) fn listen(data: &DataHandle, wake: impl Fn() + Send + Sync + 'static) -> Listening {
    struct OnWake<F>(F);
    impl<F: Fn() + Send + Sync> Listener for OnWake<F> {
        fn wake(&self) {
            (self.0)()
        }
        fn close(&self) {}
        fn is_closed(&self) -> bool {
            false
        }
    }
    let listener: Arc<dyn Listener> = Arc::new(OnWake(wake));
    data.listen(&listener).unwrap();
    Listening {
        _listener: listener,
    }
}

/// Parks the engine in a native action until the returned sender sends or drops; returns once it is
/// parked, with the action's ticket.
pub(crate) fn hold(data: &DataHandle) -> (Ticket, mpsc::Sender<()>) {
    struct Hold(mpsc::Sender<()>, mpsc::Receiver<()>);
    impl NativeAction for Hold {
        fn bytes(&self) -> usize {
            0
        }
        fn apply(self: Box<Self>, _: &mut Engine) -> Result<Reply> {
            let _ = self.0.send(());
            let _ = self.1.recv();
            Ok(Reply::NoChange)
        }
    }
    let (entered, parked) = mpsc::channel();
    let (release, held) = mpsc::channel();
    let ticket = data.submit(Action::Native(Box::new(Hold(entered, held))));
    eventually(|| parked.try_recv().ok());
    (ticket, release)
}
