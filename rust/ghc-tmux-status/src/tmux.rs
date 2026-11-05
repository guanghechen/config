use std::collections::BTreeMap;
use std::ops::Range;
use std::time::Duration;

use crate::commit::{
    CACHE_WITNESS_BYTES, SESSION_CACHE_OPTIONS, TmuxCommandPlan, tmux_command_string,
};
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, HEARTBEAT_LAST_ATTEMPT_OPTION,
    HEARTBEAT_LAST_COMPLETE_OPTION, HEARTBEAT_LAST_EXEC_OUTCOME_OPTION,
    HEARTBEAT_SCHEDULER_STATE_OPTION, MEMORY_NOW_OPTION, MEMORY_SAMPLE_STATE_OPTION,
    METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ATTEMPT_OPTION, METRIC_LAST_COMPLETE_OPTION,
    METRIC_LAST_ERROR_OPTION, METRIC_LAST_EXEC_OUTCOME_OPTION, METRIC_LAST_OK_OPTION,
    METRIC_SCHEDULER_STATE_OPTION, NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION,
    RENDER_REVISION_OPTION, ROWS_OVERRIDE_OPTION, SCHEDULER_ACTIVE_OPTION,
    SCHEDULER_GENERATION_OPTION, SESSION_RENDER_KEY_OPTION, SESSION_STATES_OPTION,
    STATUS_FORMAT_0_OPTION, STATUS_FORMAT_1_OPTION, STATUS_INTERVAL_OPTION, STATUS_JUSTIFY_OPTION,
    STATUS_LEFT_OPTION, STATUS_POSITION_OPTION, STATUS_RIGHT_OPTION,
};
use crate::error::{AppError, AppResult};
use crate::model::{SessionInfo, SessionNavigationSnapshot, TmuxSnapshot};
use crate::process::{OperationDeadline, output_with_timeout};
use crate::scheduler::SessionStatesPublish;

const TMUX_COMMAND_TIMEOUT: Duration = Duration::from_secs(2);
/*
 * This budget applies before two nested `if-shell` quoting passes. tmux 3.7c
 * rejects the fully wrapped client command near 16 KiB, so retain enough room
 * for argv framing and content-dependent escaping rather than relying on ARG_MAX.
 */
const MAX_PLAN_CHUNK_BYTES: usize = 8 * 1024;

pub struct TmuxAdapter;

#[derive(Clone, Copy)]
pub struct TmuxOptionGuard<'a> {
    pub option: &'a str,
    pub expected: &'a str,
}

/// The task-state transition a scheduler claim commits behind its guards.
pub struct SchedulerClaimMutation<'a> {
    pub state_option: &'a str,
    pub claimed_state: &'a str,
    pub last_attempt_option: &'a str,
    pub now_seconds: u64,
}

/// The task-state transition a scheduler completion commits behind its guards.
pub struct SchedulerCompletionMutation<'a> {
    pub state_option: &'a str,
    pub completed_state: &'a str,
    pub last_complete_option: &'a str,
    pub now_seconds: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GuardedMutationOutcome {
    Applied,
    Skipped,
}

#[derive(Debug)]
pub enum CompareAndSetOutcome {
    Applied,
    Skipped,
    Unknown(AppError),
}

pub struct GlobalOptionCas<'a> {
    pub option: &'a str,
    pub expected_value: &'a str,
    pub next_value: &'a str,
    pub revision_option: &'a str,
    pub expected_revision: &'a str,
    pub next_revision: &'a str,
    pub operation_option: &'a str,
    pub operation_token: &'a str,
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

/// One tmux command's argv. A queue runs several in one invocation.
type Command = Vec<String>;

impl TmuxAdapter {
    pub fn new() -> Self {
        Self
    }

    pub fn read_snapshot(&self) -> AppResult<TmuxSnapshot> {
        let options = diagnostic_snapshot_options();
        let output = self.tmux_output(queue_argv(snapshot_commands(None, &options)))?;
        parse_snapshot_output(&output, &options)
    }

