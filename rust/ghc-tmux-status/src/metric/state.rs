/*!
 * Persisted sample state (`@GHC_SL_*_SAMPLE`) and the display values a metrics
 * tick publishes from it (`@GHC_*_NOW`).
 */

use crate::metric::{CpuSample, CpuSnapshot, MemorySnapshot, NetworkSample, NetworkSnapshot};

/*
 * Leading field of the millisecond-timestamp layout. A value without it is not
 * a baseline: the next sample starts fresh instead of misreading its timestamp.
 */
const MILLIS_SNAPSHOT_TAG: &str = "v2";

pub fn encode_cpu_snapshot(snapshot: &CpuSnapshot) -> String {
    format!(
        "{}\t{}\t{}\t{}\t{}\t{}",
        snapshot.timestamp_seconds,
        snapshot.percent,
        snapshot.sample.user,
        snapshot.sample.nice,
        snapshot.sample.system,
        snapshot.sample.idle
    )
}

pub fn decode_cpu_snapshot(value: &str) -> Option<CpuSnapshot> {
    let mut parts = value.splitn(6, '\t');
    Some(CpuSnapshot {
        timestamp_seconds: parts.next()?.parse::<u64>().ok()?,
        percent: parts.next()?.parse::<f64>().ok()?,
        sample: CpuSample {
            user: parts.next()?.parse::<u64>().ok()?,
            nice: parts.next()?.parse::<u64>().ok()?,
            system: parts.next()?.parse::<u64>().ok()?,
            idle: parts.next()?.parse::<u64>().ok()?,
        },
    })
}

pub fn encode_memory_snapshot(snapshot: &MemorySnapshot) -> String {
    format!("{}\t{}", snapshot.timestamp_seconds, snapshot.percent)
}

pub fn decode_memory_snapshot(value: &str) -> Option<MemorySnapshot> {
    let mut parts = value.splitn(2, '\t');
    Some(MemorySnapshot {
        timestamp_seconds: parts.next()?.parse::<u64>().ok()?,
        percent: parts.next()?.parse::<f64>().ok()?,
    })
}

pub fn encode_network_snapshot(snapshot: &NetworkSnapshot) -> String {
    format!(
        "{MILLIS_SNAPSHOT_TAG}\t{}\t{}\t{}\t{}\t{}\t{}",
        snapshot.sample.timestamp_millis,
        snapshot.sample.rx_bytes,
        snapshot.sample.tx_bytes,
        snapshot.rx_bytes_per_second,
        snapshot.tx_bytes_per_second,
        snapshot.sample.interface
    )
}

pub fn decode_network_snapshot(value: &str) -> Option<NetworkSnapshot> {
    let fields = value
        .strip_prefix(MILLIS_SNAPSHOT_TAG)?
        .strip_prefix('\t')?;
    let mut parts = fields.splitn(6, '\t');
    let timestamp_millis = parts.next()?.parse::<u64>().ok()?;
    let rx_bytes = parts.next()?.parse::<u64>().ok()?;
    let tx_bytes = parts.next()?.parse::<u64>().ok()?;
    let rx_bytes_per_second = parts.next()?.parse::<u64>().ok()?;
    let tx_bytes_per_second = parts.next()?.parse::<u64>().ok()?;
    Some(NetworkSnapshot {
        sample: NetworkSample {
            timestamp_millis,
            rx_bytes,
            tx_bytes,
            interface: parts.next().unwrap_or_default().to_string(),
        },
        rx_bytes_per_second,
        tx_bytes_per_second,
    })
}

/// Right-aligned to two columns, matching the pill's fixed-width shadow.
pub fn format_percent(percent: f64) -> String {
    let value = percent.round().clamp(0.0, 100.0) as u64;
    format!("{value:>2}")
}

pub fn format_network_now(snapshot: &NetworkSnapshot) -> String {
    let rx = format_speed(snapshot.rx_bytes_per_second);
    let tx = format_speed(snapshot.tx_bytes_per_second);
    format!("↓{rx} ↑{tx}")
}

fn format_speed(bytes_per_second: u64) -> String {
    const KIB: f64 = 1024.0;
    const MIB: f64 = 1024.0 * 1024.0;
    const GIB: f64 = 1024.0 * 1024.0 * 1024.0;

    let value = bytes_per_second as f64;
    if value >= GIB {
        return format_unit(value / GIB, "G");
    }
    if value >= MIB {
        return format_unit(value / MIB, "M");
    }
    if value >= KIB {
        return format_unit(value / KIB, "K");
    }
    format!("{bytes_per_second}B")
}

