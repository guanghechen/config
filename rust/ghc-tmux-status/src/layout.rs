use crate::model::{LayoutKind, LayoutPlan, RowsOverride, StatusMode, StatusPosition};

pub struct LayoutEngine;

impl LayoutEngine {
    pub const WIDE_THRESHOLD: usize = 200;

    pub fn resolve(
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

        // A manual override pins the row count; `Auto` falls back to the
        // width/session-count heuristic (single session is always wide).
        let kind = match rows {
            RowsOverride::One => LayoutKind::Wide,
            RowsOverride::Two => LayoutKind::Narrow,
            RowsOverride::Auto => {
                if session_count <= 1 || width >= Self::WIDE_THRESHOLD {
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
            LayoutKind::Wide => "on".to_string(),
            LayoutKind::Narrow => "2".to_string(),
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
}

#[cfg(test)]
mod tests {
    use super::LayoutEngine;
    use crate::model::{LayoutKind, RowsOverride};

    #[test]
    fn single_session_is_wide_even_when_narrow_width() {
        let plan = LayoutEngine::resolve("02", "on", 120, 1, RowsOverride::Auto).unwrap();
        assert_eq!(plan.kind, LayoutKind::Wide);
        assert_eq!(plan.target_status, "on");
    }

    #[test]
    fn multi_session_under_threshold_is_narrow() {
        let plan = LayoutEngine::resolve("02", "on", 120, 2, RowsOverride::Auto).unwrap();
        assert_eq!(plan.kind, LayoutKind::Narrow);
        assert_eq!(plan.target_status, "2");
    }

    #[test]
    fn local_status_off_is_noop() {
        assert!(LayoutEngine::resolve("02", "off", 120, 2, RowsOverride::Auto).is_none());
    }

    #[test]
    fn override_two_forces_narrow_on_wide_screen() {
        // Wide screen + single session would be Wide under Auto; the override pins two rows.
        let plan = LayoutEngine::resolve("02", "on", 300, 1, RowsOverride::Two).unwrap();
        assert_eq!(plan.kind, LayoutKind::Narrow);
        assert_eq!(plan.rows, 2);
        assert_eq!(plan.target_status, "2");
        assert_eq!(plan.key, "02:narrow");
    }

    #[test]
    fn override_one_forces_wide_on_narrow_multi_session() {
        // Narrow width + multiple sessions would be Narrow under Auto; the override pins one row.
        let plan = LayoutEngine::resolve("02", "on", 100, 3, RowsOverride::One).unwrap();
        assert_eq!(plan.kind, LayoutKind::Wide);
        assert_eq!(plan.rows, 1);
        assert_eq!(plan.target_status, "on");
        assert_eq!(plan.key, "02:wide");
    }
}