    /**
     * Claims a render revision and collects its snapshot in one guarded tmux
     * command queue. A lifecycle fence can therefore reject a stale worker
     * before it replaces the render token, not only when it eventually commits.
     */
    pub fn read_snapshot_for_render(
        &self,
        revision: u64,
        guards: &[TmuxOptionGuard<'_>],
    ) -> AppResult<Option<TmuxSnapshot>> {
        let output = self.tmux_output(option_guarded_command_args(
            guards,
            queue_string(&snapshot_commands(Some(revision), RENDER_SNAPSHOT_OPTIONS)),
            marker_command(RENDER_SKIPPED_MARK),
        ))?;
        if output == RENDER_SKIPPED_MARK {
            return Ok(None);
        }
        parse_snapshot_output(&output, RENDER_SNAPSHOT_OPTIONS).map(Some)
    }

    pub fn read_session_navigation(&self) -> AppResult<SessionNavigationSnapshot> {
        let output = self.tmux_output(queue_argv(session_navigation_commands()))?;
        parse_session_navigation_output(&output)
    }

    /**
     * Commits `plan` behind the render revision and `guards`. A standard commit
     * folds its status refresh into the final chunk and retries a failed chunk
     * one idempotent command at a time. A scheduler commit, bounded by its task
     * `deadline`, does neither: each committed `set` already redraws attached
     * clients, while any `refresh-client` makes tmux SIGTERM and restart running
     * `#()` status jobs, including the driver awaiting this task's completion.
     */
    pub fn commit_plan(
        &self,
        plan: &TmuxCommandPlan,
        expected_revision: u64,
        guards: &[TmuxOptionGuard<'_>],
        deadline: Option<&OperationDeadline>,
    ) -> AppResult<GuardedMutationOutcome> {
        if plan.is_empty() {
            return Ok(GuardedMutationOutcome::Applied);
        }

        let standard = deadline.is_none();
        let chunks = serialized_plan_chunks(plan, MAX_PLAN_CHUNK_BYTES);
        let final_chunk_index = chunks.len() - 1;
        let mut refresh_separately = false;

        for (chunk_index, chunk) in chunks.iter().enumerate() {
            if let Some(deadline) = deadline {
                deadline.check("commit-plan")?;
            }
            let fold_refresh = standard && chunk_index == final_chunk_index;
            match self.render_guarded_mutation(
                expected_revision,
                &chunk.command_list,
                guards,
                fold_refresh,
            ) {
                Ok(GuardedMutationOutcome::Applied) => continue,
                Ok(GuardedMutationOutcome::Skipped) => {
                    return Ok(GuardedMutationOutcome::Skipped);
                }
                Err(error) if !standard => return Err(error),
                Err(_) => refresh_separately |= fold_refresh,
            }

            /*
             * Commands are idempotent. A chunk-level parser/argv failure can be
             * retried one command at a time without allowing a stale writer: both
             * guards are rebuilt around every individual mutation.
             */
            for command in &plan.commands[chunk.range.clone()] {
                let outcome = self.render_guarded_mutation(
                    expected_revision,
                    &command.to_command_string(),
                    guards,
                    false,
                )?;
                if outcome == GuardedMutationOutcome::Skipped {
                    return Ok(GuardedMutationOutcome::Skipped);
                }
            }
        }

        if refresh_separately {
            let refresh = tmux_command_string(&["refresh-client", "-S"]);
            let _ = self.tmux_status(nested_render_guard_args(
                expected_revision,
                &refresh,
                guards,
                false,
            ));
        }
        Ok(GuardedMutationOutcome::Applied)
    }

    pub fn switch_client(&self, target_session_id: &str) -> AppResult<()> {
        self.tmux_status(command(&["switch-client", "-t", target_session_id]))
    }

    /**
     * Updates a global user option only while its server-owned revision witness
     * remains current. The value, next revision, and applied marker are emitted
     * in one tmux command queue.
     */
    pub fn compare_and_set_global_option(
        &self,
        mutation: GlobalOptionCas<'_>,
    ) -> AppResult<CompareAndSetOutcome> {
        let command_list = queue_string(&[
            command(&["set", "-g", mutation.option, mutation.next_value]),
            command(&[
                "set",
                "-s",
                mutation.revision_option,
                mutation.next_revision,
            ]),
            command(&[
                "set",
                "-s",
                mutation.operation_option,
                mutation.operation_token,
            ]),
            marker(SCHEDULER_APPLIED_MARK),
        ]);
        let result = self.guarded_mutation(
            None,
            &[TmuxOptionGuard {
                option: mutation.revision_option,
                expected: mutation.expected_revision,
            }],
            command_list,
        );
        match result {
            Ok(GuardedMutationOutcome::Applied) => Ok(CompareAndSetOutcome::Applied),
            Ok(GuardedMutationOutcome::Skipped) => Ok(CompareAndSetOutcome::Skipped),
            Err(error) => self.reconcile_global_option_cas(mutation, error),
        }
    }

    fn reconcile_global_option_cas(
        &self,
        mutation: GlobalOptionCas<'_>,
        error: AppError,
    ) -> AppResult<CompareAndSetOutcome> {
        let observed = match self.show_options(&[
            (TmuxOptionScope::GlobalSession, mutation.option),
            (TmuxOptionScope::Server, mutation.revision_option),
            (TmuxOptionScope::Server, mutation.operation_option),
        ]) {
            Ok(observed) => observed,
            Err(reconcile_error) => {
                return Ok(CompareAndSetOutcome::Unknown(AppError::Render(format!(
                    "global option CAS failed ambiguously: {error}; reconciliation failed: {reconcile_error}"
                ))));
            }
        };
        let [value, revision, operation] = observed.as_slice() else {
            return Ok(CompareAndSetOutcome::Unknown(error));
        };
        if value == mutation.next_value
            && revision == mutation.next_revision
            && operation == mutation.operation_token
        {
            return Ok(CompareAndSetOutcome::Applied);
        }
        if value == mutation.expected_value && revision == mutation.expected_revision {
            return Err(error);
        }
        Ok(CompareAndSetOutcome::Unknown(error))
    }

    /**
     * Reads explicitly scoped options in one tmux invocation. Marker-delimited
     * `show -gqv`/`show -sqv` sections preserve empty, spaced, and tabbed values
     * without falling back to the current session's effective option lookup.
     */
    pub fn show_options(&self, options: &[(TmuxOptionScope, &str)]) -> AppResult<Vec<String>> {
        let output = self.tmux_output(queue_argv(option_read_commands(options)))?;
        parse_options_output(&output, options.len())
    }

    /**
     * An optional session-state publication runs ahead of the claim guard in the
     * same queue, so a skipped claim still publishes. Callers treat it as
     * attempted whatever the outcome and never publish it again.
     */
    pub fn claim_scheduler_task(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        claim: &SchedulerClaimMutation<'_>,
        publish: Option<&SessionStatesPublish>,
    ) -> AppResult<GuardedMutationOutcome> {
        let now = claim.now_seconds.to_string();
        let command_list = queue_string(&[
            command(&["set", "-g", claim.last_attempt_option, &now]),
            command(&["set", "-s", claim.state_option, claim.claimed_state]),
            marker(SCHEDULER_APPLIED_MARK),
        ]);
        self.guarded_mutation(publish, guards, command_list)
    }

    /**
     * Reads options in one queue only while the guards hold; `None` means a guard
     * no longer matched. Unlike any option write, a read redraws no client.
     */
    pub fn read_guarded_options(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        options: &[(TmuxOptionScope, &str)],
    ) -> AppResult<Option<Vec<String>>> {
        let mut commands = vec![marker(SCHEDULER_APPLIED_MARK)];
        commands.extend(option_read_commands(options));
        let output = self.tmux_output(option_guarded_command_args(
            guards,
            queue_string(&commands),
            marker_command(SCHEDULER_SKIPPED_MARK),
        ))?;
        match parse_guarded_options_output(&output, options.len())? {
            (GuardedMutationOutcome::Applied, values) => Ok(Some(values)),
            (GuardedMutationOutcome::Skipped, _) => Ok(None),
        }
    }

    /**
     * Publishes session states in a queue of its own, for owned ticks whose
     * publication no mutation queue carried.
     */
    pub fn publish_session_states(&self, publish: &SessionStatesPublish) -> AppResult<()> {
        self.tmux_status(session_states_publish_args(publish))
    }

    /**
     * A timeout after the completion remains ambiguous: callers must not retry,
     * and the next tick observes either state. The optional publication follows
     * the `claim_scheduler_task` contract.
     */
    pub fn finish_scheduler_task(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        global_sets: &[(&str, &str)],
        completion: &SchedulerCompletionMutation<'_>,
        publish: Option<&SessionStatesPublish>,
    ) -> AppResult<GuardedMutationOutcome> {
        let now = completion.now_seconds.to_string();
        let mut commands = global_sets
            .iter()
            .map(|(name, value)| command(&["set", "-g", name, value]))
            .collect::<Vec<_>>();
        commands.push(command(&[
            "set",
            "-g",
            completion.last_complete_option,
            &now,
        ]));
        // The state is the completion witness and must be the final mutation.
        commands.push(command(&[
            "set",
            "-s",
            completion.state_option,
            completion.completed_state,
        ]));
        commands.push(marker(SCHEDULER_APPLIED_MARK));
        self.guarded_mutation(publish, guards, queue_string(&commands))
    }

    pub fn record_scheduler_outcome(
        &self,
        guards: &[TmuxOptionGuard<'_>],
        outcome_option: &str,
        outcome: &str,
    ) -> AppResult<GuardedMutationOutcome> {
        let command_list = queue_string(&[
            command(&["set", "-g", outcome_option, outcome]),
            marker(SCHEDULER_APPLIED_MARK),
        ]);
        self.guarded_mutation(None, guards, command_list)
    }

    pub fn display_message(&self, message: &str) -> AppResult<()> {
        self.tmux_status(command(&["display-message", message]))
    }

    fn render_guarded_mutation(
        &self,
        expected_revision: u64,
        command_list: &str,
        guards: &[TmuxOptionGuard<'_>],
        refresh_status: bool,
    ) -> AppResult<GuardedMutationOutcome> {
        let output = self.tmux_output(nested_render_guard_args(
            expected_revision,
            command_list,
            guards,
            refresh_status,
        ))?;
        match output.as_str() {
            RENDER_APPLIED_MARK => Ok(GuardedMutationOutcome::Applied),
            RENDER_SKIPPED_MARK => Ok(GuardedMutationOutcome::Skipped),
            value => Err(AppError::TmuxParse(format!(
                "unexpected render mutation result: {value}"
            ))),
        }
    }

    fn guarded_mutation(
        &self,
        publish: Option<&SessionStatesPublish>,
        guards: &[TmuxOptionGuard<'_>],
        command_list: String,
    ) -> AppResult<GuardedMutationOutcome> {
        let output = self.tmux_output(with_session_states_publish(
            publish,
            option_guarded_command_args(
                guards,
                command_list,
                marker_command(SCHEDULER_SKIPPED_MARK),
            ),
        ))?;
        match output.trim() {
            SCHEDULER_APPLIED_MARK => Ok(GuardedMutationOutcome::Applied),
            SCHEDULER_SKIPPED_MARK => Ok(GuardedMutationOutcome::Skipped),
            value => Err(AppError::TmuxParse(format!(
                "unexpected scheduler mutation result: {value}"
            ))),
        }
    }

    fn tmux_output(&self, args: Vec<String>) -> AppResult<String> {
        let output = output_with_timeout("tmux", &args, TMUX_COMMAND_TIMEOUT)?;
        if !output.status.success() {
            return Err(AppError::TmuxCommand {
                command: format!("tmux {}", args.join(" ")),
                stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            });
        }
        Ok(String::from_utf8_lossy(&output.stdout)
            .trim_end_matches('\n')
            .to_string())
    }

    fn tmux_status(&self, args: Vec<String>) -> AppResult<()> {
        self.tmux_output(args).map(drop)
    }
}

fn command(args: &[&str]) -> Command {
    args.iter().map(|arg| (*arg).to_string()).collect()
}

fn marker(text: &str) -> Command {
    command(&["display-message", "-p", text])
}

fn marker_command(text: &str) -> String {
    tmux_command_string(&marker(text))
}

/// The argv of one tmux invocation that runs `commands` as a queue.
fn queue_argv(commands: Vec<Command>) -> Vec<String> {
    let mut argv = Vec::new();
    for command in commands {
        if !argv.is_empty() {
            argv.push(";".to_string());
        }
        argv.extend(command);
    }
    argv
}

/// The same queue as one command list, for a branch of a guarding `if-shell`.
fn queue_string(commands: &[Command]) -> String {
    commands
        .iter()
        .map(|command| tmux_command_string(command))
        .collect::<Vec<_>>()
        .join("; ")
}

fn snapshot_commands(
    render_revision: Option<u64>,
    options: &[(TmuxOptionScope, &str)],
) -> Vec<Command> {
    let mut commands = Vec::new();
    if let Some(revision) = render_revision {
        commands.push(command(&[
            "set",
            "-s",
            RENDER_REVISION_OPTION,
            &revision.to_string(),
        ]));
    }
    commands.push(marker(&format!(
        "{CONTEXT_MARK}{FIELD_SEP}#{{client_width}}{FIELD_SEP}#{{session_id}}{FIELD_SEP}#{{session_name}}{FIELD_SEP}#{{host}}"
    )));
    commands.extend(option_read_commands(options));
    commands.push(marker(SESSIONS_MARK));
    commands.push(command(&[
        "list-sessions",
        "-F",
        &format!(
            "#{{session_id}}\t#{{session_name}}\t#{{status}}\t#{{@GHC_SL_LAYOUT}}\t#{{status-left-length}}\t#{{status-right-length}}\t#{{{STATUS_FORMAT_0_OPTION}}}\t#{{{STATUS_FORMAT_1_OPTION}}}\t#{{{SESSION_RENDER_KEY_OPTION}}}\t{}",
            SESSION_CACHE_OPTIONS.map(cache_witness_format).join("\t")
        ),
    ]));
    commands.push(marker(CLIENTS_MARK));
    commands.push(command(&[
        "list-clients",
        "-F",
        "#{session_id}\t#{client_width}",
    ]));
    commands
}

fn session_navigation_commands() -> Vec<Command> {
    let mut commands = vec![marker(&format!(
        "{NAVIGATION_MARK}{FIELD_SEP}#{{session_id}}{FIELD_SEP}#{{session_name}}"
    ))];
    commands.extend(option_read_commands(&[
        (TmuxOptionScope::GlobalSession, "@GHC_SL_SESSION_ORDER"),
        (TmuxOptionScope::Server, "@GHC_SL_SESSION_ORDER_REV"),
    ]));
    commands.push(marker(SESSIONS_MARK));
    commands.push(command(&[
        "list-sessions",
        "-F",
        "#{session_id}\t#{session_name}",
    ]));
    commands
}

fn option_read_commands(options: &[(TmuxOptionScope, &str)]) -> Vec<Command> {
    let mut commands = vec![marker(OPTIONS_MARK)];
    for (index, (scope, name)) in options.iter().enumerate() {
        commands.push(marker(&option_value_mark(index)));
        commands.push(command(&["show", scope.show_value_flag(), name]));
    }
    commands.push(marker(OPTIONS_END_MARK));
    commands
}

fn option_value_mark(index: usize) -> String {
    format!("{OPTION_VALUE_MARK_PREFIX}{index}__")
}

fn cache_witness_format(option: &str) -> String {
    /*
     * Column trimming is bounded only after the marker is known to be ASCII.
     * Invalid cache data becomes a missing witness so reconcile can repair it
     * without transporting zero-width styles or combining-character payloads.
     * An explicit alphabet keeps the guard independent of locale collation.
     */
    let payload_bytes = CACHE_WITNESS_BYTES - "#{?0,,}".len();
    let pattern = format_literal(&format!(
        r"^#\{{\?0,[0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz:]{{{payload_bytes}}},\}}"
    ));
    format!("#{{?#{{m/r:{pattern},#{{{option}}}}},#{{={CACHE_WITNESS_BYTES}:{option}}},}}")
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
    refresh_status: bool,
) -> Vec<String> {
    let mut applied_commands = vec![command_list.to_string()];
    if refresh_status {
        applied_commands.push(tmux_command_string(&[
            "if-shell",
            "-F",
            "#{!=:#{client_name},}",
            &tmux_command_string(&["refresh-client", "-S"]),
            "",
        ]));
    }
    applied_commands.push(marker_command(RENDER_APPLIED_MARK));
    let render_guard = guarded_command_args(
        RENDER_REVISION_OPTION,
        expected_revision,
        applied_commands.join("; "),
    );
    option_guarded_command_args(
        guards,
        tmux_command_string(&render_guard),
        marker_command(RENDER_SKIPPED_MARK),
    )
}

fn guarded_command_args(option: &str, expected_value: u64, command_list: String) -> Vec<String> {
    vec![
        "if-shell".to_string(),
        "-F".to_string(),
        format!("#{{==:#{{{option}}},{expected_value}}}"),
        command_list,
        marker_command(RENDER_SKIPPED_MARK),
    ]
}

fn option_guarded_command_args(
    guards: &[TmuxOptionGuard<'_>],
    command_list: String,
    false_command: String,
) -> Vec<String> {
    vec![
        "if-shell".to_string(),
        "-F".to_string(),
        combined_guard_format(guards),
        command_list,
        false_command,
    ]
}

/*
 * Mirrors the lifecycle guard of every session-state consumer: an inactive
 * scheduler or a non-status02 mode samples an empty membership.
 */
const SESSION_STATES_ENABLED_FORMAT: &str =
    "#{&&:#{==:#{@GHC_SL_SCHED_ACTIVE},1},#{||:#{==:#{@GHC_SL_MODE},02},#{==:#{@GHC_SL_MODE},12}}}";

/**
 * Arms this sample's expiry, clears the option, then samples membership. The
 * expiry clears only a value still carrying this sample's prefix. `run-shell`
 * expands its command once when scheduled, so doubled hashes leave the token
 * comparison to the delayed `if-shell`. Clearing first makes a malformed
 * expansion degrade to no marker.
 */
fn session_states_publish_args(publish: &SessionStatesPublish) -> Vec<String> {
    let prefix = &publish.sample_prefix;
    let stale_clear = format!(
        "if-shell -F '##{{m:{prefix}*,##{{{SESSION_STATES_OPTION}}}}}' 'set-option -s {SESSION_STATES_OPTION} \"\"'"
    );
    let sample =
        format!("#{{?{SESSION_STATES_ENABLED_FORMAT},{prefix}#{{E:@GHC_SESSION_STATES_FMT}},}}");
    [
        "run-shell",
        "-bC",
        "-d",
        &publish.ttl_seconds,
        &stale_clear,
        ";",
        "set-option",
        "-s",
        SESSION_STATES_OPTION,
        "",
        ";",
        "set-option",
        "-sF",
        SESSION_STATES_OPTION,
        &sample,
    ]
    .into_iter()
    .map(str::to_string)
    .collect()
}

fn with_session_states_publish(
    publish: Option<&SessionStatesPublish>,
    args: Vec<String>,
) -> Vec<String> {
    match publish {
        Some(publish) => {
            let mut prefixed = session_states_publish_args(publish);
            prefixed.push(";".to_string());
            prefixed.extend(args);
            prefixed
        }
        None => args,
    }
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

fn parse_snapshot_output(
    output: &str,
    options: &[(TmuxOptionScope, &str)],
) -> AppResult<TmuxSnapshot> {
    let mut lines = output.lines().peekable();
    let context_line = lines
        .next()
        .ok_or_else(|| AppError::TmuxParse("missing context section".to_string()))?;
    let (width, current_session_name, host) = parse_context_line(context_line)?;

    let option_values = parse_option_values(&mut lines, options.len())?;
    let options = options
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
        host,
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
        .and_then(|fields| fields.split_once(FIELD_SEP))
        .filter(|(id, _)| !id.is_empty())
        .ok_or_else(|| AppError::TmuxParse("invalid navigation context".to_string()))?
        .1
        .to_string();
    let mut option_values = parse_option_values(&mut lines, 2)?.into_iter();
    let order_value = option_values.next().unwrap_or_default();
    let order_revision = option_values.next().unwrap_or_default();
    expect_marker(lines.next(), SESSIONS_MARK)?;
    let sessions = lines.filter_map(parse_navigation_session_line).collect();
    Ok(SessionNavigationSnapshot {
        current_session_name,
        sessions,
        order_value,
        order_revision,
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
    let status = fields.next().unwrap_or_default().to_string();
    let layout_key = fields.next().unwrap_or_default().to_string();
    let left_length = fields.next().unwrap_or_default().to_string();
    let right_length = fields.next().unwrap_or_default().to_string();
    let format_0 = fields.next().unwrap_or_default().to_string();
    let format_1 = fields.next().unwrap_or_default().to_string();
    let render_key = fields.next().unwrap_or_default().to_string();
    let cache_witnesses = std::array::from_fn(|_| fields.next().unwrap_or_default().to_string());

    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        status,
        layout_key,
        left_length,
        right_length,
        format_0,
        format_1,
        render_key,
        cache_witnesses,
    })
}

fn parse_navigation_session_line(line: &str) -> Option<SessionInfo> {
    let (id, name) = line.split_once('\t')?;
    Some(SessionInfo {
        id: id.to_string(),
        name: name.to_string(),
        ..SessionInfo::default()
    })
}

fn parse_client_line(line: &str) -> Option<(String, usize)> {
    let mut fields = line.split('\t');
    let session_id = fields.next()?.to_string();
    let width = fields.next()?.parse::<usize>().ok()?;
    Some((session_id, width))
}

fn parse_context_line(context_line: &str) -> AppResult<(usize, String, String)> {
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
    // tmux accepts `new-session -s ''`, so only the id proves a resolved session.
    if fields.next().unwrap_or_default().is_empty() {
        return Err(AppError::TmuxParse(
            "current session is unavailable".to_string(),
        ));
    }
    let current_session_name = fields.next().unwrap_or_default().to_string();
    let host = fields.next().unwrap_or_default().to_string();

    Ok((width, current_session_name, host))
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
const RENDER_APPLIED_MARK: &str = "__GHC_RENDER_APPLIED__";
const RENDER_SKIPPED_MARK: &str = "__GHC_RENDER_SKIPPED__";
const SCHEDULER_APPLIED_MARK: &str = "__GHC_SCHEDULER_APPLIED__";
const SCHEDULER_SKIPPED_MARK: &str = "__GHC_SCHEDULER_SKIPPED__";

/*
 * Render/apply hot path: only values consumed by context resolution, composition,
 * commit planning, and lifecycle fencing. Metric payload/health state remains
 * indirect in templates and belongs to diagnostic snapshots only.
 */
const RENDER_SNAPSHOT_OPTIONS: &[(TmuxOptionScope, &str)] = &[
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
    (TmuxOptionScope::Server, SCHEDULER_GENERATION_OPTION),
];

// Read-only diagnostics add the scheduler and metric state dump-state reports.
const DIAGNOSTIC_EXTRA_OPTIONS: &[(TmuxOptionScope, &str)] = &[
    (TmuxOptionScope::GlobalSession, "@GHC_SL_NET_IFACE"),
    (TmuxOptionScope::Server, SCHEDULER_ACTIVE_OPTION),
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
];

fn diagnostic_snapshot_options() -> Vec<(TmuxOptionScope, &'static str)> {
    [RENDER_SNAPSHOT_OPTIONS, DIAGNOSTIC_EXTRA_OPTIONS].concat()
}

#[cfg(test)]
mod tests {
    use super::{
        CONTEXT_MARK, FIELD_SEP, GuardedMutationOutcome, NAVIGATION_MARK, OPTIONS_END_MARK,
        OPTIONS_MARK, RENDER_APPLIED_MARK, RENDER_SKIPPED_MARK, RENDER_SNAPSHOT_OPTIONS,
        SCHEDULER_APPLIED_MARK, SCHEDULER_SKIPPED_MARK, SESSIONS_MARK, TmuxOptionGuard,
        TmuxOptionScope, cache_witness_format, combined_guard_format, diagnostic_snapshot_options,
        format_literal, marker_command, nested_render_guard_args, option_guarded_command_args,
        option_read_commands, option_value_mark, parse_client_line, parse_guarded_options_output,
        parse_options_output, parse_session_line, parse_session_navigation_output,
        parse_snapshot_output, queue_string, serialized_plan_chunks, session_states_publish_args,
        snapshot_commands, with_session_states_publish,
    };
    use crate::commit::{TmuxCommand, TmuxCommandPlan};
    use crate::config::RENDER_REVISION_OPTION;
    use crate::scheduler::SessionStatesPublish;

    const CLIENTS_MARK: &str = super::CLIENTS_MARK;

    #[test]
    fn session_states_publish_matches_the_driver_command_queue() {
        let publish = SessionStatesPublish::from_transport("314:5120:77:", "12").unwrap();
        assert_eq!(
            session_states_publish_args(&publish),
            [
                "run-shell",
                "-bC",
                "-d",
                "12",
                "if-shell -F '##{m:314:5120:77:*,##{@GHC_SL_SESSION_STATES}}' 'set-option -s @GHC_SL_SESSION_STATES \"\"'",
                ";",
                "set-option",
                "-s",
                "@GHC_SL_SESSION_STATES",
                "",
                ";",
                "set-option",
                "-sF",
                "@GHC_SL_SESSION_STATES",
                "#{?#{&&:#{==:#{@GHC_SL_SCHED_ACTIVE},1},#{||:#{==:#{@GHC_SL_MODE},02},#{==:#{@GHC_SL_MODE},12}}},314:5120:77:#{E:@GHC_SESSION_STATES_FMT},}",
            ]
        );
    }

    #[test]
    fn session_states_publish_precedes_the_guarded_queue() {
        let publish = SessionStatesPublish::from_transport("1:2:3:", "12").unwrap();
        let guarded = vec![
            "if-shell".to_string(),
            "-F".to_string(),
            "guard".to_string(),
        ];
        let mut expected = session_states_publish_args(&publish);
        expected.push(";".to_string());
        expected.extend(guarded.clone());

        assert_eq!(
            with_session_states_publish(Some(&publish), guarded.clone()),
            expected
        );
        assert_eq!(with_session_states_publish(None, guarded.clone()), guarded);
    }

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
        let diagnostic_options = diagnostic_snapshot_options();
        let option_values = vec![""; diagnostic_options.len()];
        let options = option_section(&option_values);
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}$1{FIELD_SEP}yui{FIELD_SEP}host
{options}
{SESSIONS_MARK}
$1	yui	on	02:wide	64	84
$2	dev	2	02:narrow	120	120
{CLIENTS_MARK}
$1	200
$2	120
$2	90"
        );

        let snapshot = parse_snapshot_output(&output, &diagnostic_options).unwrap();
        assert_eq!(snapshot.width, 120);
        assert_eq!(snapshot.status, "on");
        assert_eq!(snapshot.current_session_name, "yui");
        assert_eq!(snapshot.host, "host");
        assert_eq!(snapshot.sessions.len(), 2);
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
    fn snapshot_accepts_an_unnamed_current_session() {
        let diagnostic_options = diagnostic_snapshot_options();
        let option_values = vec![""; diagnostic_options.len()];
        let options = option_section(&option_values);
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}$2{FIELD_SEP}{FIELD_SEP}host
{options}
{SESSIONS_MARK}
$1	yui	on
$2		2
{CLIENTS_MARK}
$2	120"
        );

        let snapshot = parse_snapshot_output(&output, &diagnostic_options).unwrap();
        assert_eq!(snapshot.current_session_name, "");
        assert_eq!(snapshot.status, "2");
    }

    #[test]
    fn snapshot_rejects_an_unresolved_session() {
        let diagnostic_options = diagnostic_snapshot_options();
        let option_values = vec![""; diagnostic_options.len()];
        let options = option_section(&option_values);
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}120{FIELD_SEP}{FIELD_SEP}{FIELD_SEP}host
{options}
{SESSIONS_MARK}
{CLIENTS_MARK}"
        );

        assert!(parse_snapshot_output(&output, &diagnostic_options).is_err());
    }

    #[test]
    fn parses_session_line_fields_in_transport_order() {
        let session = parse_session_line(
            "$1\tmain\ton\t02:wide\t64\t84\tfmt0\tfmt1\t02:wide:v1:abcd\tw0\tw1\tw2\tw3",
        )
        .unwrap();
        assert_eq!(session.id, "$1");
        assert_eq!(session.name, "main");
        assert_eq!(session.status, "on");
        assert_eq!(session.layout_key, "02:wide");
        assert_eq!(session.format_0, "fmt0");
        assert_eq!(session.format_1, "fmt1");
        assert_eq!(session.render_key, "02:wide:v1:abcd");
        assert_eq!(session.cache_witnesses, ["w0", "w1", "w2", "w3"]);

        let partial = parse_session_line("$2\tdev").unwrap();
        assert_eq!(partial.status, "");
        assert_eq!(partial.layout_key, "");
    }

    #[test]
    fn parses_minimal_session_navigation_snapshot() {
        let options = option_section(&["$2\t$1", "7"]);
        let output = format!(
            "{NAVIGATION_MARK}{FIELD_SEP}$1{FIELD_SEP}main\n{options}\n{SESSIONS_MARK}\n$1\tmain\n$2\twork"
        );

        let snapshot = parse_session_navigation_output(&output).unwrap();
        assert_eq!(snapshot.current_session_name, "main");
        assert_eq!(snapshot.order_value, "$2\t$1");
        assert_eq!(snapshot.order_revision, "7");
        assert_eq!(snapshot.sessions.len(), 2);
        assert_eq!(snapshot.sessions[1].name, "work");
    }

    #[test]
    fn session_navigation_accepts_an_unnamed_current_session() {
        let options = option_section(&["", ""]);
        let output =
            format!("{NAVIGATION_MARK}{FIELD_SEP}$2{FIELD_SEP}\n{options}\n{SESSIONS_MARK}\n$2\t");

        let snapshot = parse_session_navigation_output(&output).unwrap();
        assert_eq!(snapshot.current_session_name, "");
        assert_eq!(snapshot.sessions[0].id, "$2");
    }

    #[test]
    fn session_navigation_rejects_an_unresolved_session() {
        let options = option_section(&["", ""]);
        let output = format!("{NAVIGATION_MARK}{FIELD_SEP}{FIELD_SEP}\n{options}\n{SESSIONS_MARK}");

        assert!(parse_session_navigation_output(&output).is_err());
    }

    #[test]
    fn render_snapshot_starts_revision_in_the_same_tmux_queue() {
        let commands = snapshot_commands(Some(42), RENDER_SNAPSHOT_OPTIONS);
        assert_eq!(commands[0], ["set", "-s", RENDER_REVISION_OPTION, "42"]);
        assert!(commands[1][2].starts_with(CONTEXT_MARK));
    }

    #[test]
    fn render_snapshot_excludes_diagnostic_metric_and_health_options() {
        let names = RENDER_SNAPSHOT_OPTIONS
            .iter()
            .map(|(_, name)| *name)
            .collect::<Vec<_>>();

        assert_eq!(
            names,
            [
                "@GHC_SL_MODE",
                "@GHC_SL_ROWS",
                "@GHC_SL_STATUS02_LEFT",
                "@GHC_SL_STATUS02_RIGHT",
                "@GHC_SL_STATUS02_SESSION_FORMAT",
                "@GHC_SL_STATUS02_CURRENT_FORMAT",
                "status-left",
                "status-right",
                "status-position",
                "status-justify",
                "status-interval",
                "status-format[0]",
                "status-format[1]",
                "@GHC_SL_SESSION_ORDER",
                "@GHC_SL_SCHED_GEN",
            ]
        );
        assert_eq!(diagnostic_snapshot_options().len(), 34);
        for diagnostic_only in [
            "@GHC_SL_NET_IFACE",
            "@GHC_SL_METRIC_SCHED",
            "@GHC_SL_CPU_SAMPLE",
            "@GHC_SL_METRIC_LAST_ERR",
            "@GHC_SL_HEARTBEAT_LAST_EXEC_OUTCOME",
        ] {
            assert!(!names.contains(&diagnostic_only));
        }
    }

    #[test]
    fn guarded_render_snapshot_checks_lifecycle_before_replacing_revision() {
        let args = option_guarded_command_args(
            &[TmuxOptionGuard {
                option: "@GHC_SL_SCHED_ACTIVE",
                expected: "1",
            }],
            queue_string(&snapshot_commands(Some(42), RENDER_SNAPSHOT_OPTIONS)),
            marker_command(RENDER_SKIPPED_MARK),
        );

        assert_eq!(args[0], "if-shell");
        assert_eq!(args[2], "#{==:#{@GHC_SL_SCHED_ACTIVE},#{l:1}}");
        assert!(args[3].contains("@GHC_SL_RENDER_REV"));
        assert!(args[3].contains("__GHC_STATUS_CONTEXT__"));
        assert!(args[4].contains("__GHC_RENDER_SKIPPED__"));
    }

    #[test]
    fn cache_witness_format_requires_a_fixed_ascii_prefix() {
        assert_eq!(
            cache_witness_format("@CACHE"),
            "#{?#{m/r:#{l:^##\\{\\?0,[0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz:]{19#},\\#}},#{@CACHE}},#{=26:@CACHE},}"
        );
    }

    #[test]
    fn scheduler_generation_guard_wraps_each_render_guard() {
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
                option: "@GHC_SL_SCHED_GEN",
                expected: "7",
            }],
            false,
        );

