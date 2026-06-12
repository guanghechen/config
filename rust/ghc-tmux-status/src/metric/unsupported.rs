use crate::error::{AppError, AppResult};
use crate::metric::{CpuSnapshot, MemorySnapshot, MetricsProvider, NetworkSample, NetworkSnapshot};

pub struct UnsupportedMetricsProvider;

impl MetricsProvider for UnsupportedMetricsProvider {
    fn sample_cpu(&self) -> AppResult<CpuSnapshot> {
        Err(unsupported())
    }

    fn sample_memory(&self) -> AppResult<MemorySnapshot> {
        Err(unsupported())
    }

    fn sample_network(&self, _previous: Option<&NetworkSample>) -> AppResult<NetworkSnapshot> {
        Err(unsupported())
    }
}

fn unsupported() -> AppError {
    AppError::Render("system metrics are unsupported on this platform".to_string())
}
