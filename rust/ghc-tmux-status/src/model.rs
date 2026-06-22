use std::collections::BTreeMap;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum RenderEventKind {
    Heartbeat,
    ThemeLoaded,
    ClientResized,
    SessionChanged,
    SessionCreated,
    SessionClosed,
    SessionRenamed,
    WindowChanged,
    ManualApply,
}

impl RenderEventKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Heartbeat => "heartbeat",
            Self::ThemeLoaded => "theme-loaded",
            Self::ClientResized => "client-resized",
            Self::SessionChanged => "session-changed",
            Self::SessionCreated => "session-created",
            Self::SessionClosed => "session-closed",
            Self::SessionRenamed => "session-renamed",
            Self::WindowChanged => "window-changed",
            Self::ManualApply => "manual-apply",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "heartbeat" => Some(Self::Heartbeat),
            "theme-loaded" => Some(Self::ThemeLoaded),
            "client-resized" => Some(Self::ClientResized),
            "session-changed" => Some(Self::SessionChanged),
            "session-created" => Some(Self::SessionCreated),
            "session-closed" => Some(Self::SessionClosed),
            "session-renamed" => Some(Self::SessionRenamed),
            "window-changed" => Some(Self::WindowChanged),
            "manual-apply" => Some(Self::ManualApply),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RenderEvent {
    pub kind: RenderEventKind,
}

impl RenderEvent {
    pub fn manual_apply() -> Self {
        Self {
            kind: RenderEventKind::ManualApply,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SessionInfo {
    pub id: String,
    pub name: String,
    pub has_bell: bool,
    /// This session's effective `status` option (`on` / `2` / `off`), read per-session.
    pub status: String,
    /// This session's effective `@GHC_SL_LAYOUT` (global fallback when no override).
    pub layout_key: String,
    /// This session's effective `status-left-length` / `status-right-length`.
    pub left_length: String,
    pub right_length: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TmuxSnapshot {
    pub mode: String,
    pub status: String,
    pub width: usize,
    pub current_session_name: String,
    pub client_last_session: String,
    pub host: String,
    pub session_created: i64,
    pub sessions: Vec<SessionInfo>,
    /// Attached clients as (session_id, client_width); detached sessions are absent.
    pub client_widths: Vec<(String, usize)>,
    pub options: BTreeMap<String, String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SessionGroupView {
    pub current_session_name: String,
    pub sessions: Vec<SessionInfo>,
}

#[derive(Copy, Clone, Debug, Eq, PartialEq)]
pub enum StatusMode {
    TopAdaptive,
    BottomAdaptive,
}

impl StatusMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::TopAdaptive => "02",
            Self::BottomAdaptive => "12",
        }
    }
}

#[derive(Copy, Clone, Debug, Eq, PartialEq)]
pub enum StatusPosition {
    Top,
    Bottom,
}

impl StatusPosition {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Top => "top",
            Self::Bottom => "bottom",
        }
    }
}

#[derive(Copy, Clone, Debug, Eq, PartialEq)]
pub enum LayoutKind {
    Wide,
    Narrow,
}

impl LayoutKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Wide => "wide",
            Self::Narrow => "narrow",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LayoutPlan {
    pub mode: StatusMode,
    pub position: StatusPosition,
    pub kind: LayoutKind,
    pub rows: usize,
    pub target_status: String,
    pub key: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderedSegment {
    pub literal_text: String,
    pub rich_text: String,
}

impl RenderedSegment {
    pub fn empty() -> Self {
        Self {
            literal_text: String::new(),
            rich_text: String::new(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderedStatus {
    pub status_left: RenderedSegment,
    pub status_right: RenderedSegment,
    pub session_format: RenderedSegment,
    pub current_format: RenderedSegment,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderContext {
    pub snapshot: TmuxSnapshot,
    pub group: SessionGroupView,
    pub layout: LayoutPlan,
    /// Resolved target layout for every reconciled (ON, attached) session.
    pub session_layouts: Vec<SessionLayout>,
}

/// The per-session reconcile unit: a session's resolved target layout plus the
/// current per-session values used to short-circuit a no-op write.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SessionLayout {
    pub session_id: String,
    pub session_name: String,
    pub current_status: String,
    pub current_layout_key: String,
    pub current_left_length: String,
    pub current_right_length: String,
    pub layout: LayoutPlan,
    pub width: usize,
}

#[cfg(test)]
mod tests {
    use super::RenderEventKind;

    const ALL_EVENT_KINDS: &[RenderEventKind] = &[
        RenderEventKind::Heartbeat,
        RenderEventKind::ThemeLoaded,
        RenderEventKind::ClientResized,
        RenderEventKind::SessionChanged,
        RenderEventKind::SessionCreated,
        RenderEventKind::SessionClosed,
        RenderEventKind::SessionRenamed,
        RenderEventKind::WindowChanged,
        RenderEventKind::ManualApply,
    ];

    #[test]
    fn event_kind_as_str_parse_round_trips() {
        for kind in ALL_EVENT_KINDS {
            assert_eq!(RenderEventKind::parse(kind.as_str()), Some(*kind));
        }
    }

    #[test]
    fn parse_rejects_unknown_event_kind() {
        assert_eq!(RenderEventKind::parse("not-an-event"), None);
    }
}
