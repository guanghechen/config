pub const STATUS_INTERVAL_SECONDS: u64 = 5;
pub const STATUS_INTERVAL_SECONDS_STR: &str = "5";
pub const HEARTBEAT_INTERVAL_SECONDS: u64 = 30;

// Samplers run at STATUS_INTERVAL_SECONDS; the wider freshness window tolerates
// run-shell scheduling jitter, process startup delay, and second-boundary rounding.
pub const METRIC_SAMPLE_STALE_LIMIT_SECONDS: u64 = STATUS_INTERVAL_SECONDS * 2;

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
