//! Shared fixtures for unit tests.

use std::rc::Rc;

use crate::model::{
    LayoutKind, LayoutPlan, RenderContext, SessionGroupView, SessionInfo, StatusMode,
    StatusPosition, TmuxSnapshot,
};

/// An attached-style session whose `status` is `on`.
pub fn session(id: &str, name: &str) -> SessionInfo {
    SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        status: "on".to_string(),
        ..SessionInfo::default()
    }
}

/// A status02 snapshot of a 200-column client in session `s` on host `h`.
pub fn snapshot() -> TmuxSnapshot {
    TmuxSnapshot {
        mode: "02".to_string(),
        status: "on".to_string(),
        width: 200,
        current_session_name: "s".to_string(),
        host: "h".to_string(),
        ..TmuxSnapshot::default()
    }
}

pub fn wide_layout() -> LayoutPlan {
    LayoutPlan {
        mode: StatusMode::TopAdaptive,
        position: StatusPosition::Top,
        kind: LayoutKind::Wide,
        rows: 1,
        target_status: "on",
        key: "02:wide".to_string(),
    }
}

/// A one-row context whose group is `sessions`, seen from the snapshot's current session.
pub fn render_context(snapshot: TmuxSnapshot, sessions: Vec<SessionInfo>) -> RenderContext {
    RenderContext {
        group: SessionGroupView {
            current_session_name: snapshot.current_session_name.clone(),
            sessions,
        },
        snapshot: Rc::new(snapshot),
        layout: wide_layout(),
        session_layouts: Vec::new(),
    }
}
