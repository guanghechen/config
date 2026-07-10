use std::collections::BTreeMap;
use std::process::Command;

use crate::commit::{TmuxCommandPlan, tmux_command_string};
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, HEARTBEAT_GENERATION_OPTION, MEMORY_NOW_OPTION,
    MEMORY_SAMPLE_STATE_OPTION, METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION,
    METRIC_LAST_OK_OPTION, METRIC_SAMPLE_GENERATION_OPTION, NETWORK_NOW_OPTION,
    NETWORK_SAMPLE_STATE_OPTION, ROWS_OVERRIDE_OPTION, STATUS_INTERVAL_OPTION,
    STATUS_JUSTIFY_OPTION, STATUS_LEFT_OPTION, STATUS_POSITION_OPTION, STATUS_RIGHT_OPTION,
};
use crate::error::{AppError, AppResult};
use crate::model::{SessionInfo, TmuxSnapshot};

pub struct TmuxAdapter;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TmuxOptionScope {
    GlobalSession,
    Server,
}

impl TmuxOptionScope {
    fn show_value_flag(self) -> &'static str {
        match self {
            Self::GlobalSession => "-gqv",
            Self::Server => "-sqv",
        }
    }
}

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

    /// Reads explicitly scoped options in one tmux invocation. Marker-delimited
    /// `show -gqv`/`show -sqv` sections preserve empty, spaced, and tabbed values
    /// without falling back to the current session's effective option lookup.
    pub fn show_options(&self, options: &[(TmuxOptionScope, &str)]) -> AppResult<Vec<String>> {
        let output = self.tmux_output(options_command_args(options))?;
        parse_options_output(&output, options.len())
    }

    /// Commits a status plan and its next heartbeat only if the authoritative
    /// server-scoped generation still matches. `if-shell -F` evaluates the guard
    /// and inserts the serialized command list in the same tmux command queue.
    pub fn commit_plan_guarded_and_reschedule(
        &self,
        plan: &TmuxCommandPlan,
        generation_option: &str,
        expected_generation: u64,
        delay_seconds: u64,
        command: &str,
    ) -> AppResult<()> {
        let command_list = plan_and_reschedule_command(plan, delay_seconds, command);
        self.tmux_status(guarded_command_args(
            generation_option,
            expected_generation,
            command_list,
        ))
    }

    /// Publishes metric state and schedules the next sample under one atomic
    /// server-generation guard. A stale sampler therefore performs no mutation.
    pub fn apply_sets_and_reschedule_guarded(
        &self,
        generation_option: &str,
        expected_generation: u64,
        sets: &[(&str, &str)],
        delay_seconds: u64,
        command: &str,
    ) -> AppResult<()> {
        let command_list = sets_and_reschedule_command(sets, delay_seconds, command);
        self.tmux_status(guarded_command_args(
            generation_option,
            expected_generation,
            command_list,
        ))
    }

    pub fn schedule_background_guarded(
        &self,
        generation_option: &str,
        expected_generation: u64,
        delay_seconds: u64,
        command: &str,
    ) -> AppResult<()> {
        let command_list = background_command_string(delay_seconds, command);
        self.tmux_status(guarded_command_args(
            generation_option,
            expected_generation,
            command_list,
        ))
    }

    pub fn display_message(&self, message: &str) -> AppResult<()> {
        self.tmux_status(["display-message".to_string(), message.to_string()])
    }

    fn tmux_output<I>(&self, args: I) -> AppResult<String>
    where
        I: IntoIterator<Item = String>,
    {
        let args = args.into_iter().collect::<Vec<_>>();
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

    fn tmux_status<I>(&self, args: I) -> AppResult<()>
    where
        I: IntoIterator<Item = String>,
    {
        let args = args.into_iter().collect::<Vec<_>>();
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
    let mut args = vec![
        "display-message".to_string(),
        "-p".to_string(),
        format!(
            "{CONTEXT_MARK}{FIELD_SEP}#{{client_width}}{FIELD_SEP}#{{session_name}}{FIELD_SEP}#{{client_last_session}}{FIELD_SEP}#{{host}}{FIELD_SEP}#{{session_created}}"
        ),
    ];
    append_options_commands(&mut args, SNAPSHOT_OPTIONS);
    args.extend([
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        SESSIONS_MARK.to_string(),
        ";".to_string(),
        "list-sessions".to_string(),
        "-F".to_string(),
        // bell: tmux's #{session_bell_flag} is buggy — it inspects only the first window of
        // the session (returns on the first RB-tree winlink), so a bell in any later window
        // is never reported. Derive has_bell from #{session_alerts} instead, which lists
        // every alerted window; a '!' in it marks a bell. parse_session_line reads this third
        // field as the "1"/"0" has_bell flag, so the shape is unchanged.
        "#{session_id}\t#{session_name}\t#{?#{m:*!*,#{session_alerts}},1,0}\t#{status}\t#{@GHC_SL_LAYOUT}\t#{status-left-length}\t#{status-right-length}".to_string(),
        ";".to_string(),
        "display-message".to_string(),
        "-p".to_string(),
        CLIENTS_MARK.to_string(),
        ";".to_string(),
        "list-clients".to_string(),
        "-F".to_string(),
        "#{session_id}\t#{client_width}".to_string(),
    ]);
    args
}

fn options_command_args(options: &[(TmuxOptionScope, &str)]) -> Vec<String> {
    let mut args = Vec::new();
    append_options_commands(&mut args, options);
    args
}

fn append_options_commands(args: &mut Vec<String>, options: &[(TmuxOptionScope, &str)]) {
    push_tmux_command(
        args,
        [
            "display-message".to_string(),
            "-p".to_string(),
            OPTIONS_MARK.to_string(),
        ],
    );
    for (index, (scope, name)) in options.iter().enumerate() {
        push_tmux_command(
            args,
            [
                "display-message".to_string(),
                "-p".to_string(),
                option_value_mark(index),
            ],
        );
        push_tmux_command(
            args,
            [
                "show".to_string(),
                scope.show_value_flag().to_string(),
                (*name).to_string(),
            ],
        );
    }
    push_tmux_command(
        args,
        [
            "display-message".to_string(),
            "-p".to_string(),
            OPTIONS_END_MARK.to_string(),
        ],
    );
}

fn push_tmux_command<I>(args: &mut Vec<String>, command: I)
where
    I: IntoIterator<Item = String>,
{
    if !args.is_empty() {
        args.push(";".to_string());
    }
    args.extend(command);
}

fn option_value_mark(index: usize) -> String {
    format!("{OPTION_VALUE_MARK_PREFIX}{index}__")
}

fn plan_and_reschedule_command(
    plan: &TmuxCommandPlan,
    delay_seconds: u64,
    command: &str,
) -> String {
    let mut commands = Vec::new();
    if !plan.is_empty() {
        commands.push(plan.to_command_string());
    }
    commands.push(background_command_string(delay_seconds, command));
    if !plan.is_empty() {
        commands.push(tmux_command_string(&[
            "refresh-client".to_string(),
            "-S".to_string(),
        ]));
    }
    commands.join("; ")
}

fn sets_and_reschedule_command(sets: &[(&str, &str)], delay_seconds: u64, command: &str) -> String {
    let mut commands = Vec::new();
    for (name, value) in sets {
        commands.push(tmux_command_string(&[
            "set".to_string(),
            "-g".to_string(),
            (*name).to_string(),
            (*value).to_string(),
        ]));
    }
    commands.push(background_command_string(delay_seconds, command));
    commands.join("; ")
}

fn background_command_string(delay_seconds: u64, command: &str) -> String {
    tmux_command_string(&[
        "run-shell".to_string(),
        "-b".to_string(),
        "-d".to_string(),
        delay_seconds.to_string(),
        command.to_string(),
    ])
}

fn guarded_command_args(
    generation_option: &str,
    expected_generation: u64,
    command_list: String,
) -> Vec<String> {
    vec![
        "if-shell".to_string(),
        "-F".to_string(),
        format!("#{{==:#{{{generation_option}}},{expected_generation}}}"),
        command_list,
    ]
}

fn parse_snapshot_output(output: &str) -> AppResult<TmuxSnapshot> {
    let mut lines = output.lines().peekable();
    let context_line = lines
        .next()
        .ok_or_else(|| AppError::TmuxParse("missing context section".to_string()))?;
    let (width, current_session_name, client_last_session, host, session_created) =
        parse_context_line(context_line)?;

    let option_values = parse_option_values(&mut lines, SNAPSHOT_OPTIONS.len())?;
    let options = SNAPSHOT_OPTIONS
        .iter()
        .zip(option_values)
        .map(|((_, name), value)| ((*name).to_string(), value))
        .collect::<BTreeMap<_, _>>();
    let mode = options.get("@GHC_SL_MODE").cloned().unwrap_or_default();

    expect_marker(lines.next(), SESSIONS_MARK)?;
    let mut sessions = Vec::new();
    let mut saw_clients_marker = false;
    for line in lines.by_ref() {
        if line == CLIENTS_MARK {
            saw_clients_marker = true;
            break;
        }
        if let Some(session) = parse_session_line(line) {
            sessions.push(session);
        }
    }
    if !saw_clients_marker {
        return Err(AppError::TmuxParse("missing clients section".to_string()));
    }
    let client_widths = lines.filter_map(parse_client_line).collect();

    if current_session_name.is_empty() {
        return Err(AppError::TmuxParse(
            "current session name is empty".to_string(),
        ));
    }
    let status = sessions
        .iter()
        .find(|session| session.name == current_session_name)
        .map(|session| session.status.clone())
        .ok_or_else(|| {
            AppError::TmuxParse(format!(
                "current session is missing from session list: {current_session_name}"
            ))
        })?;

    Ok(TmuxSnapshot {
        mode,
        status,
        width,
        current_session_name,
        client_last_session,
        host,
        session_created,
        sessions,
        client_widths,
        options,
    })
}

fn parse_options_output(output: &str, count: usize) -> AppResult<Vec<String>> {
    parse_option_values(&mut output.lines().peekable(), count)
}

fn parse_option_values<'a, I>(
    lines: &mut std::iter::Peekable<I>,
    count: usize,
) -> AppResult<Vec<String>>
where
    I: Iterator<Item = &'a str>,
{
    expect_marker(lines.next(), OPTIONS_MARK)?;
    let mut values = Vec::with_capacity(count);
    for index in 0..count {
        expect_marker(lines.next(), &option_value_mark(index))?;
        let next_marker = if index + 1 < count {
            option_value_mark(index + 1)
        } else {
            OPTIONS_END_MARK.to_string()
        };
        let mut value_lines = Vec::new();
        while lines.peek().copied() != Some(next_marker.as_str()) {
            value_lines.push(lines.next().ok_or_else(|| {
                AppError::TmuxParse(format!("missing option delimiter after index {index}"))
            })?);
        }
        values.push(value_lines.join("\n"));
    }
    expect_marker(lines.next(), OPTIONS_END_MARK)?;
    Ok(values)
}

