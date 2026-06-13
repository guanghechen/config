use std::collections::BTreeMap;
use std::process::Command;

use crate::commit::TmuxCommandPlan;
use crate::error::{AppError, AppResult};
use crate::model::{SessionInfo, TmuxSnapshot};

pub struct TmuxAdapter;

impl TmuxAdapter {
    pub fn new() -> Self {
        Self
    }

    pub fn read_snapshot(&self) -> AppResult<TmuxSnapshot> {
        let output = self.tmux_output(snapshot_command_args())?;
        parse_snapshot_output(&output)
    }

    pub fn commit_plan(&self, plan: &TmuxCommandPlan) -> AppResult<()> {
        if plan.is_empty() {
            return Ok(());
        }

        let combined = self.tmux_status(plan.to_tmux_args());
        if combined.is_err() {
            for command in &plan.commands {
                self.tmux_status(command.args())?;
            }
        }

        let _ = self.tmux_status(["refresh-client".to_string(), "-S".to_string()]);
        Ok(())
    }

    pub fn switch_client(&self, target_session_id: &str) -> AppResult<()> {
        self.tmux_status([
            "switch-client".to_string(),
            "-t".to_string(),
            target_session_id.to_string(),
        ])
    }

    pub fn set_global_option(&self, name: &str, value: &str) -> AppResult<()> {
        self.tmux_status([
            "set".to_string(),
            "-g".to_string(),
            name.to_string(),
            value.to_string(),
        ])
    }

    pub fn display_message(&self, message: &str) -> AppResult<()> {
        self.tmux_status(["display-message".to_string(), message.to_string()])
    }

    fn tmux_output<I, S>(&self, args: I) -> AppResult<String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let args = args
            .into_iter()
            .map(|arg| arg.as_ref().to_string())
            .collect::<Vec<_>>();
        let output = Command::new("tmux").args(&args).output()?;
        if !output.status.success() {
            return Err(AppError::TmuxCommand {
                command: format!("tmux {}", args.join(" ")),
                stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            });
        }
        Ok(String::from_utf8_lossy(&output.stdout)
            .trim_end()
            .to_string())
    }

    fn tmux_status<I, S>(&self, args: I) -> AppResult<()>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let args = args
            .into_iter()
            .map(|arg| arg.as_ref().to_string())
            .collect::<Vec<_>>();
        let output = Command::new("tmux").args(&args).output()?;
        if !output.status.success() {
            return Err(AppError::TmuxCommand {
                command: format!("tmux {}", args.join(" ")),
                stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            });
        }
        Ok(())
    }
}

fn snapshot_command_args() -> Vec<String> {
    vec![
        "display-message".to_string(),
        "-p".to_string(),
        format!(
            "{CONTEXT_MARK}{FIELD_SEP}#{{client_width}}{FIELD_SEP}#{{session_name}}{FIELD_SEP}#{{host}}{FIELD_SEP}#{{session_created}}"
        ),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        STATUS_MARK.to_string(),
        ";".to_string(),
        "show".to_string(),
        "-qv".to_string(),
        "status".to_string(),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        options_format(),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        SESSIONS_MARK.to_string(),
        ";".to_string(),
        "list-sessions".to_string(),
        "-F".to_string(),
        "#{session_id}\t#{session_name}\t#{session_bell_flag}".to_string(),
    ]
}

fn options_format() -> String {
    let mut format = OPTIONS_MARK.to_string();
    for name in SNAPSHOT_OPTION_NAMES {
        format.push(FIELD_SEP);
        format.push_str("#{");
        format.push_str(name);
        format.push('}');
    }
    format
}

fn parse_snapshot_output(output: &str) -> AppResult<TmuxSnapshot> {
    let mut lines = output.lines();
    let context_line = lines
        .next()
        .ok_or_else(|| AppError::TmuxParse("missing context section".to_string()))?;
    let (width, current_session_name, host, session_created) = parse_context_line(context_line)?;

    expect_marker(lines.next(), STATUS_MARK)?;
    let mut status_lines = Vec::new();
    let options_line = loop {
        let line = lines
            .next()
            .ok_or_else(|| AppError::TmuxParse("missing options section".to_string()))?;
        if line.starts_with(OPTIONS_MARK) {
            break line;
        }
        status_lines.push(line);
    };
    let status = status_lines
        .first()
        .copied()
        .unwrap_or_default()
        .to_string();

    let options = parse_options_line(options_line)?;
    let mode = options.get("@GHC_SL_MODE").cloned().unwrap_or_default();
    let current_layout = options.get("@GHC_SL_LAYOUT").cloned().unwrap_or_default();

    expect_marker(lines.next(), SESSIONS_MARK)?;
    let sessions = lines.filter_map(parse_session_line).collect();

    if current_session_name.is_empty() {
        return Err(AppError::TmuxParse(
            "current session name is empty".to_string(),
        ));
    }

    Ok(TmuxSnapshot {
        mode,
        current_layout,
        status,
        width,
        current_session_name,
        host,
        session_created,
        sessions,
        options,
    })
}

