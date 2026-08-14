use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment};
use crate::status_widget::ComputedWidget;

const LIST_SURFACE_BG: &str = "default";
// The first item's ">" is a powerline join the orange host segment points into the
// session list: the arrow ink is the host pill color over the item-colored cell, so the
// host flows straight on. (Not the "default" token: as fg it would be the bar text color.)
const FIRST_ITEM_ARROW_FG: &str = "#{@GHC_SL_BG_PILL_HOST}";
const ACTIVE_BG: &str = "#{@GHC_SL_BG_SESSION_LIST_ACTIVE}";
const ACTIVE_FG: &str = "#{@GHC_SL_FG_SESSION_LIST_ACTIVE}";
const INACTIVE_NAME_BG: &str = "#{@GHC_SL_BG_SESSION_ITEM_NAME}";
const INACTIVE_NAME_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_NAME}";
const INACTIVE_NUM_BG: &str = "#{@GHC_SL_BG_SESSION_ITEM_NUM}";
const INACTIVE_NUM_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_NUM}";
const LAST_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_LAST}";
const INACTIVE_BELL_FG: &str = "#{@GHC_SL_FG_SESSION_ITEM_BELL}";
const RANGE_CLOSE: &str = "#[norange]#[default]";
// The last item always pads one trailing cell so status-left-length stays constant
// across the session-owned active variants.
const LAST_RANGE_CLOSE: &str = "#[default]#[norange] #[default]";
const LAST_ITEM_CLOSE: &str = "#[default] #[default]";

// A status-left cache is embedded in a guarded tmux command. Keep the rendered
// session-list payload comfortably below tmux's parser limit, leaving headroom
// for the host segment, cache witness, command syntax, and quoting.
const MAX_SESSION_LIST_RICH_BYTES: usize = 10 * 1024;
// Session names are user-controlled. Bound their format-expanded representation
// so one pathological name cannot consume the entire list budget.
const MAX_SESSION_NAME_FORMAT_BYTES: usize = 96;
const DISPLAY_LITERAL_WRAPPER_BYTES: usize = "#{l:}".len();
const OVERFLOW_LITERAL: &str = " … ";

// This placeholder mirrors the arrow separator glyph in rich_text. status-left-length
// uses literal_text as a tmux-width shadow, so update it with the rich item shape.
const ARROW_LITERAL: char = '\u{e0b0}';
const SPINNER_LITERAL: char = '\u{00a4}';
const BELL_LITERAL: char = '\u{00a4}';

pub struct SessionListWidget;

impl ComputedWidget for SessionListWidget {
    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(render_session_list(context))
    }
}

/// Rebuilds one session-owned cache from the snapshot. Active styling is baked for
/// that cache's owning session, which keeps large groups below tmux's command parser
/// limit. The last-focus marker remains per-client because clients attached to the
/// same session can still have different navigation history.
fn render_session_list(context: &RenderContext) -> RenderedSegment {
    if context.group.sessions.is_empty() {
        return RenderedSegment::empty();
    }

    let current_offset = context
        .group
        .sessions
        .iter()
        .position(|session| session.name == context.group.current_session_name)
        .unwrap_or_default();
    let mut start = current_offset;
    let mut end = current_offset + 1;
    let mut rendered = render_session_window(context, start, end);

    loop {
        let left = (start > 0)
            .then(|| render_session_window(context, start - 1, end))
            .filter(|candidate| candidate.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);
        let right = (end < context.group.sessions.len())
            .then(|| render_session_window(context, start, end + 1))
            .filter(|candidate| candidate.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);

        match (left, right) {
            (Some(left), Some(right)) => {
                let left_count = current_offset - start;
                let right_count = end - current_offset - 1;
                if left_count <= right_count {
                    start -= 1;
                    rendered = left;
                } else {
                    end += 1;
                    rendered = right;
                }
            }
            (Some(left), None) => {
                start -= 1;
                rendered = left;
            }
            (None, Some(right)) => {
                end += 1;
                rendered = right;
            }
            (None, None) => break,
        }
    }

    debug_assert!(rendered.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);
    rendered
}

