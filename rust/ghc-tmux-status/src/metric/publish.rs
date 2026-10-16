use crate::config::{
    METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    METRIC_SAMPLE_STALE_LIMIT_SECONDS,
};
use crate::util::format::sanitize_option_text;

#[derive(Default)]
pub struct MetricPublishSummary {
    pub cpu_published: bool,
    pub memory_published: bool,
    pub network_published: bool,
    pub errors: Vec<String>,
}

pub fn is_recent_sample(
    previous_timestamp_seconds: Option<u64>,
    current_timestamp_seconds: u64,
) -> bool {
    previous_timestamp_seconds.is_some_and(|previous_timestamp_seconds| {
        current_timestamp_seconds.saturating_sub(previous_timestamp_seconds)
            <= METRIC_SAMPLE_STALE_LIMIT_SECONDS
    })
}

pub fn parse_metric_error_count(value: Option<&str>) -> u64 {
    value
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or_default()
}

pub fn metric_health_sets(
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
