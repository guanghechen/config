use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::metric::{MemorySnapshot, provider_for};
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::platform::current_platform;
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct MemoryComponent;

impl StatusComponent for MemoryComponent {
    fn id(&self) -> &'static str {
        "memory"
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
        let cache_key = "v4";
        let cached = cache.get(self.id(), cache_key).and_then(parse_cache);
        if let Some((timestamp, rendered)) = cached.as_ref()
            && (!should_refresh(event) || is_fresh(*timestamp))
        {
            return Ok(ComponentSnapshot::Rendered(rendered.clone()));
        }

        let provider = provider_for(current_platform());
        match provider.sample_memory() {
            Ok(snapshot) => {
                let rendered = render_memory(&snapshot);
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

fn render_memory(snapshot: &MemorySnapshot) -> RenderedSegment {
    let memory = snapshot.percent.round() as u64;
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

fn encode_cache(snapshot: &MemorySnapshot, rendered: &RenderedSegment) -> String {
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
    use crate::metric::MemorySnapshot;

    #[test]
    fn parses_memory_cache() {
        let snapshot = MemorySnapshot {
            percent: 47.0,
            timestamp_seconds: 1,
        };
        let rendered = super::render_memory(&snapshot);
        let parsed = parse_cache(&encode_cache(&snapshot, &rendered)).unwrap();
        assert_eq!(parsed.0, 1);
        assert_eq!(parsed.1, rendered);
    }
}
