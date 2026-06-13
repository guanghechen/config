use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::StatusWidget;
use crate::widget::pill::conditional_pill_literal;

pub struct FullscreenWidget;

impl StatusWidget for FullscreenWidget {
    fn id(&self) -> &'static str {
        "fullscreen"
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: conditional_pill_literal(" 00/00 ,"),
            rich_text: "#{?window_zoomed_flag,#[fg=#{@GHC_SL_BG_PILL_ZOOM}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_ZOOM}]#{@GHC_SYM_WIN_ZOOM} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{pane_index}/#{window_panes} ,}".to_string(),
        })
    }
}
