use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub struct TimeComponent;

impl StatusComponent for TimeComponent {
    fn id(&self) -> &'static str {
        "time"
    }

    fn render(
        &mut self,
        _context: &RenderContext,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: " 00:00 ".to_string(),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_TIME}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_TIME}]#{@GHC_SYM_TIME} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] %H:%M ".to_string(),
        })
    }
}