        assert_eq!(args[2], "#{==:#{@GHC_SL_SCHED_GEN},#{l:7}}");
        assert!(args[3].contains(RENDER_REVISION_OPTION));
        assert!(args[3].contains("@VALUE"));
    }

    #[test]
    fn folded_status_refresh_is_guarded_and_precedes_the_applied_marker() {
        let args = nested_render_guard_args(
            9,
            "set -g @VALUE new",
            &[TmuxOptionGuard {
                option: "@GHC_SL_SCHED_ACTIVE",
                expected: "1",
            }],
            true,
        );
        let applied_branch = &args[3];
        let refresh = applied_branch.find("refresh-client").unwrap();
        let marker = applied_branch.find(RENDER_APPLIED_MARK).unwrap();

        assert!(applied_branch.contains("#{!=:#{client_name},}"));
        assert!(refresh < marker);
        assert!(args[4].contains(RENDER_SKIPPED_MARK));
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
    fn configured_chunks_leave_room_for_nested_guard_quoting() {
        const TMUX_CLIENT_COMMAND_LIMIT: usize = 16 * 1024;
        let command = TmuxCommand::SetGlobal {
            name: "@CACHE".to_string(),
            value: "x".repeat(4 * 1024),
        };
        let plan = TmuxCommandPlan {
            commands: vec![command; 4],
        };
        let guards = [TmuxOptionGuard {
            option: "@ACTIVE",
            expected: "1",
        }];

        let chunks = serialized_plan_chunks(&plan, super::MAX_PLAN_CHUNK_BYTES);

        assert!(chunks.len() > 1);
        for chunk in chunks {
            let args = nested_render_guard_args(42, &chunk.command_list, &guards, false);
            let command_bytes = "tmux".len()
                + 1
                + args
                    .iter()
                    .map(|argument| argument.len() + 1)
                    .sum::<usize>();
            assert!(
                command_bytes < TMUX_CLIENT_COMMAND_LIMIT,
                "nested command grew to {command_bytes} bytes"
            );
        }
    }

    #[test]
    fn parses_client_line_reads_session_and_width() {
        assert_eq!(parse_client_line("$3\t180"), Some(("$3".to_string(), 180)));
        assert_eq!(parse_client_line("$3\tnope"), None);
        assert_eq!(parse_client_line("$3"), None);
    }

    #[test]
    fn parses_current_status_and_tabbed_cache_options() {
        let diagnostic_options = diagnostic_snapshot_options();
        let mut option_values = vec![""; diagnostic_options.len()];
        option_values[0] = "02";
        let network_index = diagnostic_options
            .iter()
            .position(|(_, name)| *name == "@GHC_SL_NET_SAMPLE")
            .unwrap();
        option_values[network_index] = "1	2	3	4	5";
        let options = option_section(&option_values);
        let output = format!(
            "{CONTEXT_MARK}{FIELD_SEP}200{FIELD_SEP}$1{FIELD_SEP}yui{FIELD_SEP}host
{options}
{SESSIONS_MARK}
$1	yui	off
{CLIENTS_MARK}
$1	200"
        );

        let snapshot = parse_snapshot_output(&output, &diagnostic_options).unwrap();
        assert_eq!(snapshot.status, "off");
        assert_eq!(snapshot.mode, "02");
        assert_eq!(
            snapshot.options.get("@GHC_SL_NET_SAMPLE").unwrap(),
            "1	2	3	4	5"
        );
    }

    #[test]
    fn option_commands_use_explicit_global_and_server_scopes() {
        let commands = option_read_commands(&[
            (TmuxOptionScope::GlobalSession, "@GLOBAL"),
            (TmuxOptionScope::Server, "@SERVER"),
        ]);

        assert!(commands.contains(&vec![
            "show".to_string(),
            "-gqv".to_string(),
            "@GLOBAL".to_string()
        ]));
        assert!(commands.contains(&vec![
            "show".to_string(),
            "-sqv".to_string(),
            "@SERVER".to_string()
        ]));
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
}
