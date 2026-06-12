use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};

pub trait StatusComponent {
    fn id(&self) -> &'static str;

    fn render(
        &mut self,
        context: &RenderContext,
        cache: &mut dyn ComponentCache,
    ) -> AppResult<RenderedSegment>;
}
