use std::collections::BTreeMap;

use crate::config::STATUS_INTERVAL_SECONDS_STR;
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedStatus, TmuxSnapshot};
use crate::status_length::{status_left_length, status_right_length};

// Reset interval when status02 is inactive; status01 also sets 20 on load.
const DEFAULT_STATUS_INTERVAL_SECONDS: &str = "20";

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TmuxCommand {
    SetGlobal { name: String, value: String },
    SetSession { name: String, value: String },
    UnsetGlobal { name: String },
}

impl TmuxCommand {
    pub fn args(&self) -> Vec<String> {
        match self {
            Self::SetGlobal { name, value } => vec![
                "set".to_string(),
                "-g".to_string(),
                name.clone(),
                value.clone(),
            ],
            Self::SetSession { name, value } => {
                vec!["set".to_string(), name.clone(), value.clone()]
            }
            Self::UnsetGlobal { name } => {
                vec!["set".to_string(), "-gu".to_string(), name.clone()]
            }
        }
    }
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct TmuxCommandPlan {
    pub commands: Vec<TmuxCommand>,
}

impl TmuxCommandPlan {
    pub fn is_empty(&self) -> bool {
        self.commands.is_empty()
    }

    pub fn to_tmux_args(&self) -> Vec<String> {
        let mut args = Vec::new();
        for (index, command) in self.commands.iter().enumerate() {
            if index > 0 {
                args.push(";".to_string());
            }
            args.extend(command.args());
        }
        args
    }
}

pub struct CommitPlanner;

impl CommitPlanner {
    pub fn plan_inactive(snapshot: &TmuxSnapshot) -> TmuxCommandPlan {
        let mut plan = TmuxCommandPlan::default();
        push_global_if_changed(
            &mut plan,
            &snapshot.options,
            "status-interval",
            DEFAULT_STATUS_INTERVAL_SECONDS,
        );
        plan
    }

    pub fn plan(
        status: &RenderedStatus,
        context: &RenderContext,
        event: &RenderEvent,
        widget_cache_options: Vec<(String, String)>,
    ) -> TmuxCommandPlan {
        let mut plan = TmuxCommandPlan::default();
        let options = &context.snapshot.options;

        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_LEFT",
            &status.status_left.rich_text,
        );
        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_RIGHT",
            &status.status_right.rich_text,
        );
        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_SESSION_FORMAT",
            &status.session_format.rich_text,
        );
        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_CURRENT_FORMAT",
            &status.current_format.rich_text,
        );

        for (name, value) in widget_cache_options {
            push_global_if_changed(&mut plan, options, &name, &value);
        }

        push_global_if_changed(&mut plan, options, "@GHC_SL_LAYOUT", &context.layout.key);

        push_set_global(&mut plan, "status-left", "#{E:@GHC_SL_STATUS02_LEFT}");
        push_global_if_changed(
            &mut plan,
            options,
            "status-left-length",
            &status_left_length(status, context),
        );
        push_global_if_changed(
            &mut plan,
            options,
            "status-interval",
            STATUS_INTERVAL_SECONDS_STR,
        );
        push_set_global(&mut plan, "status-right", "#{E:@GHC_SL_STATUS02_RIGHT}");
        push_global_if_changed(
            &mut plan,
            options,
            "status-right-length",
            &status_right_length(status, context),
        );
        push_set_global(
            &mut plan,
            "status-position",
            context.layout.position.as_str(),
        );
        push_set_global(&mut plan, "status-justify", "centre");
        push_set_global(&mut plan, "status", &context.layout.target_status);
        push_set_session(&mut plan, "status", &context.layout.target_status);

        if context.layout.rows == 1 {
            plan.commands.push(TmuxCommand::UnsetGlobal {
                name: "status-format".to_string(),
            });
        } else {
            push_set_global(
                &mut plan,
                "status-format[0]",
                "#{E:@GHC_SL_STATUS02_SESSION_FORMAT}",
            );
            push_set_global(
                &mut plan,
                "status-format[1]",
                "#{E:@GHC_SL_STATUS02_CURRENT_FORMAT}",
            );
        }

        if event.kind == RenderEventKind::ThemeLoaded {
            for name in LEGACY_WIDGET_CACHE_OPTIONS {
                plan.commands.push(TmuxCommand::UnsetGlobal {
                    name: name.to_string(),
                });
            }
        }

        plan
    }
}

fn push_global_if_changed(
    plan: &mut TmuxCommandPlan,
    options: &BTreeMap<String, String>,
    name: &str,
    value: &str,
) {
    if options.get(name).is_some_and(|current| current == value) {
        return;
    }
    push_set_global(plan, name, value);
}

fn push_set_global(plan: &mut TmuxCommandPlan, name: &str, value: &str) {
    plan.commands.push(TmuxCommand::SetGlobal {
        name: name.to_string(),
        value: value.to_string(),
    });
}

fn push_set_session(plan: &mut TmuxCommandPlan, name: &str, value: &str) {
    plan.commands.push(TmuxCommand::SetSession {
        name: name.to_string(),
        value: value.to_string(),
    });
}

