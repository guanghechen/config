use crate::model::{RenderContext, RenderedStatus};
use crate::util::width::display_width;

const DEFAULT_STATUS_LEFT_LENGTH: usize = 64;
const DEFAULT_STATUS_RIGHT_LENGTH: usize = 84;
const STATUS_LENGTH_PADDING: usize = 2;
// The session-list layout shadow already budgets one two-column state prefix.
// Running and bell may coexist, so status-left-length needs one additional
// two-column prefix per group session without lifting responsive metric guards.
const COMBINED_SESSION_STATE_EXTRA_WIDTH: usize = 2;

pub fn status_left_length(status: &RenderedStatus, context: &RenderContext) -> String {
    status_left_length_for_width(status, context.snapshot.width, context.group.sessions.len())
}

pub fn status_right_length(status: &RenderedStatus, context: &RenderContext) -> String {
    status_right_length_for_width(status, context.snapshot.width)
}

pub fn status_left_length_for_width(
    status: &RenderedStatus,
    width: usize,
    session_group_count: usize,
) -> String {
    let extra_width = session_group_count.saturating_mul(COMBINED_SESSION_STATE_EXTRA_WIDTH);
    dynamic_status_length(
        &status.status_left.literal_text,
        extra_width,
        width,
        DEFAULT_STATUS_LEFT_LENGTH,
    )
    .to_string()
}

pub fn status_right_length_for_width(status: &RenderedStatus, width: usize) -> String {
    dynamic_status_length(
        &status.status_right.literal_text,
        0,
        width,
        DEFAULT_STATUS_RIGHT_LENGTH,
    )
    .to_string()
}

fn dynamic_status_length(
    literal_text: &str,
    extra_width: usize,
    width: usize,
    default: usize,
) -> usize {
    let desired = display_width(literal_text)
        .saturating_add(extra_width)
        .saturating_add(STATUS_LENGTH_PADDING)
        .max(default);
    let max = width.max(default);

    desired.min(max)
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;
    use std::rc::Rc;

    use super::{
        DEFAULT_STATUS_LEFT_LENGTH, DEFAULT_STATUS_RIGHT_LENGTH, status_left_length,
        status_left_length_for_width, status_right_length,
    };
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderedSegment, RenderedStatus, SessionGroupView,
        StatusMode, StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn preserves_left_default_for_short_left_status() {
        let status = rendered_status("short", "short");
        assert_eq!(status_left_length(&status, &context_with_width(200)), "64");
    }

    #[test]
    fn preserves_right_default_for_short_right_status() {
        let status = rendered_status("short", "short");
        assert_eq!(status_right_length(&status, &context_with_width(200)), "84");
    }

    #[test]
    fn grows_left_with_content_plus_padding() {
        let status = rendered_status(&"x".repeat(68), "short");
        assert_eq!(status_left_length(&status, &context_with_width(200)), "70");
    }

    #[test]
    fn left_length_reserves_a_second_state_prefix_per_session() {
        let status = rendered_status(&"x".repeat(68), "short");
        let context = context_with_width_and_session_count(200, 3);

        assert_eq!(status_left_length(&status, &context), "76");
        assert_eq!(status_left_length_for_width(&status, 200, 0), "70");
    }

    #[test]
    fn grows_right_with_content_plus_padding() {
        let status = rendered_status("short", &"x".repeat(90));
        assert_eq!(status_right_length(&status, &context_with_width(200)), "92");
    }

    #[test]
    fn caps_left_length_at_client_width() {
        let status = rendered_status(&"x".repeat(240), "short");
        assert_eq!(status_left_length(&status, &context_with_width(200)), "200");
    }

    #[test]
    fn caps_right_length_at_client_width() {
        let status = rendered_status("short", &"x".repeat(240));
        assert_eq!(
            status_right_length(&status, &context_with_width(200)),
            "200"
        );
    }

    #[test]
    fn caps_long_left_status_at_narrow_client_width() {
        let status = rendered_status(&"x".repeat(200), "short");
        assert_eq!(status_left_length(&status, &context_with_width(80)), "80");
    }

    #[test]
    fn caps_long_right_status_at_narrow_client_width() {
        let status = rendered_status("short", &"x".repeat(200));
        assert_eq!(status_right_length(&status, &context_with_width(90)), "90");
    }

    #[test]
    fn never_returns_less_than_left_default_for_short_left_status() {
        let status = rendered_status("short", "short");
        assert_eq!(
            status_left_length(&status, &context_with_width(40)),
            DEFAULT_STATUS_LEFT_LENGTH.to_string()
        );
    }

    #[test]
    fn never_returns_less_than_right_default_for_short_right_status() {
        let status = rendered_status("short", "short");
        assert_eq!(
            status_right_length(&status, &context_with_width(40)),
            DEFAULT_STATUS_RIGHT_LENGTH.to_string()
        );
    }

    fn rendered_status(left: &str, right: &str) -> RenderedStatus {
        let empty = RenderedSegment::empty();
        RenderedStatus {
            status_left: RenderedSegment {
                literal_text: left.to_string(),
                rich_text: left.to_string(),
            },
            status_right: RenderedSegment {
                literal_text: right.to_string(),
                rich_text: right.to_string(),
            },
            session_right: empty.clone(),
            current_format: empty,
        }
    }

    fn context_with_width(width: usize) -> RenderContext {
        context_with_width_and_session_count(width, 0)
    }

    fn context_with_width_and_session_count(width: usize, session_count: usize) -> RenderContext {
        let sessions = (0..session_count)
            .map(|index| crate::model::SessionInfo {
                id: format!("${index}"),
                name: format!("s{index}"),
                has_bell: false,
                status: "on".to_string(),
                layout_key: String::new(),
                left_length: String::new(),
                right_length: String::new(),
                format_0: String::new(),
                format_1: String::new(),
                render_key: String::new(),
                cache_witnesses: std::array::from_fn(|_| String::new()),
                created: 1,
            })
            .collect::<Vec<_>>();
        RenderContext {
            snapshot: Rc::new(TmuxSnapshot {
                mode: "02".to_string(),
                status: "on".to_string(),
                width,
                current_session_name: "s".to_string(),
                client_last_session: String::new(),
                host: "h".to_string(),
                session_created: 1,
                sessions: sessions.clone(),
                client_widths: Vec::new(),
                options: BTreeMap::new(),
            }),
            group: SessionGroupView {
                current_session_name: "s".to_string(),
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
}
