use std::collections::BTreeMap;

use crate::config::{
    SESSION_RENDER_KEY_OPTION, STATUS_CURRENT_FORMAT, STATUS_FORMAT_0_OPTION,
    STATUS_FORMAT_1_OPTION, STATUS_INTERVAL_OPTION, STATUS_JUSTIFY_OPTION, STATUS_JUSTIFY_VALUE,
    STATUS_LEFT_FORMAT, STATUS_LEFT_OPTION, STATUS_POSITION_OPTION,
    STATUS_REDRAW_INTERVAL_SECONDS_STR, STATUS_RIGHT_FORMAT, STATUS_RIGHT_OPTION,
    STATUS_SESSION_FORMAT,
};
use crate::model::{
    RenderContext, RenderEvent, RenderEventKind, RenderedStatus, SessionLayout,
    SessionRenderedStatus, TmuxSnapshot,
};
use crate::status_length::{status_left_length_for_width, status_right_length_for_width};

// Reset interval when status02 is inactive; status01 also sets 20 on load.
const DEFAULT_STATUS_INTERVAL_SECONDS: &str = "20";
pub(crate) const CACHE_WITNESS_BYTES: usize = 26;

pub(crate) const SESSION_CACHE_OPTIONS: [&str; 4] = [
    "@GHC_SL_STATUS02_LEFT",
    "@GHC_SL_STATUS02_RIGHT",
    "@GHC_SL_STATUS02_SESSION_FORMAT",
    "@GHC_SL_STATUS02_CURRENT_FORMAT",
];

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TmuxCommand {
    SetGlobal {
        name: String,
        value: String,
    },
    SetSessionTarget {
        target: String,
        name: String,
        value: String,
    },
    UnsetGlobal {
        name: String,
    },
    UnsetSessionTarget {
        target: String,
        name: String,
    },
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
            Self::SetSessionTarget {
                target,
                name,
                value,
            } => vec![
                "set".to_string(),
                "-q".to_string(),
                "-t".to_string(),
                target.clone(),
                name.clone(),
                value.clone(),
            ],
            Self::UnsetGlobal { name } => {
                vec!["set".to_string(), "-gu".to_string(), name.clone()]
            }
            Self::UnsetSessionTarget { target, name } => vec![
                "set".to_string(),
                "-q".to_string(),
                "-t".to_string(),
                target.clone(),
                "-u".to_string(),
                name.clone(),
            ],
        }
    }

    pub(crate) fn to_command_string(&self) -> String {
        tmux_command_string(&self.args())
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
}

pub(crate) fn tmux_command_string(args: &[String]) -> String {
    args.iter()
        .map(|argument| tmux_quote(argument))
        .collect::<Vec<_>>()
        .join(" ")
}

fn tmux_quote(value: &str) -> String {
    let mut quoted = String::with_capacity(value.len() + 2);
    quoted.push('"');
    for character in value.chars() {
        match character {
            '\\' => quoted.push_str("\\\\"),
            '"' => quoted.push_str("\\\""),
            '$' => quoted.push_str("\\$"),
            // tmux expands a leading tilde while parsing double-quoted text.
            '~' => quoted.push_str("\\~"),
            '\n' => quoted.push_str("\\n"),
            '\r' => quoted.push_str("\\r"),
            '\t' => quoted.push_str("\\t"),
            '\u{1b}' => quoted.push_str("\\e"),
            character if character.is_ascii_control() => {
                quoted.push_str(&format!("\\{:03o}", u32::from(character)));
            }
            _ => quoted.push(character),
        }
    }
    quoted.push('"');
    quoted
}

pub struct CommitPlanner;

impl CommitPlanner {
    pub fn plan_inactive(snapshot: &TmuxSnapshot) -> TmuxCommandPlan {
        let mut plan = TmuxCommandPlan::default();
        push_global_if_changed(
            &mut plan,
            &snapshot.options,
            STATUS_INTERVAL_OPTION,
            DEFAULT_STATUS_INTERVAL_SECONDS,
        );
        plan
    }

