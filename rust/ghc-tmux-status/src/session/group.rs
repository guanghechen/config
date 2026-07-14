use std::collections::BTreeMap;

use crate::model::{SessionGroupView, SessionInfo};

pub struct SessionGrouper;

#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum SessionGroupKey {
    Popup,
    Agent,
    Numbered(String),
    Default,
}

impl SessionGrouper {
    pub fn group(current_session_name: &str, sessions: &[SessionInfo]) -> SessionGroupView {
        let current_key = Self::key(current_session_name);
        let sessions = sessions
            .iter()
            .filter(|session| Self::key(&session.name) == current_key)
            .cloned()
            .collect();

        SessionGroupView {
            current_session_name: current_session_name.to_string(),
            sessions,
        }
    }

    #[cfg(test)]
    pub fn count(current_session_name: &str, sessions: &[SessionInfo]) -> usize {
        let current_key = Self::key(current_session_name);
        sessions
            .iter()
            .filter(|session| Self::key(&session.name) == current_key)
            .count()
    }

    pub fn counts(sessions: &[SessionInfo]) -> BTreeMap<SessionGroupKey, usize> {
        let mut counts = BTreeMap::new();
        for session in sessions {
            *counts.entry(Self::key(&session.name)).or_default() += 1;
        }
        counts
    }

    pub fn key(session_name: &str) -> SessionGroupKey {
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
}

#[cfg(test)]
pub fn same_session_group(current_session_name: &str, session_name: &str) -> bool {
    SessionGrouper::key(current_session_name) == SessionGrouper::key(session_name)
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
    use super::{SessionGrouper, same_session_group};
    use crate::model::SessionInfo;

    #[test]
    fn popup_sessions_are_grouped_together() {
        assert!(same_session_group("_popup@a", "_popup@b"));
        assert!(!same_session_group("_popup@a", "main"));
    }

    #[test]
    fn agent_sessions_are_grouped_together() {
        assert!(same_session_group("codex-deadbeef", "claude-123abc"));
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
    fn counts_without_building_a_group_view() {
        let sessions = ["main", "work", "G1-build"]
            .into_iter()
            .enumerate()
            .map(|(index, name)| SessionInfo {
                id: format!("${index}"),
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
            .collect::<Vec<_>>();

        assert_eq!(SessionGrouper::count("main", &sessions), 2);
        assert_eq!(SessionGrouper::count("G1-test", &sessions), 1);
    }
}
