use std::collections::{BTreeMap, BTreeSet};
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

        // Fold the redraw into the same command string so the happy path costs a
        // single tmux round-trip (set...; refresh-client -S) instead of two.
        let mut combined_args = plan.to_tmux_args();
        combined_args.push(";".to_string());
        combined_args.push("refresh-client".to_string());
        combined_args.push("-S".to_string());

        if self.tmux_status(combined_args).is_err() {
            for command in &plan.commands {
                self.tmux_status(command.args())?;
            }
            let _ = self.tmux_status(["refresh-client".to_string(), "-S".to_string()]);
        }
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

    pub fn show_global_option(&self, name: &str) -> AppResult<String> {
        self.tmux_output(["show".to_string(), "-gqv".to_string(), name.to_string()])
    }

    /// Reads several global options in one tmux invocation, returning their values
    /// in request order. A `display-message` format joins them with FIELD_SEP, which
    /// never collides with the values' own `\t` separators. Missing/empty trailing
    /// fields are padded back so the result always has `names.len()` entries.
    pub fn show_global_options(&self, names: &[&str]) -> AppResult<Vec<String>> {
        let format = show_global_options_format(names);
        let output = self.tmux_output(["display-message".to_string(), "-p".to_string(), format])?;
        Ok(split_padded_option_values(&output, names.len()))
    }

    /// Folds a run of global-option sets plus a delayed background reschedule into a
    /// single tmux invocation. argv style (each token a separate element joined by a
    /// literal `;`), so option values and the command string pass verbatim with no
    /// shell quoting hazard.
    pub fn apply_sets_and_reschedule(
        &self,
        sets: &[(&str, &str)],
        delay_seconds: u64,
        command: &str,
    ) -> AppResult<()> {
        self.tmux_status(sets_and_reschedule_args(sets, delay_seconds, command))
    }

    pub fn schedule_background(&self, delay_seconds: u64, command: &str) -> AppResult<()> {
        self.tmux_status([
            "run-shell".to_string(),
            "-b".to_string(),
            "-d".to_string(),
            delay_seconds.to_string(),
            command.to_string(),
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
            "{CONTEXT_MARK}{FIELD_SEP}#{{client_width}}{FIELD_SEP}#{{session_name}}{FIELD_SEP}#{{client_last_session}}{FIELD_SEP}#{{host}}{FIELD_SEP}#{{session_created}}"
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
        "#{session_id}\t#{session_name}".to_string(),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        WINDOWS_MARK.to_string(),
        ";".to_string(),
        "list-windows".to_string(),
        "-a".to_string(),
        "-F".to_string(),
        "#{session_id}\t#{window_bell_flag}".to_string(),
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

fn show_global_options_format(names: &[&str]) -> String {
    names
        .iter()
        .map(|name| format!("#{{{name}}}"))
        .collect::<Vec<_>>()
        .join(&FIELD_SEP.to_string())
}

fn split_padded_option_values(output: &str, count: usize) -> Vec<String> {
    let mut values = output
        .split(FIELD_SEP)
        .map(str::to_string)
        .collect::<Vec<_>>();
    values.resize(count, String::new());
    values
}

fn sets_and_reschedule_args(sets: &[(&str, &str)], delay_seconds: u64, command: &str) -> Vec<String> {
    let mut args: Vec<String> = Vec::new();
    for (name, value) in sets {
        if !args.is_empty() {
            args.push(";".to_string());
        }
        args.push("set".to_string());
        args.push("-g".to_string());
        args.push((*name).to_string());
        args.push((*value).to_string());
    }
    if !args.is_empty() {
        args.push(";".to_string());
    }
    args.push("run-shell".to_string());
    args.push("-b".to_string());
    args.push("-d".to_string());
    args.push(delay_seconds.to_string());
    args.push(command.to_string());
    args
}

fn parse_snapshot_output(output: &str) -> AppResult<TmuxSnapshot> {
    let mut lines = output.lines();
    let context_line = lines
        .next()
        .ok_or_else(|| AppError::TmuxParse("missing context section".to_string()))?;
    let (width, current_session_name, client_last_session, host, session_created) =
        parse_context_line(context_line)?;

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
    let mut session_lines = Vec::new();
    let windows_line = loop {
        let line = lines
            .next()
            .ok_or_else(|| AppError::TmuxParse("missing windows section".to_string()))?;
        if line == WINDOWS_MARK {
            break line;
        }
        session_lines.push(line);
    };
    expect_marker(Some(windows_line), WINDOWS_MARK)?;
    let belling_sessions = lines
        .filter_map(parse_window_bell_line)
        .collect::<BTreeSet<_>>();
    let sessions = session_lines
        .into_iter()
        .filter_map(|line| parse_session_line(line, &belling_sessions))
        .collect();

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
        client_last_session,
        host,
        session_created,
        sessions,
        options,
    })
}

fn parse_session_line(line: &str, belling_sessions: &BTreeSet<String>) -> Option<SessionInfo> {
    let (id, name) = line.split_once('\t')?;

    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        has_bell: belling_sessions.contains(id),
    })
}

