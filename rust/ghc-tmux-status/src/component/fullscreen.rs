use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub struct FullscreenComponent;

impl StatusComponent for FullscreenComponent {
    fn id(&self) -> &'static str {
        "fullscreen"
    }

    fn render(
        &mut self,
        _context: &RenderContext,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: String::new(),
            rich_text: "#{?window_zoomed_flag,#[fg=#{@GHC_SL_BG_PILL_ZOOM}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_ZOOM}]#{@GHC_SYM_WIN_ZOOM} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{pane_index}/#{window_panes} ,}".to_string(),
        })
    }
}
