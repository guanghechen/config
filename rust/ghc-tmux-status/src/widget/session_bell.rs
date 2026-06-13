use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::alert_literal;

pub struct SessionBellWidget;

impl TemplateWidget for SessionBellWidget {
    fn id(&self) -> &'static str {
        "session-bell"
    }

    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: alert_literal(),
            rich_text: "#{?session_bell_flag,#[fg=#{@GHC_SL_BG_ALERT}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_ALERT}#,bg=#{@GHC_SL_BG_ALERT}]#{@GHC_SYM_ALERT}#[fg=#{@GHC_SL_BG_ALERT}#,bg=default]#{@GHC_SEP_ROUND_RIGHT} ,}".to_string(),
        })
    }
}
