use std::process::Command;
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::error::{AppError, AppResult};
use crate::metric::{
    CpuSample, CpuSnapshot, MemorySnapshot, MetricsProvider, NetworkSample, NetworkSnapshot,
};

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
    fn sample_cpu(&self, previous: Option<&CpuSample>) -> AppResult<CpuSnapshot> {
        let sample = read_cpu_sample()?;
        Ok(CpuSnapshot {
            percent: calculate_cpu_percent(previous, &sample),
            timestamp_seconds: unix_now(),
            sample,
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

fn read_cpu_sample() -> AppResult<CpuSample> {
    read_cpu_sample_native()
}

#[cfg(target_os = "macos")]
fn read_cpu_sample_native() -> AppResult<CpuSample> {
    let mut info = HostCpuLoadInfo::default();
    let mut count = HOST_CPU_LOAD_INFO_COUNT;
    let result = unsafe {
        host_statistics(
            mach_host_self(),
            HOST_CPU_LOAD_INFO,
            (&mut info as *mut HostCpuLoadInfo).cast::<Integer>(),
            &mut count,
        )
    };
    if result != KERN_SUCCESS {
        return Err(AppError::Render(
            "host_statistics cpu load failed".to_string(),
        ));
    }

    Ok(CpuSample {
        user: info.cpu_ticks[CPU_STATE_USER].into(),
        system: info.cpu_ticks[CPU_STATE_SYSTEM].into(),
        idle: info.cpu_ticks[CPU_STATE_IDLE].into(),
        nice: info.cpu_ticks[CPU_STATE_NICE].into(),
    })
}

#[cfg(not(target_os = "macos"))]
fn read_cpu_sample_native() -> AppResult<CpuSample> {
    Err(AppError::Render(
        "native darwin cpu sampling is unavailable".to_string(),
    ))
}

fn calculate_cpu_percent(previous: Option<&CpuSample>, current: &CpuSample) -> f64 {
    let Some(previous) = previous else {
        return cpu_percent_from_ticks(current.user, current.nice, current.system, current.idle);
    };

    let user = current.user.saturating_sub(previous.user);
    let nice = current.nice.saturating_sub(previous.nice);
    let system = current.system.saturating_sub(previous.system);
    let idle = current.idle.saturating_sub(previous.idle);
    cpu_percent_from_ticks(user, nice, system, idle)
}

fn cpu_percent_from_ticks(user: u64, nice: u64, system: u64, idle: u64) -> f64 {
    let used = user.saturating_add(nice).saturating_add(system);
    let total = used.saturating_add(idle);
    if total == 0 {
        return 0.0;
    }
    (used as f64 * 100.0 / total as f64).clamp(0.0, 100.0)
}

fn read_memory_percent() -> AppResult<f64> {
    let total_bytes = darwin_system_info()?.memory_bytes as f64;
    let vm_stat = command_output("vm_stat", &[])?;
    parse_vm_stat_memory_percent(&vm_stat, total_bytes)
}

#[derive(Clone, Debug)]
struct DarwinSystemInfo {
    memory_bytes: u64,
}

fn darwin_system_info() -> AppResult<&'static DarwinSystemInfo> {
    static SYSTEM_INFO: OnceLock<AppResult<DarwinSystemInfo>> = OnceLock::new();
    SYSTEM_INFO
        .get_or_init(read_darwin_system_info)
        .as_ref()
        .map_err(|error| AppError::Render(error.to_string()))
}

fn read_darwin_system_info() -> AppResult<DarwinSystemInfo> {
    let memory_bytes = command_output("sysctl", &["-n", "hw.memsize"])?
        .trim()
        .parse::<u64>()
        .map_err(|_| AppError::Render("failed to parse hw.memsize".to_string()))?;
    Ok(DarwinSystemInfo { memory_bytes })
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

#[cfg(target_os = "macos")]
type Integer = i32;
#[cfg(target_os = "macos")]
type MachPort = u32;
#[cfg(target_os = "macos")]
type MachMsgTypeNumber = u32;
#[cfg(target_os = "macos")]
type KernReturn = i32;

#[cfg(target_os = "macos")]
#[repr(C)]
#[derive(Default)]
struct HostCpuLoadInfo {
    cpu_ticks: [u32; CPU_STATE_MAX],
}

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn mach_host_self() -> MachPort;
    fn host_statistics(
        host: MachPort,
        flavor: i32,
        host_info_out: *mut Integer,
        host_info_out_count: *mut MachMsgTypeNumber,
    ) -> KernReturn;
}

#[cfg(target_os = "macos")]
const KERN_SUCCESS: KernReturn = 0;
#[cfg(target_os = "macos")]
const HOST_CPU_LOAD_INFO: i32 = 3;
#[cfg(target_os = "macos")]
const CPU_STATE_USER: usize = 0;
#[cfg(target_os = "macos")]
const CPU_STATE_SYSTEM: usize = 1;
#[cfg(target_os = "macos")]
const CPU_STATE_IDLE: usize = 2;
#[cfg(target_os = "macos")]
const CPU_STATE_NICE: usize = 3;
#[cfg(target_os = "macos")]
const CPU_STATE_MAX: usize = 4;
#[cfg(target_os = "macos")]
const HOST_CPU_LOAD_INFO_COUNT: MachMsgTypeNumber = 4;

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::{
        calculate_cpu_percent, calculate_speed, cpu_percent_from_ticks, parse_netstat_counters,
        parse_vm_stat_memory_percent, read_cpu_sample, read_darwin_system_info,
    };
    use crate::metric::{CpuSample, NetworkSample};

    #[test]
    fn calculates_cpu_percent_from_ticks() {
        assert_eq!(cpu_percent_from_ticks(1, 1, 2, 6), 40.0);
        let previous = CpuSample {
            user: 10,
            nice: 10,
            system: 10,
            idle: 70,
        };
        let current = CpuSample {
            user: 20,
            nice: 10,
            system: 20,
            idle: 100,
        };
        assert_eq!(calculate_cpu_percent(Some(&previous), &current), 40.0);
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn reads_cpu_sample() {
        let sample = read_cpu_sample().unwrap();
        assert!(sample.user + sample.nice + sample.system + sample.idle > 0);
    }

    #[test]
    fn parses_vm_stat_memory_percent() {
        let output = "Mach Virtual Memory Statistics: (page size of 4096 bytes)\nPages active: 100.\nPages wired down: 50.\nPages free: 850.";
        assert_eq!(
            parse_vm_stat_memory_percent(output, 4096.0 * 1000.0).unwrap(),
            15.0
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn parses_darwin_system_info() {
        let info = read_darwin_system_info().unwrap();
        assert!(info.memory_bytes > 0);
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
