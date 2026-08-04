use std::collections::BTreeMap;
use std::rc::Rc;

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
    /// Effective status row formats used to verify renderer-owned layout state.
    pub format_0: String,
    pub format_1: String,
    /// Fingerprint of this session's renderer-owned cache options.
    pub render_key: String,
    /// Fixed-size prefixes read from the four actual renderer-owned cache values.
    /// They detect drift without copying every full rich-text value into snapshots.
    pub cache_witnesses: [String; 4],
    pub created: i64,
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
    /// Owner-scope values only: global session options plus authoritative server
    /// generations. Effective per-session layout/status values live in `sessions`.
    pub options: BTreeMap<String, String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SessionNavigationSnapshot {
    pub current_session_name: String,
    pub sessions: Vec<SessionInfo>,
    pub order_value: String,
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

/// Manual override for how many rows the adaptive layout uses, read from
/// `@GHC_SL_ROWS`. `Auto` keeps the width/session-count heuristic; `One`/`Two`
/// pin the row count regardless of screen width.
#[derive(Copy, Clone, Debug, Eq, PartialEq, Default)]
pub enum RowsOverride {
    Auto,
    One,
    #[default]
    Two,
}

impl RowsOverride {
    /// Parses the raw option value. Empty uses the two-row default; `auto` and
    /// unrecognized values fall back to `Auto` so a typo never wedges the layout.
    pub fn parse(value: &str) -> Self {
        match value.trim() {
            "" => Self::default(),
            "1" => Self::One,
            "2" => Self::Two,
            _ => Self::Auto,
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
    /// Right side of the two-row session line. The fixed status-format template
    /// composes it with status_left through tmux indirection.
    pub session_right: RenderedSegment,
    pub current_format: RenderedSegment,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderContext {
    /// One immutable snapshot is shared by all per-session render contexts in an apply.
    pub snapshot: Rc<TmuxSnapshot>,
    pub group: SessionGroupView,
    pub layout: LayoutPlan,
    /// Session whose time-dependent widgets are being rendered. This is explicit
    /// because the snapshot's invoking client is not the owner of every session cache.
    pub render_session_created: i64,
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
    pub current_format_0: String,
    pub current_format_1: String,
    pub current_render_key: String,
    pub current_cache_witnesses: [String; 4],
    pub session_created: i64,
    pub layout: LayoutPlan,
    /// Widest attached client for this session. Layout rows are resolved from
    /// the narrowest client, but the shared status-length ceiling must still
    /// accommodate content visible on wider clients.
    pub status_length_width: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SessionRenderedStatus {
    pub session_layout: SessionLayout,
    pub render_key: String,
    pub status: RenderedStatus,
}

#[cfg(test)]
mod tests {
    use super::RenderEventKind;
    use super::RowsOverride;

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

    #[test]
    fn rows_override_parse_maps_known_values_and_defaults_to_two() {
        assert_eq!(RowsOverride::parse("1"), RowsOverride::One);
        assert_eq!(RowsOverride::parse("2"), RowsOverride::Two);
        assert_eq!(RowsOverride::parse(" 2 "), RowsOverride::Two);
        assert_eq!(RowsOverride::parse(""), RowsOverride::Two);
        assert_eq!(RowsOverride::parse("auto"), RowsOverride::Auto);
        assert_eq!(RowsOverride::parse("3"), RowsOverride::Auto);
    }
}
