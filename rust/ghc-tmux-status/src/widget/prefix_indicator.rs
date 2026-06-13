use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::StatusWidget;
use crate::widget::pill::prefix_literal;

pub struct PrefixIndicatorWidget;

impl StatusWidget for PrefixIndicatorWidget {
    fn id(&self) -> &'static str {
        "prefix-indicator"
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(RenderedSegment {
            literal_text: prefix_literal(),
            rich_text: "#{?client_prefix,#[fg=#{@GHC_SL_FG_PREFIX}]#{@GHC_SYM_PREFIX} ,}"
                .to_string(),
        })
    }
}
