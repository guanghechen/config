use crate::error::{AppError, AppResult};
use crate::model::{RenderEvent, RenderEventKind, RowsOverride};
use crate::session::{FocusTarget, MoveDirection};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CliCommand {
    Apply(RenderEvent),
    BootstrapTheme(u64),
    SchedulerTick,
    DumpState,
    RenderStatus02,
    FocusSession(FocusTarget),
    SwapSession(MoveDirection),
    Layout {
        mode: String,
        status: String,
        width: usize,
        session_count: usize,
        rows: RowsOverride,
    },
    Help,
}

pub fn parse(args: Vec<String>) -> AppResult<CliCommand> {
    let values = args.iter().map(String::as_str).collect::<Vec<_>>();
    match values.as_slice() {
        [] | ["help" | "--help" | "-h"] => Ok(CliCommand::Help),
        ["apply"] => Ok(CliCommand::Apply(RenderEvent::manual_apply())),
        ["apply", "theme-loaded", generation] => {
            parse_generation(generation).map(CliCommand::BootstrapTheme)
        }
        ["apply", "theme-loaded"] => Err(AppError::Usage(
            "expected: apply theme-loaded <generation>".to_string(),
        )),
        ["apply", event] => Ok(CliCommand::Apply(RenderEvent {
            kind: RenderEventKind::parse(event)
                .ok_or_else(|| AppError::Usage(format!("unknown render event: {event}")))?,
        })),
        ["scheduler-tick"] => Ok(CliCommand::SchedulerTick),
        ["dump-state"] => Ok(CliCommand::DumpState),
        ["render", "status02"] => Ok(CliCommand::RenderStatus02),
        ["session", "focus", target] => FocusTarget::parse(target)
            .map(CliCommand::FocusSession)
            .ok_or_else(|| AppError::Usage(format!("invalid session focus target: {target}"))),
        ["session", "swap", direction] => MoveDirection::parse(direction)
            .map(CliCommand::SwapSession)
            .ok_or_else(|| AppError::Usage(format!("invalid session swap direction: {direction}"))),
        ["layout", mode, status, width, session_count] => {
            parse_layout(mode, status, width, session_count, RowsOverride::default())
        }
        ["layout", mode, status, width, session_count, "auto"] => {
            parse_layout(mode, status, width, session_count, RowsOverride::Auto)
        }
        [
            "layout",
            mode,
            status,
            width,
            session_count,
            rows @ ("1" | "2"),
        ] => parse_layout(
            mode,
            status,
            width,
            session_count,
            RowsOverride::parse(rows),
        ),
        [command, ..] => Err(usage_error(command)),
    }
}

fn parse_generation(value: &str) -> AppResult<u64> {
    value.parse::<u64>().map_err(|_| {
        AppError::Usage(format!(
            "invalid generation for theme-loaded: expected an unsigned integer, got {value}"
        ))
    })
}

fn parse_layout(
    mode: &str,
    status: &str,
    width: &str,
    session_count: &str,
    rows: RowsOverride,
) -> AppResult<CliCommand> {
    let width = width
        .parse::<usize>()
        .map_err(|_| AppError::Usage(format!("invalid width: {width}")))?;
    let session_count = session_count
        .parse::<usize>()
        .map_err(|_| AppError::Usage(format!("invalid session-count: {session_count}")))?;

    Ok(CliCommand::Layout {
        mode: mode.to_string(),
        status: status.to_string(),
        width,
        session_count,
        rows,
    })
}

fn usage_error(command: &str) -> AppError {
    let expected = match command {
        "apply" => "apply [event]",
        "scheduler-tick" => "scheduler-tick",
        "dump-state" => "dump-state",
        "render" => "render status02",
        "session" => "session <focus|swap> <prev|next|index>",
        "layout" => "layout <mode> <status> <width> <session-count> [rows: auto|1|2]",
        "help" | "--help" | "-h" => "help",
        _ => return AppError::Usage(format!("unknown command: {command}")),
    };
    AppError::Usage(format!("expected: {expected}"))
}

#[cfg(test)]
mod tests {
    use super::{CliCommand, parse};
    use crate::model::{RenderEvent, RowsOverride};

    fn args(values: &[&str]) -> Vec<String> {
        values.iter().map(|value| (*value).to_string()).collect()
    }

    #[test]
    fn rejects_retired_heartbeat_command() {
        assert_eq!(
            parse(args(&["heartbeat", "42"])).unwrap_err().to_string(),
            "unknown command: heartbeat"
        );
    }

    #[test]
    fn rejects_retired_metrics_sample_command() {
        assert_eq!(
            parse(args(&["metrics-sample", "42"]))
                .unwrap_err()
                .to_string(),
            "unknown command: metrics-sample"
        );
    }

    #[test]
    fn rejects_retired_cpu_sample_command() {
        assert_eq!(
            parse(args(&["cpu-sample", "42"])).unwrap_err().to_string(),
            "unknown command: cpu-sample"
        );
    }

    #[test]
    fn parses_scheduler_tick_without_arguments() {
        assert_eq!(
            parse(args(&["scheduler-tick"])).unwrap(),
            CliCommand::SchedulerTick
        );
        assert!(parse(args(&["scheduler-tick", "extra"])).is_err());
    }

    #[test]
    fn bootstrap_theme_requires_a_typed_generation() {
        assert_eq!(
            parse(args(&["apply", "theme-loaded", "42"])).unwrap(),
            CliCommand::BootstrapTheme(42)
        );
        assert!(parse(args(&["apply", "theme-loaded"])).is_err());
        assert!(parse(args(&["apply", "theme-loaded", "bad"])).is_err());
    }

    #[test]
    fn rejects_trailing_arguments() {
        assert!(parse(args(&["apply", "manual-apply", "extra"])).is_err());
        assert!(parse(args(&["dump-state", "extra"])).is_err());
        assert!(parse(args(&["render", "status02", "extra"])).is_err());
    }

    #[test]
    fn defaults_apply_to_manual_event() {
        assert_eq!(
            parse(args(&["apply"])).unwrap(),
            CliCommand::Apply(RenderEvent::manual_apply())
        );
    }

    #[test]
    fn parses_layout_rows_override() {
        assert_eq!(
            parse(args(&["layout", "02", "on", "120", "3"])).unwrap(),
            CliCommand::Layout {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 120,
                session_count: 3,
                rows: RowsOverride::Two,
            }
        );
        assert_eq!(
            parse(args(&["layout", "02", "on", "120", "3", "auto"])).unwrap(),
            CliCommand::Layout {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 120,
                session_count: 3,
                rows: RowsOverride::Auto,
            }
        );
        assert_eq!(
            parse(args(&["layout", "02", "on", "120", "3", "2"])).unwrap(),
            CliCommand::Layout {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 120,
                session_count: 3,
                rows: RowsOverride::Two,
            }
        );
        assert!(parse(args(&["layout", "02", "on", "120", "3", "invalid"])).is_err());
    }
}
