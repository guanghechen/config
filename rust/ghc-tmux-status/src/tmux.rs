use std::collections::BTreeMap;
use std::ops::Range;
use std::time::Duration;

use crate::commit::{
    CACHE_WITNESS_BYTES, SESSION_CACHE_OPTIONS, TmuxCommandPlan, tmux_command_string,
};
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, HEARTBEAT_GENERATION_OPTION,
    HEARTBEAT_LAST_ATTEMPT_OPTION, HEARTBEAT_LAST_COMPLETE_OPTION,
    HEARTBEAT_LAST_EXEC_OUTCOME_OPTION, HEARTBEAT_SCHEDULER_STATE_OPTION, MEMORY_NOW_OPTION,
    MEMORY_SAMPLE_STATE_OPTION, METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ATTEMPT_OPTION,
    METRIC_LAST_COMPLETE_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_EXEC_OUTCOME_OPTION,
    METRIC_LAST_OK_OPTION, METRIC_SAMPLE_GENERATION_OPTION, METRIC_SCHEDULER_STATE_OPTION,
    NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION, RENDER_REVISION_OPTION, ROWS_OVERRIDE_OPTION,
    SCHEDULER_ACTIVE_OPTION, SCHEDULER_GENERATION_OPTION, SESSION_RENDER_KEY_OPTION,
    STATUS_FORMAT_0_OPTION, STATUS_FORMAT_1_OPTION, STATUS_INTERVAL_OPTION, STATUS_JUSTIFY_OPTION,
    STATUS_LEFT_OPTION, STATUS_POSITION_OPTION, STATUS_RIGHT_OPTION,
};
use crate::error::{AppError, AppResult};
use crate::model::{SessionInfo, SessionNavigationSnapshot, TmuxSnapshot};
use crate::process::{OperationDeadline, output_with_timeout};

const TMUX_COMMAND_TIMEOUT: Duration = Duration::from_secs(2);
// This budget applies before the nested `if-shell` quoting pass. Keeping it far
// below macOS ARG_MAX also leaves room for argv, environment, and escaping growth.
const MAX_PLAN_CHUNK_BYTES: usize = 32 * 1024;

pub struct TmuxAdapter;

