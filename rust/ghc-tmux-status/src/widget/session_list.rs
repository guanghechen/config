use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::ComputedWidget;

const LIST_SURFACE_BG: &str = "default";
// The first item's ">" is a powerline join the orange host segment points into the
// session list: the arrow ink is the host pill color over the item-colored cell, so the
// host flows straight on. (Not the "default" token: as fg it would be the bar text color.)
const HEAD_NOTCH_FG: &str = "#{@GHC_SL_BG_PILL_HOST}";
const ACTIVE_BG: &str = "#{@GHC_SL_BG_SESSION_LIST_ACTIVE}";
const ACTIVE_FG: &str = "#{@GHC_SL_FG_SESSION_LIST_ACTIVE}";
const INACTIVE_NAME_BG: &str = "#{@GHC_SL_BG_SESSION_ITEM_NAME}";
const INACTIVE_NAME_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_NAME}";
const INACTIVE_NUM_BG: &str = "#{@GHC_SL_BG_SESSION_ITEM_NUM}";
const INACTIVE_NUM_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_NUM}";
const LAST_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_LAST}";
const INACTIVE_BELL_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_BELL}";
const RANGE_CLOSE: &str = "#[norange]#[default]";
const LAST_INACTIVE_RANGE_CLOSE: &str = "#[default]#[norange] #[default]";

// This placeholder mirrors the arrow separator glyph in rich_text. status-left-length
// uses literal_text as a tmux-width shadow, so update it with the rich item shape.
const ARROW_LITERAL: char = '';
const BELL_LITERAL: char = '¤';

pub struct SessionListWidget;

impl ComputedWidget for SessionListWidget {
    fn id(&self) -> &'static str {
        "session-list"
    }

    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(render_session_list(context))
    }
}

/// Rebuilds from the session snapshot. Semantically relevant events are session
/// create/close/rename/switch, but dispatch remains dynamic to keep the widget
/// contract simple and honest.
fn render_session_list(context: &RenderContext) -> RenderedSegment {
    if context.group.sessions.is_empty() {
        return RenderedSegment::empty();
    }

    let mut literal_text = String::new();
    let mut rich_text = String::new();
    let session_count = context.group.sessions.len();
    let mut previous_palette = None;
    for (offset, session) in context.group.sessions.iter().enumerate() {
        let index = offset + 1;
        let is_last = index == session_count;
        let is_active = session.name == context.group.current_session_name;
        let is_last_focus = !is_active
            && !context.snapshot.client_last_session.is_empty()
            && session.name == context.snapshot.client_last_session;
        let palette = SessionItemPalette::new(is_active, is_last_focus);

        rich_text.push_str(&format!("#[range=session|{}]", session.id));
        if let Some(left_palette) = previous_palette {
            literal_text.push(ARROW_LITERAL);
            rich_text.push_str(&render_join_separator(left_palette, palette));
        } else {
            literal_text.push(ARROW_LITERAL);
            rich_text.push_str(&render_left_edge(palette.name_bg));
        }
        literal_text.push_str(&render_item_body_literal(
            &session.name,
            index,
            session.has_bell,
            palette,
        ));
        rich_text.push_str(&render_item_body(
            &session.name,
            index,
            session.has_bell,
            palette,
        ));
        if is_last {
            literal_text.push(ARROW_LITERAL);
            rich_text.push_str(&render_right_edge(
                palette.terminal_edge_fg,
                LIST_SURFACE_BG,
            ));
        }
        if is_last && !palette.is_active {
            literal_text.push(' ');
        }
        rich_text.push_str(palette.range_close(is_last));
        previous_palette = Some(palette);
    }

    RenderedSegment {
        literal_text,
        rich_text,
    }
}

#[derive(Clone, Copy)]
struct SessionItemPalette {
    is_active: bool,
    name_bg: &'static str,
    name_fg: &'static str,
    num_bg: &'static str,
    num_fg: &'static str,
    terminal_edge_fg: &'static str,
}

