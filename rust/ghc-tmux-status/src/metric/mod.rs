mod darwin;
mod unsupported;

use crate::error::AppResult;
use crate::platform::Platform;

pub use darwin::DarwinMetricsProvider;
pub use unsupported::UnsupportedMetricsProvider;

#[derive(Clone, Debug, PartialEq)]
pub struct CpuSnapshot {
    pub percent: f64,
    pub timestamp_seconds: u64,
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
}

#[derive(Clone, Debug, PartialEq)]
pub struct NetworkSnapshot {
    pub rx_bytes_per_second: u64,
    pub tx_bytes_per_second: u64,
    pub sample: NetworkSample,
}

pub trait MetricsProvider {
    fn sample_cpu(&self) -> AppResult<CpuSnapshot>;
    fn sample_memory(&self) -> AppResult<MemorySnapshot>;
    fn sample_network(&self, previous: Option<&NetworkSample>) -> AppResult<NetworkSnapshot>;
}

pub fn provider_for(platform: Platform) -> Box<dyn MetricsProvider> {
    match platform {
        Platform::Osx => Box::new(DarwinMetricsProvider::new("en0")),
        Platform::Win | Platform::Wsl | Platform::Nix => Box::new(UnsupportedMetricsProvider),
    }
}
