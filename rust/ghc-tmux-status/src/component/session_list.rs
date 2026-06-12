use crate::error::AppResult;
use crate::model::{RenderContext, RenderEventKind, RenderedSegment};
use crate::status_component::{ComponentInterests, StatusComponent};

const LIST_SURFACE_BG: &str = "default";
const ACTIVE_BG: &str = "#{@GHC_SL_BG_SESSION_LIST_ACTIVE}";
const INACTIVE_BODY_BG: &str = "#{@GHC_SL_BG_WIN_NAME}";
const INACTIVE_RIGHT_EDGE_BG: &str = "#{@GHC_SL_BG_WIN_NUM}";

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

    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(render_session_list(context))
    }
}

fn render_session_list(context: &RenderContext) -> RenderedSegment {
    if context.group.sessions.len() <= 1 {
        return RenderedSegment::empty();
    }

    let mut literal_text = String::from(" ");
    let mut rich_text = String::from(
        "#[fg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}#,bg=default]#{@GHC_SEP_ROUND_LEFT}#[fg=#{@GHC_SL_FG_SESSION_LIST_ACTIVE}#,bg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}#,bold]#{@GHC_SYM_SESSION} #[default] ",
    );
    for (offset, session) in context.group.sessions.iter().enumerate() {
        let index = offset + 1;
        let is_active = session.name == context.group.current_session_name;
        let palette = SessionItemPalette::new(is_active);

        if index > 1 {
            literal_text.push(' ');
        }
        literal_text.push_str(&format!("{} | {}", session.name, index));

        rich_text.push_str(&format!("#[range=session|{}]", session.id));
        rich_text.push_str(&render_left_edge(palette.left_edge_bg));
        rich_text.push_str(&render_item_body(is_active, &session.name, index, palette));
        rich_text.push_str(&render_right_edge(palette.right_edge_bg));
        rich_text.push_str("#[norange]#[default]");
    }

    RenderedSegment {
        literal_text,
        rich_text,
    }
}

#[derive(Clone, Copy)]
struct SessionItemPalette {
    body_bg: &'static str,
    left_edge_bg: &'static str,
    right_edge_bg: &'static str,
}

impl SessionItemPalette {
    fn new(is_active: bool) -> Self {
        if is_active {
            return Self {
                body_bg: ACTIVE_BG,
                left_edge_bg: ACTIVE_BG,
                right_edge_bg: ACTIVE_BG,
            };
        }

        Self {
            body_bg: INACTIVE_BODY_BG,
            left_edge_bg: INACTIVE_BODY_BG,
            right_edge_bg: INACTIVE_RIGHT_EDGE_BG,
        }
    }
}

fn render_left_edge(right_bg: &str) -> String {
    format!("#[fg={right_bg}#,bg={LIST_SURFACE_BG}]#{{@GHC_SEP_SLANT_LEFT}}")
}

fn render_right_edge(left_bg: &str) -> String {
    format!("#[fg={left_bg}#,bg={LIST_SURFACE_BG}]#{{@GHC_SEP_SLANT_RIGHT}}")
}

fn render_item_body(
    is_active: bool,
    session_name: &str,
    index: usize,
    palette: SessionItemPalette,
) -> String {
    if is_active {
        return format!(
            "#[fg=#{{@GHC_SL_FG_SESSION_LIST_ACTIVE}}#,bg={}#,bold] {session_name} | {index} ",
            palette.body_bg
        );
    }

    format!(
        "#[fg=#{{@GHC_SL_FG_WIN_NAME}}#,bg={}#,dim] {session_name} #[fg=#{{@GHC_SL_FG_WIN_NUM}}#,bg={}#,dim]| {index} ",
        palette.body_bg, palette.body_bg
    )
}

#[cfg(test)]
mod tests {
    use super::{
        ACTIVE_BG, INACTIVE_BODY_BG, INACTIVE_RIGHT_EDGE_BG, SessionItemPalette, render_item_body,
        render_left_edge, render_right_edge,
    };

    #[test]
    fn active_item_uses_session_active_color_for_body_and_edges() {
        let palette = SessionItemPalette::new(true);
        let item = render_item_body(true, "tmux", 2, palette);
        assert!(item.contains("@GHC_SL_FG_SESSION_LIST_ACTIVE"));
        assert!(item.contains("@GHC_SL_BG_SESSION_LIST_ACTIVE"));
        assert_eq!(palette.body_bg, ACTIVE_BG);
        assert_eq!(palette.left_edge_bg, ACTIVE_BG);
        assert_eq!(palette.right_edge_bg, ACTIVE_BG);
    }

    #[test]
    fn inactive_item_uses_window_inactive_colors() {
        let palette = SessionItemPalette::new(false);
        let item = render_item_body(false, "dev", 2, palette);
        assert!(item.contains("@GHC_SL_FG_WIN_NAME"));
        assert!(item.contains("@GHC_SL_BG_WIN_NAME"));
        assert!(item.contains("@GHC_SL_FG_WIN_NUM"));
        assert!(!item.contains("@GHC_SL_BG_WIN_NUM"));
        assert!(item.contains(" dev "));
        assert!(item.contains("| 2 "));
        assert_eq!(palette.body_bg, INACTIVE_BODY_BG);
        assert_eq!(palette.left_edge_bg, INACTIVE_BODY_BG);
        assert_eq!(palette.right_edge_bg, INACTIVE_RIGHT_EDGE_BG);
    }

    #[test]
    fn item_edges_connect_to_list_surface_without_collapsing() {
        assert_eq!(
            render_left_edge("#{item_name}"),
            "#[fg=#{item_name}#,bg=default]#{@GHC_SEP_SLANT_LEFT}"
        );
        assert_eq!(
            render_right_edge("#{item_num}"),
            "#[fg=#{item_num}#,bg=default]#{@GHC_SEP_SLANT_RIGHT}"
        );
    }
}
