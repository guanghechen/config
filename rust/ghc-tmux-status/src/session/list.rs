use std::collections::{BTreeMap, BTreeSet};

use crate::model::SessionInfo;
use crate::session::item::{FocusTarget, MoveDirection, SwapOutcome};

pub const SESSION_ORDER_OPTION: &str = "@GHC_SL_SESSION_ORDER";
pub const SESSION_ORDER_OPERATION_OPTION: &str = "@GHC_SL_SESSION_ORDER_OP";
pub const SESSION_ORDER_REVISION_OPTION: &str = "@GHC_SL_SESSION_ORDER_REV";
const ORDER_SEPARATOR: char = '\t';

pub fn ordered_sessions(sessions: &[SessionInfo], order_value: Option<&str>) -> Vec<SessionInfo> {
    let order = normalized_order(sessions, order_value);
    let sessions_by_id = sessions
        .iter()
        .map(|session| (session.id.as_str(), session))
        .collect::<BTreeMap<_, _>>();
    order
        .iter()
        .filter_map(|id| {
            sessions_by_id
                .get(id.as_str())
                .map(|session| (*session).clone())
        })
        .collect()
}

pub fn focus_target<'a>(
    ordered_group: &'a [SessionInfo],
    current_session_name: &str,
    target: FocusTarget,
) -> Option<&'a SessionInfo> {
    if ordered_group.is_empty() {
        return None;
    }

    match target {
        FocusTarget::Index(index) => {
            if index == 0 {
                return None;
            }
            ordered_group.get(index - 1)
        }
        FocusTarget::Previous | FocusTarget::Next => {
            let current_index = ordered_group
                .iter()
                .position(|session| session.name == current_session_name)?;
            let count = ordered_group.len();
            let target_index = match target {
                FocusTarget::Previous => (current_index + count - 1) % count,
                FocusTarget::Next => (current_index + 1) % count,
                FocusTarget::Index(_) => unreachable!(),
            };
            ordered_group.get(target_index)
        }
    }
}

pub fn swap_current(
    live_sessions: &[SessionInfo],
    ordered_group: &[SessionInfo],
    current_session_name: &str,
    order_value: Option<&str>,
    direction: MoveDirection,
) -> SwapOutcome {
    let Some(current_index) = ordered_group
        .iter()
        .position(|session| session.name == current_session_name)
    else {
        return SwapOutcome::CurrentMissing;
    };

    let count = ordered_group.len();
    if count <= 1 {
        return match direction {
            MoveDirection::Previous => SwapOutcome::AlreadyFirst,
            MoveDirection::Next => SwapOutcome::AlreadyLast,
        };
    }

    let neighbor_index = match direction {
        MoveDirection::Previous => (current_index + count - 1) % count,
        MoveDirection::Next => (current_index + 1) % count,
    };

    let current_id = &ordered_group[current_index].id;
    let neighbor_id = &ordered_group[neighbor_index].id;
    let mut order = normalized_order(live_sessions, order_value);

    // Swap the two visible group members in the global order so sessions from
    // other groups keep their relative slots between visible sessions.
    let Some(current_position) = order.iter().position(|id| id == current_id) else {
        return SwapOutcome::CurrentMissing;
    };
    let Some(neighbor_position) = order.iter().position(|id| id == neighbor_id) else {
        return SwapOutcome::CurrentMissing;
    };

    order.swap(current_position, neighbor_position);
    SwapOutcome::Changed(encode_order(&order))
}

fn normalized_order(sessions: &[SessionInfo], order_value: Option<&str>) -> Vec<String> {
    let mut order = Vec::new();
    let live_ids = sessions
        .iter()
        .map(|session| session.id.as_str())
        .collect::<BTreeSet<_>>();
    let mut seen = BTreeSet::new();
    for id in parse_order(order_value) {
        if live_ids.contains(id.as_str()) && seen.insert(id.clone()) {
            order.push(id);
        }
    }

    for session in sessions_by_creation_id(sessions) {
        if seen.insert(session.id.clone()) {
            order.push(session.id.clone());
        }
    }

    order
}

fn sessions_by_creation_id(sessions: &[SessionInfo]) -> Vec<&SessionInfo> {
    // tmux session ids are allocated monotonically within a server, so numeric id
    // order gives a stable creation-order fallback for sessions missing from the virtual order.
    let mut indexed_sessions = sessions.iter().enumerate().collect::<Vec<_>>();
    indexed_sessions.sort_by_key(|(index, session)| {
        (session_id_number(&session.id).unwrap_or(u64::MAX), *index)
    });
    indexed_sessions
        .into_iter()
        .map(|(_, session)| session)
        .collect()
}

fn session_id_number(session_id: &str) -> Option<u64> {
    session_id.strip_prefix('$')?.parse().ok()
}

fn parse_order(value: Option<&str>) -> Vec<String> {
    value
        .unwrap_or_default()
        .split(ORDER_SEPARATOR)
        .filter(|id| !id.is_empty())
        .map(str::to_string)
        .collect()
}

fn encode_order(order: &[String]) -> String {
    order.join(&ORDER_SEPARATOR.to_string())
}

#[cfg(test)]
mod tests {
    use super::{focus_target, ordered_sessions, swap_current};
    use crate::model::SessionInfo;
    use crate::session::{FocusTarget, MoveDirection, SwapOutcome};

