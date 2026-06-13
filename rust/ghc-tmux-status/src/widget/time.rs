use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::{StatusWidget, WidgetInterests};
use crate::util::shell::shell_quote;

pub struct TimeWidget;

impl StatusWidget for TimeWidget {
    fn id(&self) -> &'static str {
        "time"
    }

    fn interests(&self) -> WidgetInterests {
        WidgetInterests::Periodic { interval_secs: 1 }
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: " 00:00:00 ".to_string(),
            rich_text: format!(
                "#[fg=#{{@GHC_SL_BG_PILL_TIME}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_TIME}}]#{{@GHC_SYM_TIME}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}] %H:%M:%S {}",
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

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::TimeWidget;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, StatusMode, StatusPosition,
        TmuxSnapshot,
    };
    use crate::status_widget::StatusWidget;

    #[test]
    fn renders_time_with_seconds() {
        let segment = TimeWidget.render(&context()).unwrap();

        assert_eq!(segment.literal_text, " 00:00:00 ");
        assert!(segment.rich_text.contains("%H:%M:%S"));
    }

    fn context() -> RenderContext {
        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "s".to_string(),
                host: "h".to_string(),
                session_created: 1,
                sessions: Vec::new(),
                options: BTreeMap::new(),
            },
            group: SessionGroupView {
                current_session_name: "s".to_string(),
                sessions: Vec::new(),
            },
            layout: LayoutPlan {
                mode: StatusMode::TopAdaptive,
                position: StatusPosition::Top,
                kind: LayoutKind::Wide,
                rows: 1,
                target_status: "on".to_string(),
                key: "02:wide".to_string(),
            },
        }
    }
}
