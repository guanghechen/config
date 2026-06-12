use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::{ComponentSnapshot, StatusComponent};

pub struct PrefixIndicatorComponent;

impl StatusComponent for PrefixIndicatorComponent {
    fn id(&self) -> &'static str {
        "prefix-indicator"
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        Ok(ComponentSnapshot::Rendered(RenderedSegment {
            literal_text: String::new(),
            rich_text: "#{?client_prefix,#[fg=#{@GHC_SL_FG_PREFIX}]#{@GHC_SYM_PREFIX} ,}"
                .to_string(),
        }))
    }
}
