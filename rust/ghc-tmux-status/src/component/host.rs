use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct HostComponent;

impl StatusComponent for HostComponent {
    fn id(&self) -> &'static str {
        "host"
    }

    fn interests(&self) -> ComponentInterests {
        ComponentInterests::Static
    }

    fn snapshot(
        &mut self,
        context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        let host = truncate_chars(&context.snapshot.host, 16);
        Ok(ComponentSnapshot::Rendered(RenderedSegment {
            literal_text: format!(" {host} "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_HOST}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_HOST}]#{@GHC_SYM_OS} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{=16:host} ".to_string(),
        }))
    }
}

fn truncate_chars(text: &str, limit: usize) -> String {
    text.chars().take(limit).collect()
}