    #[test]
    fn applies_order_and_appends_new_sessions() {
        let sessions = sessions([("$3", "c"), ("$1", "a"), ("$2", "b")]);
        let ordered = ordered_sessions(&sessions, Some("$2\t$9\t$1"));

        assert_eq!(names(&ordered), vec!["b", "a", "c"]);
    }

    #[test]
    fn orders_unpersisted_sessions_by_creation_id() {
        let sessions = sessions([("$3", "new"), ("$1", "first"), ("$2", "second")]);
        let ordered = ordered_sessions(&sessions, None);

        assert_eq!(names(&ordered), vec!["first", "second", "new"]);
    }

    #[test]
    fn focuses_by_index_and_direction() {
        let sessions = sessions([("$1", "a"), ("$2", "b"), ("$3", "c")]);

        assert_eq!(
            focus_target(&sessions, "b", FocusTarget::Index(3))
                .unwrap()
                .name,
            "c"
        );
        assert_eq!(
            focus_target(&sessions, "b", FocusTarget::Previous)
                .unwrap()
                .name,
            "a"
        );
        assert_eq!(
            focus_target(&sessions, "b", FocusTarget::Next)
                .unwrap()
                .name,
            "c"
        );
    }

    #[test]
    fn focus_direction_wraps_like_legacy_shortcuts() {
        let sessions = sessions([("$1", "a"), ("$2", "b")]);

        assert_eq!(
            focus_target(&sessions, "a", FocusTarget::Previous)
                .unwrap()
                .name,
            "b"
        );
        assert_eq!(
            focus_target(&sessions, "b", FocusTarget::Next)
                .unwrap()
                .name,
            "a"
        );
    }

    #[test]
    fn swaps_current_with_visible_neighbor() {
        let live = sessions([("$1", "a"), ("$2", "b"), ("$3", "c")]);
        let ordered = ordered_sessions(&live, Some("$1\t$2\t$3"));

        let outcome = swap_current(
            &live,
            &ordered,
            "b",
            Some("$1\t$2\t$3"),
            MoveDirection::Next,
        );

        assert_eq!(outcome, SwapOutcome::Changed("$1\t$3\t$2".to_string()));
    }

    #[test]
    fn swaps_current_with_previous_visible_neighbor() {
        let live = sessions([("$1", "a"), ("$2", "b"), ("$3", "c")]);
        let ordered = ordered_sessions(&live, Some("$1\t$2\t$3"));

        let outcome = swap_current(
            &live,
            &ordered,
            "b",
            Some("$1\t$2\t$3"),
            MoveDirection::Previous,
        );

        assert_eq!(outcome, SwapOutcome::Changed("$2\t$1\t$3".to_string()));
    }

    #[test]
    fn swap_preserves_interleaved_sessions_from_other_groups() {
        let live = sessions([
            ("$1", "group-a1"),
            ("$2", "other-x"),
            ("$3", "group-a2"),
            ("$4", "other-y"),
            ("$5", "group-a3"),
        ]);
        let group = sessions([("$1", "group-a1"), ("$3", "group-a2"), ("$5", "group-a3")]);
        let ordered_group = ordered_sessions(&group, Some("$1\t$2\t$3\t$4\t$5"));

        let outcome = swap_current(
            &live,
            &ordered_group,
            "group-a1",
            Some("$1\t$2\t$3\t$4\t$5"),
            MoveDirection::Next,
        );

        assert_eq!(
            outcome,
            SwapOutcome::Changed("$3\t$2\t$1\t$4\t$5".to_string())
        );
    }

    #[test]
    fn swap_direction_wraps_like_focus_shortcuts() {
        let live = sessions([("$1", "a"), ("$2", "b"), ("$3", "c")]);
        let ordered = ordered_sessions(&live, None);

        assert_eq!(
            swap_current(&live, &ordered, "a", None, MoveDirection::Previous),
            SwapOutcome::Changed("$3\t$2\t$1".to_string())
        );
        assert_eq!(
            swap_current(&live, &ordered, "c", None, MoveDirection::Next),
            SwapOutcome::Changed("$3\t$2\t$1".to_string())
        );
    }

    #[test]
    fn swap_single_visible_session_is_noop() {
        let live = sessions([("$1", "a")]);
        let ordered = ordered_sessions(&live, None);

        assert_eq!(
            swap_current(&live, &ordered, "a", None, MoveDirection::Previous),
            SwapOutcome::AlreadyFirst
        );
        assert_eq!(
            swap_current(&live, &ordered, "a", None, MoveDirection::Next),
            SwapOutcome::AlreadyLast
        );
    }

    fn sessions<const N: usize>(items: [(&str, &str); N]) -> Vec<SessionInfo> {
        items
            .into_iter()
            .map(|(id, name)| SessionInfo {
                id: id.to_string(),
                name: name.to_string(),
                has_bell: false,
                status: "on".to_string(),
                layout_key: String::new(),
                left_length: String::new(),
                right_length: String::new(),
                format_0: String::new(),
                format_1: String::new(),
                render_key: String::new(),
                cache_witnesses: std::array::from_fn(|_| String::new()),
                created: 0,
            })
            .collect()
    }

    fn names(sessions: &[SessionInfo]) -> Vec<&str> {
        sessions
            .iter()
            .map(|session| session.name.as_str())
            .collect()
    }
}
