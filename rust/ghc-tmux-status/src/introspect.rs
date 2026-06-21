use crate::cache::WIDGET_CACHE_OPTION_PREFIX;
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, MEMORY_NOW_OPTION, MEMORY_SAMPLE_STATE_OPTION,
    METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    METRIC_SAMPLE_STALE_LIMIT_SECONDS, NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION,
};
use crate::model::TmuxSnapshot;
use crate::widget::{decode_cpu_snapshot, decode_memory_snapshot, decode_network_snapshot};

// Placement counts describe how many times each widget lifecycle appears in the
// rendered status02 output (duplicates across rows included). Maintained by hand
// for `dump-state`; kept in sync with the render in composer::render_status02.
pub const TEMPLATE_WIDGET_PLACEMENTS: usize = 16;
pub const COMPUTED_WIDGET_PLACEMENTS: usize = 4;
pub const CACHED_METRIC_WIDGET_PLACEMENTS: usize = 0;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MetricHealthState {
    last_ok_age_seconds: Option<u64>,
    last_error_age_seconds: Option<u64>,
    consecutive_errors: u64,
    last_error: String,
}

impl MetricHealthState {
    pub fn format_line(&self) -> String {
        format!(
            "last_ok_age_seconds={} consecutive_errors={} last_error_age_seconds={} last_error={}",
            format_optional_seconds(self.last_ok_age_seconds),
            self.consecutive_errors,
            format_optional_seconds(self.last_error_age_seconds),
            if self.last_error.is_empty() {
                "<none>"
            } else {
                &self.last_error
            }
        )
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MetricSampleState {
    id: &'static str,
    status: MetricSampleStatus,
}

#[derive(Clone, Debug, Eq, PartialEq)]
enum MetricSampleStatus {
    Missing,
    Invalid {
        bytes: usize,
    },
    Present {
        age_seconds: u64,
        fresh: bool,
        bytes: usize,
        display_value: String,
    },
}

impl MetricSampleState {
    pub fn format_line(&self) -> String {
        match &self.status {
            MetricSampleStatus::Missing => format!("{} status=missing", self.id),
            MetricSampleStatus::Invalid { bytes } => {
                format!("{} status=invalid bytes={bytes}", self.id)
            }
            MetricSampleStatus::Present {
                age_seconds,
                fresh,
                bytes,
                display_value,
            } => format!(
                "{} status=present fresh={} age_seconds={} stale_limit_seconds={} bytes={} display={}",
                self.id,
                fresh,
                age_seconds,
                METRIC_SAMPLE_STALE_LIMIT_SECONDS,
                bytes,
                display_value
            ),
        }
    }
}

pub fn metric_health_state(snapshot: &TmuxSnapshot) -> MetricHealthState {
    let now = crate::util::time::unix_timestamp_seconds();
    metric_health_state_at(snapshot, now)
}

fn metric_health_state_at(snapshot: &TmuxSnapshot, now_seconds: u64) -> MetricHealthState {
    let (last_error_timestamp, last_error) = snapshot
        .options
        .get(METRIC_LAST_ERROR_OPTION)
        .and_then(|value| parse_last_error(value))
        .unwrap_or_default();

    MetricHealthState {
        last_ok_age_seconds: snapshot
            .options
            .get(METRIC_LAST_OK_OPTION)
            .and_then(|value| value.parse::<u64>().ok())
            .map(|timestamp| now_seconds.saturating_sub(timestamp)),
        last_error_age_seconds: last_error_timestamp
            .map(|timestamp| now_seconds.saturating_sub(timestamp)),
        consecutive_errors: snapshot
            .options
            .get(METRIC_ERROR_COUNT_OPTION)
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or_default(),
        last_error,
    }
}

fn parse_last_error(value: &str) -> Option<(Option<u64>, String)> {
    let (timestamp, message) = value.split_once('\t')?;
    Some((timestamp.parse::<u64>().ok(), message.trim().to_string()))
}

fn format_optional_seconds(value: Option<u64>) -> String {
    value
        .map(|value| value.to_string())
        .unwrap_or_else(|| "missing".to_string())
}

pub fn metric_sample_states(snapshot: &TmuxSnapshot) -> Vec<MetricSampleState> {
    let now = crate::util::time::unix_timestamp_seconds();
    metric_sample_specs()
        .into_iter()
        .map(|spec| metric_sample_state(snapshot, spec, now))
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
struct MetricSampleSpec {
    id: &'static str,
    state_option: &'static str,
    display_option: &'static str,
    timestamp_seconds: fn(&str) -> Option<u64>,
}

fn metric_sample_specs() -> [MetricSampleSpec; 3] {
    [
        MetricSampleSpec {
            id: "cpu",
            state_option: CPU_SAMPLE_STATE_OPTION,
            display_option: CPU_NOW_OPTION,
            timestamp_seconds: cpu_sample_timestamp_seconds,
        },
        MetricSampleSpec {
            id: "memory",
            state_option: MEMORY_SAMPLE_STATE_OPTION,
            display_option: MEMORY_NOW_OPTION,
            timestamp_seconds: memory_sample_timestamp_seconds,
        },
        MetricSampleSpec {
            id: "network",
            state_option: NETWORK_SAMPLE_STATE_OPTION,
            display_option: NETWORK_NOW_OPTION,
            timestamp_seconds: network_sample_timestamp_seconds,
        },
    ]
}

fn cpu_sample_timestamp_seconds(value: &str) -> Option<u64> {
    decode_cpu_snapshot(value).map(|snapshot| snapshot.timestamp_seconds)
}

fn memory_sample_timestamp_seconds(value: &str) -> Option<u64> {
    decode_memory_snapshot(value).map(|snapshot| snapshot.timestamp_seconds)
}

fn network_sample_timestamp_seconds(value: &str) -> Option<u64> {
    decode_network_snapshot(value).map(|snapshot| snapshot.sample.timestamp_seconds)
}

fn metric_sample_state(
    snapshot: &TmuxSnapshot,
    spec: MetricSampleSpec,
    now_seconds: u64,
) -> MetricSampleState {
    let Some(value) = snapshot.options.get(spec.state_option) else {
        return MetricSampleState {
            id: spec.id,
            status: MetricSampleStatus::Missing,
        };
    };

    let Some(timestamp_seconds) = (spec.timestamp_seconds)(value) else {
        return MetricSampleState {
            id: spec.id,
            status: MetricSampleStatus::Invalid { bytes: value.len() },
        };
    };

    let age_seconds = now_seconds.saturating_sub(timestamp_seconds);
    MetricSampleState {
        id: spec.id,
        status: MetricSampleStatus::Present {
            age_seconds,
            fresh: age_seconds <= METRIC_SAMPLE_STALE_LIMIT_SECONDS,
            bytes: value.len(),
            display_value: snapshot
                .options
                .get(spec.display_option)
                .cloned()
                .unwrap_or_default(),
        },
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        MetricHealthState, MetricSampleSpec, MetricSampleState, MetricSampleStatus,
        cpu_sample_timestamp_seconds, metric_health_state_at, metric_sample_state,
    };
    use crate::config::{
        CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, METRIC_ERROR_COUNT_OPTION,
        METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    };
    use crate::model::TmuxSnapshot;

    #[test]
    fn metric_sample_state_reports_missing_state() {
        let state = metric_sample_state(&snapshot_with_options(BTreeMap::new()), spec(), 100);

        assert_eq!(
            state,
            MetricSampleState {
                id: "cpu",
                status: MetricSampleStatus::Missing,
            }
        );
    }

    #[test]
    fn metric_sample_state_reports_invalid_state_timestamp() {
        let state = metric_sample_state(
            &snapshot_with_options(BTreeMap::from([(
                CPU_SAMPLE_STATE_OPTION.to_string(),
                "invalid\tstate".to_string(),
            )])),
            spec(),
            100,
        );

        assert_eq!(
            state,
            MetricSampleState {
                id: "cpu",
                status: MetricSampleStatus::Invalid { bytes: 13 },
            }
        );
    }

    #[test]
    fn metric_sample_state_uses_snapshot_decoder_for_validity() {
        let state = metric_sample_state(
            &snapshot_with_options(BTreeMap::from([(
                CPU_SAMPLE_STATE_OPTION.to_string(),
                "90\tvalue".to_string(),
            )])),
            spec(),
            100,
        );

        assert_eq!(
            state,
            MetricSampleState {
                id: "cpu",
                status: MetricSampleStatus::Invalid { bytes: 8 },
            }
        );
    }

    #[test]
    fn metric_health_state_reports_missing_values() {
        assert_eq!(
            metric_health_state_at(&snapshot_with_options(BTreeMap::new()), 100),
            MetricHealthState {
                last_ok_age_seconds: None,
                last_error_age_seconds: None,
                consecutive_errors: 0,
                last_error: String::new(),
            }
        );
    }

    #[test]
    fn metric_health_state_reports_ok_and_last_error_age() {
        let snapshot = snapshot_with_options(BTreeMap::from([
            (METRIC_LAST_OK_OPTION.to_string(), "90".to_string()),
            (
                METRIC_LAST_ERROR_OPTION.to_string(),
                "80\tnetwork failed".to_string(),
            ),
            (METRIC_ERROR_COUNT_OPTION.to_string(), "2".to_string()),
        ]));

        assert_eq!(
            metric_health_state_at(&snapshot, 100),
            MetricHealthState {
                last_ok_age_seconds: Some(10),
                last_error_age_seconds: Some(20),
                consecutive_errors: 2,
                last_error: "network failed".to_string(),
            }
        );
    }

    #[test]
    fn metric_sample_state_reports_fresh_and_stale_state() {
        let state_value = "90\t12\t1\t2\t3\t4";
        let snapshot = snapshot_with_options(BTreeMap::from([
            (CPU_SAMPLE_STATE_OPTION.to_string(), state_value.to_string()),
            (CPU_NOW_OPTION.to_string(), " 12".to_string()),
        ]));
        let bytes = state_value.len();

        let fresh = metric_sample_state(&snapshot, spec(), 100);
        let stale = metric_sample_state(
            &snapshot,
            spec(),
            101 + crate::config::METRIC_SAMPLE_STALE_LIMIT_SECONDS,
        );

        assert_eq!(
            fresh,
            MetricSampleState {
                id: "cpu",
                status: MetricSampleStatus::Present {
                    age_seconds: 10,
                    fresh: true,
                    bytes,
                    display_value: " 12".to_string(),
                },
            }
        );
        assert_eq!(
            stale,
            MetricSampleState {
                id: "cpu",
                status: MetricSampleStatus::Present {
                    age_seconds: 21,
                    fresh: false,
                    bytes,
                    display_value: " 12".to_string(),
                },
            }
        );
    }

    fn spec() -> MetricSampleSpec {
        MetricSampleSpec {
            id: "cpu",
            state_option: CPU_SAMPLE_STATE_OPTION,
            display_option: CPU_NOW_OPTION,
            timestamp_seconds: cpu_sample_timestamp_seconds,
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
