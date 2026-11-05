use std::collections::BTreeMap;

use crate::config::ROWS_OVERRIDE_OPTION;
use crate::model::{
    LayoutKind, LayoutPlan, RowsOverride, SessionLayout, StatusMode, StatusPosition, TmuxSnapshot,
};
use crate::session::{group_counts, group_key};

const WIDE_THRESHOLD: usize = 200;

pub fn resolve_layout(
    mode: &str,
    status: &str,
    width: usize,
    session_count: usize,
    rows: RowsOverride,
) -> Option<LayoutPlan> {
    if status == "off" {
        return None;
    }

    let (mode, position) = match mode {
        "02" => (StatusMode::TopAdaptive, StatusPosition::Top),
        "12" => (StatusMode::BottomAdaptive, StatusPosition::Bottom),
        _ => return None,
    };

    /*
     * A manual override pins the row count; `Auto` falls back to the
     * width/session-count heuristic (single session is always wide).
     */
    let kind = match rows {
        RowsOverride::One => LayoutKind::Wide,
        RowsOverride::Two => LayoutKind::Narrow,
        RowsOverride::Auto => {
            if session_count <= 1 || width >= WIDE_THRESHOLD {
                LayoutKind::Wide
            } else {
                LayoutKind::Narrow
            }
        }
    };
    let rows = match kind {
        LayoutKind::Wide => 1,
        LayoutKind::Narrow => 2,
    };
    let target_status = match kind {
        LayoutKind::Wide => "on",
        LayoutKind::Narrow => "2",
    };
    let key = format!("{}:{}", mode.as_str(), kind.as_str());

    Some(LayoutPlan {
        mode,
        position,
        kind,
        rows,
        target_status,
        key,
    })
}

/**
 * The manual rows override (`@GHC_SL_ROWS`) for this snapshot, defaulting to
 * `Two` when the option is unset. Shared by the global and per-session resolves
 * so both agree on the pinned row count.
 */
pub fn rows_override(snapshot: &TmuxSnapshot) -> RowsOverride {
    RowsOverride::parse(
        snapshot
            .options
            .get(ROWS_OVERRIDE_OPTION)
            .map(String::as_str)
            .unwrap_or_default(),
    )
}

/**
 * Reconciles a per-session target layout for every ON (not currently `off`),
 * attached session. A session whose effective `status` is `off` (popup/agent,
 * owned by the session-created policy hook in tmux.conf) is skipped — the
 * renderer respects the current status and has no knowledge of the naming
 * convention. Detached sessions (no client width) are skipped until a client
 * attaches and an event re-reconciles them.
 */
pub fn resolve_session_layouts(snapshot: &TmuxSnapshot) -> Vec<SessionLayout> {
    let width_ranges = client_width_ranges(&snapshot.client_widths);
    let counts = group_counts(&snapshot.sessions);
    let rows = rows_override(snapshot);
    let mut session_layouts = Vec::new();
    for session in &snapshot.sessions {
        if session.status == "off" {
            continue;
        }
        let Some(&(layout_width, status_length_width)) = width_ranges.get(session.id.as_str())
        else {
            continue;
        };
        let count = counts
            .get(&group_key(&session.name))
            .copied()
            .unwrap_or_default();
        let Some(layout) = resolve_layout(&snapshot.mode, "on", layout_width, count, rows) else {
            continue;
        };
        session_layouts.push(SessionLayout {
            session: session.clone(),
            layout,
            status_length_width,
        });
    }
    session_layouts
}

/**
 * Narrowest and widest attached-client widths per session id. Rows are shared
 * session state and resolve from the minimum; status-length maxima resolve from
 * the maximum so a narrow peer cannot clip content on a wider client.
 */
fn client_width_ranges(client_widths: &[(String, usize)]) -> BTreeMap<&str, (usize, usize)> {
    let mut ranges = BTreeMap::new();
    for (session_id, width) in client_widths {
        ranges
            .entry(session_id.as_str())
            .and_modify(|(min, max): &mut (usize, usize)| {
                *min = (*min).min(*width);
                *max = (*max).max(*width);
            })
            .or_insert((*width, *width));
    }
    ranges
}

#[cfg(test)]
mod tests {
    use super::{resolve_layout, resolve_session_layouts};
    use crate::model::{LayoutKind, RowsOverride, SessionInfo, TmuxSnapshot};
    use crate::test_support::{session, snapshot};

    #[test]
    fn resolve_session_layouts_skips_off_status_and_detached_sessions() {
        /*
         * on + attached -> reconciled; off + attached (popup/agent) -> skipped by
         * status, not by name; on + detached (no client width) -> skipped.
         */
        let snapshot = TmuxSnapshot {
            current_session_name: "main".to_string(),
            sessions: vec![
                session("$1", "main"),
                SessionInfo {
                    status: "off".to_string(),
                    ..session("$2", "_popup@x")
                },
                session("$3", "detached"),
            ],
            client_widths: vec![("$1".to_string(), 200), ("$2".to_string(), 200)],
            ..snapshot()
        };

        let layouts = resolve_session_layouts(&snapshot);
        assert_eq!(layouts.len(), 1);
        assert_eq!(layouts[0].session.id, "$1");
    }

    #[test]
    fn resolve_session_layouts_uses_min_width_for_rows_and_max_width_for_lengths() {
        let snapshot = TmuxSnapshot {
            width: 90,
            current_session_name: "main".to_string(),
            sessions: vec![session("$1", "main"), session("$2", "work")],
            client_widths: vec![
                ("$1".to_string(), 90),
                ("$1".to_string(), 300),
                ("$2".to_string(), 300),
            ],
            ..snapshot()
        };

        let layouts = resolve_session_layouts(&snapshot);
        let main = layouts
            .iter()
            .find(|layout| layout.session.id == "$1")
            .unwrap();

        assert_eq!(main.layout.kind, LayoutKind::Narrow);
        assert_eq!(main.status_length_width, 300);
    }

    #[test]
    fn single_session_is_wide_even_when_narrow_width() {
        let plan = resolve_layout("02", "on", 120, 1, RowsOverride::Auto).unwrap();
        assert_eq!(plan.kind, LayoutKind::Wide);
        assert_eq!(plan.target_status, "on");
    }

    #[test]
    fn multi_session_under_threshold_is_narrow() {
        let plan = resolve_layout("02", "on", 120, 2, RowsOverride::Auto).unwrap();
        assert_eq!(plan.kind, LayoutKind::Narrow);
        assert_eq!(plan.target_status, "2");
    }

    #[test]
    fn local_status_off_is_noop() {
        assert!(resolve_layout("02", "off", 120, 2, RowsOverride::Auto).is_none());
    }

    #[test]
    fn override_two_forces_narrow_on_wide_screen() {
        // Wide screen + single session would be Wide under Auto; the override pins two rows.
        let plan = resolve_layout("02", "on", 300, 1, RowsOverride::Two).unwrap();
        assert_eq!(plan.kind, LayoutKind::Narrow);
        assert_eq!(plan.rows, 2);
        assert_eq!(plan.target_status, "2");
        assert_eq!(plan.key, "02:narrow");
    }

    #[test]
    fn override_one_forces_wide_on_narrow_multi_session() {
        // Narrow width + multiple sessions would be Narrow under Auto; the override pins one row.
        let plan = resolve_layout("02", "on", 100, 3, RowsOverride::One).unwrap();
        assert_eq!(plan.kind, LayoutKind::Wide);
        assert_eq!(plan.rows, 1);
        assert_eq!(plan.target_status, "on");
        assert_eq!(plan.key, "02:wide");
    }
}
