use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::{ComponentSnapshot, StatusComponent};

pub struct WindowIdComponent;

impl StatusComponent for WindowIdComponent {
    fn id(&self) -> &'static str {
        "window-id"
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        Ok(ComponentSnapshot::Rendered(RenderedSegment {
            literal_text: " @0 ".to_string(),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_SESSION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_SESSION}]#{@GHC_SYM_SESSION} #[default]#[fg=#{@GHC_SL_FG_PILL_WINNR}] #{window_id} ".to_string(),
        }))
    }
}
