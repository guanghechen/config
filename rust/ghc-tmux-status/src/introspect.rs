use crate::cache::WIDGET_CACHE_OPTION_PREFIX;
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, MEMORY_NOW_OPTION, MEMORY_SAMPLE_STATE_OPTION,
    METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    METRIC_SAMPLE_STALE_LIMIT_SECONDS, NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION,
    SCHEDULER_ACTIVE_OPTION, SCHEDULER_GENERATION_OPTION,
};
use crate::model::TmuxSnapshot;
use crate::platform::current_platform;
use crate::scheduler::{ScheduleState, SchedulerTask};
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

pub fn scheduler_state_lines(snapshot: &TmuxSnapshot) -> Vec<String> {
    scheduler_state_lines_at(
        snapshot,
        crate::util::time::unix_timestamp_seconds(),
        current_platform().supports_metrics(),
    )
}

fn scheduler_state_lines_at(
    snapshot: &TmuxSnapshot,
    now_seconds: u64,
    metrics_supported: bool,
) -> Vec<String> {
    let active = snapshot
        .options
        .get(SCHEDULER_ACTIVE_OPTION)
        .map(String::as_str)
        == Some("1");
    let generation = snapshot
        .options
        .get(SCHEDULER_GENERATION_OPTION)
        .and_then(|value| value.parse::<u64>().ok());
    let mut lines = vec![format!(
        "lifecycle active={} generation={}",
        active,
        generation
            .map(|value| value.to_string())
            .unwrap_or_else(|| "invalid".to_string())
    )];
    for task in SchedulerTask::ALL {
        lines.push(scheduler_task_line(
            snapshot,
            task,
            active,
            generation,
            now_seconds,
            metrics_supported,
        ));
    }
    lines
}

fn scheduler_task_line(
    snapshot: &TmuxSnapshot,
    task: SchedulerTask,
    active: bool,
    generation: Option<u64>,
    now_seconds: u64,
    metrics_supported: bool,
) -> String {
    let raw_state = snapshot
        .options
        .get(task.state_option())
        .map(String::as_str)
        .unwrap_or_default();
    let state = ScheduleState::parse(raw_state);
    let last_attempt = option_timestamp(snapshot.options.get(task.last_attempt_option()));
    let last_complete = option_timestamp(snapshot.options.get(task.last_complete_option()));
    let status = match (task, metrics_supported, active, generation, state.as_ref()) {
        (SchedulerTask::Metrics, false, _, _, _) => "unsupported",
        (_, _, false, _, _) => "inactive",
        (_, _, true, None, _) => "invalid",
        (_, _, true, Some(_), None) => "starting",
        (_, _, true, Some(generation), Some(state)) if state.generation != generation => "starting",
        (_, _, true, Some(_), Some(state)) if state.lease_until_seconds > now_seconds => "running",
        (_, _, true, Some(_), Some(state)) if state.lease_until_seconds != 0 => "lease-expired",
        (_, _, true, Some(_), Some(state))
            if now_seconds
                > state
                    .next_due_seconds
                    .saturating_add(task.interval_seconds()) =>
        {
            "overdue"
        }
        (_, _, true, Some(_), Some(_))
            if last_complete.is_none() || last_attempt > last_complete =>
        {
            "degraded"
        }
        (_, _, true, Some(_), Some(_)) => "healthy",
    };
    let sequence = state
        .as_ref()
        .map(|state| state.sequence.to_string())
        .unwrap_or_else(|| "missing".to_string());
    let next_due_in = state
        .as_ref()
        .map(|state| {
            state
                .next_due_seconds
                .saturating_sub(now_seconds)
                .to_string()
        })
        .unwrap_or_else(|| "missing".to_string());
    let lease_remaining = state
        .as_ref()
        .map(|state| {
            state
                .lease_until_seconds
                .saturating_sub(now_seconds)
                .to_string()
        })
        .unwrap_or_else(|| "missing".to_string());
    let last_attempt_age = timestamp_age(last_attempt, now_seconds);
    let last_complete_age = timestamp_age(last_complete, now_seconds);
    let last_outcome = snapshot
        .options
        .get(task.last_outcome_option())
        .map(|value| value.replace(['\t', '\n', '\r'], " "))
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "<none>".to_string());
    format!(
        "{} status={} sequence={} next_due_in_seconds={} lease_remaining_seconds={} last_attempt_age_seconds={} last_complete_age_seconds={} last_outcome={}",
        task.as_str(),
        status,
        sequence,
        next_due_in,
        lease_remaining,
        last_attempt_age,
        last_complete_age,
        last_outcome
    )
}

