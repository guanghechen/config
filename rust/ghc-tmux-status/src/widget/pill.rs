// These placeholders mirror the common tmux pill shape used by rich_text:
// ROUND_LEFT + icon glyph + one spacer before the body literal.
// status-*-length uses literal_text as a tmux-width shadow, so keep this helper
// in sync when the rich pill shape changes.
const ROUND_LEFT_LITERAL: &str = "";
const ICON_LITERAL: &str = "¤";

pub(super) fn pill_literal(body: &str) -> String {
    format!("{ROUND_LEFT_LITERAL}{ICON_LITERAL} {body}")
}

pub(super) fn prefix_literal() -> String {
    format!("{ICON_LITERAL} ,")
}

#[cfg(test)]
mod tests {
    use super::{pill_literal, prefix_literal};

    #[test]
    fn pill_literal_mirrors_round_icon_spacer_shape() {
        assert_eq!(pill_literal(" body "), "¤  body ");
    }

    #[test]
    fn prefix_literal_mirrors_bare_prefix_indicator_shape() {
        assert_eq!(prefix_literal(), "¤ ,");
    }
}
