pub const STATUS_REDRAW_INTERVAL_SECONDS_STR: &str = "1";
pub const METRIC_RESAMPLE_INTERVAL_SECONDS: u64 = 5;
pub const HEARTBEAT_INTERVAL_SECONDS: u64 = 30;

// Samplers run at METRIC_RESAMPLE_INTERVAL_SECONDS; the wider freshness window
// tolerates run-shell scheduling jitter, process startup delay, and second-boundary
// rounding.
pub const METRIC_SAMPLE_STALE_LIMIT_SECONDS: u64 = METRIC_RESAMPLE_INTERVAL_SECONDS * 2;

pub const HEARTBEAT_GENERATION_OPTION: &str = "@GHC_SL_HEARTBEAT_GEN";
pub const METRIC_SAMPLE_GENERATION_OPTION: &str = "@GHC_SL_METRIC_GEN";

// Legacy generation guard is still bumped by load-theme so any old CPU-only chain
// expires after upgrading to the unified metric sampler.
pub const LEGACY_CPU_SAMPLE_GENERATION_OPTION: &str = "@GHC_SL_CPU_GEN";

pub const CPU_NOW_OPTION: &str = "@GHC_CPU_NOW";
pub const CPU_SAMPLE_STATE_OPTION: &str = "@GHC_SL_CPU_SAMPLE";
pub const MEMORY_NOW_OPTION: &str = "@GHC_MEM_NOW";
pub const MEMORY_SAMPLE_STATE_OPTION: &str = "@GHC_SL_MEM_SAMPLE";
pub const NETWORK_NOW_OPTION: &str = "@GHC_NET_NOW";
pub const NETWORK_SAMPLE_STATE_OPTION: &str = "@GHC_SL_NET_SAMPLE";

// Manual rows override for the adaptive layout: `auto` (or unset) keeps the
// width/session-count heuristic; `1` forces a single row, `2` forces two rows.
pub const ROWS_OVERRIDE_OPTION: &str = "@GHC_SL_ROWS";

pub const METRIC_LAST_OK_OPTION: &str = "@GHC_SL_METRIC_LAST_OK";
pub const METRIC_LAST_ERROR_OPTION: &str = "@GHC_SL_METRIC_LAST_ERR";
pub const METRIC_ERROR_COUNT_OPTION: &str = "@GHC_SL_METRIC_ERR_COUNT";