fn option_timestamp(value: Option<&String>) -> Option<u64> {
    value.and_then(|value| value.parse::<u64>().ok())
}

fn timestamp_age(timestamp: Option<u64>, now_seconds: u64) -> String {
    timestamp
        .map(|timestamp| now_seconds.saturating_sub(timestamp).to_string())
        .unwrap_or_else(|| "missing".to_string())
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
        scheduler_state_lines_at,
    };
    use crate::config::{
        CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, METRIC_ERROR_COUNT_OPTION,
        METRIC_LAST_ATTEMPT_OPTION, METRIC_LAST_COMPLETE_OPTION, METRIC_LAST_ERROR_OPTION,
        METRIC_LAST_EXEC_OUTCOME_OPTION, METRIC_LAST_OK_OPTION, METRIC_SCHEDULER_STATE_OPTION,
        SCHEDULER_ACTIVE_OPTION, SCHEDULER_GENERATION_OPTION,
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
    fn scheduler_state_reports_running_and_completion_ages() {
        let snapshot = snapshot_with_options(BTreeMap::from([
            (SCHEDULER_ACTIVE_OPTION.to_string(), "1".to_string()),
            (SCHEDULER_GENERATION_OPTION.to_string(), "7".to_string()),
            (
                METRIC_SCHEDULER_STATE_OPTION.to_string(),
                "7:4:105:110".to_string(),
            ),
            (METRIC_LAST_ATTEMPT_OPTION.to_string(), "98".to_string()),
            (METRIC_LAST_COMPLETE_OPTION.to_string(), "95".to_string()),
            (
                METRIC_LAST_EXEC_OUTCOME_OPTION.to_string(),
                "95\t7\t4\tcomplete\tknown\tok".to_string(),
            ),
        ]));

        let lines = scheduler_state_lines_at(&snapshot, 100, true);

        assert_eq!(lines[0], "lifecycle active=true generation=7");
        assert!(lines[1].contains("metrics status=running sequence=4"));
        assert!(lines[1].contains("lease_remaining_seconds=10"));
        assert!(lines[1].contains("last_attempt_age_seconds=2"));
        assert!(lines[1].contains("last_complete_age_seconds=5"));
        assert!(lines[1].contains("last_outcome=95 7 4 complete known ok"));
        assert!(lines[2].contains("heartbeat status=starting"));
    }

    #[test]
    fn scheduler_state_does_not_report_missing_completion_as_healthy() {
        let snapshot = snapshot_with_options(BTreeMap::from([
            (SCHEDULER_ACTIVE_OPTION.to_string(), "1".to_string()),
            (SCHEDULER_GENERATION_OPTION.to_string(), "7".to_string()),
            (
                METRIC_SCHEDULER_STATE_OPTION.to_string(),
                "7:4:105:0".to_string(),
            ),
            (METRIC_LAST_ATTEMPT_OPTION.to_string(), "98".to_string()),
        ]));

        let lines = scheduler_state_lines_at(&snapshot, 100, true);

        assert!(lines[1].contains("metrics status=degraded"));
    }

    #[test]
    fn scheduler_state_reports_expired_incomplete_lease() {
        let snapshot = snapshot_with_options(BTreeMap::from([
            (SCHEDULER_ACTIVE_OPTION.to_string(), "1".to_string()),
            (SCHEDULER_GENERATION_OPTION.to_string(), "7".to_string()),
            (
                METRIC_SCHEDULER_STATE_OPTION.to_string(),
                "7:4:130:120".to_string(),
            ),
            (METRIC_LAST_ATTEMPT_OPTION.to_string(), "100".to_string()),
            (METRIC_LAST_COMPLETE_OPTION.to_string(), "100".to_string()),
        ]));

        let lines = scheduler_state_lines_at(&snapshot, 121, true);

        assert!(lines[1].contains("metrics status=lease-expired"));
    }

    #[test]
    fn scheduler_state_marks_metrics_unsupported() {
        let snapshot = snapshot_with_options(BTreeMap::from([
            (SCHEDULER_ACTIVE_OPTION.to_string(), "1".to_string()),
            (SCHEDULER_GENERATION_OPTION.to_string(), "7".to_string()),
        ]));

        let lines = scheduler_state_lines_at(&snapshot, 100, false);

        assert!(lines[1].contains("metrics status=unsupported"));
        assert!(lines[2].contains("heartbeat status=starting"));
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
            status: "on".to_string(),
            width: 200,
            current_session_name: "s".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: Vec::new(),
            client_widths: Vec::new(),
            options,
        }
    }
}
