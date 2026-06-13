use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::ComputedWidget;
use crate::widget::pill::alert_literal;

pub struct SessionBellWidget;

impl ComputedWidget for SessionBellWidget {
    fn id(&self) -> &'static str {
        "session-bell"
    }

    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            // Keep the pessimistic width stable across bell set/clear; the rich
            // text is state-dependent, but status-right-length should not flap.
            literal_text: alert_literal(),
            rich_text: render_session_bell(context),
        })
    }
}

fn render_session_bell(context: &RenderContext) -> String {
    if !current_session_has_bell(context) {
        return String::new();
    }

    "#[fg=#{@GHC_SL_BG_ALERT}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_ALERT}#,bg=#{@GHC_SL_BG_ALERT}]#{@GHC_SYM_ALERT}#[fg=#{@GHC_SL_BG_ALERT}#,bg=default]#{@GHC_SEP_ROUND_RIGHT} ,".to_string()
}

fn current_session_has_bell(context: &RenderContext) -> bool {
    context
        .snapshot
        .sessions
        .iter()
        .any(|session| session.name == context.snapshot.current_session_name && session.has_bell)
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::render_session_bell;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, SessionInfo, StatusMode,
        StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn renders_alert_when_current_session_has_aggregated_window_bell() {
        let context = context_with_current_session_bell(true);

        assert!(render_session_bell(&context).contains("@GHC_SYM_ALERT"));
    }

    #[test]
    fn renders_empty_when_current_session_has_no_window_bell() {
        let context = context_with_current_session_bell(false);

        assert_eq!(render_session_bell(&context), "");
    }

    fn context_with_current_session_bell(has_bell: bool) -> RenderContext {
        let sessions = vec![SessionInfo {
            id: "$1".to_string(),
            name: "tmux".to_string(),
            has_bell,
        }];

        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "tmux".to_string(),
                host: "h".to_string(),
                session_created: 1,
                sessions: sessions.clone(),
                options: BTreeMap::new(),
            },
            group: SessionGroupView {
                current_session_name: "tmux".to_string(),
                sessions,
            },
            layout: LayoutPlan {
                mode: StatusMode::TopAdaptive,
                position: StatusPosition::Top,
                kind: LayoutKind::Wide,
                rows: 1,
                target_status: "on".to_string(),
                key: "02:wide".to_string(),
            },
        }
    }
}