    pub fn plan(
        fallback_status: &RenderedStatus,
        session_statuses: &[SessionRenderedStatus],
        context: &RenderContext,
        event: &RenderEvent,
    ) -> TmuxCommandPlan {
        let mut plan = TmuxCommandPlan::default();
        let options = &context.snapshot.options;

        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_LEFT",
            &fallback_status.status_left.rich_text,
        );
        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_RIGHT",
            &fallback_status.status_right.rich_text,
        );
        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_SESSION_FORMAT",
            &fallback_status.session_right.rich_text,
        );
        push_global_if_changed(
            &mut plan,
            options,
            "@GHC_SL_STATUS02_CURRENT_FORMAT",
            &fallback_status.current_format.rich_text,
        );

        // STYLE stays global: templates + redraw cadence + position/justify apply to
        // every client identically. LAYOUT (rows, lengths, @GHC_SL_LAYOUT) is per-session.
        push_global_if_changed(&mut plan, options, STATUS_LEFT_OPTION, STATUS_LEFT_FORMAT);
        push_global_if_changed(
            &mut plan,
            options,
            STATUS_INTERVAL_OPTION,
            STATUS_REDRAW_INTERVAL_SECONDS_STR,
        );
        push_global_if_changed(&mut plan, options, STATUS_RIGHT_OPTION, STATUS_RIGHT_FORMAT);
        push_global_if_changed(
            &mut plan,
            options,
            STATUS_POSITION_OPTION,
            context.layout.position.as_str(),
        );
        push_global_if_changed(
            &mut plan,
            options,
            STATUS_JUSTIFY_OPTION,
            STATUS_JUSTIFY_VALUE,
        );

        // Session-dependent output has exactly one writer: the target session's
        // local options. Global values above are only a stable fallback for a
        // newly attached session before its first reconcile.
        for rendered_session in session_statuses {
            let session_layout = &rendered_session.session_layout;
            let status = &rendered_session.status;
            if session_layout_settled(
                session_layout,
                status,
                &rendered_session.render_key,
                options,
            ) {
                continue;
            }
            let session_target = &session_layout.session_id;
            let render_key = target_render_key(session_layout, &rendered_session.render_key);
            for (name, value) in SESSION_CACHE_OPTIONS.iter().zip([
                &status.status_left.rich_text,
                &status.status_right.rich_text,
                &status.session_right.rich_text,
                &status.current_format.rich_text,
            ]) {
                push_set_session_target(
                    &mut plan,
                    session_target,
                    name,
                    &cache_value(&rendered_session.render_key, value),
                );
            }
            push_set_session_target(
                &mut plan,
                session_target,
                SESSION_RENDER_KEY_OPTION,
                &render_key,
            );
            push_set_session_target(
                &mut plan,
                session_target,
                "@GHC_SL_LAYOUT",
                &session_layout.layout.key,
            );
            push_set_session_target(
                &mut plan,
                session_target,
                "status-left-length",
                &status_left_length_for_width(status, session_layout.width),
            );
            push_set_session_target(
                &mut plan,
                session_target,
                "status-right-length",
                &status_right_length_for_width(status, session_layout.width),
            );
            push_set_session_target(
                &mut plan,
                session_target,
                "status",
                &session_layout.layout.target_status,
            );
            if session_layout.layout.rows == 1 {
                plan.commands.push(TmuxCommand::UnsetSessionTarget {
                    target: session_target.clone(),
                    name: "status-format".to_string(),
                });
            } else {
                push_set_session_target(
                    &mut plan,
                    session_target,
                    "status-format[0]",
                    STATUS_SESSION_FORMAT,
                );
                push_set_session_target(
                    &mut plan,
                    session_target,
                    "status-format[1]",
                    STATUS_CURRENT_FORMAT,
                );
            }
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

/// True when a session's per-session layout options already match the reconcile
/// target: rows/status, layout key, and the width-derived status lengths. Lengths
/// are part of the witness so a content- or width-driven length change that keeps
/// the same wide/narrow kind (same key + status) still triggers a refresh.
pub fn session_layout_settled(
    session_layout: &SessionLayout,
    status: &RenderedStatus,
    render_key: &str,
    global_options: &BTreeMap<String, String>,
) -> bool {
    let target_cache_witness = cache_witness(render_key);
    session_layout.current_layout_key == session_layout.layout.key
        && session_layout.current_status == session_layout.layout.target_status
        && session_layout.current_left_length
            == status_left_length_for_width(status, session_layout.width)
        && session_layout.current_right_length
            == status_right_length_for_width(status, session_layout.width)
        && session_layout.current_render_key == target_render_key(session_layout, render_key)
        && session_layout
            .current_cache_witnesses
            .iter()
            .all(|current| current == &target_cache_witness)
        && session_formats_settled(session_layout, global_options)
}

fn cache_value(render_key: &str, value: &str) -> String {
    format!("{}{value}", cache_witness(render_key))
}

pub(crate) fn cache_witness(render_key: &str) -> String {
    let witness = format!("#{{?0,{render_key},}}");
    debug_assert_eq!(witness.len(), CACHE_WITNESS_BYTES);
    witness
}

fn target_render_key(session_layout: &SessionLayout, render_key: &str) -> String {
    format!("{}:{render_key}", session_layout.layout.key)
}

fn session_formats_settled(
    session_layout: &SessionLayout,
    global_options: &BTreeMap<String, String>,
) -> bool {
    if session_layout.layout.rows == 2 {
        return session_layout.current_format_0 == STATUS_SESSION_FORMAT
            && session_layout.current_format_1 == STATUS_CURRENT_FORMAT;
    }

    session_layout.current_format_0
        == global_options
            .get(STATUS_FORMAT_0_OPTION)
            .map(String::as_str)
            .unwrap_or_default()
        && session_layout.current_format_1
            == global_options
                .get(STATUS_FORMAT_1_OPTION)
                .map(String::as_str)
                .unwrap_or_default()
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

fn push_set_session_target(plan: &mut TmuxCommandPlan, target: &str, name: &str, value: &str) {
    plan.commands.push(TmuxCommand::SetSessionTarget {
        target: target.to_string(),
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
    use std::rc::Rc;

    use super::{CommitPlanner, TmuxCommand, TmuxCommandPlan, cache_witness, tmux_command_string};
    use crate::composer::render_cache_key;
    use crate::config::{
        STATUS_CURRENT_FORMAT, STATUS_INTERVAL_OPTION, STATUS_JUSTIFY_OPTION, STATUS_JUSTIFY_VALUE,
        STATUS_LEFT_FORMAT, STATUS_LEFT_OPTION, STATUS_POSITION_OPTION,
        STATUS_REDRAW_INTERVAL_SECONDS_STR, STATUS_RIGHT_FORMAT, STATUS_RIGHT_OPTION,
        STATUS_SESSION_FORMAT,
    };
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderEvent, RenderEventKind, RenderedSegment,
        RenderedStatus, SessionGroupView, SessionLayout, SessionRenderedStatus, StatusMode,
        StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn command_string_quotes_tmux_special_characters() {
        let args = vec![
            "set".to_string(),
            "-g".to_string(),
            "@VALUE".to_string(),
            "space # semi; dollar$ quote' slash\\".to_string(),
        ];

        assert_eq!(
            tmux_command_string(&args),
            "\"set\" \"-g\" \"@VALUE\" \"space # semi; dollar\\$ quote' slash\\\\\""
        );
        assert_eq!(tmux_command_string(&[String::new()]), "\"\"");

        let multiline = vec!["line one\nline two\t~\"".to_string()];
        assert_eq!(
            tmux_command_string(&multiline),
            "\"line one\\nline two\\t\\~\\\"\""
        );
    }

    fn session_layout(
        session_id: &str,
        kind: LayoutKind,
        target_status: &str,
        target_key: &str,
        current_status: &str,
        current_key: &str,
    ) -> SessionLayout {
        let render_key = render_cache_key(&rendered_status("body"));
        SessionLayout {
            session_id: session_id.to_string(),
            session_name: "work".to_string(),
            current_status: current_status.to_string(),
            current_layout_key: current_key.to_string(),
            // Defaults match status_*_length_for_width(rendered_status("body"), 200).
            current_left_length: "64".to_string(),
            current_right_length: "84".to_string(),
            current_format_0: if kind == LayoutKind::Narrow {
                STATUS_SESSION_FORMAT.to_string()
            } else {
                String::new()
            },
            current_format_1: if kind == LayoutKind::Narrow {
                STATUS_CURRENT_FORMAT.to_string()
            } else {
                String::new()
            },
            current_render_key: format!("{target_key}:{render_key}"),
            current_cache_witnesses: std::array::from_fn(|_| cache_witness(&render_key)),
            session_created: 1,
            layout: LayoutPlan {
                mode: StatusMode::TopAdaptive,
                position: StatusPosition::Top,
                kind,
                rows: if kind == LayoutKind::Wide { 1 } else { 2 },
                target_status: target_status.to_string(),
                key: target_key.to_string(),
            },
            width: 200,
        }
    }

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
        let plan = plan(&status, &context, &RenderEvent::manual_apply());
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
        let plan = plan(&status, &context, &event);
        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::UnsetGlobal { name } if name == "@GHC_STATUS_COMPONENT_CACHE_duration"
        )));
    }

    #[test]
    fn skips_settled_global_style_options() {
        let status = rendered_status("same");
        let options = BTreeMap::from([
            (
                STATUS_LEFT_OPTION.to_string(),
                STATUS_LEFT_FORMAT.to_string(),
            ),
            (
                STATUS_RIGHT_OPTION.to_string(),
                STATUS_RIGHT_FORMAT.to_string(),
            ),
            (STATUS_POSITION_OPTION.to_string(), "top".to_string()),
            (
                STATUS_JUSTIFY_OPTION.to_string(),
                STATUS_JUSTIFY_VALUE.to_string(),
            ),
            (
                STATUS_INTERVAL_OPTION.to_string(),
                STATUS_REDRAW_INTERVAL_SECONDS_STR.to_string(),
            ),
        ]);
        let plan = plan(
            &status,
            &context_with_options(options),
            &RenderEvent::manual_apply(),
        );

        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. }
                if matches!(
                    name.as_str(),
                    STATUS_LEFT_OPTION
                        | STATUS_RIGHT_OPTION
                        | STATUS_POSITION_OPTION
                        | STATUS_JUSTIFY_OPTION
                        | STATUS_INTERVAL_OPTION
                )
        )));
    }

    #[test]
    fn per_session_commands_ignore_a_vanished_target() {
        assert_eq!(
            TmuxCommand::SetSessionTarget {
                target: "$9".to_string(),
                name: "status".to_string(),
                value: "2".to_string(),
            }
            .args(),
            ["set", "-q", "-t", "$9", "status", "2"]
        );
        assert_eq!(
            TmuxCommand::UnsetSessionTarget {
                target: "$9".to_string(),
                name: "status-format".to_string(),
            }
            .args(),
            ["set", "-q", "-t", "$9", "-u", "status-format"]
        );
    }

    #[test]
    fn writes_per_session_layout_for_a_changed_narrow_session() {
        let status = rendered_status("body");
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout(
            "$7",
            LayoutKind::Narrow,
            "2",
            "02:narrow",
            "on",
            "02:wide",
        )];
        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, name, value }
                if target == "$7" && name == "status" && value == "2"
        )));
        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, name, .. }
                if target == "$7" && name == "status-format[0]"
        )));
        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, name, value }
                if target == "$7" && name == "@GHC_SL_LAYOUT" && value == "02:narrow"
        )));
        // Layout never leaks to the global status option anymore.
        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. } if name == "status"
        )));
    }

    #[test]
    fn wide_session_unsets_status_format_per_session() {
        let status = rendered_status("body");
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout(
            "$3",
            LayoutKind::Wide,
            "on",
            "02:wide",
            "2",
            "02:narrow",
        )];
        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::UnsetSessionTarget { target, name }
                if target == "$3" && name == "status-format"
        )));
    }

    #[test]
    fn skips_per_session_layout_when_already_settled() {
        let status = rendered_status("body");
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout(
            "$9",
            LayoutKind::Wide,
            "on",
            "02:wide",
            "on",
            "02:wide",
        )];
        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, .. } | TmuxCommand::UnsetSessionTarget { target, .. }
                if target == "$9"
        )));
    }

    #[test]
    fn rewrites_per_session_layout_when_only_length_is_stale() {
        // F-001: rows + layout key match the target, but the width-derived length is
        // stale (content/width changed within the same wide/narrow kind). The bundle
        // must still be rewritten so the per-session length is repaired without a
        // reload or kind/status transition.
        let status = rendered_status("body");
        let mut session_layout =
            session_layout("$2", LayoutKind::Wide, "on", "02:wide", "on", "02:wide");
        session_layout.current_left_length = "40".to_string();
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout];
        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, name, value }
                if target == "$2" && name == "status-left-length" && value == "64"
        )));
    }

    #[test]
    fn repairs_narrow_status_format_drift_with_other_witnesses_settled() {
        let status = rendered_status("body");
        let mut session_layout =
            session_layout("$4", LayoutKind::Narrow, "2", "02:narrow", "2", "02:narrow");
        session_layout.current_format_1 = "BROKEN".to_string();
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout];

        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, name, value }
                if target == "$4"
                    && name == "status-format[1]"
                    && value == STATUS_CURRENT_FORMAT
        )));
    }

    #[test]
    fn writes_session_scoped_render_cache_as_one_reconcile_bundle() {
        let status = rendered_status("session-specific");
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout(
            "$8",
            LayoutKind::Wide,
            "on",
            "02:wide",
            "2",
            "02:narrow",
        )];

        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        for option in [
            "@GHC_SL_STATUS02_LEFT",
            "@GHC_SL_STATUS02_RIGHT",
            "@GHC_SL_STATUS02_SESSION_FORMAT",
            "@GHC_SL_STATUS02_CURRENT_FORMAT",
            "@GHC_SL_RENDER_KEY",
        ] {
            assert!(plan.commands.iter().any(|command| matches!(
                command,
                TmuxCommand::SetSessionTarget { target, name, .. }
                    if target == "$8" && name == option
            )));
        }

        let target_witness = cache_witness(&render_cache_key(&status));
        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetSessionTarget { target, name, value }
                if target == "$8"
                    && name == "@GHC_SL_STATUS02_LEFT"
                    && value == &format!("{target_witness}session-specific")
        )));
    }

    #[test]
    fn rewrites_all_session_caches_when_one_actual_witness_drifts() {
        let status = rendered_status("body");
        let mut session_layout =
            session_layout("$8", LayoutKind::Wide, "on", "02:wide", "on", "02:wide");
        session_layout.current_cache_witnesses[2].clear();
        let mut context = context_with_options(BTreeMap::new());
        context.session_layouts = vec![session_layout];

        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert_eq!(
            plan.commands
                .iter()
                .filter(|command| matches!(
                    command,
                    TmuxCommand::SetSessionTarget { target, name, .. }
                        if target == "$8" && [
                            "@GHC_SL_STATUS02_LEFT",
                            "@GHC_SL_STATUS02_RIGHT",
                            "@GHC_SL_STATUS02_SESSION_FORMAT",
                            "@GHC_SL_STATUS02_CURRENT_FORMAT",
                        ].contains(&name.as_str())
                ))
                .count(),
            4
        );
    }

    #[test]
    fn sets_one_second_status_interval_when_cached_value_is_stale() {
        let status = rendered_status("same");
        let context = context_with_options(BTreeMap::from([(
            "status-interval".to_string(),
            "20".to_string(),
        )]));
        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, value }
                if name == "status-interval" && value == "1"
        )));
    }

    #[test]
    fn skips_one_second_status_interval_when_cached_value_matches() {
        let status = rendered_status("same");
        let context = context_with_options(BTreeMap::from([(
            "status-interval".to_string(),
            "1".to_string(),
        )]));
        let plan = plan(&status, &context, &RenderEvent::manual_apply());

        assert!(!plan.commands.iter().any(|command| matches!(
            command,
            TmuxCommand::SetGlobal { name, .. } if name == "status-interval"
        )));
    }

    #[test]
    fn resets_status_interval_when_runtime_is_inactive() {
        let mut snapshot = tmux_snapshot(BTreeMap::from([(
            "status-interval".to_string(),
            "1".to_string(),
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
            session_right: segment.clone(),
            current_format: segment,
        }
    }

    fn context_with_options(options: BTreeMap<String, String>) -> RenderContext {
        RenderContext {
            snapshot: Rc::new(tmux_snapshot(options)),
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
            render_session_created: 1,
            session_layouts: Vec::new(),
        }
    }

    fn plan(
        status: &RenderedStatus,
        context: &RenderContext,
        event: &RenderEvent,
    ) -> TmuxCommandPlan {
        let render_key = render_cache_key(status);
        let session_statuses = context
            .session_layouts
            .iter()
            .cloned()
            .map(|session_layout| SessionRenderedStatus {
                session_layout,
                render_key: render_key.clone(),
                status: status.clone(),
            })
            .collect::<Vec<_>>();
        CommitPlanner::plan(status, &session_statuses, context, event)
    }

    fn tmux_snapshot(options: BTreeMap<String, String>) -> TmuxSnapshot {
        TmuxSnapshot {
            mode: "02".to_string(),
            status: "on".to_string(),
            width: 200,
            current_session_name: "s".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: Vec::new(),
            client_widths: Vec::new(),
            options,
        }
    }
}
