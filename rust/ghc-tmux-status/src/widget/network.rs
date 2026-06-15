use crate::error::AppResult;
use crate::metric::{NetworkSample, NetworkSnapshot, provider_for_current_platform};
use crate::model::RenderedSegment;
use crate::status_widget::CachedMetricWidget;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct NetworkWidget {
    interface: Option<String>,
}

impl NetworkWidget {
    pub fn for_interface(interface: Option<String>) -> Self {
        Self { interface }
    }
}

impl CachedMetricWidget for NetworkWidget {
    type Snapshot = NetworkSnapshot;

    fn id(&self) -> &'static str {
        "network"
    }

    fn ttl_seconds(&self) -> u64 {
        REFRESH_INTERVAL_SECONDS
    }

    fn timestamp_seconds(&self, snapshot: &Self::Snapshot) -> u64 {
        snapshot.sample.timestamp_seconds
    }

    fn decode_cache(&self, value: &str) -> Option<Self::Snapshot> {
        parse_cache(value)
    }

    fn encode_cache(&self, snapshot: &Self::Snapshot) -> String {
        encode_cache(snapshot)
    }

    fn sample(&self, previous: Option<&Self::Snapshot>) -> AppResult<Self::Snapshot> {
        provider_for_current_platform(self.interface.as_deref())
            .sample_network(previous.map(|snapshot| &snapshot.sample))
    }

    fn render_snapshot(&self, snapshot: &Self::Snapshot) -> RenderedSegment {
        render_network(snapshot)
    }
}

const REFRESH_INTERVAL_SECONDS: u64 = 30;

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
