use crate::cache::WIDGET_CACHE_OPTION_PREFIX;
use crate::model::TmuxSnapshot;
use crate::status_widget::CachedMetricWidget;
use crate::widget::{MemoryWidget, NetworkWidget};

// Placement counts describe how many times each widget lifecycle appears in the
// rendered status02 output (duplicates across rows included). Maintained by hand
// for `dump-state`; kept in sync with the render in composer::render_status02.
pub const TEMPLATE_WIDGET_PLACEMENTS: usize = 12;
pub const COMPUTED_WIDGET_PLACEMENTS: usize = 4;
pub const CACHED_METRIC_WIDGET_PLACEMENTS: usize = 4;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MetricCacheState {
    id: &'static str,
    status: MetricCacheStatus,
}

#[derive(Clone, Debug, Eq, PartialEq)]
enum MetricCacheStatus {
    Missing,
    Invalid {
        bytes: usize,
    },
    Present {
        age_seconds: u64,
        ttl_seconds: u64,
        fresh: bool,
        bytes: usize,
    },
}

impl MetricCacheState {
    pub fn format_line(&self) -> String {
        match self.status {
            MetricCacheStatus::Missing => format!("{} status=missing", self.id),
            MetricCacheStatus::Invalid { bytes } => {
                format!("{} status=invalid bytes={bytes}", self.id)
            }
            MetricCacheStatus::Present {
                age_seconds,
                ttl_seconds,
                fresh,
                bytes,
            } => format!(
                "{} status=present fresh={} age_seconds={} ttl_seconds={} bytes={}",
                self.id, fresh, age_seconds, ttl_seconds, bytes
            ),
        }
    }
}

pub fn metric_cache_states(snapshot: &TmuxSnapshot) -> Vec<MetricCacheState> {
    let now = crate::util::time::unix_timestamp_seconds();
    metric_cache_specs()
        .into_iter()
        .map(|spec| metric_cache_state(snapshot, spec, now))
        .collect()
}

pub fn cache_bytes(snapshot: &TmuxSnapshot) -> usize {
    snapshot
        .options
        .iter()
        .filter(|(name, _)| name.starts_with(WIDGET_CACHE_OPTION_PREFIX))
        .map(|(_, value)| value.len())
        .sum()
}

#[derive(Clone, Copy)]
struct MetricCacheSpec {
    id: &'static str,
    ttl_seconds: u64,
    timestamp_seconds: fn(&str) -> Option<u64>,
}

fn metric_cache_specs() -> [MetricCacheSpec; 2] {
    [
        MetricCacheSpec {
            id: "memory",
            ttl_seconds: MemoryWidget.ttl_seconds(),
            timestamp_seconds: memory_cache_timestamp_seconds,
        },
        MetricCacheSpec {
            id: "network",
            ttl_seconds: NetworkWidget::default().ttl_seconds(),
            timestamp_seconds: network_cache_timestamp_seconds,
        },
    ]
}

// CPU is no longer a TTL-cached metric (it renders a live tmux indirect reference
// refreshed by a detached sampler), so it is absent from the production specs above.
// The decoder stays here, test-gated, to exercise the generic cache-state logic.
#[cfg(test)]
fn cpu_cache_timestamp_seconds(value: &str) -> Option<u64> {
    crate::widget::decode_cpu_snapshot(value).map(|snapshot| snapshot.timestamp_seconds)
}

fn memory_cache_timestamp_seconds(value: &str) -> Option<u64> {
    let widget = MemoryWidget;
    widget
        .decode_cache(value)
        .map(|snapshot| widget.timestamp_seconds(&snapshot))
}

fn network_cache_timestamp_seconds(value: &str) -> Option<u64> {
    let widget = NetworkWidget::default();
    widget
        .decode_cache(value)
        .map(|snapshot| widget.timestamp_seconds(&snapshot))
}

fn metric_cache_state(
    snapshot: &TmuxSnapshot,
    spec: MetricCacheSpec,
    now_seconds: u64,
) -> MetricCacheState {
    let option_name = format!("{WIDGET_CACHE_OPTION_PREFIX}{}", spec.id);
    let Some(value) = snapshot.options.get(&option_name) else {
        return MetricCacheState {
            id: spec.id,
            status: MetricCacheStatus::Missing,
        };
    };

    let Some(timestamp_seconds) = (spec.timestamp_seconds)(value) else {
        return MetricCacheState {
            id: spec.id,
            status: MetricCacheStatus::Invalid { bytes: value.len() },
        };
    };

    let age_seconds = now_seconds.saturating_sub(timestamp_seconds);
    MetricCacheState {
        id: spec.id,
        status: MetricCacheStatus::Present {
            age_seconds,
            ttl_seconds: spec.ttl_seconds,
            fresh: age_seconds < spec.ttl_seconds,
            bytes: value.len(),
        },
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        MetricCacheSpec, MetricCacheState, MetricCacheStatus, cpu_cache_timestamp_seconds,
        metric_cache_state,
    };
    use crate::model::TmuxSnapshot;

    #[test]
    fn metric_cache_state_reports_missing_cache() {
        let state = metric_cache_state(&snapshot_with_options(BTreeMap::new()), spec(), 100);

        assert_eq!(
            state,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Missing,
            }
        );
    }

    #[test]
    fn metric_cache_state_reports_invalid_cache_timestamp() {
        let state = metric_cache_state(
            &snapshot_with_options(BTreeMap::from([(
                "@GHC_STATUS_COMPONENT_CACHE_cpu".to_string(),
                "invalid\tcache".to_string(),
            )])),
            spec(),
            100,
        );

        assert_eq!(
            state,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Invalid { bytes: 13 },
            }
        );
    }

    #[test]
    fn metric_cache_state_uses_widget_decoder_for_validity() {
        let state = metric_cache_state(
            &snapshot_with_options(BTreeMap::from([(
                "@GHC_STATUS_COMPONENT_CACHE_cpu".to_string(),
                "90\tvalue".to_string(),
            )])),
            spec(),
            100,
        );

        assert_eq!(
            state,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Invalid { bytes: 8 },
            }
        );
    }

    #[test]
    fn metric_cache_state_reports_fresh_and_stale_cache() {
        let cache_value = "90\t12\t1\t2\t3\t4";
        let snapshot = snapshot_with_options(BTreeMap::from([(
            "@GHC_STATUS_COMPONENT_CACHE_cpu".to_string(),
            cache_value.to_string(),
        )]));
        let bytes = cache_value.len();

        let fresh = metric_cache_state(&snapshot, spec(), 100);
        let stale = metric_cache_state(&snapshot, spec(), 111);

        assert_eq!(
            fresh,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Present {
                    age_seconds: 10,
                    ttl_seconds: 20,
                    fresh: true,
                    bytes,
                },
            }
        );
        assert_eq!(
            stale,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Present {
                    age_seconds: 21,
                    ttl_seconds: 20,
                    fresh: false,
                    bytes,
                },
            }
        );
    }

    fn spec() -> MetricCacheSpec {
        MetricCacheSpec {
            id: "cpu",
            ttl_seconds: 20,
            timestamp_seconds: cpu_cache_timestamp_seconds,
        }
    }

    fn snapshot_with_options(options: BTreeMap<String, String>) -> TmuxSnapshot {
        TmuxSnapshot {
            mode: "02".to_string(),
            current_layout: "02:wide".to_string(),
            status: "on".to_string(),
            width: 200,
            current_session_name: "s".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: Vec::new(),
            options,
        }
    }
}
