use crate::model::RenderedStatus;
use crate::util::width::display_width;

const DEFAULT_STATUS_LEFT_LENGTH: usize = 64;
const DEFAULT_STATUS_RIGHT_LENGTH: usize = 84;
const STATUS_LENGTH_PADDING: usize = 2;
/*
 * The session-list shadow budgets one prefix; status-left-length reserves the
 * second independently of the live responsive guards used by the metric block.
 */
const COMBINED_SESSION_STATE_EXTRA_WIDTH: usize = 2;

pub fn status_left_length(
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

pub fn status_right_length(status: &RenderedStatus, width: usize) -> String {
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
    use super::{
        DEFAULT_STATUS_LEFT_LENGTH, DEFAULT_STATUS_RIGHT_LENGTH, status_left_length,
        status_right_length,
    };
    use crate::model::{RenderedSegment, RenderedStatus};

    #[test]
    fn preserves_left_default_for_short_left_status() {
        let status = rendered_status("short", "short");
        assert_eq!(status_left_length(&status, 200, 0), "64");
    }

    #[test]
    fn preserves_right_default_for_short_right_status() {
        let status = rendered_status("short", "short");
        assert_eq!(status_right_length(&status, 200), "84");
    }

    #[test]
    fn grows_left_with_content_plus_padding() {
        let status = rendered_status(&"x".repeat(68), "short");
        assert_eq!(status_left_length(&status, 200, 0), "70");
    }

    #[test]
    fn left_length_covers_supplementary_cjk_cells() {
        let status = rendered_status(&"𠮷".repeat(40), "short");
        assert_eq!(status_left_length(&status, 200, 0), "82");
    }

    #[test]
    fn left_length_reserves_a_second_state_prefix_per_session() {
        let status = rendered_status(&"x".repeat(68), "short");
        assert_eq!(status_left_length(&status, 200, 3), "76");
        assert_eq!(status_left_length(&status, 200, 0), "70");
    }

    #[test]
    fn grows_right_with_content_plus_padding() {
        let status = rendered_status("short", &"x".repeat(90));
        assert_eq!(status_right_length(&status, 200), "92");
    }

    #[test]
    fn caps_left_length_at_client_width() {
        let status = rendered_status(&"x".repeat(240), "short");
        assert_eq!(status_left_length(&status, 200, 0), "200");
    }

    #[test]
    fn caps_right_length_at_client_width() {
        let status = rendered_status("short", &"x".repeat(240));
        assert_eq!(status_right_length(&status, 200), "200");
    }

    #[test]
    fn caps_long_left_status_at_narrow_client_width() {
        let status = rendered_status(&"x".repeat(200), "short");
        assert_eq!(status_left_length(&status, 80, 0), "80");
    }

    #[test]
    fn caps_long_right_status_at_narrow_client_width() {
        let status = rendered_status("short", &"x".repeat(200));
        assert_eq!(status_right_length(&status, 90), "90");
    }

    #[test]
    fn never_returns_less_than_left_default_for_short_left_status() {
        let status = rendered_status("short", "short");
        assert_eq!(
            status_left_length(&status, 40, 0),
            DEFAULT_STATUS_LEFT_LENGTH.to_string()
        );
    }

    #[test]
    fn never_returns_less_than_right_default_for_short_right_status() {
        let status = rendered_status("short", "short");
        assert_eq!(
            status_right_length(&status, 40),
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
}
