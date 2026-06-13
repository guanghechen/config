use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::StatusWidget;

pub struct WindowIdWidget;

impl StatusWidget for WindowIdWidget {
    fn id(&self) -> &'static str {
        "window-id"
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: " @0 ".to_string(),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_SESSION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_SESSION}]#{@GHC_SYM_SESSION} #[default]#[fg=#{@GHC_SL_FG_PILL_WINNR}] #{window_id} ".to_string(),
        })
    }
}
