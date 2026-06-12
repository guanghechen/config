use std::collections::BTreeMap;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum RenderEventKind {
    Tick,
    ThemeLoaded,
    ClientResized,
    SessionChanged,
    SessionCreated,
    SessionClosed,
    SessionRenamed,
    ManualApply,
}

impl RenderEventKind {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "tick" => Some(Self::Tick),
            "theme-loaded" => Some(Self::ThemeLoaded),
            "client-resized" => Some(Self::ClientResized),
            "session-changed" => Some(Self::SessionChanged),
            "session-created" => Some(Self::SessionCreated),
            "session-closed" => Some(Self::SessionClosed),
            "session-renamed" => Some(Self::SessionRenamed),
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
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TmuxSnapshot {
    pub mode: String,
    pub current_layout: String,
    pub status: String,
    pub width: usize,
    pub current_session_name: String,
    pub host: String,
    pub session_created: i64,
    pub sessions: Vec<SessionInfo>,
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
}
