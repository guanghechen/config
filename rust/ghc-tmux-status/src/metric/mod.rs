mod darwin;
pub mod publish;
pub mod state;

pub use darwin::{sample_cpu, sample_memory, sample_network};

/*
 * Live CPU/memory/network sampling is implemented for macOS only. Elsewhere the
 * metric pills are omitted and the scheduler never runs the metrics task.
 */
pub const METRICS_SUPPORTED: bool = cfg!(target_os = "macos");

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CpuSample {
    pub user: u64,
    pub nice: u64,
    pub system: u64,
    pub idle: u64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CpuSnapshot {
    pub percent: f64,
    pub timestamp_seconds: u64,
    pub sample: CpuSample,
}

#[derive(Clone, Debug, PartialEq)]
pub struct MemorySnapshot {
    pub percent: f64,
    pub timestamp_seconds: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct NetworkSample {
    /**
     * Rates divide by elapsed milliseconds; whole seconds would skew a ~4 s
     * sampling window by up to 25%.
     */
    pub timestamp_millis: u64,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
    /// Counter owner. A baseline from another interface must never be diffed.
    pub interface: String,
}

impl NetworkSample {
    /// Whole-second view for freshness checks shared with the other metrics.
    pub fn timestamp_seconds(&self) -> u64 {
        self.timestamp_millis / 1000
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct NetworkSnapshot {
    pub rx_bytes_per_second: u64,
    pub tx_bytes_per_second: u64,
    pub sample: NetworkSample,
}

// tmux option overriding the auto-detected primary network interface.
pub const NET_INTERFACE_OPTION: &str = "@GHC_SL_NET_IFACE";

pub fn normalize_network_interface(value: Option<&str>) -> Option<&str> {
    value.map(str::trim).filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::normalize_network_interface;

    #[test]
    fn normalize_network_interface_trims_and_filters_empty_values() {
        assert_eq!(normalize_network_interface(Some(" en0 ")), Some("en0"));
        assert_eq!(
            normalize_network_interface(Some("\tutun4\n")),
            Some("utun4")
        );
        assert_eq!(normalize_network_interface(Some("   ")), None);
        assert_eq!(normalize_network_interface(None), None);
    }
}