fn render_session_window(context: &RenderContext, start: usize, end: usize) -> RenderedSegment {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    let session_count = context.group.sessions.len();
    let entry_count = end - start + usize::from(start > 0) + usize::from(end < session_count);
    let mut entry_offset = 0;
    let mut previous_active: Option<bool> = None;

    if start > 0 {
        push_overflow_item(
            &mut literal_text,
            &mut rich_text,
            previous_active,
            entry_offset + 1 == entry_count,
        );
        previous_active = Some(false);
        entry_offset += 1;
    }

    for (offset, session) in context.group.sessions[start..end].iter().enumerate() {
        let index = start + offset + 1;
        let is_last = entry_offset + 1 == entry_count;
        let is_active = session.name == context.group.current_session_name;
        let (display_name, name_was_truncated) = bounded_session_name(&session.name);

        rich_text.push_str(&format!("#[range=session|{}]", session.id));
        literal_text.push(ARROW_LITERAL);
        match previous_active {
            Some(left_active) => rich_text.push_str(&render_join_separator(left_active, is_active)),
            None => rich_text.push_str(&render_left_edge(is_active)),
        }
        literal_text.push_str(&render_item_body_literal(
            &display_name,
            index,
            session.has_bell,
        ));
        rich_text.push_str(&render_item_body_with_last_focus(
            &display_name,
            &session.id,
            index,
            session.has_bell,
            is_active,
            (!name_was_truncated).then_some(session.name.as_str()),
        ));
        if is_last {
            literal_text.push(ARROW_LITERAL);
            literal_text.push(' ');
            rich_text.push_str(&render_right_edge(is_active));
            rich_text.push_str(LAST_RANGE_CLOSE);
        } else {
            rich_text.push_str(RANGE_CLOSE);
        }
        previous_active = Some(is_active);
        entry_offset += 1;
    }

    if end < session_count {
        push_overflow_item(&mut literal_text, &mut rich_text, previous_active, true);
    }

    RenderedSegment {
        literal_text,
        rich_text,
    }
}

fn push_overflow_item(
    literal_text: &mut String,
    rich_text: &mut String,
    previous_active: Option<bool>,
    is_last: bool,
) {
    literal_text.push(ARROW_LITERAL);
    match previous_active {
        Some(left_active) => rich_text.push_str(&render_join_separator(left_active, false)),
        None => rich_text.push_str(&render_left_edge(false)),
    }
    literal_text.push_str(OVERFLOW_LITERAL);
    rich_text.push_str(&format!(
        "#[fg={INACTIVE_NAME_FG}#,bg={INACTIVE_NAME_BG}] … #[fg={INACTIVE_NUM_FG}#,bg={INACTIVE_NUM_BG}]"
    ));
    if is_last {
        literal_text.push(ARROW_LITERAL);
        literal_text.push(' ');
        rich_text.push_str(&render_right_edge(false));
        rich_text.push_str(LAST_ITEM_CLOSE);
    }
}

fn bounded_session_name(session_name: &str) -> (String, bool) {
    let body_budget = MAX_SESSION_NAME_FORMAT_BYTES - DISPLAY_LITERAL_WRAPPER_BYTES;
    let ellipsis_bytes = '…'.len_utf8();
    let mut display_name = String::new();
    let mut rendered_bytes = 0;
    let mut truncated = false;

    for character in session_name.chars() {
        let character_bytes = display_literal_character_bytes(character);
        if rendered_bytes + character_bytes > body_budget {
            truncated = true;
            break;
        }
        display_name.push(character);
        rendered_bytes += character_bytes;
    }

    if truncated {
        while rendered_bytes + ellipsis_bytes > body_budget {
            let character = display_name
                .pop()
                .expect("session-name budget always fits an ellipsis");
            rendered_bytes -= display_literal_character_bytes(character);
        }
        display_name.push('…');
    }

    (display_name, truncated)
}

