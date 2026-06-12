use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub struct PrefixIndicatorComponent;

impl StatusComponent for PrefixIndicatorComponent {
    fn id(&self) -> &'static str {
        "prefix-indicator"
    }

    fn render(
        &mut self,
        _context: &RenderContext,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: String::new(),
            rich_text: "#{?client_prefix,#[fg=#{@GHC_SL_FG_PREFIX}]#{@GHC_SYM_PREFIX} ,}"
                .to_string(),
        })
    }
}
