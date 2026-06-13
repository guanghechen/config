use crate::model::{RenderContext, RenderedStatus};
use crate::util::width::display_width;

const DEFAULT_STATUS_LEFT_LENGTH: usize = 64;
const DEFAULT_STATUS_RIGHT_LENGTH: usize = 84;
const STATUS_LENGTH_PADDING: usize = 2;

pub fn status_left_length(status: &RenderedStatus, context: &RenderContext) -> String {
    dynamic_status_length(
        &status.status_left.literal_text,
        context,
        DEFAULT_STATUS_LEFT_LENGTH,
    )
    .to_string()
}

pub fn status_right_length(status: &RenderedStatus, context: &RenderContext) -> String {
    dynamic_status_length(
        &status.status_right.literal_text,
        context,
        DEFAULT_STATUS_RIGHT_LENGTH,
    )
    .to_string()
}

fn dynamic_status_length(literal_text: &str, context: &RenderContext, default: usize) -> usize {
    let desired = display_width(literal_text)
        .saturating_add(STATUS_LENGTH_PADDING)
        .max(default);
    let max = context.snapshot.width.max(default);

    desired.min(max)
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        DEFAULT_STATUS_LEFT_LENGTH, DEFAULT_STATUS_RIGHT_LENGTH, status_left_length,
        status_right_length,
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
            session_format: empty.clone(),
            current_format: empty,
        }
    }

    fn context_with_width(width: usize) -> RenderContext {
        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width,
                current_session_name: "s".to_string(),
                host: "h".to_string(),
                session_created: 1,
                sessions: Vec::new(),
                options: BTreeMap::new(),
            },
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
        }
    }
}
