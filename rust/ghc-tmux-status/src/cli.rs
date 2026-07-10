use crate::error::{AppError, AppResult};
use crate::model::{RenderEvent, RenderEventKind, RowsOverride};
use crate::session::{FocusTarget, MoveDirection};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CliCommand {
    Apply(RenderEvent),
    Heartbeat(u64),
    MetricsSample(u64),
    LegacyCpuSample(u64),
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
        ["apply", event] => Ok(CliCommand::Apply(RenderEvent {
            kind: RenderEventKind::parse(event)
                .ok_or_else(|| AppError::Usage(format!("unknown render event: {event}")))?,
        })),
        ["heartbeat", generation] => Ok(CliCommand::Heartbeat(parse_generation(
            generation,
            "heartbeat",
        )?)),
        ["metrics-sample", generation] => Ok(CliCommand::MetricsSample(parse_generation(
            generation,
            "metrics-sample",
        )?)),
        ["cpu-sample", generation] => Ok(CliCommand::LegacyCpuSample(parse_generation(
            generation,
            "cpu-sample",
        )?)),
        ["dump-state"] => Ok(CliCommand::DumpState),
        ["render", "status02"] => Ok(CliCommand::RenderStatus02),
        ["session", "focus", target] => FocusTarget::parse(target)
            .map(CliCommand::FocusSession)
            .ok_or_else(|| AppError::Usage(format!("invalid session focus target: {target}"))),
        ["session", "swap", direction] => MoveDirection::parse(direction)
            .map(CliCommand::SwapSession)
            .ok_or_else(|| AppError::Usage(format!("invalid session swap direction: {direction}"))),
        ["layout", mode, status, width, session_count]
        | ["layout", mode, status, width, session_count, "auto"] => {
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

fn parse_generation(value: &str, command: &str) -> AppResult<u64> {
    value.parse::<u64>().map_err(|_| {
        AppError::Usage(format!(
            "invalid generation for {command}: expected an unsigned integer, got {value}"
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
        "heartbeat" => "heartbeat <generation>",
        "metrics-sample" => "metrics-sample <generation>",
        "cpu-sample" => "cpu-sample <generation>",
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
    fn parses_typed_generation() {
        assert_eq!(
            parse(args(&["heartbeat", "42"])).unwrap(),
            CliCommand::Heartbeat(42)
        );
        assert!(parse(args(&["heartbeat", "42; touch /tmp/pwned"])).is_err());
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
