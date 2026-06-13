use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::metric::{CpuSample, CpuSnapshot, provider_for_current_platform};
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::status_widget::StatusWidget;
use crate::util::format::format_percent_min_width_2;
use crate::util::time::unix_timestamp_seconds;

#[derive(Default)]
pub struct CpuWidget {
    snapshot: Option<CpuSnapshot>,
}

impl StatusWidget for CpuWidget {
    fn id(&self) -> &'static str {
        "cpu"
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
        self.snapshot = match provider.sample_cpu(cached.as_ref().map(|snapshot| &snapshot.sample))
        {
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
            .map(render_cpu)
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

fn render_cpu(snapshot: &CpuSnapshot) -> RenderedSegment {
    let cpu = format_percent_min_width_2(snapshot.percent);
    let literal_text = format!(" {cpu}% ");
    let rich_value = format!(" {cpu}%% ");
    let rich_text = format!(
        "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SYM_CPU}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}]{rich_value}"
    );
    RenderedSegment {
        literal_text,
        rich_text,
    }
}

fn encode_cache(snapshot: &CpuSnapshot) -> String {
    format!(
        "{}\t{}\t{}\t{}\t{}\t{}",
        snapshot.timestamp_seconds,
        snapshot.percent,
        snapshot.sample.user,
        snapshot.sample.nice,
        snapshot.sample.system,
        snapshot.sample.idle
    )
}

fn parse_cache(value: &str) -> Option<CpuSnapshot> {
    let mut parts = value.splitn(6, '\t');
    Some(CpuSnapshot {
        timestamp_seconds: parts.next()?.parse::<u64>().ok()?,
        percent: parts.next()?.parse::<f64>().ok()?,
        sample: CpuSample {
            user: parts.next()?.parse::<u64>().ok()?,
            nice: parts.next()?.parse::<u64>().ok()?,
            system: parts.next()?.parse::<u64>().ok()?,
            idle: parts.next()?.parse::<u64>().ok()?,
        },
    })
}

#[cfg(test)]
mod tests {
    use super::{encode_cache, parse_cache};
    use crate::metric::{CpuSample, CpuSnapshot};

    #[test]
    fn parses_cpu_cache() {
        let snapshot = CpuSnapshot {
            percent: 12.0,
            timestamp_seconds: 1,
            sample: CpuSample {
                user: 1,
                nice: 2,
                system: 3,
                idle: 4,
            },
        };
        let parsed = parse_cache(&encode_cache(&snapshot)).unwrap();
        assert_eq!(parsed, snapshot);
    }
}
