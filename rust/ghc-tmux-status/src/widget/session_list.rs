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
// The last item always pads one trailing cell so status-left-length stays constant no
// matter which client is on which session (the active state is decided per-client at
// redraw, so the literal width shadow must not depend on it).
const LAST_RANGE_CLOSE: &str = "#[default]#[norange] #[default]";

// This placeholder mirrors the arrow separator glyph in rich_text. status-left-length
// uses literal_text as a tmux-width shadow, so update it with the rich item shape.
const ARROW_LITERAL: char = '\u{e0b0}';
const BELL_LITERAL: char = '\u{00a4}';

pub struct SessionListWidget;

impl ComputedWidget for SessionListWidget {
    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(render_session_list(context))
    }
}

/// Rebuilds from the session snapshot. The active session and the last-focus marker are
/// per-client facts, so they are emitted as tmux conditionals keyed on `#{session_id}` /
/// `#{client_last_session}` rather than baked from one client's viewpoint: a single shared
/// option then renders correctly for every attached client at its own status redraw.
fn render_session_list(context: &RenderContext) -> RenderedSegment {
    if context.group.sessions.is_empty() {
        return RenderedSegment::empty();
    }

    let mut literal_text = String::new();
    let mut rich_text = String::new();
    let session_count = context.group.sessions.len();
    let mut previous_id: Option<&str> = None;
    for (offset, session) in context.group.sessions.iter().enumerate() {
        let index = offset + 1;
        let is_last = index == session_count;

        rich_text.push_str(&format!("#[range=session|{}]", session.id));
        literal_text.push(ARROW_LITERAL);
        match previous_id {
            Some(left_id) => rich_text.push_str(&render_join_separator(left_id, &session.id)),
            None => rich_text.push_str(&render_left_edge(&session.id)),
        }
        literal_text.push_str(&render_item_body_literal(
            &session.name,
            index,
            session.has_bell,
        ));
        rich_text.push_str(&render_item_body(
            &session.name,
            index,
            session.has_bell,
            &session.id,
        ));
        if is_last {
            literal_text.push(ARROW_LITERAL);
            literal_text.push(' ');
            rich_text.push_str(&render_right_edge(&session.id));
            rich_text.push_str(LAST_RANGE_CLOSE);
        } else {
            rich_text.push_str(RANGE_CLOSE);
        }
        previous_id = Some(&session.id);
    }

    RenderedSegment {
        literal_text,
        rich_text,
    }
}

/// `1` for the client whose current session is this item, `0` otherwise. Keyed on the
/// stable session id (not the name) so duplicate session names cannot alias.
fn active_condition(session_id: &str) -> String {
    format!("#{{==:#{{session_id}},{session_id}}}")
}

/// `cond ? active : inactive`, written as a tmux `#{?...}` so only the selected branch is
/// expanded at redraw (style commas inside the branches stay escaped as `#,`).
fn conditional(cond: &str, active: &str, inactive: &str) -> String {
    format!("#{{?{cond},{active},{inactive}}}")
}

/// Inactive foreground: orange last-focus ink when this item is the client's
/// `client_last_session`, otherwise the base item ink. Per-client like the active state.
/// The compared name is a literal so a `,`/`#`/`}` in it cannot split the surrounding DSL.
fn last_focus_fg(session_name: &str, base_fg: &str) -> String {
    let name = compare_literal(session_name);
    format!("#{{?#{{==:#{{client_last_session}},{name}}},{LAST_FG},{base_fg}}}")
}

/// Wraps a session name as a tmux literal for use as an `#{==}` right-value. It is compared
/// against the raw `#{client_last_session}` and never drawn, so it only has to survive the
/// format-expand pass: `#{l:}` brace-protects `,`, and `#`->`##` / `}`->`#}` (in that order,
/// so the `#` injected by `#}` is not re-doubled) stop `#`/`}` from terminating the format.
/// `format_unescape` then folds these back to the raw name for the comparison.
fn compare_literal(session_name: &str) -> String {
    let escaped = session_name.replace('#', "##").replace('}', "#}");
    format!("#{{l:{escaped}}}")
}

