use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub struct DateComponent;

impl StatusComponent for DateComponent {
    fn id(&self) -> &'static str {
        "date"
    }

    fn render(
        &mut self,
        _context: &RenderContext,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: " Mon, 01 Jan ".to_string(),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_DATE}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DATE}]#{@GHC_SYM_DATE} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] %a, %d %b ".to_string(),
        })
    }
}
