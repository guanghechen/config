use crate::model::RenderedSegment;

/*
 * Width placeholders for the glyph variables every pill draws. status-*-length
 * reads literal_text as a tmux-width shadow of rich_text.
 */
const ROUND_LEFT_LITERAL: &str = "\u{e0b6}";
const ICON_LITERAL: &str = "¤";

/**
 * The shared pill: a rounded cap and reversed icon cell in `bg`, then `body` in
 * `text_fg`. `literal` is the body's widest rendering, so the width shadow comes
 * from the same definition as the rich text.
 */
fn pill(bg: &str, symbol: &str, text_fg: &str, body: &str, literal: &str) -> RenderedSegment {
    RenderedSegment {
        literal_text: format!("{ROUND_LEFT_LITERAL}{ICON_LITERAL} {literal}"),
        rich_text: format!(
            "#[fg=#{{{bg}}}]#{{@GHC_SEP_ROUND_LEFT}}#[fg=#{{{bg}}}#,bg=#{{@GHC_SL_FG_PILL_ICON}}#,reverse]#{{{symbol}}} #[default]#[fg=#{{{text_fg}}}]{body}"
        ),
    }
}

/*
 * Dynamic metrics are indirect references to sampler-owned options, so tmux
 * redraws show fresh values without a render. Each literal reserves the widest value.
 */
pub fn network() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_DURATION",
        "@GHC_SYM_NET",
        "@GHC_SL_FG_PILL_TXT",
        " #{@GHC_NET_NOW} ",
        " ↓99.9G ↑99.9G ",
    )
}

pub fn cpu() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_DURATION",
        "@GHC_SYM_CPU",
        "@GHC_SL_FG_PILL_TXT",
        " #{@GHC_CPU_NOW}%% ",
        " 100% ",
    )
}

pub fn memory() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_DURATION",
        "@GHC_SYM_MEMORY",
        "@GHC_SL_FG_PILL_TXT",
        " #{@GHC_MEM_NOW}%% ",
        " 100% ",
    )
}

// tmux derives the session age at every redraw, so session caches stay static.
pub fn duration() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_DURATION",
        "@GHC_SYM_DURATION",
        "@GHC_SL_FG_PILL_TXT",
        " #{E:@GHC_SESSION_DURATION_FMT} ",
        " 999d 23h ",
    )
}

pub fn date() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_DATE",
        "@GHC_SYM_DATE",
        "@GHC_SL_FG_PILL_TXT",
        " %a, %d %b ",
        " Mon, 01 Jan ",
    )
}

pub fn time() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_TIME",
        "@GHC_SYM_TIME",
        "@GHC_SL_FG_PILL_TXT",
        " %H:%M:%S ",
        " 00:00:00 ",
    )
}

pub fn window_id() -> RenderedSegment {
    pill(
        "@GHC_SL_BG_PILL_SESSION",
        "@GHC_SYM_SESSION",
        "@GHC_SL_FG_PILL_WINNR",
        " #{window_id} ",
        " @00 ",
    )
}

/*
 * The zoom pill renders only when window_zoomed_flag is set, but the shadow
 * reserves it so status-*-length stays stable across zoom changes. Like the
 * prefix indicator, the shadow also counts the conditional's closing comma.
 */
pub fn fullscreen() -> RenderedSegment {
    let pill = pill(
        "@GHC_SL_BG_PILL_ZOOM",
        "@GHC_SYM_WIN_ZOOM",
        "@GHC_SL_FG_PILL_TXT",
        " #{pane_index}/#{window_panes} ",
        " 00/00 ",
    );
    RenderedSegment {
        literal_text: format!("{},", pill.literal_text),
        rich_text: format!("#{{?window_zoomed_flag,{},}}", pill.rich_text),
    }
}

pub fn prefix_indicator() -> RenderedSegment {
    RenderedSegment {
        literal_text: format!("{ICON_LITERAL} ,"),
        rich_text: "#{?client_prefix,#[fg=#{@GHC_SL_FG_PREFIX}]#{@GHC_SYM_PREFIX} ,}".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{date, duration, fullscreen, prefix_indicator, time, window_id};

    #[test]
    fn pill_shadow_mirrors_round_icon_spacer_and_widest_body() {
        assert_eq!(time().literal_text, "\u{e0b6}¤  00:00:00 ");
        assert_eq!(duration().literal_text, "\u{e0b6}¤  999d 23h ");
        assert_eq!(window_id().literal_text, "\u{e0b6}¤  @00 ");
        assert_eq!(date().literal_text, "\u{e0b6}¤  Mon, 01 Jan ");
    }

    #[test]
    fn pills_draw_their_values_at_redraw_time() {
        assert!(
            time()
                .rich_text
                .ends_with("#[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] %H:%M:%S ")
        );
        assert!(
            duration()
                .rich_text
                .contains(" #{E:@GHC_SESSION_DURATION_FMT} ")
        );
        for segment in [time(), duration(), date(), window_id()] {
            assert!(!segment.rich_text.contains("#("));
        }
    }

    #[test]
    fn conditional_pills_reserve_their_shown_width() {
        let zoom = fullscreen();
        assert!(zoom.rich_text.starts_with("#{?window_zoomed_flag,#[fg="));
        assert!(
            zoom.rich_text
                .ends_with(" #{pane_index}/#{window_panes} ,}")
        );
        assert_eq!(zoom.literal_text, "\u{e0b6}¤  00/00 ,");
        assert_eq!(prefix_indicator().literal_text, "¤ ,");
    }
}
