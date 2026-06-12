use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::status_component::StatusComponent;

pub fn render_components(
    components: &mut [&mut dyn StatusComponent],
    context: &RenderContext,
    event: &RenderEvent,
    cache: &mut dyn ComponentCache,
) -> AppResult<RenderedSegment> {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for component in components {
        let segment = render_component(*component, context, event, cache)?;
        literal_text.push_str(&segment.literal_text);
        rich_text.push_str(&segment.rich_text);
    }
    Ok(RenderedSegment {
        literal_text,
        rich_text,
    })
}

fn render_component(
    component: &mut dyn StatusComponent,
    context: &RenderContext,
    event: &RenderEvent,
    cache: &mut dyn ComponentCache,
) -> AppResult<RenderedSegment> {
    if !component.interests().matches(event)
        && let Some(cached) = cache.get(component.id(), RENDERED_CACHE_KEY)
        && let Some(segment) = decode_rendered_segment(cached)
    {
        return Ok(segment);
    }

    let snapshot = component.snapshot(context, event, cache)?;
    let segment = component.render(context, &snapshot)?;
    cache.set(
        component.id(),
        RENDERED_CACHE_KEY,
        encode_rendered_segment(&segment),
    );
    Ok(segment)
}

const RENDERED_CACHE_KEY: &str = "rendered";

fn encode_rendered_segment(segment: &RenderedSegment) -> String {
    format!("{}\t{}", segment.literal_text, segment.rich_text)
}

fn decode_rendered_segment(value: &str) -> Option<RenderedSegment> {
    let (literal_text, rich_text) = value.split_once('\t')?;
    Some(RenderedSegment {
        literal_text: literal_text.to_string(),
        rich_text: rich_text.to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::{decode_rendered_segment, encode_rendered_segment};
    use crate::model::RenderedSegment;

    #[test]
    fn roundtrips_rendered_segment() {
        let segment = RenderedSegment {
            literal_text: " literal ".to_string(),
            rich_text: "#[x] rich".to_string(),
        };
        assert_eq!(
            decode_rendered_segment(&encode_rendered_segment(&segment)),
            Some(segment)
        );
    }
}
