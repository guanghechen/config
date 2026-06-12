use crate::model::{LayoutKind, LayoutPlan, StatusMode, StatusPosition};

pub struct LayoutEngine;

impl LayoutEngine {
    pub const WIDE_THRESHOLD: usize = 200;

    pub fn resolve(
        mode: &str,
        status: &str,
        width: usize,
        session_count: usize,
    ) -> Option<LayoutPlan> {
        if status == "off" {
            return None;
        }

        let (mode, position) = match mode {
            "02" => (StatusMode::TopAdaptive, StatusPosition::Top),
            "12" => (StatusMode::BottomAdaptive, StatusPosition::Bottom),
            _ => return None,
        };

        let kind = if session_count <= 1 || width >= Self::WIDE_THRESHOLD {
            LayoutKind::Wide
        } else {
            LayoutKind::Narrow
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
    use crate::model::LayoutKind;

    #[test]
    fn single_session_is_wide_even_when_narrow_width() {
        let plan = LayoutEngine::resolve("02", "on", 120, 1).unwrap();
        assert_eq!(plan.kind, LayoutKind::Wide);
        assert_eq!(plan.target_status, "on");
    }

    #[test]
    fn multi_session_under_threshold_is_narrow() {
        let plan = LayoutEngine::resolve("02", "on", 120, 2).unwrap();
        assert_eq!(plan.kind, LayoutKind::Narrow);
        assert_eq!(plan.target_status, "2");
    }

    #[test]
    fn local_status_off_is_noop() {
        assert!(LayoutEngine::resolve("02", "off", 120, 2).is_none());
    }
}
