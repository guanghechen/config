use std::sync::OnceLock;
use std::time::Duration;

const TRACE_ENV: &str = "GHC_TMUX_STATUS_TRACE";

pub fn trace_enabled() -> bool {
    static ENABLED: OnceLock<bool> = OnceLock::new();
    *ENABLED.get_or_init(read_trace_enabled)
}

fn read_trace_enabled() -> bool {
    std::env::var(TRACE_ENV)
        .map(|value| {
            let normalized = value.trim().to_ascii_lowercase();
            !normalized.is_empty() && normalized != "0" && normalized != "false"
        })
        .unwrap_or(false)
}

pub fn trace_line(scope: &str, message: impl AsRef<str>) {
    if !trace_enabled() {
        return;
    }

    eprintln!("[ghc-tmux-status][{scope}] {}", message.as_ref());
}

pub fn duration_ms(duration: Duration) -> f64 {
    duration.as_secs_f64() * 1000.0
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::duration_ms;

    #[test]
    fn formats_duration_as_milliseconds() {
        assert_eq!(duration_ms(Duration::from_micros(1_500)), 1.5);
    }
}
