use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_widget::{StatusWidget, WidgetInterests};
use crate::util::time::unix_timestamp_seconds;

#[derive(Default)]
pub struct DurationWidget {
    duration: String,
}

impl StatusWidget for DurationWidget {
    fn id(&self) -> &'static str {
        "duration"
    }

    fn interests(&self) -> WidgetInterests {
        WidgetInterests::Periodic { interval_secs: 20 }
    }

    fn snapshot(
        &mut self,
        context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn WidgetCache,
    ) -> AppResult<()> {
        self.duration = format_duration(
            (unix_timestamp_seconds() as i64).saturating_sub(context.snapshot.session_created),
        );
        Ok(())
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        let literal_text = format!(" {} ", self.duration);
        let rich_text = format!(
            "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SYM_DURATION}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}] {} ",
            self.duration
        );
        Ok(RenderedSegment {
            literal_text,
            rich_text,
        })
    }
}

fn format_duration(seconds: i64) -> String {
    let seconds = seconds.max(0);
    let days = seconds / 86_400;
    let hours = (seconds % 86_400) / 3_600;
    let minutes = (seconds % 3_600) / 60;

    if days > 0 {
        return format!("{days}d{hours}h");
    }
    if hours > 0 {
        return format!("{hours}h{minutes}m");
    }
    format!("{minutes}m")
}

#[cfg(test)]
mod tests {
    use super::format_duration;

    #[test]
    fn formats_duration_compactly() {
        assert_eq!(format_duration(59), "0m");
        assert_eq!(format_duration(3_600 + 120), "1h2m");
        assert_eq!(format_duration(86_400 + 7_200), "1d2h");
    }
}
