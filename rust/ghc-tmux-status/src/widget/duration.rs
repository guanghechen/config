use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct DurationWidget;

impl TemplateWidget for DurationWidget {
    /*
     * tmux derives the session age from `@GHC_SESSION_DURATION_FMT` at every redraw,
     * so session caches stay static instead of being republished each minute. The
     * literal placeholder reserves the widest value below 1000 days.
     */
    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: pill_literal(" 999d 23h "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_BG_PILL_DURATION}#,bg=#{@GHC_SL_FG_PILL_ICON}#,reverse]#{@GHC_SYM_DURATION} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{E:@GHC_SESSION_DURATION_FMT} ".to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;
    use std::rc::Rc;

    use super::DurationWidget;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, StatusMode, StatusPosition,
        TmuxSnapshot,
    };
    use crate::status_widget::TemplateWidget;

    #[test]
    fn renders_session_age_at_draw_time() {
        let segment = DurationWidget.render_template(&context()).unwrap();

        assert_eq!(segment.literal_text, "\u{e0b6}¤  999d 23h ");
        assert!(
            segment
                .rich_text
                .contains(" #{E:@GHC_SESSION_DURATION_FMT} ")
        );
        assert!(!segment.rich_text.contains("#("));
    }

    fn context() -> RenderContext {
        RenderContext {
            snapshot: Rc::new(TmuxSnapshot {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "s".to_string(),
                client_last_session: String::new(),
                host: "h".to_string(),
                sessions: Vec::new(),
                client_widths: Vec::new(),
                options: BTreeMap::new(),
            }),
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
            session_layouts: Vec::new(),
        }
    }
}
