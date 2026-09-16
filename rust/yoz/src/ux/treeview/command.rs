use super::model::*;
use super::projection::{Direction, Snapshot};
use super::state::{SelectAction, SelectionSources};
use super::tasks::{CleanupToken, LockToken};
use std::sync::Arc;

#[derive(Clone)]
pub enum Targets {
    Nodes(Arc<[NodeId]>),
    Range {
        frame: Arc<Snapshot>,
        start: usize,
        end: usize,
    },
}

#[derive(Clone, Default)]
pub struct Context {
    pub expected_state: Option<Revision>,
    pub frame: Option<Arc<Snapshot>>,
}

#[derive(Clone)]
pub enum Command {
    SetRoot(Root),
    SetDisplay(DisplayOptions),
    SetExpanded {
        targets: Targets,
        value: bool,
        scope: Scope,
    },
    ToggleExpanded {
        node: NodeId,
        scope: Scope,
    },
    SetCursor(Option<NodeId>),
    Navigate {
        frame: Arc<Snapshot>,
        row: usize,
        direction: Direction,
    },
    Select {
        targets: Targets,
        action: SelectAction,
        scope: Scope,
    },
    ClearSelection,
    InspectSelection,
    PrepareSources(LockToken),
    Unselect {
        lock: LockToken,
        cleanup: CleanupToken,
        successful: Arc<[NodeId]>,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Revisions {
    pub commit: Revision,
    pub data: Revision,
    pub state: Option<Revision>,
    pub selection: Option<Revision>,
}

#[derive(Clone, Debug)]
pub enum Effect {
    NeedChildren {
        token: super::reads::ReadToken,
        sequence: u64,
    },
    CancelChildren {
        token: super::reads::ReadToken,
    },
    Query {
        token: super::query::QueryToken,
        input: super::query::QueryInput,
        sequence: u64,
    },
    CancelQuery {
        token: super::query::QueryToken,
    },
    ViewChanged {
        state: u64,
    },
    RootUnavailable {
        state: u64,
        node: NodeId,
    },
    NodeInvalidated {
        nodes: Arc<[NodeId]>,
    },
    SelectionPending {
        state: u64,
        nodes: Arc<[NodeId]>,
    },
    TaskFailed {
        lock: LockToken,
        error: Error,
    },
}

#[derive(Clone, Debug)]
pub enum Reply {
    Applied {
        revisions: Revisions,
        effects: Arc<[Effect]>,
    },
    NoChange,
    Inspected {
        revisions: Revisions,
        sources: SelectionSources,
    },
    Ready {
        revisions: Revisions,
        sources: SelectionSources,
        cleanup: CleanupToken,
        source: Arc<super::data::Source>,
    },
    Pending {
        revisions: Revisions,
        sources: SelectionSources,
    },
    Locked {
        revisions: Revisions,
        token: LockToken,
    },
    Rejected {
        error: Error,
    },
}

impl From<Error> for Reply {
    fn from(error: Error) -> Self {
        Self::Rejected { error }
    }
}

impl Reply {
    pub(crate) fn into_effects(self) -> Vec<Effect> {
        match self {
            Self::Applied { effects, .. } => effects.to_vec(),
            _ => Vec::new(),
        }
    }
}
