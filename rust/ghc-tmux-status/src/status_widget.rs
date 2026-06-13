use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};

pub trait StatusWidget {
    fn id(&self) -> &'static str;

    fn interests(&self) -> SnapshotPolicy {
        SnapshotPolicy::Dynamic
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

/// Controls whether a widget refreshes its internal snapshot for a render event.
///
/// This is only a static-vs-dynamic dispatcher gate. Periodic throttling belongs
/// inside each widget, for example the metric widgets' cache TTL.
pub enum SnapshotPolicy {
    /// Snapshot only on full-refresh events; render may still read the live context.
    Static,
    /// Snapshot on every render event.
    Dynamic,
}

impl SnapshotPolicy {
    pub fn should_snapshot(&self, event: &RenderEvent) -> bool {
        match self {
            Self::Dynamic => true,
            Self::Static => matches!(
                event.kind,
                RenderEventKind::Tick | RenderEventKind::ThemeLoaded | RenderEventKind::ManualApply
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::SnapshotPolicy;
    use crate::model::{RenderEvent, RenderEventKind};

    #[test]
    fn dynamic_widgets_snapshot_on_every_event() {
        let event = RenderEvent {
            kind: RenderEventKind::ClientResized,
        };

        assert!(SnapshotPolicy::Dynamic.should_snapshot(&event));
    }

    #[test]
    fn static_widgets_snapshot_only_on_render_driven_events() {
        let resize = RenderEvent {
            kind: RenderEventKind::ClientResized,
        };
        let tick = RenderEvent {
            kind: RenderEventKind::Tick,
        };

        assert!(!SnapshotPolicy::Static.should_snapshot(&resize));
        assert!(SnapshotPolicy::Static.should_snapshot(&tick));
    }
}