fn parse_window_bell_line(line: &str) -> Option<String> {
    let (session_id, has_bell) = line.split_once('\t')?;
    if has_bell == "1" {
        return Some(session_id.to_string());
    }

    None
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

fn parse_context_line(context_line: &str) -> AppResult<(usize, String, String, String, i64)> {
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
    let client_last_session = fields.next().unwrap_or_default().to_string();
    let host = fields.next().unwrap_or_default().to_string();
    let session_created = fields
        .next()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or_default();

    Ok((
        width,
        current_session_name,
        client_last_session,
        host,
        session_created,
    ))
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
const WINDOWS_MARK: &str = "__GHC_STATUS_WINDOWS__";

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
    "@GHC_SL_NET_IFACE",
    "@GHC_STATUS_COMPONENT_CACHE_cpu",
    "@GHC_STATUS_COMPONENT_CACHE_memory",
    "@GHC_STATUS_COMPONENT_CACHE_network",
];

#[cfg(test)]
mod tests {
    use std::collections::BTreeSet;

    use super::{
        CONTEXT_MARK, FIELD_SEP, OPTIONS_MARK, SESSIONS_MARK, SNAPSHOT_OPTION_NAMES, STATUS_MARK,
        WINDOWS_MARK, parse_session_line, parse_snapshot_output, parse_window_bell_line,
        sets_and_reschedule_args, show_global_options_format, split_padded_option_values,
    };

    #[test]
    fn parses_snapshot_output() {
        let options = std::iter::repeat_n("", SNAPSHOT_OPTION_NAMES.len())
            .collect::<Vec<_>>()
            .join(&FIELD_SEP.to_string());
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}yui{FIELD_SEP}dev{FIELD_SEP}host{FIELD_SEP}42
{STATUS_MARK}
on
{OPTIONS_MARK}{FIELD_SEP}{options}
{SESSIONS_MARK}
$1	yui
$2	dev
{WINDOWS_MARK}
$1	0
$2	1"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.width, 120);
        assert_eq!(snapshot.status, "on");
        assert_eq!(snapshot.current_session_name, "yui");
        assert_eq!(snapshot.client_last_session, "dev");
        assert_eq!(snapshot.sessions.len(), 2);
        assert!(!snapshot.sessions[0].has_bell);
        assert!(snapshot.sessions[1].has_bell);
    }

    #[test]
    fn parses_session_line_with_aggregated_window_bell_state() {
        let belling_sessions = BTreeSet::from(["$1".to_string()]);

        let session = parse_session_line("$1\tlegacy", &belling_sessions).unwrap();

        assert_eq!(session.id, "$1");
        assert_eq!(session.name, "legacy");
        assert!(session.has_bell);
    }

    #[test]
    fn parses_window_bell_line_only_when_window_has_bell() {
        assert_eq!(parse_window_bell_line("$1\t1"), Some("$1".to_string()));
        assert_eq!(parse_window_bell_line("$1\t0"), None);
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
            "{CONTEXT_MARK}{FIELD_SEP}200{FIELD_SEP}yui{FIELD_SEP}{FIELD_SEP}host{FIELD_SEP}42
{STATUS_MARK}
{OPTIONS_MARK}{FIELD_SEP}{options}
{SESSIONS_MARK}
$1	yui
{WINDOWS_MARK}
$1	0"
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

    #[test]
    fn show_global_options_format_joins_placeholders_with_field_sep() {
        let format = show_global_options_format(&["@A", "@B"]);
        assert_eq!(format, format!("#{{@A}}{FIELD_SEP}#{{@B}}"));
    }

    #[test]
    fn split_padded_option_values_pads_missing_trailing_fields() {
        let output = format!("gen-1{FIELD_SEP}state-blob");
        assert_eq!(
            split_padded_option_values(&output, 2),
            vec!["gen-1".to_string(), "state-blob".to_string()]
        );

        // A blank current generation collapses to one empty token; the state slot is padded.
        assert_eq!(
            split_padded_option_values("", 2),
            vec![String::new(), String::new()]
        );
    }

    #[test]
    fn sets_and_reschedule_args_orders_sets_then_reschedule() {
        let args = sets_and_reschedule_args(
            &[("@GHC_SL_CPU_SAMPLE", "blob"), ("@GHC_CPU_NOW", "100")],
            2,
            "'/bin/ghc' cpu-sample 7",
        );
        assert_eq!(
            args,
            vec![
                "set", "-g", "@GHC_SL_CPU_SAMPLE", "blob", ";", "set", "-g", "@GHC_CPU_NOW", "100",
                ";", "run-shell", "-b", "-d", "2", "'/bin/ghc' cpu-sample 7",
            ]
        );
    }

    #[test]
    fn sets_and_reschedule_args_skips_separator_with_no_sets() {
        let args = sets_and_reschedule_args(&[], 2, "cmd");
        assert_eq!(args, vec!["run-shell", "-b", "-d", "2", "cmd"]);
    }
}