impl SessionItemPalette {
    fn new(is_active: bool, is_last_focus: bool) -> Self {
        if is_active {
            return Self {
                is_active,
                name_bg: ACTIVE_BG,
                name_fg: ACTIVE_FG,
                num_bg: ACTIVE_BG,
                num_fg: ACTIVE_FG,
                terminal_edge_fg: ACTIVE_BG,
            };
        }

        Self {
            is_active,
            name_bg: INACTIVE_NAME_BG,
            name_fg: if is_last_focus {
                LAST_FG
            } else {
                INACTIVE_NAME_FG
            },
            num_bg: INACTIVE_NUM_BG,
            num_fg: if is_last_focus {
                LAST_FG
            } else {
                INACTIVE_NUM_FG
            },
            terminal_edge_fg: INACTIVE_NUM_BG,
        }
    }

    fn range_close(self, is_last: bool) -> &'static str {
        if is_last && !self.is_active {
            return LAST_INACTIVE_RANGE_CLOSE;
        }

        RANGE_CLOSE
    }
}

fn render_join_separator(left: SessionItemPalette, right: SessionItemPalette) -> String {
    render_right_edge(left.num_bg, right.name_bg)
}

fn render_left_edge(edge_bg: &str) -> String {
    // The orange host segment points its ">" arrow into the first item: ink = host pill
    // color, bg = the item color, so the host flows into the session list as a powerline
    // join. (Head only; joins/tail keep item-colored ink, see render_right_edge.)
    format!("#[fg={HEAD_NOTCH_FG}#,bg={edge_bg}]#{{@GHC_SEP_ARROW_RIGHT}}")
}

fn render_right_edge(edge_bg: &str, surface_bg: &str) -> String {
    format!("#[fg={edge_bg}#,bg={surface_bg}]#{{@GHC_SEP_ARROW_RIGHT}}")
}

fn render_item_body_literal(
    session_name: &str,
    index: usize,
    has_bell: bool,
    palette: SessionItemPalette,
) -> String {
    if palette.is_active && has_bell {
        return format!(" {session_name} | {index} {BELL_LITERAL}");
    }

    if palette.is_active {
        return format!(" {session_name} | {index} ");
    }

    if has_bell {
        return format!(" {session_name}  {index} {BELL_LITERAL}");
    }

    format!(" {session_name}  {index} ")
}