fn format_unit(value: f64, suffix: &str) -> String {
    if value >= 99.95 {
        let rounded = value.round().min(999.0) as u64;
        return format!("{rounded}{suffix}");
    }
    format!("{value:.1}{suffix}")
}

#[cfg(test)]
mod tests {
    use super::{
        decode_cpu_snapshot, decode_memory_snapshot, decode_network_snapshot, encode_cpu_snapshot,
        encode_memory_snapshot, encode_network_snapshot, format_network_now, format_percent,
        format_speed,
    };
    use crate::metric::{CpuSample, CpuSnapshot, MemorySnapshot, NetworkSample, NetworkSnapshot};

    #[test]
    fn round_trips_cpu_snapshot() {
        let snapshot = CpuSnapshot {
            percent: 12.0,
            timestamp_seconds: 1,
            sample: CpuSample {
                user: 1,
                nice: 2,
                system: 3,
                idle: 4,
            },
        };
        let parsed = decode_cpu_snapshot(&encode_cpu_snapshot(&snapshot)).unwrap();
        assert_eq!(parsed, snapshot);
    }

    #[test]
    fn round_trips_memory_snapshot() {
        let snapshot = MemorySnapshot {
            percent: 47.0,
            timestamp_seconds: 1,
        };
        let parsed = decode_memory_snapshot(&encode_memory_snapshot(&snapshot)).unwrap();
        assert_eq!(parsed, snapshot);
    }

    #[test]
    fn round_trips_network_snapshot() {
        let snapshot = NetworkSnapshot {
            rx_bytes_per_second: 1,
            tx_bytes_per_second: 2,
            sample: NetworkSample {
                timestamp_millis: 1_234,
                rx_bytes: 2,
                tx_bytes: 3,
                interface: "utun4".to_string(),
            },
        };
        let encoded = encode_network_snapshot(&snapshot);
        assert_eq!(encoded, "v2\t1234\t2\t3\t1\t2\tutun4");
        assert_eq!(decode_network_snapshot(&encoded).unwrap(), snapshot);
    }

    #[test]
    fn rejects_untagged_and_unknown_network_layouts() {
        assert!(decode_network_snapshot("1700000000\t2\t3\t4\t5\ten0").is_none());
        assert!(decode_network_snapshot("v3\t1\t2\t3\t4\t5\ten0").is_none());
        assert!(decode_network_snapshot("v2x\t1\t2\t3\t4\t5\ten0").is_none());
    }

    #[test]
    fn formats_percent_right_aligned_width_2() {
        assert_eq!(format_percent(5.0), " 5");
        assert_eq!(format_percent(12.0), "12");
        assert_eq!(format_percent(100.0), "100");
        assert_eq!(format_percent(-3.0), " 0");
        assert_eq!(format_percent(250.0), "100");
    }

    #[test]
    fn formats_speed_compactly() {
        assert_eq!(format_speed(999), "999B");
        assert_eq!(format_speed(12 * 1024), "12.0K");
        assert_eq!(format_speed(2 * 1024 * 1024), "2.0M");
        assert_eq!(format_speed(123 * 1024 * 1024), "123M");
        assert_eq!(format_speed(102_390), "100K");
        assert_eq!(format_speed(1_023_590), "999K");
    }

    #[test]
    fn formatted_speed_tokens_fit_fixed_width_budget() {
        let samples = [
            999,
            1023,
            (9.94 * 1024.0) as u64,
            (9.95 * 1024.0) as u64,
            (99.94 * 1024.0) as u64,
            (99.95 * 1024.0) as u64,
            (999.4 * 1024.0) as u64,
            (999.6 * 1024.0) as u64,
            (99.95 * 1024.0 * 1024.0) as u64,
            (999.6 * 1024.0 * 1024.0 * 1024.0) as u64,
        ];
        for bytes_per_second in samples {
            assert!(
                format_speed(bytes_per_second).len() <= 5,
                "{} formatted as {}",
                bytes_per_second,
                format_speed(bytes_per_second)
            );
        }
    }

    #[test]
    fn formats_network_for_fixed_width_display() {
        let snapshot = NetworkSnapshot {
            rx_bytes_per_second: 12 * 1024,
            tx_bytes_per_second: 999,
            sample: NetworkSample {
                timestamp_millis: 1_000,
                rx_bytes: 2,
                tx_bytes: 3,
                interface: "en0".to_string(),
            },
        };
        assert_eq!(format_network_now(&snapshot), "↓12.0K ↑999B");
    }
}
