use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::ComputedWidget;
use crate::util::time::unix_timestamp_seconds;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct DurationWidget;

impl ComputedWidget for DurationWidget {
    fn id(&self) -> &'static str {
        "duration"
    }

    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        let duration = format_duration(
            (unix_timestamp_seconds() as i64).saturating_sub(context.snapshot.session_created),
        );
        let body_literal = format!(" {duration} ");
        let literal_text = pill_literal(&body_literal);
        let rich_text = format!(
            "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SYM_DURATION}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}] {duration} "
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
        return format!("{days}d {hours:02}h");
    }
    if hours > 0 {
        return format!("{hours}h {minutes:02}m");
    }
    format!("{minutes}m")
}

#[cfg(test)]
mod tests {
    use super::format_duration;

    #[test]
    fn formats_duration_compactly() {
        assert_eq!(format_duration(59), "0m");
        assert_eq!(format_duration(3_600 + 120), "1h 02m");
        assert_eq!(format_duration(86_400 + 7_200), "1d 02h");
    }
}
