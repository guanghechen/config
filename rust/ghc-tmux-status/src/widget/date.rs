use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::StatusWidget;
use crate::widget::pill::pill_literal;

pub struct DateWidget;

impl StatusWidget for DateWidget {
    fn id(&self) -> &'static str {
        "date"
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: pill_literal(" Mon, 01 Jan "),
            rich_text: "#[fg=#{@GHC_SL_BG_PILL_DATE}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_PILL_ICON}#,bg=#{@GHC_SL_BG_PILL_DATE}]#{@GHC_SYM_DATE} #[default]#[fg=#{@GHC_SL_FG_PILL_TXT}] %a, %d %b ".to_string(),
        })
    }
}