#[derive(Clone, Copy)]
pub struct TmuxOptionGuard<'a> {
    pub option: &'a str,
    pub expected: &'a str,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GuardedMutationOutcome {
    Applied,
    Skipped,
}

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
        let output = self.tmux_output(snapshot_command_args(None))?;
        parse_snapshot_output(&output)
    }

    /// Starts a render revision and collects its snapshot in one tmux command
    /// queue. A later apply replaces the server token, so this worker's eventual
    /// commit becomes a guarded no-op instead of publishing stale state.
    pub fn read_snapshot_for_render(&self, revision: u64) -> AppResult<TmuxSnapshot> {
        let output = self.tmux_output(snapshot_command_args(Some(revision)))?;
        parse_snapshot_output(&output)
    }

    pub fn read_session_navigation(&self) -> AppResult<SessionNavigationSnapshot> {
        let output = self.tmux_output(session_navigation_command_args())?;
        parse_session_navigation_output(&output)
    }

    pub fn commit_plan_guarded(
        &self,
        plan: &TmuxCommandPlan,
        expected_revision: u64,
    ) -> AppResult<()> {
        self.commit_plan_with_guards(plan, expected_revision, &[], true, None)
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

    pub fn claim_scheduler_task(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        state_option: &str,
        claimed_state: &str,
        last_attempt_option: &str,
        now_seconds: u64,
    ) -> AppResult<GuardedMutationOutcome> {
        let mut commands = scheduler_claim_commands(
            state_option,
            claimed_state,
            last_attempt_option,
            now_seconds,
        );
        commands.push(marker_command(SCHEDULER_APPLIED_MARK));
        let command_list = tmux_command_sequence(&commands);
        self.guarded_mutation(guards, command_list)
    }

    /// Claims a scheduler task and snapshots its execution inputs in the same
    /// tmux command queue. A timeout after the state mutation remains ambiguous:
    /// callers must not retry; the claimed lease is the recovery boundary.
    pub fn claim_scheduler_task_with_options(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        state_option: &str,
        claimed_state: &str,
        last_attempt_option: &str,
        now_seconds: u64,
        options: &[(TmuxOptionScope, &str)],
    ) -> AppResult<(GuardedMutationOutcome, Vec<String>)> {
        let mut commands = scheduler_claim_commands(
            state_option,
            claimed_state,
            last_attempt_option,
            now_seconds,
        );
        commands.push(marker_command(SCHEDULER_APPLIED_MARK));
        commands.extend(serialized_option_commands(options));
        let skipped = marker_command(SCHEDULER_SKIPPED_MARK);
        let output = self.tmux_output(option_guarded_command_args(
            guards,
            tmux_command_sequence(&commands),
            Some(skipped),
        ))?;
        parse_guarded_options_output(&output, options.len())
    }

    pub fn finish_scheduler_task(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        global_sets: &[(&str, &str)],
        state_option: &str,
        completed_state: &str,
        last_complete_option: &str,
        now_seconds: u64,
    ) -> AppResult<GuardedMutationOutcome> {
        let mut commands = global_sets
            .iter()
            .map(|(name, value)| {
                tmux_command_string(&[
                    "set".to_string(),
                    "-g".to_string(),
                    (*name).to_string(),
                    (*value).to_string(),
                ])
            })
            .collect::<Vec<_>>();
        commands.push(tmux_command_string(&[
            "set".to_string(),
            "-g".to_string(),
            last_complete_option.to_string(),
            now_seconds.to_string(),
        ]));
        // The state is the completion witness and must be the final mutation.
        commands.push(tmux_command_string(&[
            "set".to_string(),
            "-s".to_string(),
            state_option.to_string(),
            completed_state.to_string(),
        ]));
        commands.push(tmux_command_string(&[
            "display-message".to_string(),
            "-p".to_string(),
            SCHEDULER_APPLIED_MARK.to_string(),
        ]));
        self.guarded_mutation(guards, tmux_command_sequence(&commands))
    }

    pub fn record_scheduler_outcome(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        outcome_option: &str,
        outcome: &str,
    ) -> AppResult<GuardedMutationOutcome> {
        let command_list = tmux_command_sequence(&[
            tmux_command_string(&[
                "set".to_string(),
                "-g".to_string(),
                outcome_option.to_string(),
                outcome.to_string(),
            ]),
            tmux_command_string(&[
                "display-message".to_string(),
                "-p".to_string(),
                SCHEDULER_APPLIED_MARK.to_string(),
            ]),
        ]);
        self.guarded_mutation(guards, command_list)
    }

    pub fn commit_plan_scheduler_guarded(
        &self,
        plan: &TmuxCommandPlan,
        expected_revision: u64,
        guards: &[TmuxOptionGuard<'_>],
        deadline: &OperationDeadline,
    ) -> AppResult<()> {
        self.commit_plan_with_guards(plan, expected_revision, guards, false, Some(deadline))
    }

    /// Commits a bounded status plan under generation + render guards, then
    /// schedules exactly one successor under the generation guard. Each chunk
    /// rechecks both tokens, so a reload or newer render aborts the remainder.
    pub fn commit_plan_guarded_and_reschedule(
        &self,
        plan: &TmuxCommandPlan,
        generation_option: &str,
        expected_generation: u64,
        expected_render_revision: u64,
        delay_seconds: u64,
        command: &str,
    ) -> AppResult<()> {
        let generation = expected_generation.to_string();
        self.commit_plan_with_guards(
            plan,
            expected_render_revision,
            &[TmuxOptionGuard {
                option: generation_option,
                expected: &generation,
            }],
            true,
            None,
        )?;
        self.schedule_background_guarded(
            generation_option,
            expected_generation,
            delay_seconds,
            command,
        )
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

    fn commit_plan_with_guards(
        &self,
        plan: &TmuxCommandPlan,
        expected_revision: u64,
        guards: &[TmuxOptionGuard<'_>],
        retry_individual_commands: bool,
        deadline: Option<&OperationDeadline>,
    ) -> AppResult<()> {
        if plan.is_empty() {
            return Ok(());
        }

        for chunk in serialized_plan_chunks(plan, MAX_PLAN_CHUNK_BYTES) {
            if let Some(deadline) = deadline {
                deadline.check("commit-plan")?;
            }
            let guarded = nested_render_guard_args(expected_revision, &chunk.command_list, guards);
            let result = self.tmux_status(guarded);
            if result.is_ok() {
                continue;
            }
            if !retry_individual_commands {
                return result;
            }

            // Commands are idempotent. A chunk-level parser/argv failure can be
            // retried one command at a time without allowing a stale writer: both
            // guards are rebuilt around every individual mutation.
            for command in &plan.commands[chunk.range] {
                self.tmux_status(nested_render_guard_args(
                    expected_revision,
                    &command.to_command_string(),
                    guards,
                ))?;
            }
        }

        let refresh = tmux_command_string(&["refresh-client".to_string(), "-S".to_string()]);
        let _ = self.tmux_status(nested_render_guard_args(
            expected_revision,
            &refresh,
            guards,
        ));
        Ok(())
    }

    fn guarded_mutation(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        command_list: String,
    ) -> AppResult<GuardedMutationOutcome> {
        let skipped = tmux_command_string(&[
            "display-message".to_string(),
            "-p".to_string(),
            SCHEDULER_SKIPPED_MARK.to_string(),
        ]);
        let output = self.tmux_output(option_guarded_command_args(
            guards,
            command_list,
            Some(skipped),
        ))?;
        match output.trim() {
            SCHEDULER_APPLIED_MARK => Ok(GuardedMutationOutcome::Applied),
            SCHEDULER_SKIPPED_MARK => Ok(GuardedMutationOutcome::Skipped),
            value => Err(AppError::TmuxParse(format!(
                "unexpected scheduler mutation result: {value}"
            ))),
        }
    }

    fn tmux_output<I>(&self, args: I) -> AppResult<String>
    where
        I: IntoIterator<Item = String>,
    {
        let args = args.into_iter().collect::<Vec<_>>();
        let output = output_with_timeout("tmux", &args, TMUX_COMMAND_TIMEOUT)?;
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
        let output = output_with_timeout("tmux", &args, TMUX_COMMAND_TIMEOUT)?;
        if !output.status.success() {
            return Err(AppError::TmuxCommand {
                command: format!("tmux {}", args.join(" ")),
                stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            });
        }
        Ok(())
    }
}

fn snapshot_command_args(render_revision: Option<u64>) -> Vec<String> {
    let mut args = Vec::new();
    let cache_witness_formats = SESSION_CACHE_OPTIONS.map(cache_witness_format);
    if let Some(revision) = render_revision {
        push_tmux_command(
            &mut args,
            [
                "set".to_string(),
                "-s".to_string(),
                RENDER_REVISION_OPTION.to_string(),
                revision.to_string(),
            ],
        );
    }
    push_tmux_command(
        &mut args,
        [
            "display-message".to_string(),
            "-p".to_string(),
            format!(
                "{CONTEXT_MARK}{FIELD_SEP}#{{client_width}}{FIELD_SEP}#{{session_name}}{FIELD_SEP}#{{client_last_session}}{FIELD_SEP}#{{host}}{FIELD_SEP}#{{session_created}}"
            ),
        ],
    );
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
        format!(
            "#{{session_id}}\t#{{session_name}}\t#{{?#{{m:*!*,#{{session_alerts}}}},1,0}}\t#{{status}}\t#{{@GHC_SL_LAYOUT}}\t#{{status-left-length}}\t#{{status-right-length}}\t#{{{STATUS_FORMAT_0_OPTION}}}\t#{{{STATUS_FORMAT_1_OPTION}}}\t#{{{SESSION_RENDER_KEY_OPTION}}}\t{}\t{}\t{}\t{}\t#{{session_created}}",
            cache_witness_formats[0],
            cache_witness_formats[1],
            cache_witness_formats[2],
            cache_witness_formats[3],
        ),
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

fn session_navigation_command_args() -> Vec<String> {
    let mut args = Vec::new();
    push_tmux_command(
        &mut args,
        [
            "display-message".to_string(),
            "-p".to_string(),
            format!("{NAVIGATION_MARK}{FIELD_SEP}#{{session_name}}"),
        ],
    );
    append_options_commands(
        &mut args,
        &[(TmuxOptionScope::GlobalSession, "@GHC_SL_SESSION_ORDER")],
    );
    push_tmux_command(
        &mut args,
        [
            "display-message".to_string(),
            "-p".to_string(),
            SESSIONS_MARK.to_string(),
        ],
    );
    push_tmux_command(
        &mut args,
        [
            "list-sessions".to_string(),
            "-F".to_string(),
            "#{session_id}\t#{session_name}".to_string(),
        ],
    );
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

fn cache_witness_format(option: &str) -> String {
    let capture = ".".repeat(CACHE_WITNESS_BYTES);
    format!("#{{s/^({capture}).*$/\\1/:{option}}}")
}

struct SerializedPlanChunk {
    range: Range<usize>,
    command_list: String,
}

fn serialized_plan_chunks(plan: &TmuxCommandPlan, max_bytes: usize) -> Vec<SerializedPlanChunk> {
    let mut chunks = Vec::new();
    let mut chunk_start = 0;
    let mut command_list = String::new();

    for (index, command) in plan.commands.iter().enumerate() {
        let serialized = command.to_command_string();
        let separator_bytes = usize::from(!command_list.is_empty()) * 2;
        if !command_list.is_empty()
            && command_list.len() + separator_bytes + serialized.len() > max_bytes
        {
            chunks.push(SerializedPlanChunk {
                range: chunk_start..index,
                command_list,
            });
            chunk_start = index;
            command_list = String::new();
        }
        if !command_list.is_empty() {
            command_list.push_str("; ");
        }
        command_list.push_str(&serialized);
    }

    if !command_list.is_empty() {
        chunks.push(SerializedPlanChunk {
            range: chunk_start..plan.commands.len(),
            command_list,
        });
    }
    chunks
}

fn nested_render_guard_args(
    expected_revision: u64,
    command_list: &str,
    guards: &[TmuxOptionGuard<'_>],
) -> Vec<String> {
    let render_guard = guarded_command_args(
        RENDER_REVISION_OPTION,
        expected_revision,
        command_list.to_string(),
    );
    if guards.is_empty() {
        return render_guard;
    }
    option_guarded_command_args(guards, tmux_command_string(&render_guard), None)
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

fn option_guarded_command_args(
    guards: &[TmuxOptionGuard<'_>],
    command_list: String,
    false_command: Option<String>,
) -> Vec<String> {
    let mut args = vec![
        "if-shell".to_string(),
        "-F".to_string(),
        combined_guard_format(guards),
        command_list,
    ];
    if let Some(false_command) = false_command {
        args.push(false_command);
    }
    args
}

fn scheduler_claim_commands(
    state_option: &str,
    claimed_state: &str,
    last_attempt_option: &str,
    now_seconds: u64,
) -> Vec<String> {
    vec![
        tmux_command_string(&[
            "set".to_string(),
            "-g".to_string(),
            last_attempt_option.to_string(),
            now_seconds.to_string(),
        ]),
        tmux_command_string(&[
            "set".to_string(),
            "-s".to_string(),
            state_option.to_string(),
            claimed_state.to_string(),
        ]),
    ]
}

fn marker_command(marker: &str) -> String {
    tmux_command_string(&[
        "display-message".to_string(),
        "-p".to_string(),
        marker.to_string(),
    ])
}

fn serialized_option_commands(options: &[(TmuxOptionScope, &str)]) -> Vec<String> {
    let mut commands = vec![marker_command(OPTIONS_MARK)];
    for (index, (scope, name)) in options.iter().enumerate() {
        commands.push(marker_command(&option_value_mark(index)));
        commands.push(tmux_command_string(&[
            "show".to_string(),
            scope.show_value_flag().to_string(),
            (*name).to_string(),
        ]));
    }
    commands.push(marker_command(OPTIONS_END_MARK));
    commands
}

fn combined_guard_format(guards: &[TmuxOptionGuard<'_>]) -> String {
    let mut conditions = guards.iter().map(|guard| {
        format!(
            "#{{==:#{{{}}},{}}}",
            guard.option,
            format_literal(guard.expected)
        )
    });
    let first = conditions
        .next()
        .expect("guarded tmux command requires at least one guard");
    conditions.fold(first, |combined, condition| {
        format!("#{{&&:{combined},{condition}}}")
    })
}

fn format_literal(value: &str) -> String {
    let escaped = value.replace('#', "##").replace('}', "#}");
    format!("#{{l:{escaped}}}")
}

fn tmux_command_sequence(commands: &[String]) -> String {
    commands.join("; ")
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

fn parse_guarded_options_output(
    output: &str,
    count: usize,
) -> AppResult<(GuardedMutationOutcome, Vec<String>)> {
    let mut lines = output.lines().peekable();
    match lines.next() {
        Some(SCHEDULER_APPLIED_MARK) => {
            let values = parse_option_values(&mut lines, count)?;
            if lines.next().is_some() {
                return Err(AppError::TmuxParse(
                    "unexpected output after scheduler claim options".to_string(),
                ));
            }
            Ok((GuardedMutationOutcome::Applied, values))
        }
        Some(SCHEDULER_SKIPPED_MARK) if lines.next().is_none() => {
            Ok((GuardedMutationOutcome::Skipped, Vec::new()))
        }
        value => Err(AppError::TmuxParse(format!(
            "unexpected scheduler claim result: {}",
            value.unwrap_or("<missing>")
        ))),
    }
}

fn parse_session_navigation_output(output: &str) -> AppResult<SessionNavigationSnapshot> {
    let mut lines = output.lines().peekable();
    let context = lines
        .next()
        .ok_or_else(|| AppError::TmuxParse("missing navigation context".to_string()))?;
    let current_session_name = context
        .strip_prefix(&format!("{NAVIGATION_MARK}{FIELD_SEP}"))
        .filter(|name| !name.is_empty())
        .ok_or_else(|| AppError::TmuxParse("invalid navigation context".to_string()))?
        .to_string();
    let order_value = parse_option_values(&mut lines, 1)?
        .into_iter()
        .next()
        .unwrap_or_default();
    expect_marker(lines.next(), SESSIONS_MARK)?;
    let sessions = lines.filter_map(parse_navigation_session_line).collect();
    Ok(SessionNavigationSnapshot {
        current_session_name,
        sessions,
        order_value,
    })
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
    let format_0 = fields.next().unwrap_or_default().to_string();
    let format_1 = fields.next().unwrap_or_default().to_string();
    let render_key = fields.next().unwrap_or_default().to_string();
    let cache_witnesses = std::array::from_fn(|_| fields.next().unwrap_or_default().to_string());
    let created = fields
        .next()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or_default();

    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        has_bell,
        status,
        layout_key,
        left_length,
        right_length,
        format_0,
        format_1,
        render_key,
        cache_witnesses,
        created,
    })
}

fn parse_navigation_session_line(line: &str) -> Option<SessionInfo> {
    let (id, name) = line.split_once('\t')?;
    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        has_bell: false,
        status: String::new(),
        layout_key: String::new(),
        left_length: String::new(),
        right_length: String::new(),
        format_0: String::new(),
        format_1: String::new(),
        render_key: String::new(),
        cache_witnesses: std::array::from_fn(|_| String::new()),
        created: 0,
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
const NAVIGATION_MARK: &str = "__GHC_STATUS_NAVIGATION__";
const OPTIONS_MARK: &str = "__GHC_STATUS_OPTIONS__";
const OPTIONS_END_MARK: &str = "__GHC_STATUS_OPTIONS_END__";
const OPTION_VALUE_MARK_PREFIX: &str = "\u{1e}__GHC_STATUS_OPTION_";
const SESSIONS_MARK: &str = "__GHC_STATUS_SESSIONS__";
const CLIENTS_MARK: &str = "__GHC_STATUS_CLIENTS__";
const SCHEDULER_APPLIED_MARK: &str = "__GHC_SCHEDULER_APPLIED__";
const SCHEDULER_SKIPPED_MARK: &str = "__GHC_SCHEDULER_SKIPPED__";

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
    (TmuxOptionScope::GlobalSession, STATUS_FORMAT_0_OPTION),
    (TmuxOptionScope::GlobalSession, STATUS_FORMAT_1_OPTION),
    (TmuxOptionScope::GlobalSession, "@GHC_SL_SESSION_ORDER"),
    (TmuxOptionScope::GlobalSession, "@GHC_SL_NET_IFACE"),
    (TmuxOptionScope::Server, HEARTBEAT_GENERATION_OPTION),
    (TmuxOptionScope::Server, METRIC_SAMPLE_GENERATION_OPTION),
    (TmuxOptionScope::Server, SCHEDULER_ACTIVE_OPTION),
    (TmuxOptionScope::Server, SCHEDULER_GENERATION_OPTION),
    (TmuxOptionScope::Server, METRIC_SCHEDULER_STATE_OPTION),
    (TmuxOptionScope::Server, HEARTBEAT_SCHEDULER_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, CPU_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, CPU_NOW_OPTION),
    (TmuxOptionScope::GlobalSession, MEMORY_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, MEMORY_NOW_OPTION),
    (TmuxOptionScope::GlobalSession, NETWORK_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, NETWORK_NOW_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_LAST_OK_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_LAST_ERROR_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_ERROR_COUNT_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_LAST_ATTEMPT_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_LAST_COMPLETE_OPTION),
    (
        TmuxOptionScope::GlobalSession,
        METRIC_LAST_EXEC_OUTCOME_OPTION,
    ),
    (
        TmuxOptionScope::GlobalSession,
        HEARTBEAT_LAST_ATTEMPT_OPTION,
    ),
    (
        TmuxOptionScope::GlobalSession,
        HEARTBEAT_LAST_COMPLETE_OPTION,
    ),
    (
        TmuxOptionScope::GlobalSession,
        HEARTBEAT_LAST_EXEC_OUTCOME_OPTION,
    ),
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
        CONTEXT_MARK, FIELD_SEP, GuardedMutationOutcome, NAVIGATION_MARK, OPTIONS_END_MARK,
        OPTIONS_MARK, SCHEDULER_APPLIED_MARK, SCHEDULER_SKIPPED_MARK, SESSIONS_MARK,
        SNAPSHOT_OPTIONS, TmuxOptionGuard, TmuxOptionScope, cache_witness_format,
        combined_guard_format, format_literal, guarded_command_args, nested_render_guard_args,
        option_value_mark, options_command_args, parse_client_line, parse_guarded_options_output,
        parse_options_output, parse_session_line, parse_session_navigation_output,
        parse_snapshot_output, serialized_plan_chunks, sets_and_reschedule_command,
        snapshot_command_args,
    };
    use crate::commit::{TmuxCommand, TmuxCommandPlan};
    use crate::config::RENDER_REVISION_OPTION;

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
        let belling = parse_session_line(
            "$1\tlegacy\t1\ton\t02:wide\t64\t84\tfmt0\tfmt1\t02:wide:v1:abcd\tw0\tw1\tw2\tw3\t123",
        )
        .unwrap();
        assert_eq!(belling.id, "$1");
        assert_eq!(belling.name, "legacy");
        assert!(belling.has_bell);
        assert_eq!(belling.status, "on");
        assert_eq!(belling.layout_key, "02:wide");
        assert_eq!(belling.format_0, "fmt0");
        assert_eq!(belling.format_1, "fmt1");
        assert_eq!(belling.render_key, "02:wide:v1:abcd");
        assert_eq!(belling.cache_witnesses, ["w0", "w1", "w2", "w3"]);
        assert_eq!(belling.created, 123);

        let quiet = parse_session_line("$2\tdev\t0").unwrap();
        assert!(!quiet.has_bell);
        assert_eq!(quiet.status, "");
        assert_eq!(quiet.layout_key, "");
    }

    #[test]
    fn parses_minimal_session_navigation_snapshot() {
        let options = option_section(&["$2\t$1"]);
        let output = format!(
            "{NAVIGATION_MARK}{FIELD_SEP}main\n{options}\n{SESSIONS_MARK}\n$1\tmain\n$2\twork"
        );

        let snapshot = parse_session_navigation_output(&output).unwrap();
        assert_eq!(snapshot.current_session_name, "main");
        assert_eq!(snapshot.order_value, "$2\t$1");
        assert_eq!(snapshot.sessions.len(), 2);
        assert_eq!(snapshot.sessions[1].name, "work");
    }

    #[test]
    fn render_snapshot_starts_revision_in_the_same_tmux_queue() {
        let args = snapshot_command_args(Some(42));
        assert_eq!(&args[..4], ["set", "-s", RENDER_REVISION_OPTION, "42"]);
        assert_eq!(args[4], ";");
    }

    #[test]
    fn cache_witness_format_extracts_a_fixed_prefix() {
        assert_eq!(
            cache_witness_format("@CACHE"),
            "#{s/^(..........................).*$/\\1/:@CACHE}"
        );
    }

    #[test]
    fn generation_guard_wraps_each_render_guard() {
        let plan = TmuxCommandPlan {
            commands: vec![TmuxCommand::SetGlobal {
                name: "@VALUE".to_string(),
                value: "new".to_string(),
            }],
        };
        let chunks = serialized_plan_chunks(&plan, 1024);
        let args = nested_render_guard_args(
            9,
            &chunks[0].command_list,
            &[TmuxOptionGuard {
                option: "@GHC_SL_HEARTBEAT_GEN",
                expected: "7",
            }],
        );

        assert_eq!(args[2], "#{==:#{@GHC_SL_HEARTBEAT_GEN},#{l:7}}");
        assert!(args[3].contains(RENDER_REVISION_OPTION));
        assert!(args[3].contains("@VALUE"));
    }

    #[test]
    fn multi_option_guards_escape_literal_state_and_require_every_match() {
        assert_eq!(format_literal("1:2:#,}"), "#{l:1:2:##,#}}");
        assert_eq!(
            combined_guard_format(&[
                TmuxOptionGuard {
                    option: "@ACTIVE",
                    expected: "1",
                },
                TmuxOptionGuard {
                    option: "@STATE",
                    expected: "7:4:105:0",
                },
            ]),
            "#{&&:#{==:#{@ACTIVE},#{l:1}},#{==:#{@STATE},#{l:7:4:105:0}}}"
        );
    }

    #[test]
    fn splits_large_plans_without_splitting_a_command() {
        let plan = TmuxCommandPlan {
            commands: (0..4)
                .map(|index| TmuxCommand::SetGlobal {
                    name: format!("@VALUE_{index}"),
                    value: "x".repeat(40),
                })
                .collect(),
        };

        let chunks = serialized_plan_chunks(&plan, 100);

        assert_eq!(chunks.len(), 4);
        assert_eq!(chunks[0].range, 0..1);
        assert_eq!(chunks[3].range, 3..4);
        assert!(chunks.iter().all(|chunk| chunk.command_list.len() < 100));
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
    fn guarded_claim_parser_preserves_applied_option_values() {
        let options = option_section(&["", "tab\tvalue", "line one\nline two"]);
        let output = format!("{SCHEDULER_APPLIED_MARK}\n{options}");

        assert_eq!(
            parse_guarded_options_output(&output, 3).unwrap(),
            (
                GuardedMutationOutcome::Applied,
                vec![
                    String::new(),
                    "tab\tvalue".to_string(),
                    "line one\nline two".to_string(),
                ],
            )
        );
    }

    #[test]
    fn guarded_claim_parser_accepts_exact_skipped_marker_only() {
        assert_eq!(
            parse_guarded_options_output(SCHEDULER_SKIPPED_MARK, 5).unwrap(),
            (GuardedMutationOutcome::Skipped, Vec::new())
        );
        assert!(
            parse_guarded_options_output(&format!("{SCHEDULER_SKIPPED_MARK}\nunexpected"), 5)
                .is_err()
        );
    }

    #[test]
    fn guarded_claim_parser_rejects_trailing_applied_output() {
        let options = option_section(&["value"]);
        let output = format!("{SCHEDULER_APPLIED_MARK}\n{options}\nunexpected");

        assert!(parse_guarded_options_output(&output, 1).is_err());
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
