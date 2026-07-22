pub const STATUS_LEFT_OPTION: &str = "status-left";
pub const STATUS_RIGHT_OPTION: &str = "status-right";
pub const STATUS_POSITION_OPTION: &str = "status-position";
pub const STATUS_JUSTIFY_OPTION: &str = "status-justify";
pub const STATUS_INTERVAL_OPTION: &str = "status-interval";
pub const STATUS_FORMAT_0_OPTION: &str = "status-format[0]";
pub const STATUS_FORMAT_1_OPTION: &str = "status-format[1]";

pub const STATUS_LEFT_FORMAT: &str =
    "#($HOME/.config/tmux/script/status-scheduler.sh)#{E:@GHC_SL_STATUS02_LEFT}";
pub const STATUS_RIGHT_FORMAT: &str = "#{E:@GHC_SL_STATUS02_RIGHT}";
pub const STATUS_JUSTIFY_VALUE: &str = "centre";
pub const STATUS_SESSION_FORMAT: &str = "#($HOME/.config/tmux/script/status-scheduler.sh)#[default]#[align=left]#{E:@GHC_SL_STATUS02_LEFT}#[align=right]#{E:@GHC_SL_STATUS02_SESSION_FORMAT}#[default]";
pub const STATUS_CURRENT_FORMAT: &str = "#{E:@GHC_SL_STATUS02_CURRENT_FORMAT}";
pub const STATUS_REDRAW_INTERVAL_SECONDS_STR: &str = "1";
pub const METRIC_RESAMPLE_INTERVAL_SECONDS: u64 = 5;
pub const HEARTBEAT_INTERVAL_SECONDS: u64 = 30;
pub const METRIC_EXECUTION_BUDGET_SECONDS: u64 = 8;
pub const METRIC_EXECUTION_LEASE_SECONDS: u64 = 15;
pub const HEARTBEAT_EXECUTION_BUDGET_SECONDS: u64 = 10;
pub const HEARTBEAT_EXECUTION_LEASE_SECONDS: u64 = 20;

// Samples become due at METRIC_RESAMPLE_INTERVAL_SECONDS; the wider freshness
// window tolerates the tmux #() driver cadence, process startup, and rounding.
pub const METRIC_SAMPLE_STALE_LIMIT_SECONDS: u64 = METRIC_RESAMPLE_INTERVAL_SECONDS * 2;

// load-theme owns these server-scoped generation tokens. It mirrors the same
// values to global session options only so pre-upgrade renderer chains expire.
pub const HEARTBEAT_GENERATION_OPTION: &str = "@GHC_SL_HEARTBEAT_GEN";
pub const METRIC_SAMPLE_GENERATION_OPTION: &str = "@GHC_SL_METRIC_GEN";

pub const SCHEDULER_ACTIVE_OPTION: &str = "@GHC_SL_SCHED_ACTIVE";
pub const SCHEDULER_GENERATION_OPTION: &str = "@GHC_SL_SCHED_GEN";
pub const METRIC_SCHEDULER_STATE_OPTION: &str = "@GHC_SL_METRIC_SCHED";
pub const HEARTBEAT_SCHEDULER_STATE_OPTION: &str = "@GHC_SL_HEARTBEAT_SCHED";
pub const METRIC_LAST_ATTEMPT_OPTION: &str = "@GHC_SL_METRIC_LAST_ATTEMPT";
pub const METRIC_LAST_COMPLETE_OPTION: &str = "@GHC_SL_METRIC_LAST_COMPLETE";
pub const METRIC_LAST_EXEC_OUTCOME_OPTION: &str = "@GHC_SL_METRIC_LAST_EXEC_OUTCOME";
pub const HEARTBEAT_LAST_ATTEMPT_OPTION: &str = "@GHC_SL_HEARTBEAT_LAST_ATTEMPT";
pub const HEARTBEAT_LAST_COMPLETE_OPTION: &str = "@GHC_SL_HEARTBEAT_LAST_COMPLETE";
pub const HEARTBEAT_LAST_EXEC_OUTCOME_OPTION: &str = "@GHC_SL_HEARTBEAT_LAST_EXEC_OUTCOME";

pub const CPU_NOW_OPTION: &str = "@GHC_CPU_NOW";
pub const CPU_SAMPLE_STATE_OPTION: &str = "@GHC_SL_CPU_SAMPLE";
pub const MEMORY_NOW_OPTION: &str = "@GHC_MEM_NOW";
pub const MEMORY_SAMPLE_STATE_OPTION: &str = "@GHC_SL_MEM_SAMPLE";
pub const NETWORK_NOW_OPTION: &str = "@GHC_NET_NOW";
pub const NETWORK_SAMPLE_STATE_OPTION: &str = "@GHC_SL_NET_SAMPLE";

// Manual rows override for the adaptive layout: `auto` (or unset) keeps the
// width/session-count heuristic; `1` forces a single row, `2` forces two rows.
pub const ROWS_OVERRIDE_OPTION: &str = "@GHC_SL_ROWS";
pub const RENDER_REVISION_OPTION: &str = "@GHC_SL_RENDER_REV";
pub const SESSION_RENDER_KEY_OPTION: &str = "@GHC_SL_RENDER_KEY";

pub const METRIC_LAST_OK_OPTION: &str = "@GHC_SL_METRIC_LAST_OK";
pub const METRIC_LAST_ERROR_OPTION: &str = "@GHC_SL_METRIC_LAST_ERR";
pub const METRIC_ERROR_COUNT_OPTION: &str = "@GHC_SL_METRIC_ERR_COUNT";

#[cfg(test)]
mod tests {
    use super::{STATUS_LEFT_FORMAT, STATUS_SESSION_FORMAT};

    #[test]
    fn fail_closed_scheduler_driver_is_present_once_in_one_and_two_row_formats() {
        for format in [STATUS_LEFT_FORMAT, STATUS_SESSION_FORMAT] {
            assert_eq!(format.matches("status-scheduler.sh").count(), 1);
            assert!(format.starts_with("#($HOME/.config/tmux/script/status-scheduler.sh)"));
            assert!(!format.contains("scheduler-tick"));
        }
    }
}
