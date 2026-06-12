use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub struct DurationComponent;

impl StatusComponent for DurationComponent {
    fn id(&self) -> &'static str {
        "duration"
    }

    fn render(
        &mut self,
        context: &RenderContext,
        cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment> {
        let now = unix_now();
        let minute_bucket = now / 60;
        let cache_key = format!("{}:{minute_bucket}", context.snapshot.session_created);
        if let Some(cached) = cache.get(self.id(), &cache_key)
            && let Some((literal_text, rich_text)) = cached.split_once('\t')
        {
            return Ok(RenderedSegment {
                literal_text: literal_text.to_string(),
                rich_text: rich_text.to_string(),
            });
        }

        let duration = format_duration(now.saturating_sub(context.snapshot.session_created));
        let rendered = RenderedSegment {
            literal_text: format!(" {duration} "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SYM_DURATION} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #(~/.config/tmux/script/duration.sh #{session_created}) ".to_string(),
        };
        cache.set(
            self.id(),
            &cache_key,
            format!("{}\t{}", rendered.literal_text, rendered.rich_text),
        );
        Ok(rendered)
    }
}

fn unix_now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or_default()
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
