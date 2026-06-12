use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment};
use crate::status_component::{ComponentInterests, ComponentSnapshot, StatusComponent};

pub struct SessionListComponent;

impl StatusComponent for SessionListComponent {
    fn id(&self) -> &'static str {
        "session-list"
    }

    fn interests(&self) -> ComponentInterests {
        ComponentInterests::Events(&[
            RenderEventKind::SessionChanged,
            RenderEventKind::SessionCreated,
            RenderEventKind::SessionClosed,
            RenderEventKind::SessionRenamed,
        ])
    }

    fn snapshot(
        &mut self,
        context: &RenderContext,
        _event: &RenderEvent,
        cache: &mut dyn ComponentCache,
    ) -> AppResult<ComponentSnapshot> {
        let cache_key = format!(
            "{}:{}",
            context.group.current_session_name,
            context
                .group
                .sessions
                .iter()
                .map(|session| format!("{}={}", session.id, session.name))
                .collect::<Vec<_>>()
                .join(",")
        );

        if let Some(cached) = cache.get(self.id(), &cache_key)
            && let Some((literal_text, rich_text)) = cached.split_once('\t')
        {
            return Ok(ComponentSnapshot::Rendered(RenderedSegment {
                literal_text: literal_text.to_string(),
                rich_text: rich_text.to_string(),
            }));
        }

        let rendered = render_session_list(context);
        cache.set(
            self.id(),
            &cache_key,
            format!("{}\t{}", rendered.literal_text, rendered.rich_text),
        );
        Ok(ComponentSnapshot::Rendered(rendered))
    }
}

fn render_session_list(context: &RenderContext) -> RenderedSegment {
    if context.group.sessions.len() <= 1 {
        return RenderedSegment::empty();
    }

    let mut literal_text = String::from(" ");
    let mut rich_text = String::from(
        "#[fg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_SESSION_LIST_ACTIVE}#,bg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}#,bold]#{@GHC_SYM_SESSION} #[default] ",
    );

    for (offset, session) in context.group.sessions.iter().enumerate() {
        let index = offset + 1;
        if index > 1 {
            literal_text.push(' ');
            rich_text.push(' ');
        }

        literal_text.push_str(&format!("{} | {}", session.name, index));
        if session.name == context.group.current_session_name {
            let left_sep = if index == 1 {
                ""
            } else {
                "#{@GHC_SEP_SLANT_LEFT}"
            };
            rich_text.push_str(&format!(
                "#[fg=#{{@GHC_SL_BG_SESSION_LIST_ACTIVE}}#,bg=#{{@GHC_SL_BG_SESSION_LIST_SURFACE}}]#[range=session|{}]{}#[fg=#{{@GHC_SL_FG_SESSION_LIST_ACTIVE}}#,bg=#{{@GHC_SL_BG_SESSION_LIST_ACTIVE}}#,bold] {} | {} #[fg=#{{@GHC_SL_BG_SESSION_LIST_ACTIVE}}#,bg=#{{@GHC_SL_BG_SESSION_LIST_SURFACE}}]#{{@GHC_SEP_SLANT_RIGHT}}#[norange]#[default]",
                session.id, left_sep, session.name, index
            ));
        } else {
            rich_text.push_str(&format!(
                "#[fg=#{{@GHC_SL_FG_SESSION_LIST_INACTIVE}}#,bg=#{{@GHC_SL_BG_SESSION_LIST_INACTIVE}}#,dim]#[range=session|{}]{} | {}#[norange]#[default]",
                session.id, session.name, index
            ));
        }
    }

    RenderedSegment {
        literal_text,
        rich_text,
    }
}
