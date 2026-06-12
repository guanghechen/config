use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct DateComponent;

impl StatusComponent for DateComponent {
    fn id(&self) -> &'static str {
        "date"
    }

    fn interests(&self) -> ComponentInterests {
        ComponentInterests::Periodic { interval_secs: 20 }
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        Ok(ComponentSnapshot::Rendered(RenderedSegment {
            literal_text: " Mon, 01 Jan ".to_string(),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_DATE}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DATE}]#{@GHC_SYM_DATE} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] %a, %d %b ".to_string(),
        }))
    }
}
