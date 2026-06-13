use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::ComputedWidget;

pub struct HostWidget;

impl ComputedWidget for HostWidget {
    fn id(&self) -> &'static str {
        "host"
    }

    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        let host = truncate_chars(&context.snapshot.host, 16);
        Ok(RenderedSegment {
            literal_text: format!("{ROUND_LEFT}{OS_ICON}  {host} "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_HOST}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_HOST}]#{@GHC_SYM_OS} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{=16:host} ".to_string(),
        })
    }
}

// These placeholders mirror glyph variables in rich_text. status-left-length uses
// literal_text as a tmux-width shadow, so update them with the rich pill shape.
const ROUND_LEFT: &str = "";
const OS_ICON: &str = "";

fn truncate_chars(text: &str, limit: usize) -> String {
    text.chars().take(limit).collect()
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::HostWidget;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, StatusMode, StatusPosition,
        TmuxSnapshot,
    };
    use crate::status_widget::ComputedWidget;

    #[test]
    fn literal_text_accounts_for_visible_host_pill_glyphs() {
        let segment = HostWidget
            .render_computed(&context_with_host("mbp-m5-64g"))
            .unwrap();
        assert_eq!(segment.literal_text, "  mbp-m5-64g ");
    }

    fn context_with_host(host: &str) -> RenderContext {
        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "s".to_string(),
                client_last_session: String::new(),
                host: host.to_string(),
                session_created: 1,
                sessions: Vec::new(),
                options: BTreeMap::new(),
            },
            group: SessionGroupView {
                current_session_name: "s".to_string(),
                sessions: Vec::new(),
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
