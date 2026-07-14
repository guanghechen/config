use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};

pub trait StatusWidget {
    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

pub trait TemplateWidget {
    fn render_template(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

pub trait ComputedWidget {
    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

pub struct Template<T> {
    widget: T,
}

pub struct Computed<T> {
    widget: T,
}

pub fn template<T: TemplateWidget>(widget: T) -> Template<T> {
    Template { widget }
}

pub fn computed<T: ComputedWidget>(widget: T) -> Computed<T> {
    Computed { widget }
}

impl<T: TemplateWidget> StatusWidget for Template<T> {
    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        self.widget.render_template(context)
    }
}

impl<T: ComputedWidget> StatusWidget for Computed<T> {
    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        self.widget.render_computed(context)
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;
    use std::rc::Rc;

    use super::{ComputedWidget, StatusWidget, TemplateWidget, computed, template};
    use crate::error::AppResult;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderedSegment, SessionGroupView, StatusMode,
        StatusPosition, TmuxSnapshot,
    };

    struct FakeTemplate;

    impl TemplateWidget for FakeTemplate {
        fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
            Ok(RenderedSegment {
                literal_text: "template".to_string(),
                rich_text: "template".to_string(),
            })
        }
    }

    struct FakeComputed;

    impl ComputedWidget for FakeComputed {
        fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
            Ok(RenderedSegment {
                literal_text: context.snapshot.host.clone(),
                rich_text: context.snapshot.host.clone(),
            })
        }
    }

    #[test]
    fn template_adapter_renders_without_refresh_state() {
        let widget = template(FakeTemplate);
        let rendered = widget.render(&context()).unwrap();
        assert_eq!(rendered.literal_text, "template");
    }

    #[test]
    fn computed_adapter_renders_from_context_without_refresh_state() {
        let widget = computed(FakeComputed);
        let rendered = widget.render(&context()).unwrap();
        assert_eq!(rendered.literal_text, "host");
    }

    fn context() -> RenderContext {
        RenderContext {
            snapshot: Rc::new(TmuxSnapshot {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "s".to_string(),
                client_last_session: String::new(),
                host: "host".to_string(),
                session_created: 1,
                sessions: Vec::new(),
                client_widths: Vec::new(),
                options: BTreeMap::new(),
            }),
            group: SessionGroupView {
                current_session_name: "s".to_string(),
                sessions: Vec::new(),
            },
            layout: LayoutPlan {
                mode: StatusMode::TopAdaptive,
                position: StatusPosition::Top,
                kind: LayoutKind::Wide,
                rows: 1,
                target_status: "on".to_string(),
                key: "02:wide".to_string(),
            },
            render_session_created: 1,
            session_layouts: Vec::new(),
        }
    }
}