fn render_item_body(
    session_name: &str,
    index: usize,
    has_bell: bool,
    palette: SessionItemPalette,
) -> String {
    if palette.is_active && has_bell {
        return format!(
            "#[fg={}#,bg={}#,bold] {session_name} | {index} #[fg={}#,bg={}#,bold]#{{@GHC_SYM_WIN_BELL}}#[fg={}#,bg={}#,bold]",
            palette.name_fg,
            palette.name_bg,
            palette.name_fg,
            palette.name_bg,
            palette.name_fg,
            palette.name_bg
        );
    }

    if palette.is_active {
        return format!(
            "#[fg={}#,bg={}#,bold] {session_name} | {index} ",
            palette.name_fg, palette.name_bg
        );
    }

    if has_bell {
        return format!(
            "#[fg={}#,bg={}] {session_name} #[fg={}#,bg={}] {index} #[fg={INACTIVE_BELL_FG}#,bg={}#,bold]#{{@GHC_SYM_WIN_BELL}}",
            palette.name_fg, palette.name_bg, palette.num_fg, palette.num_bg, palette.num_bg
        );
    }

    format!(
        "#[fg={}#,bg={}] {session_name} #[fg={}#,bg={}] {index} ",
        palette.name_fg, palette.name_bg, palette.num_fg, palette.num_bg
    )
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        ACTIVE_BG, ACTIVE_FG, INACTIVE_NAME_BG, INACTIVE_NUM_BG, LAST_FG,
        LAST_INACTIVE_RANGE_CLOSE, LIST_SURFACE_BG, RANGE_CLOSE, SessionItemPalette,
        render_item_body, render_item_body_literal, render_join_separator, render_left_edge,
        render_right_edge, render_session_list,
    };
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderedSegment, SessionGroupView, SessionInfo,
        StatusMode, StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn active_item_uses_session_active_color_for_body_and_edges() {
        let palette = SessionItemPalette::new(true, false);
        let item = render_item_body("tmux", 2, false, palette);
        assert!(item.contains("@GHC_SL_FG_SESSION_LIST_ACTIVE"));
        assert!(item.contains("@GHC_SL_BG_SESSION_LIST_ACTIVE"));
        assert!(palette.is_active);
        assert_eq!(palette.name_bg, ACTIVE_BG);
        assert_eq!(palette.num_bg, ACTIVE_BG);
        assert_eq!(palette.terminal_edge_fg, ACTIVE_BG);
    }

    #[test]
    fn active_palette_wins_over_last_session_marker() {
        let palette = SessionItemPalette::new(true, true);
        let item = render_item_body("tmux", 2, false, palette);

        assert!(item.contains("@GHC_SL_FG_SESSION_LIST_ACTIVE"));
        assert!(!item.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
        assert_eq!(palette.name_fg, ACTIVE_FG);
        assert_eq!(palette.num_fg, ACTIVE_FG);
    }

    #[test]
    fn inactive_item_uses_session_item_inactive_colors() {
        let palette = SessionItemPalette::new(false, false);
        let item = render_item_body("dev", 2, false, palette);
        assert!(item.contains("@GHC_SL_FG_SESSION_ITEM_NAME"));
        assert!(item.contains("@GHC_SL_BG_SESSION_ITEM_NAME"));
        assert!(item.contains("@GHC_SL_FG_SESSION_ITEM_NUM"));
        assert!(item.contains("@GHC_SL_BG_SESSION_ITEM_NUM"));
        assert!(item.contains(" dev "));
        assert!(item.contains(" 2 "));
        assert!(!item.contains("| 2 "));
        assert!(!palette.is_active);
        assert_eq!(palette.name_bg, INACTIVE_NAME_BG);
        assert_eq!(palette.num_bg, INACTIVE_NUM_BG);
        assert_eq!(palette.terminal_edge_fg, INACTIVE_NUM_BG);
    }

    #[test]
    fn last_session_item_uses_orange_text_without_changing_backgrounds() {
        let palette = SessionItemPalette::new(false, true);
        let item = render_item_body("yui", 3, false, palette);

        assert!(item.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
        assert!(item.contains("@GHC_SL_BG_SESSION_ITEM_NAME"));
        assert!(item.contains("@GHC_SL_BG_SESSION_ITEM_NUM"));
        assert_eq!(palette.name_fg, LAST_FG);
        assert_eq!(palette.num_fg, LAST_FG);
        assert_eq!(palette.name_bg, INACTIVE_NAME_BG);
        assert_eq!(palette.num_bg, INACTIVE_NUM_BG);
    }

    #[test]
    fn active_item_with_bell_renders_bell_after_number() {
        let palette = SessionItemPalette::new(true, false);
        let item = render_item_body("tmux", 2, true, palette);
        assert!(item.contains("@GHC_SYM_WIN_BELL"));
        assert!(item.contains(" tmux | "));
        assert!(item.contains(" 2 "));
        assert_eq!(
            render_item_body_literal("tmux", 2, true, palette),
            " tmux | 2 ¤"
        );
    }

    #[test]
    fn inactive_item_with_bell_renders_bell_without_pipe() {
        let palette = SessionItemPalette::new(false, false);
        let item = render_item_body("dev", 2, true, palette);
        assert!(item.contains("@GHC_SYM_WIN_BELL"));
        assert!(item.contains("@GHC_SL_FG_SESSION_ITEM_BELL"));
        assert!(item.contains(" dev "));
        assert!(item.contains(" 2 "));
        assert!(!item.contains("| 2 "));
        assert_eq!(
            render_item_body_literal("dev", 2, true, palette),
            " dev  2 ¤"
        );
    }

    #[test]
    fn join_separator_collapses_internal_edges_to_one_glyph() {
        let inactive = SessionItemPalette::new(false, false);
        let active = SessionItemPalette::new(true, false);
        assert_eq!(
            render_join_separator(inactive, active),
            "#[fg=#{@GHC_SL_BG_SESSION_ITEM_NUM}#,bg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}]#{@GHC_SEP_ARROW_RIGHT}"
        );
        assert_eq!(
            render_join_separator(active, inactive),
            "#[fg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}#,bg=#{@GHC_SL_BG_SESSION_ITEM_NAME}]#{@GHC_SEP_ARROW_RIGHT}"
        );
        assert_eq!(
            render_join_separator(inactive, inactive),
            "#[fg=#{@GHC_SL_BG_SESSION_ITEM_NUM}#,bg=#{@GHC_SL_BG_SESSION_ITEM_NAME}]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn last_inactive_item_edge_uses_num_bg_on_default_surface() {
        let inactive = SessionItemPalette::new(false, false);
        assert_eq!(
            render_left_edge("#{item_name}"),
            "#[fg=#{@GHC_SL_BG_PILL_HOST}#,bg=#{item_name}]#{@GHC_SEP_ARROW_RIGHT}"
        );
        assert_eq!(
            render_right_edge(inactive.terminal_edge_fg, LIST_SURFACE_BG),
            "#[fg=#{@GHC_SL_BG_SESSION_ITEM_NUM}#,bg=default]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn inactive_last_item_keeps_one_space_before_default() {
        let inactive = SessionItemPalette::new(false, false);
        let active = SessionItemPalette::new(true, false);
        assert_eq!(inactive.range_close(true), LAST_INACTIVE_RANGE_CLOSE);
        assert_eq!(inactive.range_close(false), RANGE_CLOSE);
        assert_eq!(active.range_close(true), RANGE_CLOSE);
    }
    #[test]
    fn literal_text_accounts_for_visible_session_list_glyphs() {
        let context = context_with_sessions("dev", [("$1", "dev"), ("$2", "yui")]);
        let segment = render_session_list(&context);

        assert_eq!(segment.literal_text, " dev | 1  yui  2  ");
    }

    #[test]
    fn single_visible_session_still_renders_session_list() {
        let context = context_with_sessions("dev", [("$1", "dev")]);
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("#[range=session|$1]"));
        assert!(segment.rich_text.contains("@GHC_SL_BG_SESSION_LIST_ACTIVE"));
        assert_eq!(segment.literal_text, " dev | 1 ");
    }

    #[test]
    fn empty_session_group_renders_empty_list() {
        let context = context_with_sessions("dev", []);
        let segment = render_session_list(&context);

        assert_eq!(segment, RenderedSegment::empty());
    }

    #[test]
    fn rendered_list_marks_visible_last_session_with_orange_text() {
        let context = context_with_session_states_and_last(
            "dev",
            "yui",
            [("$1", "dev", false), ("$2", "yui", false)],
        );
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
        assert!(segment.rich_text.contains("#[range=session|$2]"));
        assert_eq!(segment.literal_text, " dev | 1  yui  2  ");
    }

    #[test]
    fn rendered_list_includes_bell_marker_and_literal_width_for_belling_session() {
        let context =
            context_with_session_states("dev", [("$1", "dev", false), ("$2", "yui", true)]);
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("@GHC_SYM_WIN_BELL"));
        assert!(segment.rich_text.contains("#[range=session|$2]"));
        assert_eq!(segment.literal_text, " dev | 1  yui  2 ¤ ");
    }

    fn context_with_sessions<const N: usize>(
        current_session_name: &str,
        sessions: [(&str, &str); N],
    ) -> RenderContext {
        let sessions = sessions.map(|(id, name)| (id, name, false));
        context_with_session_states(current_session_name, sessions)
    }

    fn context_with_session_states<const N: usize>(
        current_session_name: &str,
        sessions: [(&str, &str, bool); N],
    ) -> RenderContext {
        context_with_session_states_and_last(current_session_name, "", sessions)
    }

    fn context_with_session_states_and_last<const N: usize>(
        current_session_name: &str,
        client_last_session: &str,
        sessions: [(&str, &str, bool); N],
    ) -> RenderContext {
        let sessions = sessions
            .into_iter()
            .map(|(id, name, has_bell)| SessionInfo {
                id: id.to_string(),
                name: name.to_string(),
                has_bell,
            })
            .collect::<Vec<_>>();

        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: current_session_name.to_string(),
                client_last_session: client_last_session.to_string(),
                host: "h".to_string(),
                session_created: 1,
                sessions: sessions.clone(),
                options: BTreeMap::new(),
            },
            group: SessionGroupView {
                current_session_name: current_session_name.to_string(),
                sessions,
            },
            layout: LayoutPlan {
                mode: StatusMode::TopAdaptive,
                position: StatusPosition::Top,
                kind: LayoutKind::Wide,
                rows: 1,
                target_status: "on".to_string(),
                key: "02:wide".to_string(),
            },
        }
    }
}
