use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub struct HostComponent;

impl StatusComponent for HostComponent {
    fn id(&self) -> &'static str {
        "host"
    }

    fn render(
        &mut self,
        context: &RenderContext,
        _cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment> {
        let host = truncate_chars(&context.snapshot.host, 16);
        Ok(RenderedSegment {
            literal_text: format!(" {host} "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_HOST}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_HOST}]#{@GHC_SYM_OS} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{=16:host} ".to_string(),
        })
    }
}

fn truncate_chars(text: &str, limit: usize) -> String {
    text.chars().take(limit).collect()
}
