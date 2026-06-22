use crate::error::AppResult;
use crate::metric::{NetworkSample, NetworkSnapshot, provider_for_current_platform};
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct NetworkWidget;

impl TemplateWidget for NetworkWidget {
    // The sampler is the single writer of `@GHC_NET_NOW`; render only installs an
    // indirect reference so tmux redraws can show fresh bandwidth without a full render.
    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        let body_literal = " ↓99.9G ↑99.9G ";
        let literal_text = pill_literal(body_literal);
        let rich_text = "#[fg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SYM_NET} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{@GHC_NET_NOW} ".to_string();
        Ok(RenderedSegment {
            literal_text,
            rich_text,
        })
    }
}

pub fn sample_network(
    interface: Option<&str>,
    previous: Option<&NetworkSnapshot>,
) -> AppResult<NetworkSnapshot> {
    provider_for_current_platform(interface)
        .sample_network(previous.map(|snapshot| &snapshot.sample))
}

pub fn encode_network_snapshot(snapshot: &NetworkSnapshot) -> String {
    format!(
        "{}\t{}\t{}\t{}\t{}",
        snapshot.sample.timestamp_seconds,
        snapshot.sample.rx_bytes,
        snapshot.sample.tx_bytes,
        snapshot.rx_bytes_per_second,
        snapshot.tx_bytes_per_second
    )
}

pub fn decode_network_snapshot(value: &str) -> Option<NetworkSnapshot> {
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

pub fn format_network_now(snapshot: &NetworkSnapshot) -> String {
    let rx = format_speed(snapshot.rx_bytes_per_second);
    let tx = format_speed(snapshot.tx_bytes_per_second);
    format!("↓{rx} ↑{tx}")
}

fn format_speed(bytes_per_second: u64) -> String {
    const KIB: f64 = 1024.0;
    const MIB: f64 = 1024.0 * 1024.0;
    const GIB: f64 = 1024.0 * 1024.0 * 1024.0;

    let value = bytes_per_second as f64;
    if value >= GIB {
        return format_unit(value / GIB, "G");
    }
    if value >= MIB {
        return format_unit(value / MIB, "M");
    }
    if value >= KIB {
        return format_unit(value / KIB, "K");
    }
    format!("{bytes_per_second}B")
}

fn format_unit(value: f64, suffix: &str) -> String {
    if value >= 99.95 {
        let rounded = value.round().min(999.0) as u64;
        return format!("{rounded}{suffix}");
    }
    format!("{value:.1}{suffix}")
}

#[cfg(test)]
mod tests {
    use super::{decode_network_snapshot, format_network_now, format_speed};
    use crate::metric::{NetworkSample, NetworkSnapshot};

    #[test]
    fn formats_speed_compactly() {
        assert_eq!(format_speed(999), "999B");
        assert_eq!(format_speed(12 * 1024), "12.0K");
        assert_eq!(format_speed(2 * 1024 * 1024), "2.0M");
        assert_eq!(format_speed(123 * 1024 * 1024), "123M");
        assert_eq!(format_speed(102_390), "100K");
        assert_eq!(format_speed(1_023_590), "999K");
    }

    #[test]
    fn formatted_speed_tokens_fit_fixed_width_budget() {
        let samples = [
            999,
            1023,
            (9.94 * 1024.0) as u64,
            (9.95 * 1024.0) as u64,
            (99.94 * 1024.0) as u64,
            (99.95 * 1024.0) as u64,
            (999.4 * 1024.0) as u64,
            (999.6 * 1024.0) as u64,
            (99.95 * 1024.0 * 1024.0) as u64,
            (999.6 * 1024.0 * 1024.0 * 1024.0) as u64,
        ];
        for bytes_per_second in samples {
            assert!(
                format_speed(bytes_per_second).len() <= 5,
                "{} formatted as {}",
                bytes_per_second,
                format_speed(bytes_per_second)
            );
        }
    }

    #[test]
    fn formats_network_for_fixed_width_display() {
        let snapshot = NetworkSnapshot {
            rx_bytes_per_second: 12 * 1024,
            tx_bytes_per_second: 999,
            sample: NetworkSample {
                timestamp_seconds: 1,
                rx_bytes: 2,
                tx_bytes: 3,
            },
        };
        assert_eq!(format_network_now(&snapshot), "↓12.0K ↑999B");
    }

    #[test]
    fn round_trips_network_snapshot() {
        let snapshot = NetworkSnapshot {
            rx_bytes_per_second: 1,
            tx_bytes_per_second: 2,
            sample: NetworkSample {
                timestamp_seconds: 1,
                rx_bytes: 2,
                tx_bytes: 3,
            },
        };
        let parsed = decode_network_snapshot(&super::encode_network_snapshot(&snapshot)).unwrap();
        assert_eq!(parsed, snapshot);
    }
}
