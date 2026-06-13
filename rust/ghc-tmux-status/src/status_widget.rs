use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};

pub trait StatusWidget {
    fn id(&self) -> &'static str;

    fn interests(&self) -> WidgetInterests {
        WidgetInterests::All
    }

    fn snapshot(
        &mut self,
        _context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn WidgetCache,
    ) -> AppResult<()> {
        Ok(())
    }

    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

pub enum WidgetInterests {
    Static,
    All,
    Events(&'static [RenderEventKind]),
    Periodic { interval_secs: u64 },
}

impl WidgetInterests {
    pub fn matches(&self, event: &RenderEvent) -> bool {
        if matches!(
            event.kind,
            RenderEventKind::Tick | RenderEventKind::ThemeLoaded | RenderEventKind::ManualApply
        ) {
            return true;
        }

        match self {
            Self::Static => false,
            Self::All => true,
            Self::Events(events) => events.contains(&event.kind),
            Self::Periodic { interval_secs } => {
                let _interval_secs = interval_secs;
                false
            }
        }
    }
}
