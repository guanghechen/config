use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::error::{AppError, AppResult};
use crate::metric::{CpuSnapshot, MemorySnapshot, MetricsProvider, NetworkSample, NetworkSnapshot};

pub struct DarwinMetricsProvider {
    interface: String,
}

impl DarwinMetricsProvider {
    pub fn new(interface: &str) -> Self {
        Self {
            interface: interface.to_string(),
        }
    }
}

impl MetricsProvider for DarwinMetricsProvider {
    fn sample_cpu(&self) -> AppResult<CpuSnapshot> {
        Ok(CpuSnapshot {
            percent: read_cpu_percent()?,
            timestamp_seconds: unix_now(),
        })
    }

    fn sample_memory(&self) -> AppResult<MemorySnapshot> {
        Ok(MemorySnapshot {
            percent: read_memory_percent()?,
            timestamp_seconds: unix_now(),
        })
    }

    fn sample_network(&self, previous: Option<&NetworkSample>) -> AppResult<NetworkSnapshot> {
        let timestamp_seconds = unix_now();
        let (rx_bytes, tx_bytes) = read_network_counters(&self.interface)?;
        let (rx_bytes_per_second, tx_bytes_per_second) =
            calculate_speed(previous, timestamp_seconds, rx_bytes, tx_bytes);

        Ok(NetworkSnapshot {
            rx_bytes_per_second,
            tx_bytes_per_second,
            sample: NetworkSample {
                timestamp_seconds,
                rx_bytes,
                tx_bytes,
            },
        })
    }
}

fn read_cpu_percent() -> AppResult<f64> {
    let cpu_total = parse_ps_cpu_total(&command_output("ps", &["-A", "-o", "%cpu="])?)?;
    let cpu_count = command_output("sysctl", &["-n", "hw.ncpu"])?
        .trim()
        .parse::<f64>()
        .map_err(|_| AppError::Render("failed to parse hw.ncpu".to_string()))?;
    if cpu_count <= 0.0 {
        return Err(AppError::Render("invalid hw.ncpu".to_string()));
    }
    Ok((cpu_total / cpu_count).clamp(0.0, 100.0))
}

fn read_memory_percent() -> AppResult<f64> {
    let total_bytes = command_output("sysctl", &["-n", "hw.memsize"])?
        .trim()
        .parse::<f64>()
        .map_err(|_| AppError::Render("failed to parse hw.memsize".to_string()))?;
    let vm_stat = command_output("vm_stat", &[])?;
    parse_vm_stat_memory_percent(&vm_stat, total_bytes)
}

fn read_network_counters(interface: &str) -> AppResult<(u64, u64)> {
    let output = command_output("netstat", &["-bn", "-I", interface])?;
    parse_netstat_counters(&output)
}

fn command_output(command: &str, args: &[&str]) -> AppResult<String> {
    let output = Command::new(command).args(args).output()?;
    if !output.status.success() {
        return Err(AppError::Render(format!(
            "metrics command failed: {} {}",
            command,
            args.join(" ")
        )));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

fn parse_ps_cpu_total(output: &str) -> AppResult<f64> {
    let mut total = 0.0;
    for line in output.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        total += line
            .parse::<f64>()
            .map_err(|_| AppError::Render("failed to parse ps cpu field".to_string()))?;
    }
    Ok(total)
}

fn parse_vm_stat_memory_percent(output: &str, total_bytes: f64) -> AppResult<f64> {
    let page_size = output
        .lines()
        .next()
        .and_then(parse_page_size)
        .ok_or_else(|| AppError::Render("failed to parse vm_stat page size".to_string()))?;
    let mut used_pages = 0_u64;
    for line in output.lines() {
        if line.starts_with("Pages active:")
            || line.starts_with("Pages wired down:")
            || line.starts_with("Pages occupied by compressor:")
        {
            used_pages += parse_vm_stat_pages(line).unwrap_or_default();
        }
    }
    if total_bytes <= 0.0 {
        return Err(AppError::Render("invalid hw.memsize".to_string()));
    }
    let used_bytes = used_pages as f64 * page_size as f64;
    Ok((used_bytes * 100.0 / total_bytes).clamp(0.0, 100.0))
}

fn parse_page_size(line: &str) -> Option<u64> {
    let (_, rest) = line.split_once("page size of ")?;
    let size = rest.split_whitespace().next()?;
    size.parse::<u64>().ok()
}

fn parse_vm_stat_pages(line: &str) -> Option<u64> {
    let (_, value) = line.split_once(':')?;
    value
        .chars()
        .filter(|character| character.is_ascii_digit())
        .collect::<String>()
        .parse::<u64>()
        .ok()
}

fn parse_netstat_counters(output: &str) -> AppResult<(u64, u64)> {
    let line = output
        .lines()
        .find(|line| line.contains("<Link#"))
        .ok_or_else(|| AppError::Render("failed to find netstat link row".to_string()))?;
    let fields = line.split_whitespace().collect::<Vec<_>>();
    if fields.len() <= 9 {
        return Err(AppError::Render("invalid netstat link row".to_string()));
    }
    let rx_bytes = fields[6]
        .parse::<u64>()
        .map_err(|_| AppError::Render("failed to parse netstat rx bytes".to_string()))?;
    let tx_bytes = fields[9]
        .parse::<u64>()
        .map_err(|_| AppError::Render("failed to parse netstat tx bytes".to_string()))?;
    Ok((rx_bytes, tx_bytes))
}

fn calculate_speed(
    previous: Option<&NetworkSample>,
    timestamp_seconds: u64,
    rx_bytes: u64,
    tx_bytes: u64,
) -> (u64, u64) {
    let Some(previous) = previous else {
        return (0, 0);
    };
    let elapsed = timestamp_seconds.saturating_sub(previous.timestamp_seconds);
    if elapsed == 0 || rx_bytes < previous.rx_bytes || tx_bytes < previous.tx_bytes {
        return (0, 0);
    }
    (
        (rx_bytes - previous.rx_bytes) / elapsed,
        (tx_bytes - previous.tx_bytes) / elapsed,
    )
}

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::{
        calculate_speed, parse_netstat_counters, parse_ps_cpu_total, parse_vm_stat_memory_percent,
    };
    use crate::metric::NetworkSample;

    #[test]
    fn parses_ps_cpu_total() {
        let output = " 10.5\n2.0\n 0.5\n";
        assert_eq!(parse_ps_cpu_total(output).unwrap(), 13.0);
    }

    #[test]
    fn parses_vm_stat_memory_percent() {
        let output = "Mach Virtual Memory Statistics: (page size of 4096 bytes)\nPages active: 100.\nPages wired down: 50.\nPages free: 850.";
        assert_eq!(
            parse_vm_stat_memory_percent(output, 4096.0 * 1000.0).unwrap(),
            15.0
        );
    }

    #[test]
    fn parses_netstat_counters() {
        let output = "Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll\nen0 1500 <Link#15> aa:bb 10 0 1024 20 0 2048 0";
        assert_eq!(parse_netstat_counters(output).unwrap(), (1024, 2048));
    }

    #[test]
    fn calculates_network_speed() {
        let previous = NetworkSample {
            timestamp_seconds: 10,
            rx_bytes: 100,
            tx_bytes: 200,
        };
        assert_eq!(calculate_speed(Some(&previous), 20, 1100, 700), (100, 50));
    }
}
