use crate::error::AppResult;
use crate::metric::{CpuSample, CpuSnapshot, provider_for_current_platform};
use crate::model::RenderedSegment;
use crate::status_widget::CachedMetricWidget;
use crate::util::format::format_percent_min_width_2;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct CpuWidget;

impl CachedMetricWidget for CpuWidget {
    type Snapshot = CpuSnapshot;

    fn id(&self) -> &'static str {
        "cpu"
    }

    fn ttl_seconds(&self) -> u64 {
        REFRESH_INTERVAL_SECONDS
    }

    fn timestamp_seconds(&self, snapshot: &Self::Snapshot) -> u64 {
        snapshot.timestamp_seconds
    }

    fn decode_cache(&self, value: &str) -> Option<Self::Snapshot> {
        parse_cache(value)
    }

    fn encode_cache(&self, snapshot: &Self::Snapshot) -> String {
        encode_cache(snapshot)
    }

    fn sample(&self, previous: Option<&Self::Snapshot>) -> AppResult<Self::Snapshot> {
        provider_for_current_platform().sample_cpu(previous.map(|snapshot| &snapshot.sample))
    }

    fn render_snapshot(&self, snapshot: &Self::Snapshot) -> RenderedSegment {
        render_cpu(snapshot)
    }
}

const REFRESH_INTERVAL_SECONDS: u64 = 20;

fn render_cpu(snapshot: &CpuSnapshot) -> RenderedSegment {
    let cpu = format_percent_min_width_2(snapshot.percent);
    let body_literal = format!(" {cpu}% ");
    let literal_text = pill_literal(&body_literal);
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
