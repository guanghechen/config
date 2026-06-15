use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::pill_literal;

pub struct TimeWidget;

impl TemplateWidget for TimeWidget {
    fn id(&self) -> &'static str {
        "time"
    }

    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: pill_literal(" 00:00:00 "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_TIME}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_TIME}]#{@GHC_SYM_TIME} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] %H:%M:%S ".to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::TimeWidget;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, StatusMode, StatusPosition,
        TmuxSnapshot,
    };
    use crate::status_widget::TemplateWidget;

    #[test]
    fn renders_time_with_seconds() {
        let segment = TimeWidget.render_template(&context()).unwrap();

        assert_eq!(segment.literal_text, "¤  00:00:00 ");
        assert!(segment.rich_text.contains("%H:%M:%S"));
        assert!(!segment.rich_text.contains("#("));
    }

    fn context() -> RenderContext {
        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "s".to_string(),
                client_last_session: String::new(),
                host: "h".to_string(),
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
