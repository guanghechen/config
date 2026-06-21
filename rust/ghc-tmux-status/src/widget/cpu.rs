use crate::error::AppResult;
use crate::metric::{CpuSample, CpuSnapshot, provider_for_current_platform};
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct CpuWidget;

impl TemplateWidget for CpuWidget {
    // The CPU pill emits a tmux indirect reference instead of a baked number. The
    // unified metric sampler is the single writer of `@GHC_CPU_NOW`, so tmux redraws
    // can show fresh values without rewriting the big status option on every sample.
    // The literal placeholder is fixed at the widest value (100%) so
    // `status_right_length` stays stable regardless of the live digits.
    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        let literal_text = pill_literal(" 100% ");
        let rich_text = "#[fg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SYM_CPU} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{@GHC_CPU_NOW}%% ".to_string();
        Ok(RenderedSegment {
            literal_text,
            rich_text,
        })
    }
}

pub fn sample_cpu(previous: Option<&CpuSnapshot>) -> AppResult<CpuSnapshot> {
    provider_for_current_platform(None).sample_cpu(previous.map(|snapshot| &snapshot.sample))
}

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

#[cfg(test)]
mod tests {
    use super::{decode_cpu_snapshot, encode_cpu_snapshot};
    use crate::metric::{CpuSample, CpuSnapshot};

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
}