fn parse_session_line(line: &str) -> Option<SessionInfo> {
    let mut fields = line.splitn(3, '\t');
    let id = fields.next()?;
    let name = fields.next()?;
    let has_bell = fields.next() == Some("1");

    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        has_bell,
    })
}

fn parse_options_line(options_line: &str) -> AppResult<BTreeMap<String, String>> {
    let mut fields = options_line.split(FIELD_SEP);
    if fields.next() != Some(OPTIONS_MARK) {
        return Err(AppError::TmuxParse(format!(
            "expected options marker, got: {options_line}"
        )));
    }

    let mut options = BTreeMap::new();
    for name in SNAPSHOT_OPTION_NAMES {
        options.insert(
            (*name).to_string(),
            fields.next().unwrap_or_default().to_string(),
        );
    }
    Ok(options)
}

fn parse_context_line(context_line: &str) -> AppResult<(usize, String, String, i64)> {
    let mut fields = context_line.split(FIELD_SEP);
    let marker = fields.next();
    if marker != Some(CONTEXT_MARK) {
        return Err(AppError::TmuxParse(format!(
            "expected context marker, got: {}",
            context_line
        )));
    }

    let width = fields
        .next()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(200);
    let current_session_name = fields.next().unwrap_or_default().to_string();
    let host = fields.next().unwrap_or_default().to_string();
    let session_created = fields
        .next()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or_default();

    Ok((width, current_session_name, host, session_created))
}

fn expect_marker(line: Option<&str>, marker: &str) -> AppResult<()> {
    if line == Some(marker) {
        return Ok(());
    }

    Err(AppError::TmuxParse(format!(
        "expected marker {marker}, got: {}",
        line.unwrap_or("<missing>")
    )))
}

const FIELD_SEP: char = '\u{1f}';
const CONTEXT_MARK: &str = "__GHC_STATUS_CONTEXT__";
const STATUS_MARK: &str = "__GHC_STATUS_STATUS__";
const OPTIONS_MARK: &str = "__GHC_STATUS_OPTIONS__";
const SESSIONS_MARK: &str = "__GHC_STATUS_SESSIONS__";

const SNAPSHOT_OPTION_NAMES: &[&str] = &[
    "@GHC_SL_MODE",
    "@GHC_SL_LAYOUT",
    "@GHC_SL_STATUS02_LEFT",
    "@GHC_SL_STATUS02_RIGHT",
    "@GHC_SL_STATUS02_SESSION_FORMAT",
    "@GHC_SL_STATUS02_CURRENT_FORMAT",
    "status-left-length",
    "status-right-length",
    "status-interval",
    "@GHC_SL_SESSION_ORDER",
    "@GHC_STATUS_COMPONENT_CACHE_cpu",
    "@GHC_STATUS_COMPONENT_CACHE_memory",
    "@GHC_STATUS_COMPONENT_CACHE_network",
];

#[cfg(test)]
mod tests {
    use super::{
        CONTEXT_MARK, FIELD_SEP, OPTIONS_MARK, SESSIONS_MARK, SNAPSHOT_OPTION_NAMES, STATUS_MARK,
        parse_session_line, parse_snapshot_output,
    };

    #[test]
    fn parses_snapshot_output() {
        let options = std::iter::repeat_n("", SNAPSHOT_OPTION_NAMES.len())
            .collect::<Vec<_>>()
            .join(&FIELD_SEP.to_string());
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}yui{FIELD_SEP}host{FIELD_SEP}42
{STATUS_MARK}
on
{OPTIONS_MARK}{FIELD_SEP}{options}
{SESSIONS_MARK}
$1	yui	0
$2	dev	1"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.width, 120);
        assert_eq!(snapshot.status, "on");
        assert_eq!(snapshot.current_session_name, "yui");
        assert_eq!(snapshot.sessions.len(), 2);
        assert!(!snapshot.sessions[0].has_bell);
        assert!(snapshot.sessions[1].has_bell);
    }

    #[test]
    fn parses_legacy_two_field_session_line_without_bell() {
        let session = parse_session_line("$1\tlegacy").unwrap();

        assert_eq!(session.id, "$1");
        assert_eq!(session.name, "legacy");
        assert!(!session.has_bell);
    }

    #[test]
    fn parses_empty_status_and_tabbed_cache_options() {
        let mut option_values = vec![""; SNAPSHOT_OPTION_NAMES.len()];
        option_values[0] = "02";
        let network_index = SNAPSHOT_OPTION_NAMES
            .iter()
            .position(|name| *name == "@GHC_STATUS_COMPONENT_CACHE_network")
            .unwrap();
        option_values[network_index] = "1	2	3	4	5";
        let options = option_values.join(&FIELD_SEP.to_string());
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}200{FIELD_SEP}yui{FIELD_SEP}host{FIELD_SEP}42
{STATUS_MARK}
{OPTIONS_MARK}{FIELD_SEP}{options}
{SESSIONS_MARK}
$1	yui	0"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.status, "");
        assert_eq!(snapshot.mode, "02");
        assert_eq!(
            snapshot
                .options
                .get("@GHC_STATUS_COMPONENT_CACHE_network")
                .unwrap(),
            "1	2	3	4	5"
        );
    }
}