fn parse_session_line(line: &str) -> Option<SessionInfo> {
    let mut fields = line.split('\t');
    let id = fields.next()?;
    let name = fields.next()?;
    let has_bell = fields.next() == Some("1");
    let status = fields.next().unwrap_or_default().to_string();
    let layout_key = fields.next().unwrap_or_default().to_string();
    let left_length = fields.next().unwrap_or_default().to_string();
    let right_length = fields.next().unwrap_or_default().to_string();

    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        has_bell,
        status,
        layout_key,
        left_length,
        right_length,
    })
}

fn parse_client_line(line: &str) -> Option<(String, usize)> {
    let mut fields = line.split('\t');
    let session_id = fields.next()?.to_string();
    let width = fields.next()?.parse::<usize>().ok()?;
    Some((session_id, width))
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
const OPTIONS_MARK: &str = "__GHC_STATUS_OPTIONS__";
const OPTIONS_END_MARK: &str = "__GHC_STATUS_OPTIONS_END__";
const OPTION_VALUE_MARK_PREFIX: &str = "\u{1e}__GHC_STATUS_OPTION_";
const SESSIONS_MARK: &str = "__GHC_STATUS_SESSIONS__";
const CLIENTS_MARK: &str = "__GHC_STATUS_CLIENTS__";

const SNAPSHOT_OPTIONS: &[(TmuxOptionScope, &str)] = &[
    (TmuxOptionScope::GlobalSession, "@GHC_SL_MODE"),
    (TmuxOptionScope::GlobalSession, ROWS_OVERRIDE_OPTION),
    (TmuxOptionScope::GlobalSession, "@GHC_SL_STATUS02_LEFT"),
    (TmuxOptionScope::GlobalSession, "@GHC_SL_STATUS02_RIGHT"),
    (
        TmuxOptionScope::GlobalSession,
        "@GHC_SL_STATUS02_SESSION_FORMAT",
    ),
    (
        TmuxOptionScope::GlobalSession,
        "@GHC_SL_STATUS02_CURRENT_FORMAT",
    ),
    (TmuxOptionScope::GlobalSession, STATUS_LEFT_OPTION),
    (TmuxOptionScope::GlobalSession, STATUS_RIGHT_OPTION),
    (TmuxOptionScope::GlobalSession, STATUS_POSITION_OPTION),
    (TmuxOptionScope::GlobalSession, STATUS_JUSTIFY_OPTION),
    (TmuxOptionScope::GlobalSession, STATUS_INTERVAL_OPTION),
    (TmuxOptionScope::GlobalSession, "@GHC_SL_SESSION_ORDER"),
    (TmuxOptionScope::GlobalSession, "@GHC_SL_NET_IFACE"),
    (TmuxOptionScope::Server, HEARTBEAT_GENERATION_OPTION),
    (TmuxOptionScope::Server, METRIC_SAMPLE_GENERATION_OPTION),
    (TmuxOptionScope::GlobalSession, CPU_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, CPU_NOW_OPTION),
    (TmuxOptionScope::GlobalSession, MEMORY_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, MEMORY_NOW_OPTION),
    (TmuxOptionScope::GlobalSession, NETWORK_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, NETWORK_NOW_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_LAST_OK_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_LAST_ERROR_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_ERROR_COUNT_OPTION),
    (
        TmuxOptionScope::GlobalSession,
        "@GHC_STATUS_COMPONENT_CACHE_cpu",
    ),
    (
        TmuxOptionScope::GlobalSession,
        "@GHC_STATUS_COMPONENT_CACHE_memory",
    ),
    (
        TmuxOptionScope::GlobalSession,
        "@GHC_STATUS_COMPONENT_CACHE_network",
    ),
];

#[cfg(test)]
mod tests {
    use super::{
        CONTEXT_MARK, FIELD_SEP, OPTIONS_END_MARK, OPTIONS_MARK, SESSIONS_MARK, SNAPSHOT_OPTIONS,
        TmuxOptionScope, guarded_command_args, option_value_mark, options_command_args,
        parse_client_line, parse_options_output, parse_session_line, parse_snapshot_output,
        sets_and_reschedule_command,
    };

    const CLIENTS_MARK: &str = super::CLIENTS_MARK;

    fn option_section(values: &[&str]) -> String {
        let mut lines = vec![OPTIONS_MARK.to_string()];
        for (index, value) in values.iter().enumerate() {
            lines.push(option_value_mark(index));
            if !value.is_empty() {
                lines.extend(value.split('\n').map(str::to_string));
            }
        }
        lines.push(OPTIONS_END_MARK.to_string());
        lines.join("\n")
    }

    #[test]
    fn parses_snapshot_output() {
        let option_values = vec![""; SNAPSHOT_OPTIONS.len()];
        let options = option_section(&option_values);
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}yui{FIELD_SEP}dev{FIELD_SEP}host{FIELD_SEP}42
{options}
{SESSIONS_MARK}
$1	yui	0	on	02:wide	64	84
$2	dev	1	2	02:narrow	120	120
{CLIENTS_MARK}
$1	200
$2	120
$2	90"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.width, 120);
        assert_eq!(snapshot.status, "on");
        assert_eq!(snapshot.current_session_name, "yui");
        assert_eq!(snapshot.client_last_session, "dev");
        assert_eq!(snapshot.sessions.len(), 2);
        assert!(!snapshot.sessions[0].has_bell);
        assert!(snapshot.sessions[1].has_bell);
        assert_eq!(snapshot.sessions[0].status, "on");
        assert_eq!(snapshot.sessions[0].layout_key, "02:wide");
        assert_eq!(snapshot.sessions[0].left_length, "64");
        assert_eq!(snapshot.sessions[0].right_length, "84");
        assert_eq!(snapshot.sessions[1].status, "2");
        assert_eq!(snapshot.sessions[1].left_length, "120");
        assert_eq!(
            snapshot.client_widths,
            vec![
                ("$1".to_string(), 200),
                ("$2".to_string(), 120),
                ("$2".to_string(), 90),
            ]
        );
    }

    #[test]
    fn parses_session_line_reads_bell_flag_field() {
        let belling = parse_session_line("$1\tlegacy\t1\ton\t02:wide").unwrap();
        assert_eq!(belling.id, "$1");
        assert_eq!(belling.name, "legacy");
        assert!(belling.has_bell);
        assert_eq!(belling.status, "on");
        assert_eq!(belling.layout_key, "02:wide");

        let quiet = parse_session_line("$2\tdev\t0").unwrap();
        assert!(!quiet.has_bell);
        assert_eq!(quiet.status, "");
        assert_eq!(quiet.layout_key, "");
    }

    #[test]
    fn parses_client_line_reads_session_and_width() {
        assert_eq!(parse_client_line("$3\t180"), Some(("$3".to_string(), 180)));
        assert_eq!(parse_client_line("$3\tnope"), None);
        assert_eq!(parse_client_line("$3"), None);
    }

    #[test]
    fn parses_current_status_and_tabbed_cache_options() {
        let mut option_values = vec![""; SNAPSHOT_OPTIONS.len()];
        option_values[0] = "02";
        let network_index = SNAPSHOT_OPTIONS
            .iter()
            .position(|(_, name)| *name == "@GHC_SL_NET_SAMPLE")
            .unwrap();
        option_values[network_index] = "1	2	3	4	5";
        let options = option_section(&option_values);
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}200{FIELD_SEP}yui{FIELD_SEP}{FIELD_SEP}host{FIELD_SEP}42
{options}
{SESSIONS_MARK}
$1	yui	0	off
{CLIENTS_MARK}
$1	200"
        );

        let snapshot = parse_snapshot_output(&output).unwrap();
        assert_eq!(snapshot.status, "off");
        assert_eq!(snapshot.mode, "02");
        assert_eq!(
            snapshot.options.get("@GHC_SL_NET_SAMPLE").unwrap(),
            "1	2	3	4	5"
        );
    }

    #[test]
    fn option_commands_use_explicit_global_and_server_scopes() {
        let args = options_command_args(&[
            (TmuxOptionScope::GlobalSession, "@GLOBAL"),
            (TmuxOptionScope::Server, "@SERVER"),
        ]);

        assert!(
            args.windows(3)
                .any(|args| args == ["show", "-gqv", "@GLOBAL"])
        );
        assert!(
            args.windows(3)
                .any(|args| args == ["show", "-sqv", "@SERVER"])
        );
    }

    #[test]
    fn option_parser_preserves_empty_special_and_multiline_values() {
        let output = option_section(&[
            "",
            "space # semi; dollar$ quote' slash\\\ttab",
            "line one\nline two",
        ]);

        assert_eq!(
            parse_options_output(&output, 3).unwrap(),
            vec![
                String::new(),
                "space # semi; dollar$ quote' slash\\\ttab".to_string(),
                "line one\nline two".to_string(),
            ]
        );
    }

    #[test]
    fn guarded_sets_serialize_mutation_and_reschedule_in_one_branch() {
        let command = sets_and_reschedule_command(
            &[
                ("@GHC_SL_CPU_SAMPLE", "blob #1; '$\\"),
                ("@GHC_CPU_NOW", "100"),
            ],
            5,
            "'/bin/ghc status' metrics-sample 7",
        );
        assert_eq!(
            command,
            "\"set\" \"-g\" \"@GHC_SL_CPU_SAMPLE\" \"blob #1; '\\$\\\\\"; \"set\" \"-g\" \"@GHC_CPU_NOW\" \"100\"; \"run-shell\" \"-b\" \"-d\" \"5\" \"'/bin/ghc status' metrics-sample 7\""
        );

        assert_eq!(
            guarded_command_args("@GHC_SL_METRIC_GEN", 7, command.clone()),
            vec![
                "if-shell".to_string(),
                "-F".to_string(),
                "#{==:#{@GHC_SL_METRIC_GEN},7}".to_string(),
                command,
            ]
        );
    }
}
