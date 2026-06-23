use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::pill_literal;

pub struct FullscreenWidget;

impl TemplateWidget for FullscreenWidget {
    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            // The zoom pill only renders when window_zoomed_flag is set, but the literal
            // width shadow reserves its worst case so status-*-length stays stable whether
            // or not the current window is zoomed.
            literal_text: pill_literal(" 00/00 ,"),
            rich_text: "#{?window_zoomed_flag,#[fg=#{@GHC_SL_BG_PILL_ZOOM}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_ZOOM}]#{@GHC_SYM_WIN_ZOOM} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{pane_index}/#{window_panes} ,}".to_string(),
        })
    }
}
