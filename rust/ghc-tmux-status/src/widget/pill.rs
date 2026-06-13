// These placeholders mirror the common tmux pill shape used by rich_text:
// ROUND_LEFT + icon glyph + one spacer before the body literal.
// status-*-length uses literal_text as a tmux-width shadow, so keep this helper
// in sync when the rich pill shape changes.
const ROUND_LEFT_LITERAL: &str = "";
const ROUND_RIGHT_LITERAL: &str = "";
const ICON_LITERAL: &str = "¤";

pub(super) fn pill_literal(body: &str) -> String {
    format!("{ROUND_LEFT_LITERAL}{ICON_LITERAL} {body}")
}

// Semantic marker for state-dependent widgets. The pessimistic width comes from
// the caller-provided body template, while the pill shell stays shared.
pub(super) fn conditional_pill_literal(body: &str) -> String {
    pill_literal(body)
}

pub(super) fn prefix_literal() -> String {
    format!("{ICON_LITERAL} ,")
}

pub(super) fn alert_literal() -> String {
    format!("{ROUND_LEFT_LITERAL}{ICON_LITERAL}{ROUND_RIGHT_LITERAL} ,")
}

#[cfg(test)]
mod tests {
    use super::{alert_literal, pill_literal, prefix_literal};

    #[test]
    fn pill_literal_mirrors_round_icon_spacer_shape() {
        assert_eq!(pill_literal(" body "), "¤  body ");
    }

    #[test]
    fn conditional_literals_cover_non_pill_indicators() {
        assert_eq!(prefix_literal(), "¤ ,");
        assert_eq!(alert_literal(), "¤ ,");
    }
}