fn display_literal_character_bytes(character: char) -> usize {
    match character {
        '#' => 4,
        '}' => 2,
        _ => character.len_utf8(),
    }
}

/// Inactive foreground: orange last-focus ink when this item is the client's
/// `client_last_session`, otherwise the base item ink.
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

fn render_left_edge(first_active: bool) -> String {
    // The orange host segment points its ">" arrow into the first item: ink = host pill
    // color, bg = the owning session's statically selected item color.
    render_arrow(
        FIRST_ITEM_ARROW_FG,
        if first_active {
            ACTIVE_BG
        } else {
            INACTIVE_NAME_BG
        },
    )
}

fn render_join_separator(left_active: bool, right_active: bool) -> String {
    // Powerline seam between two items: ink = left item's trailing (num) bg, bg = right
    // item's leading (name) bg.
    let fg = if left_active {
        ACTIVE_BG
    } else {
        INACTIVE_NUM_BG
    };
    let bg = if right_active {
        ACTIVE_BG
    } else {
        INACTIVE_NAME_BG
    };
    render_arrow(fg, bg)
}

fn render_right_edge(last_active: bool) -> String {
    let fg = if last_active {
        ACTIVE_BG
    } else {
        INACTIVE_NUM_BG
    };
    render_arrow(fg, LIST_SURFACE_BG)
}

fn render_item_body_literal(session_name: &str, index: usize, has_bell: bool) -> String {
    // Budget the maximum dynamic prefix. Idle omits its gap and SPINNER_LITERAL;
    // active (`name | N`) and inactive (`name  N`) bodies remain equal width.
    if has_bell {
        return format!(" {SPINNER_LITERAL}{BELL_LITERAL} {session_name}  {index} ");
    }

    format!(" {SPINNER_LITERAL} {session_name}  {index} ")
}

fn render_item_body_with_last_focus(
    session_name: &str,
    session_id: &str,
    index: usize,
    has_bell: bool,
    is_active: bool,
    last_focus_session_name: Option<&str>,
) -> String {
    if is_active {
        return active_item_body(session_name, session_id, index, has_bell);
    }
    inactive_item_body_with_last_focus(
        session_name,
        session_id,
        index,
        has_bell,
        last_focus_session_name,
    )
}

fn active_item_body(session_name: &str, session_id: &str, index: usize, has_bell: bool) -> String {
    let name = display_literal(session_name);
    let running_prefix = running_spinner_prefix(session_id);
    if has_bell {
        return format!(
            "#[fg={ACTIVE_FG}#,bg={ACTIVE_BG}#,bold]{running_prefix}#{{@GHC_SYM_WIN_BELL}} {name} | {index} "
        );
    }

    format!("#[fg={ACTIVE_FG}#,bg={ACTIVE_BG}#,bold]{running_prefix} {name} | {index} ")
}

fn inactive_item_body_with_last_focus(
    session_name: &str,
    session_id: &str,
    index: usize,
    has_bell: bool,
    last_focus_session_name: Option<&str>,
) -> String {
    let name_fg = last_focus_session_name.map_or_else(
        || INACTIVE_NAME_FG.to_string(),
        |name| last_focus_fg(name, INACTIVE_NAME_FG),
    );
    let num_fg = last_focus_session_name.map_or_else(
        || INACTIVE_NUM_FG.to_string(),
        |name| last_focus_fg(name, INACTIVE_NUM_FG),
    );
    let name = display_literal(session_name);
    let running_prefix = running_spinner_prefix(session_id);
    if has_bell {
        return format!(
            "#[fg={name_fg}#,bg={INACTIVE_NAME_BG}]{running_prefix}#[fg={INACTIVE_BELL_FG}#,bg={INACTIVE_NAME_BG}#,bold]#{{@GHC_SYM_WIN_BELL}}#[fg={name_fg}#,bg={INACTIVE_NAME_BG}] {name} #[fg={num_fg}#,bg={INACTIVE_NUM_BG}] {index} "
        );
    }

    format!(
        "#[fg={name_fg}#,bg={INACTIVE_NAME_BG}]{running_prefix} {name} #[fg={num_fg}#,bg={INACTIVE_NUM_BG}] {index} "
    )
}

