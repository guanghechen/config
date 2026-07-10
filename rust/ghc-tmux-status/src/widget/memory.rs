use crate::error::AppResult;
use crate::metric::MemorySnapshot;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::TemplateWidget;
use crate::util::format::format_percent_width_2;
use crate::widget::pill::pill_literal;

#[derive(Default)]
pub struct MemoryWidget;

impl TemplateWidget for MemoryWidget {
    // The sampler is the single writer of `@GHC_MEM_NOW`; render only installs an
    // indirect reference so tmux redraws can show fresh memory without a full render.
    fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        let body_literal = " 100% ";
        let literal_text = pill_literal(body_literal);
        let rich_text = "#[fg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DURATION}]#{@GHC_SYM_MEMORY} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] #{@GHC_MEM_NOW}%% ".to_string();
        Ok(RenderedSegment {
            literal_text,
            rich_text,
        })
    }
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

pub fn format_memory_now(snapshot: &MemorySnapshot) -> String {
    format_percent_width_2(snapshot.percent)
}

#[cfg(test)]
mod tests {
    use super::{decode_memory_snapshot, encode_memory_snapshot, format_memory_now};
    use crate::metric::MemorySnapshot;

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
    fn formats_memory_for_fixed_width_display() {
        let snapshot = MemorySnapshot {
            percent: 47.0,
            timestamp_seconds: 1,
        };
        assert_eq!(format_memory_now(&snapshot), "47");
    }
}
