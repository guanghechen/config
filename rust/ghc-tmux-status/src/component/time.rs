use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct TimeComponent;

impl StatusComponent for TimeComponent {
    fn id(&self) -> &'static str {
        "time"
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
            literal_text: " 00:00 ".to_string(),
            rich_text: format!(
                "#[fg=#{{@GHC_SL_BG_PILL_TIME}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_TIME}}]#{{@GHC_SYM_TIME}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}] %H:%M {}",
                tick_trigger()
            ),
        }))
    }
}

fn tick_trigger() -> String {
    let binary = std::env::current_exe()
        .ok()
        .and_then(|path| path.into_os_string().into_string().ok())
        .unwrap_or_else(|| {
            "~/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status".to_string()
        });
    format!("#({binary} apply tick >/dev/null 2>&1)")
}