/// Wraps a session name as a tmux literal for *visible* branch text. Display text crosses two
/// folding stages: format-expand (where `#{l:}`/`format_unescape` folds `##`->`#`) and then
/// `format_draw` (which folds `##`->`#` again and reads `#[` as a style introducer). A raw `#`
/// would survive to the draw stage and either inject `#[...]` style markup or mis-measure the
/// on-screen width against the raw-name `literal_text` shadow. Doubling for *both* folds means
/// `#`->`####`; `}`->`#}` (order: `#` first) since `}` is not draw-special; `,` stays
/// brace-protected by `#{l:}`.
fn display_literal(session_name: &str) -> String {
    let escaped = session_name.replace('#', "####").replace('}', "#}");
    format!("#{{l:{escaped}}}")
}

fn render_arrow(fg: &str, bg: &str) -> String {
    format!("#[fg={fg}#,bg={bg}]#{{@GHC_SEP_ARROW_RIGHT}}")
}

fn render_left_edge(first_session_id: &str) -> String {
    // The orange host segment points its ">" arrow into the first item: ink = host pill
    // color, bg = the item color (active or name bg, decided per-client).
    let bg = conditional(
        &active_condition(first_session_id),
        ACTIVE_BG,
        INACTIVE_NAME_BG,
    );
    render_arrow(HEAD_NOTCH_FG, &bg)
}

fn render_join_separator(left_id: &str, right_id: &str) -> String {
    // Powerline seam between two items: ink = left item's trailing (num) bg, bg = right
    // item's leading (name) bg. Both sides depend on each item's per-client active state.
    let fg = conditional(&active_condition(left_id), ACTIVE_BG, INACTIVE_NUM_BG);
    let bg = conditional(&active_condition(right_id), ACTIVE_BG, INACTIVE_NAME_BG);
    render_arrow(&fg, &bg)
}

fn render_right_edge(last_id: &str) -> String {
    let fg = conditional(&active_condition(last_id), ACTIVE_BG, INACTIVE_NUM_BG);
    render_arrow(&fg, LIST_SURFACE_BG)
}

fn render_item_body_literal(session_name: &str, index: usize, has_bell: bool) -> String {
    // Active (` name | N `) and inactive (` name  N `) bodies are equal width, so the
    // literal width shadow is active-invariant: one form covers every client's render.
    if has_bell {
        return format!(" {session_name}  {index} {BELL_LITERAL}");
    }

    format!(" {session_name}  {index} ")
}

fn render_item_body(session_name: &str, index: usize, has_bell: bool, session_id: &str) -> String {
    conditional(
        &active_condition(session_id),
        &active_item_body(session_name, index, has_bell),
        &inactive_item_body(session_name, index, has_bell),
    )
}

fn active_item_body(session_name: &str, index: usize, has_bell: bool) -> String {
    let name = display_literal(session_name);
    if has_bell {
        return format!(
            "#[fg={ACTIVE_FG}#,bg={ACTIVE_BG}#,bold] {name} | {index} #[fg={ACTIVE_FG}#,bg={ACTIVE_BG}#,bold]#{{@GHC_SYM_WIN_BELL}}#[fg={ACTIVE_FG}#,bg={ACTIVE_BG}#,bold]"
        );
    }

    format!("#[fg={ACTIVE_FG}#,bg={ACTIVE_BG}#,bold] {name} | {index} ")
}

