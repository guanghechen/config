use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::metric::{CpuSnapshot, provider_for};
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::platform::current_platform;
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct CpuComponent;

impl StatusComponent for CpuComponent {
    fn id(&self) -> &'static str {
        "cpu"
    }

    fn interests(&self) -> ComponentInterests {
        ComponentInterests::Periodic { interval_secs: 20 }
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        event: &RenderEvent,
        cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        let cache_key = "v1";
        let cached = cache.get(self.id(), cache_key).and_then(parse_cache);
        if let Some((timestamp, rendered)) = cached.as_ref()
            && (!should_refresh(event) || is_fresh(*timestamp))
        {
            return Ok(ComponentSnapshot::Rendered(rendered.clone()));
        }

        let provider = provider_for(current_platform());
        match provider.sample_cpu() {
            Ok(snapshot) => {
                let rendered = render_cpu(&snapshot);
                cache.set(self.id(), cache_key, encode_cache(&snapshot, &rendered));
                Ok(ComponentSnapshot::Rendered(rendered))
            }
            Err(_) => Ok(ComponentSnapshot::Rendered(
                cached
                    .map(|(_, rendered)| rendered)
                    .unwrap_or_else(RenderedSegment::empty),
            )),
        }
    }
}

fn should_refresh(event: &RenderEvent) -> bool {
    matches!(
        event.kind,
        RenderEventKind::Tick | RenderEventKind::ManualApply | RenderEventKind::ThemeLoaded
    )
}

fn is_fresh(timestamp_seconds: u64) -> bool {
    unix_now().saturating_sub(timestamp_seconds) <= 1
}

fn render_cpu(snapshot: &CpuSnapshot) -> RenderedSegment {
    let cpu = snapshot.percent.round() as u64;
    let literal_text = format!(" CPU {cpu}% ");
    let rich_text = format!(
        "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}]{literal_text}"
    );
    RenderedSegment {
        literal_text,
        rich_text,
    }
}

fn encode_cache(snapshot: &CpuSnapshot, rendered: &RenderedSegment) -> String {
    format!(
        "{}\t{}\t{}",
        snapshot.timestamp_seconds, rendered.literal_text, rendered.rich_text
    )
}

fn parse_cache(value: &str) -> Option<(u64, RenderedSegment)> {
    let mut parts = value.splitn(3, '\t');
    let timestamp_seconds = parts.next()?.parse::<u64>().ok()?;
    let literal_text = parts.next()?.to_string();
    let rich_text = parts.next()?.to_string();
    Some((
        timestamp_seconds,
        RenderedSegment {
            literal_text,
            rich_text,
        },
    ))
}

fn unix_now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::{encode_cache, parse_cache};
    use crate::metric::CpuSnapshot;

    #[test]
    fn parses_cpu_cache() {
        let snapshot = CpuSnapshot {
            percent: 12.0,
            timestamp_seconds: 1,
        };
        let rendered = super::render_cpu(&snapshot);
        let parsed = parse_cache(&encode_cache(&snapshot, &rendered)).unwrap();
        assert_eq!(parsed.0, 1);
        assert_eq!(parsed.1, rendered);
    }
}
