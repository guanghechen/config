use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::{ComponentSnapshot, StatusComponent};

pub struct SessionBellComponent;

impl StatusComponent for SessionBellComponent {
    fn id(&self) -> &'static str {
        "session-bell"
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        Ok(ComponentSnapshot::Rendered(RenderedSegment {
            literal_text: String::new(),
            rich_text: "#{?session_bell_flag,#[fg=#{@GHC_SL_BG_ALERT}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_ALERT}#,bg=#{@GHC_SL_BG_ALERT}]#{@GHC_SYM_ALERT}#[fg=#{@GHC_SL_BG_ALERT}#,bg=default]#{@GHC_SEP_ROUND_RIGHT} ,}".to_string(),
        }))
    }
}
