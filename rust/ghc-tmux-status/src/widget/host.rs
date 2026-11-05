use crate::model::{RenderContext, RenderedSegment};

pub fn host(context: &RenderContext) -> RenderedSegment {
    let host = truncate_chars(&context.snapshot.host, 16);
    // Reverse keeps the host fill as opaque as the adjoining session arrow.
    RenderedSegment {
        literal_text: format!("{ARROW_RIGHT} {OS_ICON} {host} "),
        rich_text: "#[fg=#{@GHC_SL_BG_PILL_HOST}#,bg=#{@GHC_SL_BG_SESSION_LIST_SURFACE}#,reverse]#{@GHC_SEP_ARROW_RIGHT}#[fg=#{@GHC_SL_BG_PILL_HOST}#,bg=#{@GHC_SL_FG_PILL_ICON}] #{@GHC_SYM_OS}#[fg=#{@GHC_SL_BG_PILL_HOST}#,bg=#{@GHC_SL_FG_PILL_HOST_TXT}] #{=16:host} #[noreverse]".to_string(),
    }
}

/*
 * These placeholders mirror glyph variables in rich_text. status-left-length uses
 * literal_text as a tmux-width shadow, so update them with the rich pill shape.
 * ARROW_RIGHT carves the surface-colored ">" notch into the host head; the whole
 * host block is the PILL_HOST color and the session list's first item connects on
 * via its own ">" notch.
 */
const ARROW_RIGHT: &str = "";
const OS_ICON: &str = "";

fn truncate_chars(text: &str, limit: usize) -> String {
    text.chars().take(limit).collect()
}

#[cfg(test)]
mod tests {
    use super::host;
    use crate::model::TmuxSnapshot;
    use crate::test_support::{render_context, snapshot};

    #[test]
    fn literal_text_accounts_for_visible_host_pill_glyphs() {
        let segment = host(&render_context(
            TmuxSnapshot {
                host: "mbp-m5-64g".to_string(),
                ..snapshot()
            },
            Vec::new(),
        ));
        assert_eq!(segment.literal_text, "  mbp-m5-64g ");
    }
}
