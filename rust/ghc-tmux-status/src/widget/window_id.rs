use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::pill_literal;

pub struct WindowIdWidget;

impl TemplateWidget for WindowIdWidget {
    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: pill_literal(" @00 "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_SESSION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_SESSION}]#{@GHC_SYM_SESSION} #[default]#[fg=#{@GHC_SL_FG_PILL_WINNR}] #{window_id} ".to_string(),
        })
    }
}