// External tmux option names keep COMPONENT for compatibility with existing cached values.
const LEGACY_WIDGET_CACHE_OPTIONS: &[&str] = &[
    "@GHC_STATUS_COMPONENT_CACHE_host",
    "@GHC_STATUS_COMPONENT_CACHE_prefix_indicator",
    "@GHC_STATUS_COMPONENT_CACHE_session_bell",
    "@GHC_STATUS_COMPONENT_CACHE_date",
    "@GHC_STATUS_COMPONENT_CACHE_time",
    "@GHC_STATUS_COMPONENT_CACHE_fullscreen",
    "@GHC_STATUS_COMPONENT_CACHE_window_id",
    "@GHC_STATUS_COMPONENT_CACHE_session_list",
    "@GHC_STATUS_COMPONENT_CACHE_duration",
    "@GHC_STATUS_COMPONENT_CACHE_system_metrics",
    "@GHC_STATUS_COMPONENT_CACHE_cpu",
    "@GHC_STATUS_COMPONENT_CACHE_memory",
    "@GHC_STATUS_COMPONENT_CACHE_network",
];

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{CommitPlanner, TmuxCommand};
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderEvent, RenderEventKind, RenderedSegment,
        RenderedStatus, SessionGroupView, StatusMode, StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn skips_unchanged_large_status_options() {
        let status = rendered_status("same");
        let context = context_with_options(BTreeMap::from([
            ("@GHC_SL_STATUS02_LEFT".to_string(), "same".to_string()),
            ("@GHC_SL_STATUS02_RIGHT".to_string(), "same".to_string()),
            (
                "@GHC_SL_STATUS02_SESSION_FORMAT".to_string(),
                "same".to_string(),
            ),
            (
                "@GHC_SL_STATUS02_CURRENT_FORMAT".to_string(),
                "same".to_string(),
            ),
            ("@GHC_SL_LAYOUT".to_string(), "02:wide".to_string()),
        ]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);
        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. } if name == "@GHC_SL_STATUS02_LEFT"
        )));
    }

    #[test]
    fn includes_theme_loaded_legacy_widget_cache_cleanup() {
        let status = rendered_status("new");
        let context = context_with_options(BTreeMap::new());
        let event = RenderEvent {
            kind: RenderEventKind::ThemeLoaded,
        };
        let plan = CommitPlanner::plan(&status, &context, &event, vec![]);
        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::UnsetGlobal { name } if name == "@GHC_STATUS_COMPONENT_CACHE_duration"
        )));
    }

    #[test]
    fn sets_dynamic_status_left_length_when_cached_value_is_stale() {
        let status = rendered_status(&"x".repeat(68));
        let context = context_with_options(BTreeMap::from([(
            "status-left-length".to_string(),
            "64".to_string(),
        )]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, value }
                if name == "status-left-length" && value == "70"
        )));
    }

    #[test]
    fn skips_dynamic_status_left_length_when_cached_value_matches() {
        let status = rendered_status(&"x".repeat(68));
        let context = context_with_options(BTreeMap::from([(
            "status-left-length".to_string(),
            "70".to_string(),
        )]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);

        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. } if name == "status-left-length"
        )));
    }

    #[test]
    fn sets_dynamic_status_right_length_when_cached_value_is_stale() {
        let status = rendered_status(&"x".repeat(90));
        let context = context_with_options(BTreeMap::from([(
            "status-right-length".to_string(),
            "84".to_string(),
        )]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, value }
                if name == "status-right-length" && value == "92"
        )));
    }

    #[test]
    fn skips_dynamic_status_right_length_when_cached_value_matches() {
        let status = rendered_status(&"x".repeat(90));
        let context = context_with_options(BTreeMap::from([(
            "status-right-length".to_string(),
            "92".to_string(),
        )]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);

        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. } if name == "status-right-length"
        )));
    }

    #[test]
    fn sets_five_second_status_interval_when_cached_value_is_stale() {
        let status = rendered_status("same");
        let context = context_with_options(BTreeMap::from([(
            "status-interval".to_string(),
            "20".to_string(),
        )]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, value }
                if name == "status-interval" && value == "5"
        )));
    }

    #[test]
    fn skips_five_second_status_interval_when_cached_value_matches() {
        let status = rendered_status("same");
        let context = context_with_options(BTreeMap::from([(
            "status-interval".to_string(),
            "5".to_string(),
        )]));
        let plan = CommitPlanner::plan(&status, &context, &RenderEvent::manual_apply(), vec![]);

        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. } if name == "status-interval"
        )));
    }

    #[test]
    fn resets_status_interval_when_runtime_is_inactive() {
        let mut snapshot = tmux_snapshot(BTreeMap::from([(
            "status-interval".to_string(),
            "5".to_string(),
        )]));
        let plan = CommitPlanner::plan_inactive(&snapshot);

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, value }
                if name == "status-interval" && value == "20"
        )));

        snapshot
            .options
            .insert("status-interval".to_string(), "20".to_string());
        let plan = CommitPlanner::plan_inactive(&snapshot);
        assert!(plan.is_empty());
    }

    fn rendered_status(value: &str) -> RenderedStatus {
        let segment = RenderedSegment {
            literal_text: value.to_string(),
            rich_text: value.to_string(),
        };
        RenderedStatus {
            status_left: segment.clone(),
            status_right: segment.clone(),
            session_format: segment.clone(),
            current_format: segment,
        }
    }

    fn context_with_options(options: BTreeMap<String, String>) -> RenderContext {
        RenderContext {
            snapshot: tmux_snapshot(options),
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

    fn tmux_snapshot(options: BTreeMap<String, String>) -> TmuxSnapshot {
        TmuxSnapshot {
            mode: "02".to_string(),
            current_layout: "02:wide".to_string(),
            status: "on".to_string(),
            width: 200,
            current_session_name: "s".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: Vec::new(),
            options,
        }
    }
}
