use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::metric::{NetworkSample, NetworkSnapshot, provider_for_current_platform};
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::status_widget::StatusWidget;
use crate::util::time::unix_timestamp_seconds;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct NetworkWidget {
    snapshot: Option<NetworkSnapshot>,
}

impl StatusWidget for NetworkWidget {
    fn id(&self) -> &'static str {
        "network"
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        event: &RenderEvent,
        cache: &mut dyn WidgetCache,
    ) -> AppResult<()> {
        let cached = cache.get(self.id()).and_then(parse_cache);
        if let Some(snapshot) = cached.clone()
            && (!should_refresh(event) || is_fresh(snapshot.sample.timestamp_seconds))
        {
            self.snapshot = Some(snapshot);
            return Ok(());
        }

        let provider = provider_for_current_platform();
        self.snapshot =
            match provider.sample_network(cached.as_ref().map(|snapshot| &snapshot.sample)) {
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
            .map(render_network)
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

fn render_network(snapshot: &NetworkSnapshot) -> RenderedSegment {
    let rx = format_speed(snapshot.rx_bytes_per_second);
    let tx = format_speed(snapshot.tx_bytes_per_second);
    let body_literal = format!(" ↓{rx} ↑{tx} ");
    let literal_text = pill_literal(&body_literal);
    let rich_text = format!(
        "#[fg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{@GHC_SL_FG_PILL_ICON}}#,bg=#{{@GHC_SL_BG_PILL_DURATION}}]#{{@GHC_SYM_NET}} #[default]#[fg=#{{@GHC_SL_FG_PILL_TXT}}]{body_literal}"
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

fn encode_cache(snapshot: &NetworkSnapshot) -> String {
    format!(
        "{}\t{}\t{}\t{}\t{}",
        snapshot.sample.timestamp_seconds,
        snapshot.sample.rx_bytes,
        snapshot.sample.tx_bytes,
        snapshot.rx_bytes_per_second,
        snapshot.tx_bytes_per_second
    )
}

fn parse_cache(value: &str) -> Option<NetworkSnapshot> {
    let mut parts = value.splitn(5, '\t');
    let sample = NetworkSample {
        timestamp_seconds: parts.next()?.parse::<u64>().ok()?,
        rx_bytes: parts.next()?.parse::<u64>().ok()?,
        tx_bytes: parts.next()?.parse::<u64>().ok()?,
    };
    Some(NetworkSnapshot {
        sample,
        rx_bytes_per_second: parts.next()?.parse::<u64>().ok()?,
        tx_bytes_per_second: parts.next()?.parse::<u64>().ok()?,
    })
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
        let parsed = parse_cache(&super::encode_cache(&snapshot)).unwrap();
        assert_eq!(parsed, snapshot);
    }
}
