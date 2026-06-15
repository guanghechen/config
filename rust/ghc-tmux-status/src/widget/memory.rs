use crate::error::AppResult;
use crate::metric::{MemorySnapshot, provider_for_current_platform};
use crate::model::RenderedSegment;
use crate::status_widget::CachedMetricWidget;
use crate::util::format::format_percent_min_width_2;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct MemoryWidget;

impl CachedMetricWidget for MemoryWidget {
    type Snapshot = MemorySnapshot;

    fn id(&self) -> &'static str {
        "memory"
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

    fn sample(&self, _previous: Option<&Self::Snapshot>) -> AppResult<Self::Snapshot> {
        provider_for_current_platform().sample_memory()
    }

    fn render_snapshot(&self, snapshot: &Self::Snapshot) -> RenderedSegment {
        render_memory(snapshot)
    }
}

const REFRESH_INTERVAL_SECONDS: u64 = 30;

fn render_memory(snapshot: &MemorySnapshot) -> RenderedSegment {
    let memory = format_percent_min_width_2(snapshot.percent);
    let body_literal = format!(" {memory}% ");
    let literal_text = pill_literal(&body_literal);
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
