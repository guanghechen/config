mod darwin;
mod unsupported;

use crate::error::AppResult;
use crate::platform::{Platform, current_platform};

pub use darwin::DarwinMetricsProvider;
pub use unsupported::UnsupportedMetricsProvider;

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
    pub timestamp_seconds: u64,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
    /// Counter owner. A baseline from another interface must never be diffed.
    pub interface: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct NetworkSnapshot {
    pub rx_bytes_per_second: u64,
    pub tx_bytes_per_second: u64,
    pub sample: NetworkSample,
}

/// Read-only sampling boundary. `StatusRuntime` creates one provider per sampler tick
/// and remains the single writer of tmux metric state. Providers do not retry; external
/// commands use the shared bounded process runner. Each method returns `AppError`, and the
/// runtime degrades that metric independently before publishing available values and
/// rescheduling in one tmux invocation.
pub trait MetricsProvider {
    fn sample_cpu(&self, previous: Option<&CpuSample>) -> AppResult<CpuSnapshot>;
    fn sample_memory(&self) -> AppResult<MemorySnapshot>;
    fn sample_network(&self, previous: Option<&NetworkSample>) -> AppResult<NetworkSnapshot>;
}

pub fn provider_for_current_platform(interface: Option<&str>) -> Box<dyn MetricsProvider> {
    provider_for(current_platform(), interface)
}

pub fn provider_for(platform: Platform, interface: Option<&str>) -> Box<dyn MetricsProvider> {
    match platform {
        Platform::Osx => Box::new(DarwinMetricsProvider::new(interface)),
        Platform::Win | Platform::Wsl | Platform::Nix => Box::new(UnsupportedMetricsProvider),
    }
}

// tmux option overriding the auto-detected primary network interface.
pub const NET_INTERFACE_OPTION: &str = "@GHC_SL_NET_IFACE";
