use std::collections::BTreeMap;

use crate::model::{SessionGroupView, SessionInfo, TmuxSnapshot};
use crate::session::list::{SESSION_ORDER_OPTION, ordered_sessions};

#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum SessionGroupKey {
    Popup,
    Agent,
    Numbered(String),
    Default,
}

pub fn group_key(session_name: &str) -> SessionGroupKey {
    if session_name.starts_with("_popup@") {
        return SessionGroupKey::Popup;
    }
    if is_agent_session(session_name) {
        return SessionGroupKey::Agent;
    }
    if let Some(group_id) = grouped_session_id(session_name) {
        return SessionGroupKey::Numbered(group_id.to_string());
    }
    SessionGroupKey::Default
}

pub fn group_counts(sessions: &[SessionInfo]) -> BTreeMap<SessionGroupKey, usize> {
    let mut counts = BTreeMap::new();
    for session in sessions {
        *counts.entry(group_key(&session.name)).or_default() += 1;
    }
    counts
}

pub fn ordered_group_from_snapshot(snapshot: &TmuxSnapshot) -> SessionGroupView {
    ordered_group_for_session(snapshot, &snapshot.current_session_name)
}

pub fn ordered_group_for_session(snapshot: &TmuxSnapshot, session_name: &str) -> SessionGroupView {
    ordered_group(
        session_name,
        &snapshot.sessions,
        session_order_value(snapshot),
    )
}

pub fn ordered_group(
    session_name: &str,
    sessions: &[SessionInfo],
    order_value: Option<&str>,
) -> SessionGroupView {
    let key = group_key(session_name);
    let members = sessions
        .iter()
        .filter(|session| group_key(&session.name) == key)
        .cloned()
        .collect::<Vec<_>>();
    SessionGroupView {
        current_session_name: session_name.to_string(),
        sessions: ordered_sessions(&members, order_value),
    }
}

fn session_order_value(snapshot: &TmuxSnapshot) -> Option<&str> {
    snapshot
        .options
        .get(SESSION_ORDER_OPTION)
        .map(String::as_str)
}

fn is_agent_session(session_name: &str) -> bool {
    let Some((prefix, suffix)) = session_name.split_once('-') else {
        return false;
    };
    matches!(prefix, "claude" | "codex" | "gemini")
        && !suffix.is_empty()
        && suffix.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn grouped_session_id(session_name: &str) -> Option<&str> {
    let rest = session_name.strip_prefix('G')?;
    let (digits, _) = rest.split_once('-')?;
    if digits.is_empty() || !digits.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    Some(digits)
}

#[cfg(test)]
mod tests {
    use super::{SessionGroupKey, group_counts, group_key};
    use crate::test_support::session;

    fn same_session_group(current_session_name: &str, session_name: &str) -> bool {
        group_key(current_session_name) == group_key(session_name)
    }

    #[test]
    fn popup_sessions_are_grouped_together() {
        assert!(same_session_group("_popup@a", "_popup@b"));
        assert!(!same_session_group("_popup@a", "main"));
    }

    #[test]
    fn agent_sessions_are_grouped_together() {
        assert!(same_session_group("codex-deadbeef", "claude-123abc"));
        assert!(same_session_group("codex-DEADBEEF", "claude-Ab12"));
        assert!(!same_session_group("codex-deadbeef", "main"));
    }

    #[test]
    fn numbered_group_sessions_match_same_group() {
        assert!(same_session_group("G1-work", "G1-test"));
        assert!(!same_session_group("G1-work", "G2-test"));
    }

    #[test]
    fn normal_sessions_exclude_special_sessions() {
        assert!(same_session_group("main", "work"));
        assert!(!same_session_group("main", "G1-work"));
        assert!(!same_session_group("main", "_popup@a"));
        assert!(!same_session_group("main", "gemini-abcdef"));
    }

    #[test]
    fn counts_sessions_per_group() {
        let sessions = ["main", "work", "G1-build"]
            .into_iter()
            .enumerate()
            .map(|(index, name)| session(&format!("${index}"), name))
            .collect::<Vec<_>>();

        let counts = group_counts(&sessions);
        assert_eq!(counts.get(&SessionGroupKey::Default), Some(&2));
        assert_eq!(counts.get(&group_key("G1-test")), Some(&1));
    }
}
