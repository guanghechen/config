use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::metric::{MemorySnapshot, provider_for_current_platform};
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::status_widget::StatusWidget;
use crate::util::format::format_percent_min_width_2;
use crate::util::time::unix_timestamp_seconds;

#[derive(Default)]
pub struct MemoryWidget {
    snapshot: Option<MemorySnapshot>,
}

impl StatusWidget for MemoryWidget {
    fn id(&self) -> &'static str {
        "memory"
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        event: &RenderEvent,
        cache: &mut dyn WidgetCache,
    ) -> AppResult<()> {
        let cached = cache.get(self.id()).and_then(parse_cache);
        if let Some(snapshot) = cached.clone()
            && (!should_refresh(event) || is_fresh(snapshot.timestamp_seconds))
        {
            self.snapshot = Some(snapshot);
            return Ok(());
        }

        let provider = provider_for_current_platform();
        self.snapshot = match provider.sample_memory() {
            Ok(snapshot) => {
                cache.set(self.id(), encode_cache(&snapshot));
                Some(snapshot)
            }
            Err(_) => cached,
        };
        Ok(())
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(self
            .snapshot
            .as_ref()
            .map(render_memory)
            .unwrap_or_else(RenderedSegment::empty))
    }
}

fn should_refresh(event: &RenderEvent) -> bool {
    matches!(
        event.kind,
        RenderEventKind::Tick | RenderEventKind::ManualApply | RenderEventKind::ThemeLoaded
    )
}

const REFRESH_INTERVAL_SECONDS: u64 = 20;

fn is_fresh(timestamp_seconds: u64) -> bool {
    unix_timestamp_seconds().saturating_sub(timestamp_seconds) < REFRESH_INTERVAL_SECONDS
}

fn render_memory(snapshot: &MemorySnapshot) -> RenderedSegment {
    let memory = format_percent_min_width_2(snapshot.percent);
    let literal_text = format!(" {memory}% ");
    let rich_value = format!(" {memory}%% ");
    let rich_text = format!(
        "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SYM_MEMORY}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}]{rich_value}"
    );
    RenderedSegment {
        literal_text,
        rich_text,
    }
}

fn encode_cache(snapshot: &MemorySnapshot) -> String {
    format!("{}\t{}", snapshot.timestamp_seconds, snapshot.percent)
}

fn parse_cache(value: &str) -> Option<MemorySnapshot> {
    let mut parts = value.splitn(2, '\t');
    Some(MemorySnapshot {
        timestamp_seconds: parts.next()?.parse::<u64>().ok()?,
        percent: parts.next()?.parse::<f64>().ok()?,
    })
}

#[cfg(test)]
mod tests {
    use super::{encode_cache, parse_cache};
    use crate::metric::MemorySnapshot;

    #[test]
    fn parses_memory_cache() {
        let snapshot = MemorySnapshot {
            percent: 47.0,
            timestamp_seconds: 1,
        };
        let parsed = parse_cache(&encode_cache(&snapshot)).unwrap();
        assert_eq!(parsed, snapshot);
    }
}