/// Adds a leading gap plus one live cell before the title only while running.
/// `render_item_body_literal` budgets that maximum width without drawing idle padding.
fn running_spinner_prefix(session_id: &str) -> String {
    format!(
        "#{{?#{{&&:#{{==:#{{@GHC_SL_SCHED_ACTIVE}},1}},#{{m:*|{session_id}|*,#{{@GHC_SL_RUNNING_SESSIONS}}}}}},#{{=2:#{{E:@GHC_SESSION_RUNNING_PREFIX_FMT}}}},}}"
    )
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;
    use std::rc::Rc;

    use super::{
        MAX_SESSION_LIST_RICH_BYTES, RenderedSegment, active_item_body, compare_literal,
        display_literal, inactive_item_body_with_last_focus, render_item_body_literal,
        render_item_body_with_last_focus, render_join_separator, render_left_edge,
        render_right_edge, render_session_list, running_spinner_prefix,
    };
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, SessionGroupView, SessionInfo, StatusMode,
        StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn item_body_bakes_the_owner_active_branch() {
        let active = render_item_body_with_last_focus("tmux", "$2", 2, false, true, Some("tmux"));
        assert!(active.contains("@GHC_SL_FG_SESSION_LIST_ACTIVE"));
        assert!(!active.contains("client_last_session"));

        let inactive =
            render_item_body_with_last_focus("tmux", "$2", 2, false, false, Some("tmux"));
        assert!(inactive.contains("@GHC_SL_FG_SESSION_ITEM_NAME"));
        assert!(inactive.contains("#{==:#{client_last_session},#{l:tmux}}"));
        assert!(inactive.contains(&running_spinner_prefix("$2")));
    }

    #[test]
    fn active_branch_places_running_prefix_before_title() {
        let active = active_item_body("tmux", "$2", 2, false);
        let running_prefix = running_spinner_prefix("$2");
        assert_eq!(
            active,
            format!(
                "#[fg=#{{@GHC_SL_FG_SESSION_LIST_ACTIVE}}#,bg=#{{@GHC_SL_BG_SESSION_LIST_ACTIVE}}#,bold]{running_prefix} #{{l:tmux}} | 2 "
            )
        );
        assert!(!active.contains("@GHC_SL_FG_SESSION_ITEM_LAST"));
    }

    #[test]
    fn inactive_branch_splits_name_and_number_with_last_focus_fg() {
        let inactive = inactive_item_body_with_last_focus("dev", "$2", 2, false, Some("dev"));
        let running_prefix = running_spinner_prefix("$2");
        assert_eq!(
            inactive,
            format!(
                "#[fg=#{{?#{{==:#{{client_last_session}},#{{l:dev}}}},#{{@GHC_SL_FG_SESSION_ITEM_LAST}},#{{@GHC_SL_FG_SESSION_ITEM_NAME}}}}#,bg=#{{@GHC_SL_BG_SESSION_ITEM_NAME}}]{running_prefix} #{{l:dev}} #[fg=#{{?#{{==:#{{client_last_session}},#{{l:dev}}}},#{{@GHC_SL_FG_SESSION_ITEM_LAST}},#{{@GHC_SL_FG_SESSION_ITEM_NUM}}}}#,bg=#{{@GHC_SL_BG_SESSION_ITEM_NUM}}] 2 "
            )
        );
    }

    #[test]
    fn active_branch_places_running_and_bell_before_title() {
        let active = active_item_body("tmux", "$2", 2, true);
        let running = active.find("@GHC_SESSION_RUNNING_PREFIX_FMT").unwrap();
        let bell = active.find("@GHC_SYM_WIN_BELL").unwrap();
        let title = active.find("#{l:tmux}").unwrap();
        assert!(running < bell && bell < title);
        assert!(active.contains(" | 2 "));
        assert_eq!(render_item_body_literal("tmux", 2, true), " ¤¤ tmux  2 ");
    }

    #[test]
    fn inactive_branch_places_running_and_bell_before_title_without_pipe() {
        let inactive = inactive_item_body_with_last_focus("dev", "$2", 2, true, Some("dev"));
        let running = inactive.find("@GHC_SESSION_RUNNING_PREFIX_FMT").unwrap();
        let bell = inactive.find("@GHC_SYM_WIN_BELL").unwrap();
        let title = inactive.rfind("#{l:dev}").unwrap();
        assert!(running < bell && bell < title);
        assert!(inactive.contains("@GHC_SL_FG_SESSION_ITEM_BELL"));
        assert!(inactive.contains(" #{l:dev} "));
        assert!(!inactive.contains("| 2 "));
        assert_eq!(render_item_body_literal("dev", 2, true), " ¤¤ dev  2 ");
    }

    #[test]
    fn running_prefix_targets_one_session_and_has_no_idle_padding() {
        assert_eq!(
            running_spinner_prefix("$2"),
            "#{?#{&&:#{==:#{@GHC_SL_SCHED_ACTIVE},1},#{m:*|$2|*,#{@GHC_SL_RUNNING_SESSIONS}}},#{=2:#{E:@GHC_SESSION_RUNNING_PREFIX_FMT}},}"
        );
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
        let active = active_item_body("a#b", "$1", 1, false);
        assert!(active.contains(" #{l:a####b} "));
        let inactive = inactive_item_body_with_last_focus("a#b", "$1", 1, false, Some("a#b"));
        assert!(inactive.contains(" #{l:a####b} "));
        // ...while the last-focus compare right-value keeps the expand-only (doubled) form.
        assert!(inactive.contains("#{==:#{client_last_session},#{l:a##b}}"));
    }

    #[test]
    fn join_separator_uses_baked_neighbor_states() {
        assert_eq!(
            render_join_separator(true, false),
            "#[fg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}#,bg=#{@GHC_SL_BG_SESSION_ITEM_NAME}]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn left_edge_uses_baked_first_item_state() {
        assert_eq!(
            render_left_edge(true),
            "#[fg=#{@GHC_SL_BG_PILL_HOST}#,bg=#{@GHC_SL_BG_SESSION_LIST_ACTIVE}]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn right_edge_uses_baked_last_item_state() {
        assert_eq!(
            render_right_edge(false),
            "#[fg=#{@GHC_SL_BG_SESSION_ITEM_NUM}#,bg=default]#{@GHC_SEP_ARROW_RIGHT}"
        );
    }

    #[test]
    fn literal_text_accounts_for_visible_session_list_glyphs() {
        let context = context_with_sessions("dev", [("$1", "dev"), ("$2", "yui")]);
        let segment = render_session_list(&context);

        assert_eq!(
            segment.literal_text,
            "\u{e0b0} ¤ dev  1 \u{e0b0} ¤ yui  2 \u{e0b0} "
        );
    }

    #[test]
    fn session_owned_rich_text_bakes_a_different_active_item() {
        let on_dev = render_session_list(&context_with_sessions(
            "dev",
            [("$1", "dev"), ("$2", "yui")],
        ));
        let on_yui = render_session_list(&context_with_sessions(
            "yui",
            [("$1", "dev"), ("$2", "yui")],
        ));

        assert_eq!(on_dev.literal_text, on_yui.literal_text);
        assert_ne!(on_dev.rich_text, on_yui.rich_text);
        assert!(on_dev.rich_text.contains(&running_spinner_prefix("$1")));
        assert!(on_yui.rich_text.contains(&running_spinner_prefix("$2")));
    }

    #[test]
    fn single_visible_session_still_renders_session_list() {
        let context = context_with_sessions("dev", [("$1", "dev")]);
        let segment = render_session_list(&context);

        assert!(segment.rich_text.contains("#[range=session|$1]"));
        assert!(segment.rich_text.contains("@GHC_SL_BG_SESSION_LIST_ACTIVE"));
        assert_eq!(segment.literal_text, "\u{e0b0} ¤ dev  1 \u{e0b0} ");
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
            "\u{e0b0} ¤ dev  1 \u{e0b0} ¤ yui  2 \u{e0b0} "
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
            "\u{e0b0} ¤ dev  1 \u{e0b0} ¤¤ yui  2 \u{e0b0} "
        );
    }

    #[test]
    fn session_owned_cache_stays_bounded_and_keeps_current_global_index() {
        let sessions = (1..=40)
            .map(|index| session_info(&format!("${index}"), &format!("s{index:02}"), false))
            .collect();
        let context = context_with_session_infos("s20", "", sessions);

        let segment = render_session_list(&context);

        assert!(
            segment.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES,
            "session list cache grew to {} bytes",
            segment.rich_text.len()
        );
        assert!(segment.rich_text.contains("#{l:s20}"));
        assert!(segment.rich_text.contains(&running_spinner_prefix("$20")));
        assert!(segment.literal_text.starts_with("\u{e0b0} … "));
        assert!(segment.literal_text.contains("… \u{e0b0} "));
    }

    #[test]
    fn bounded_window_keeps_current_at_group_edges() {
        let sessions = (1..=40)
            .map(|index| session_info(&format!("${index}"), &format!("s{index:02}"), false))
            .collect::<Vec<_>>();

        let first = render_session_list(&context_with_session_infos("s01", "", sessions.clone()));
        let last = render_session_list(&context_with_session_infos("s40", "", sessions));

        assert!(first.rich_text.contains(&running_spinner_prefix("$1")));
        assert!(last.rich_text.contains(&running_spinner_prefix("$40")));
        assert!(first.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);
        assert!(last.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);
    }

    #[test]
    fn oversized_current_session_name_is_truncated_to_budget() {
        let long_name = "#".repeat(MAX_SESSION_LIST_RICH_BYTES * 2);
        let context =
            context_with_session_infos(&long_name, "", vec![session_info("$1", &long_name, false)]);

        let segment = render_session_list(&context);

        assert!(segment.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);
        assert!(segment.literal_text.contains('…'));
        assert!(!segment.rich_text.contains(&long_name));
    }

    #[test]
    fn oversized_inactive_name_drops_full_last_focus_comparison() {
        let long_name = "#".repeat(MAX_SESSION_LIST_RICH_BYTES * 2);
        let context = context_with_session_infos(
            "main",
            &long_name,
            vec![
                session_info("$1", "main", false),
                session_info("$2", &long_name, false),
            ],
        );

        let segment = render_session_list(&context);

        assert!(segment.rich_text.len() <= MAX_SESSION_LIST_RICH_BYTES);
        assert!(segment.literal_text.contains('…'));
        assert!(!segment.rich_text.contains("client_last_session"));
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
            .map(|(id, name, has_bell)| session_info(id, name, has_bell))
            .collect::<Vec<_>>();

        context_with_session_infos(current_session_name, client_last_session, sessions)
    }

    fn context_with_session_infos(
        current_session_name: &str,
        client_last_session: &str,
        sessions: Vec<SessionInfo>,
    ) -> RenderContext {
        RenderContext {
            snapshot: Rc::new(TmuxSnapshot {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: current_session_name.to_string(),
                client_last_session: client_last_session.to_string(),
                host: "h".to_string(),
                session_created: 1,
                sessions: sessions.clone(),
                client_widths: Vec::new(),
                options: BTreeMap::new(),
            }),
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
            render_session_created: 1,
            session_layouts: Vec::new(),
        }
    }

    fn session_info(id: &str, name: &str, has_bell: bool) -> SessionInfo {
        SessionInfo {
            id: id.to_string(),
            name: name.to_string(),
            has_bell,
            status: "on".to_string(),
            layout_key: String::new(),
            left_length: String::new(),
            right_length: String::new(),
            format_0: String::new(),
            format_1: String::new(),
            render_key: String::new(),
            cache_witnesses: std::array::from_fn(|_| String::new()),
            created: 1,
        }
    }
}
