use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::metric::{NetworkSample, NetworkSnapshot, provider_for};
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::platform::current_platform;
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct NetworkComponent;

impl StatusComponent for NetworkComponent {
    fn id(&self) -> &'static str {
        "network"
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
        let cache_key = "v2:en0";
        let cached = cache.get(self.id(), cache_key).and_then(parse_cache);
        if let Some((sample, rendered)) = cached.as_ref()
            && (!should_refresh(event) || is_fresh(sample.timestamp_seconds))
        {
            return Ok(ComponentSnapshot::Rendered(rendered.clone()));
        }

        let provider = provider_for(current_platform());
        match provider.sample_network(cached.as_ref().map(|(sample, _)| sample)) {
            Ok(snapshot) => {
                let rendered = render_network(&snapshot);
                cache.set(
                    self.id(),
                    cache_key,
                    encode_cache(&snapshot.sample, &rendered),
                );
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

fn render_network(snapshot: &NetworkSnapshot) -> RenderedSegment {
    let rx = format_speed(snapshot.rx_bytes_per_second);
    let tx = format_speed(snapshot.tx_bytes_per_second);
    let literal_text = format!(" ↓{rx} ↑{tx} ");
    let rich_text = format!(
        "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SYM_NET}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}]{literal_text}"
    );
    RenderedSegment {
        literal_text,
        rich_text,
    }
}

fn format_speed(bytes_per_second: u64) -> String {
    const KIB: f64 = 1024.0;
    const MIB: f64 = 1024.0 * 1024.0;
    const GIB: f64 = 1024.0 * 1024.0 * 1024.0;

    let value = bytes_per_second as f64;
    if value >= GIB {
        return format!("{:.1}G", value / GIB);
    }
    if value >= MIB {
        return format!("{:.1}M", value / MIB);
    }
    if value >= KIB {
        return format!("{:.0}K", value / KIB);
    }
    format!("{bytes_per_second}B")
}

fn encode_cache(sample: &NetworkSample, rendered: &RenderedSegment) -> String {
    format!(
        "{}\t{}\t{}\t{}\t{}",
        sample.timestamp_seconds,
        sample.rx_bytes,
        sample.tx_bytes,
        rendered.literal_text,
        rendered.rich_text
    )
}

fn parse_cache(value: &str) -> Option<(NetworkSample, RenderedSegment)> {
    let mut parts = value.splitn(5, '\t');
    let timestamp_seconds = parts.next()?.parse::<u64>().ok()?;
    let rx_bytes = parts.next()?.parse::<u64>().ok()?;
    let tx_bytes = parts.next()?.parse::<u64>().ok()?;
    let literal_text = parts.next()?.to_string();
    let rich_text = parts.next()?.to_string();
    Some((
        NetworkSample {
            timestamp_seconds,
            rx_bytes,
            tx_bytes,
        },
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
    use super::{format_speed, parse_cache};
    use crate::metric::{NetworkSample, NetworkSnapshot};

    #[test]
    fn formats_speed_compactly() {
        assert_eq!(format_speed(999), "999B");
        assert_eq!(format_speed(12 * 1024), "12K");
        assert_eq!(format_speed(2 * 1024 * 1024), "2.0M");
    }

    #[test]
    fn parses_network_cache() {
        let snapshot = NetworkSnapshot {
            rx_bytes_per_second: 1,
            tx_bytes_per_second: 2,
            sample: NetworkSample {
                timestamp_seconds: 1,
                rx_bytes: 2,
                tx_bytes: 3,
            },
        };
        let rendered = super::render_network(&snapshot);
        let parsed = parse_cache(&super::encode_cache(&snapshot.sample, &rendered)).unwrap();
        assert_eq!(parsed.0.rx_bytes, 2);
        assert_eq!(parsed.1, rendered);
    }
}
