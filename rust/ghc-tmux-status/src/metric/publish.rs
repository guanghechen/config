use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, MEMORY_NOW_OPTION, MEMORY_SAMPLE_STATE_OPTION,
    METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    METRIC_SAMPLE_STALE_LIMIT_SECONDS, NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION,
};
use crate::metric::state::{
    decode_cpu_snapshot, decode_memory_snapshot, decode_network_snapshot, encode_cpu_snapshot,
    encode_memory_snapshot, encode_network_snapshot, format_network_now, format_percent,
};
use crate::metric::{normalize_network_interface, sample_cpu, sample_memory, sample_network};
use crate::util::format::sanitize_option_text;
use crate::util::time::unix_timestamp_seconds;

#[derive(Default)]
pub struct MetricPublishSummary {
    pub cpu_published: bool,
    pub memory_published: bool,
    pub network_published: bool,
    pub errors: Vec<String>,
}

/// The persisted option values one metrics tick starts from.
pub struct MetricInputs<'a> {
    pub cpu_state: &'a str,
    pub memory_state: &'a str,
    pub network_state: &'a str,
    pub network_interface: &'a str,
    pub error_count: &'a str,
}

/// The option writes a metrics completion carries, and what they published.
pub struct MetricSample {
    pub summary: MetricPublishSummary,
    pub sets: Vec<(&'static str, String)>,
}

/**
 * Samples every metric against its previous persisted state. Each metric
 * degrades on its own: a failed sample keeps the last published value, and CPU
 * and network publish a rate only from a recent baseline. Health options then
 * summarize the tick.
 */
pub fn collect_sample(inputs: &MetricInputs<'_>) -> MetricSample {
    let previous_cpu = decode_cpu_snapshot(inputs.cpu_state);
    let previous_memory = decode_memory_snapshot(inputs.memory_state);
    let previous_network = decode_network_snapshot(inputs.network_state);
    let mut summary = MetricPublishSummary::default();
    let mut sets = Vec::new();

    match sample_cpu(previous_cpu.as_ref().map(|snapshot| &snapshot.sample)) {
        Ok(snapshot) => {
            sets.push((CPU_SAMPLE_STATE_OPTION, encode_cpu_snapshot(&snapshot)));
            if is_recent_sample(
                previous_cpu.map(|previous| previous.timestamp_seconds),
                snapshot.timestamp_seconds,
            ) {
                sets.push((CPU_NOW_OPTION, format_percent(snapshot.percent)));
                summary.cpu_published = true;
            }
        }
        Err(error) => summary.errors.push(format!("cpu:{error}")),
    }

    match sample_memory() {
        Ok(snapshot) => {
            sets.push((
                MEMORY_SAMPLE_STATE_OPTION,
                encode_memory_snapshot(&snapshot),
            ));
            sets.push((MEMORY_NOW_OPTION, format_percent(snapshot.percent)));
            summary.memory_published = true;
        }
        Err(error) if previous_memory.is_none() => summary.errors.push(format!("memory:{error}")),
        Err(error) => summary.errors.push(format!("memory:{error}:kept-last")),
    }

    match sample_network(
        previous_network.as_ref().map(|snapshot| &snapshot.sample),
        normalize_network_interface(Some(inputs.network_interface)),
    ) {
        Ok(snapshot) => {
            sets.push((
                NETWORK_SAMPLE_STATE_OPTION,
                encode_network_snapshot(&snapshot),
            ));
            if is_recent_sample(
                previous_network.map(|previous| previous.sample.timestamp_seconds()),
                snapshot.sample.timestamp_seconds(),
            ) {
                sets.push((NETWORK_NOW_OPTION, format_network_now(&snapshot)));
                summary.network_published = true;
            }
        }
        Err(error) => summary.errors.push(format!("network:{error}")),
    }

    sets.extend(metric_health_sets(
        &summary,
        parse_metric_error_count(Some(inputs.error_count)),
        unix_timestamp_seconds(),
    ));
    MetricSample { summary, sets }
}

fn is_recent_sample(
    previous_timestamp_seconds: Option<u64>,
    current_timestamp_seconds: u64,
) -> bool {
    previous_timestamp_seconds.is_some_and(|previous_timestamp_seconds| {
        current_timestamp_seconds.saturating_sub(previous_timestamp_seconds)
            <= METRIC_SAMPLE_STALE_LIMIT_SECONDS
    })
}

fn parse_metric_error_count(value: Option<&str>) -> u64 {
    value
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or_default()
}

fn metric_health_sets(
    summary: &MetricPublishSummary,
    previous_error_count: u64,
    now_seconds: u64,
) -> Vec<(&'static str, String)> {
    if summary.errors.is_empty() {
        return vec![
            (METRIC_LAST_OK_OPTION, now_seconds.to_string()),
            (METRIC_ERROR_COUNT_OPTION, "0".to_string()),
        ];
    }

    vec![
        (
            METRIC_LAST_ERROR_OPTION,
            format!(
                "{}\t{}",
                now_seconds,
                sanitize_option_text(&summary.errors.join("; "))
            ),
        ),
        (
            METRIC_ERROR_COUNT_OPTION,
            previous_error_count.saturating_add(1).to_string(),
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::{MetricPublishSummary, metric_health_sets, parse_metric_error_count};
    use crate::config::{
        METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    };

    #[test]
    fn parse_metric_error_count_uses_zero_for_missing_or_invalid_values() {
        assert_eq!(parse_metric_error_count(Some("7")), 7);
        assert_eq!(parse_metric_error_count(Some("bad")), 0);
        assert_eq!(parse_metric_error_count(None), 0);
    }

    #[test]
    fn metric_health_sets_reset_error_count_on_clean_sample() {
        let summary = MetricPublishSummary::default();
        assert_eq!(
            metric_health_sets(&summary, 3, 100),
            vec![
                (METRIC_LAST_OK_OPTION, "100".to_string()),
                (METRIC_ERROR_COUNT_OPTION, "0".to_string()),
            ]
        );
    }

    #[test]
    fn metric_health_sets_increment_error_count_and_records_last_error() {
        let summary = MetricPublishSummary {
            errors: vec!["network:failed\tbadly".to_string()],
            ..MetricPublishSummary::default()
        };
        assert_eq!(
            metric_health_sets(&summary, 3, 100),
            vec![
                (
                    METRIC_LAST_ERROR_OPTION,
                    "100\tnetwork:failed badly".to_string()
                ),
                (METRIC_ERROR_COUNT_OPTION, "4".to_string()),
            ]
        );
    }
}
