use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_component::StatusComponent;

pub fn render_components(
    components: &mut [&mut dyn StatusComponent],
    context: &RenderContext,
    cache: &mut dyn ComponentCache,
) -> AppResult<RenderedSegment> {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for component in components {
        let segment = component.render(context, cache)?;
        literal_text.push_str(&segment.literal_text);
        rich_text.push_str(&segment.rich_text);
    }
    Ok(RenderedSegment {
        literal_text,
        rich_text,
    })
}