fn inactive_item_body(session_name: &str, index: usize, has_bell: bool) -> String {
    let name_fg = last_focus_fg(session_name, INACTIVE_NAME_FG);
    let num_fg = last_focus_fg(session_name, INACTIVE_NUM_FG);
    let name = display_literal(session_name);
    if has_bell {
        return format!(
            "#[fg={name_fg}#,bg={INACTIVE_NAME_BG}] {name} #[fg={num_fg}#,bg={INACTIVE_NUM_BG}] {index} #[fg={INACTIVE_BELL_FG}#,bg={INACTIVE_NUM_BG}#,bold]#{{@GHC_SYM_WIN_BELL}}"
        );
    }

    format!(
        "#[fg={name_fg}#,bg={INACTIVE_NAME_BG}] {name} #[fg={num_fg}#,bg={INACTIVE_NUM_BG}] {index} "
    )
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        RenderedSegment, active_item_body, compare_literal, display_literal, inactive_item_body,
        render_item_body, render_item_body_literal, render_join_separator, render_left_edge,
        render_right_edge, render_session_list,
    };
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, SessionInfo, StatusMode,
        StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn item_body_is_a_per_client_conditional_on_session_id() {
        let body = render_item_body("tmux", 2, false, "$2");
        assert!(body.starts_with("#{?#{==:#{session_id},$2},"));
        // Active branch colors.
        assert!(body.contains("@GHC_SL_FG_SESSION_LIST_ACTIVE"));
        assert!(body.contains("@GHC_SL_BG_SESSION_LIST_ACTIVE"));
        // Inactive branch colors plus the per-client last-focus marker.
        assert!(body.contains("@GHC_SL_FG_SESSION_ITEM_NAME"));
        assert!(body.contains("@GHC_SL_BG_SESSION_ITEM_NAME"));
        assert!(body.contains("@GHC_SL_FG_SESSION_ITEM_NUM"));
        assert!(body.contains("@GHC_SL_BG_SESSION_ITEM_NUM"));
        assert!(body.contains("#{==:#{client_last_session},#{l:tmux}}"));
        assert!(body.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
    }

    #[test]
    fn active_branch_uses_pipe_and_active_palette_without_last_marker() {
        let active = active_item_body("tmux", 2, false);
        assert_eq!(
            active,
            "#[fg=#{@GHC_SL_FG_SESSION_LIST_ACTIVE}#,bg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}#,bold] #{l:tmux} | 2 "
        );
        assert!(!active.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
    }

    #[test]
    fn inactive_branch_splits_name_and_number_with_last_focus_fg() {
        let inactive = inactive_item_body("dev", 2, false);
        assert_eq!(
            inactive,
            "#[fg=#{?#{==:#{client_last_session},#{l:dev}},#{@GHC_SL_FG_SESSION_ITEM_LAST},#{@GHC_SL_FG_SESSION_ITEM_NAME}}#,bg=#{@GHC_SL_BG_SESSION_ITEM_NAME}] #{l:dev} #[fg=#{?#{==:#{client_last_session},#{l:dev}},#{@GHC_SL_FG_SESSION_ITEM_LAST},#{@GHC_SL_FG_SESSION_ITEM_NUM}}#,bg=#{@GHC_SL_BG_SESSION_ITEM_NUM}] 2 "
        );
    }

    #[test]
    fn active_branch_with_bell_renders_bell_after_number() {
        let active = active_item_body("tmux", 2, true);
        assert!(active.contains("@GHC_SYM_WIN_BELL"));
        assert!(active.contains(" #{l:tmux} | 2 "));
        assert_eq!(render_item_body_literal("tmux", 2, true), " tmux  2 ¤");
    }

    #[test]
    fn inactive_branch_with_bell_renders_bell_without_pipe() {
        let inactive = inactive_item_body("dev", 2, true);
        assert!(inactive.contains("@GHC_SYM_WIN_BELL"));
        assert!(inactive.contains("@GHC_SL_FG_SESSION_ITEM_BELL"));
        assert!(inactive.contains(" #{l:dev} "));
        assert!(inactive.contains(" 2 "));
        assert!(!inactive.contains("| 2 "));
        assert_eq!(render_item_body_literal("dev", 2, true), " dev  2 ¤");
    }

    #[test]
    fn compare_literal_escapes_for_the_format_expand_pass_only() {
        // `==` right-value never reaches format_draw, so a single `#{l:}` fold is enough:
        // `,` is brace-protected, `#`->`##`, `}`->`#}` (and the order keeps `#}`'s `#` intact).
        assert_eq!(compare_literal("a,b"), "#{l:a,b}");
        assert_eq!(compare_literal("a#b"), "#{l:a##b}");
        assert_eq!(compare_literal("a}b"), "#{l:a#}b}");
        assert_eq!(compare_literal("a#}b"), "#{l:a###}b}");
    }

    #[test]
    fn display_literal_double_escapes_hash_for_the_draw_stage() {
        // Visible text crosses format-expand AND format_draw; each folds `##`->`#`, so `#`
        // must be quadrupled. `}` is not draw-special, so it still only needs `#}`.
        assert_eq!(display_literal("a,b"), "#{l:a,b}");
        assert_eq!(display_literal("a#b"), "#{l:a####b}");
        assert_eq!(display_literal("a}b"), "#{l:a#}b}");
        // A draw-stage style introducer in the name is neutralised, not injected.
        assert_eq!(display_literal("a#[x]"), "#{l:a####[x]}");
    }

    #[test]
    fn item_bodies_use_draw_safe_display_and_expand_safe_compare() {
        // Display text takes the draw-safe (quadrupled) form in both branches...
        let active = active_item_body("a#b", 1, false);
        assert!(active.contains(" #{l:a####b} | 1 "));
        let inactive = inactive_item_body("a#b", 1, false);
        assert!(inactive.contains(" #{l:a####b} "));
        // ...while the last-focus compare right-value keeps the expand-only (doubled) form.
        assert!(inactive.contains("#{==:#{client_last_session},#{l:a##b}}"));
    }

    #[test]
    fn join_separator_keys_both_sides_on_session_id() {
        assert_eq!(
            render_join_separator("$1", "$2"),
            "#[fg=#{?#{==:#{session_id},$1},#{@GHC_SL_BG_SESSION_LIST_ACTIVE},#{@GHC_SL_BG_SESSION_ITEM_NUM}}#,bg=#{?#{==:#{session_id},$2},#{@GHC_SL_BG_SESSION_LIST_ACTIVE},#{@GHC_SL_BG_SESSION_ITEM_NAME}}]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn left_edge_keys_first_item_background_on_session_id() {
        assert_eq!(
            render_left_edge("$1"),
            "#[fg=#{@GHC_SL_BG_PILL_HOST}#,bg=#{?#{==:#{session_id},$1},#{@GHC_SL_BG_SESSION_LIST_ACTIVE},#{@GHC_SL_BG_SESSION_ITEM_NAME}}]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn right_edge_keys_last_item_ink_on_session_id_over_default_surface() {
        assert_eq!(
            render_right_edge("$2"),
            "#[fg=#{?#{==:#{session_id},$2},#{@GHC_SL_BG_SESSION_LIST_ACTIVE},#{@GHC_SL_BG_SESSION_ITEM_NUM}}#,bg=default]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn literal_text_accounts_for_visible_session_list_glyphs() {
        let context = context_with_sessions("dev", [("$1", "dev"), ("$2", "yui")]);
        let segment = render_session_list(&context);

        assert_eq!(
            segment.literal_text,
            "\u{e0b0} dev  1 \u{e0b0} yui  2 \u{e0b0} "
        );
    }

    #[test]
    fn literal_and_rich_are_independent_of_current_session() {
        // The whole point of the per-client conditional rewrite: one shared option string
        // renders correctly for every client, so neither the rich text nor its width shadow
        // may depend on which session is current at build time.
        let on_dev = render_session_list(&context_with_sessions(
            "dev",
            [("$1", "dev"), ("$2", "yui")],
        ));
        let on_yui = render_session_list(&context_with_sessions(
            "yui",
            [("$1", "dev"), ("$2", "yui")],
        ));

        assert_eq!(on_dev.literal_text, on_yui.literal_text);
        assert_eq!(on_dev.rich_text, on_yui.rich_text);
    }

    #[test]
    fn single_visible_session_still_renders_session_list() {
        let context = context_with_sessions("dev", [("$1", "dev")]);
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("#[range=session|$1]"));
        assert!(segment.rich_text.contains("@GHC_SL_BG_SESSION_LIST_ACTIVE"));
        assert_eq!(segment.literal_text, "\u{e0b0} dev  1 \u{e0b0} ");
    }

    #[test]
    fn empty_session_group_renders_empty_list() {
        let context = context_with_sessions("dev", []);
        let segment = render_session_list(&context);

        assert_eq!(segment, RenderedSegment::empty());
    }

    #[test]
    fn rendered_list_emits_per_client_last_focus_marker() {
        let context = context_with_session_states_and_last(
            "dev",
            "yui",
            [("$1", "dev", false), ("$2", "yui", false)],
        );
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
        assert!(
            segment
                .rich_text
                .contains("#{==:#{client_last_session},#{l:yui}}")
        );
        assert!(segment.rich_text.contains("#[range=session|$2]"));
        assert_eq!(
            segment.literal_text,
            "\u{e0b0} dev  1 \u{e0b0} yui  2 \u{e0b0} "
        );
    }

    #[test]
    fn rendered_list_includes_bell_marker_and_literal_width_for_belling_session() {
        let context =
            context_with_session_states("dev", [("$1", "dev", false), ("$2", "yui", true)]);
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("@GHC_SYM_WIN_BELL"));
        assert!(segment.rich_text.contains("#[range=session|$2]"));
        assert_eq!(
            segment.literal_text,
            "\u{e0b0} dev  1 \u{e0b0} yui  2 ¤\u{e0b0} "
        );
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
