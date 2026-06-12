use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::{ComponentInterests, StatusComponent};

pub struct TimeComponent;

impl StatusComponent for TimeComponent {
    fn id(&self) -> &'static str {
        "time"
    }

    fn interests(&self) -> ComponentInterests {
        ComponentInterests::Periodic { interval_secs: 20 }
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: " 00:00 ".to_string(),
            rich_text: format!(
                "#[fg=#{{@GHC_SL_BG_PILL_TIME}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_TIME}}]#{{@GHC_SYM_TIME}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}] %H:%M {}",
                tick_trigger()
            ),
        })
    }
}

fn tick_trigger() -> String {
    let binary = std::env::current_exe()
        .ok()
        .and_then(|path| path.into_os_string().into_string().ok())
        .unwrap_or_else(fallback_binary_path);
    format!("#({} apply tick >/dev/null 2>&1)", shell_quote(&binary))
}

fn fallback_binary_path() -> String {
    std::env::var("HOME")
        .map(|home| {
            format!("{home}/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status")
        })
        .unwrap_or_else(|_| {
            "/Users/wanchenfang/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
                .to_string()
        })
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

#[cfg(test)]
mod tests {
    use super::shell_quote;

    #[test]
    fn quotes_tick_binary_path_for_shell() {
        assert_eq!(shell_quote("/tmp/app"), "'/tmp/app'");
        assert_eq!(shell_quote("/tmp/with space/app"), "'/tmp/with space/app'");
        assert_eq!(shell_quote("/tmp/it's/app"), "'/tmp/it'\\''s/app'");
    }
}
