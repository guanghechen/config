use std::rc::Rc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

use crate::commit::{self, TmuxCommandPlan};
use crate::composer::{render_cache_key, render_status02};
use crate::config::{
    CPU_SAMPLE_STATE_OPTION, MEMORY_SAMPLE_STATE_OPTION, METRIC_ERROR_COUNT_OPTION,
    NETWORK_SAMPLE_STATE_OPTION, SCHEDULER_ACTIVE_OPTION, SCHEDULER_GENERATION_OPTION,
};
use crate::error::{AppError, AppResult};
use crate::introspect::{metric_health_state, metric_sample_states, scheduler_state_lines};
use crate::layout::{resolve_layout, resolve_session_layouts, rows_override};
use crate::metric::publish::{MetricInputs, collect_sample};
use crate::metric::{METRICS_SUPPORTED, NET_INTERFACE_OPTION};
use crate::model::{
    RenderContext, RenderEvent, SessionGroupView, SessionRenderedStatus, TmuxSnapshot,
};
use crate::observability::{duration_ms, trace_enabled, trace_line};
use crate::process::{OperationDeadline, output_with_timeout};
use crate::scheduler::{
    ClaimPlan, SchedulerSnapshot, SchedulerTask, SessionStatesPublish, plan_claim,
};
use crate::session::{
    FocusTarget, MoveDirection, SESSION_ORDER_OPERATION_OPTION, SESSION_ORDER_OPTION,
    SESSION_ORDER_REVISION_OPTION, SwapOutcome, focus_target, ordered_group,
    ordered_group_for_session, ordered_group_from_snapshot, swap_current,
};
use crate::status_length::{status_left_length, status_right_length};
use crate::tmux::{
    CompareAndSetOutcome, GlobalOptionCas, GuardedMutationOutcome, SchedulerClaimMutation,
    SchedulerCompletionMutation, TmuxAdapter, TmuxOptionGuard, TmuxOptionScope,
};
use crate::util::time::unix_timestamp_seconds;
use crate::util::width::display_width;

pub struct StatusRuntime {
    tmux: TmuxAdapter,
}

const MAX_SESSION_SWAP_ATTEMPTS: usize = 3;
const SESSION_SWAP_RENDER_TIMEOUT: Duration = Duration::from_secs(10);

const METRIC_INPUT_OPTIONS: &[(TmuxOptionScope, &str)] = &[
    (TmuxOptionScope::GlobalSession, CPU_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, MEMORY_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, NETWORK_SAMPLE_STATE_OPTION),
    (TmuxOptionScope::GlobalSession, NET_INTERFACE_OPTION),
    (TmuxOptionScope::GlobalSession, METRIC_ERROR_COUNT_OPTION),
];

#[derive(Clone, Copy)]
enum ApplyMode<'a> {
    Standard,
    // The loader's bootstrap, fenced to the generation it just wrote.
    Bootstrap {
        generation: &'a str,
    },
    Scheduler {
        claim: &'a ClaimPlan,
        generation: &'a str,
        deadline: &'a OperationDeadline,
    },
}

impl<'a> ApplyMode<'a> {
    /*
     * Guards for the snapshot read. A standard render learns the lifecycle
     * generation from that snapshot and adds it to its commit guards only.
     */
    fn snapshot_guards(self) -> Vec<TmuxOptionGuard<'a>> {
        match self {
            Self::Standard => vec![ACTIVE_LIFECYCLE_GUARD],
            Self::Bootstrap { generation } => vec![
                TmuxOptionGuard {
                    option: SCHEDULER_ACTIVE_OPTION,
                    expected: "0",
                },
                TmuxOptionGuard {
                    option: SCHEDULER_GENERATION_OPTION,
                    expected: generation,
                },
            ],
            Self::Scheduler {
                claim, generation, ..
            } => scheduler_guards(claim, generation, &claim.claimed_state).to_vec(),
        }
    }

    fn check_deadline(self, phase: &str) -> AppResult<()> {
        match self {
            Self::Scheduler { deadline, .. } => deadline.check(phase),
            Self::Standard | Self::Bootstrap { .. } => Ok(()),
        }
    }
}

const ACTIVE_LIFECYCLE_GUARD: TmuxOptionGuard<'static> = TmuxOptionGuard {
    option: SCHEDULER_ACTIVE_OPTION,
    expected: "1",
};

impl StatusRuntime {
    pub fn live() -> Self {
        Self {
            tmux: TmuxAdapter::new(),
        }
    }

    pub fn apply(&self, event: RenderEvent) -> AppResult<()> {
        self.apply_inner(event, ApplyMode::Standard).map(|_| ())
    }

    pub fn bootstrap_theme(&self, expected_generation: u64) -> AppResult<()> {
        const MAX_BOOTSTRAP_ATTEMPTS: usize = 3;

        let generation = expected_generation.to_string();
        for _ in 0..MAX_BOOTSTRAP_ATTEMPTS {
            let outcome = self.apply_inner(
                RenderEvent::ThemeLoaded,
                ApplyMode::Bootstrap {
                    generation: &generation,
                },
            )?;
            if outcome == GuardedMutationOutcome::Applied {
                return Ok(());
            }
        }

        Err(AppError::Render(format!(
            "theme bootstrap did not acquire lifecycle generation {expected_generation}"
        )))
    }

    fn apply_inner(
        &self,
        event: RenderEvent,
        mode: ApplyMode<'_>,
    ) -> AppResult<GuardedMutationOutcome> {
        mode.check_deadline("start")?;
        let started = Instant::now();
        let render_revision = next_render_revision();
        let Some(snapshot) = self
            .tmux
            .read_snapshot_for_render(render_revision, &mode.snapshot_guards())?
        else {
            trace_apply(|| {
                format!(
                    "event={} action=lifecycle-skipped total_ms={:.2}",
                    event.as_str(),
                    duration_ms(started.elapsed())
                )
            });
            return Ok(GuardedMutationOutcome::Skipped);
        };
        let lifecycle_generation = lifecycle_generation(&snapshot)?;
        let context_state = context_state_from_snapshot(snapshot);
        mode.check_deadline("read-context")?;
        let context_ms = duration_ms(started.elapsed());

        let render_start = Instant::now();
        let (plan, scope) = match context_state {
            LiveContextState::Inactive(snapshot) => {
                (commit::plan_inactive(&snapshot), "active=false".to_string())
            }
            LiveContextState::Active(context) => {
                let fallback_status =
                    render_status02(&fallback_render_context(&context), METRICS_SUPPORTED);
                let session_statuses = render_session_statuses(&context, METRICS_SUPPORTED);
                mode.check_deadline("render")?;
                let plan = commit::plan(&fallback_status, &session_statuses, &context);
                let scope = format!(
                    "active=true layout={} session_count={}",
                    context.layout.key,
                    context.group.sessions.len()
                );
                (plan, scope)
            }
        };
        let render_ms = duration_ms(render_start.elapsed());

        let commit_start = Instant::now();
        let result = self.commit_plan(&plan, render_revision, mode, &lifecycle_generation);
        trace_apply(|| {
            format!(
                "event={} {scope} plan_commands={} context_ms={context_ms:.2} render_ms={render_ms:.2} commit_ms={:.2} total_ms={:.2}",
                event.as_str(),
                plan.commands.len(),
                duration_ms(commit_start.elapsed()),
                duration_ms(started.elapsed())
            )
        });
        result
    }

    /**
     * Runs due scheduler tasks. An owned session-state publication rides in the
     * first mutation queue the tick executes; an ordinary exit that reached no
     * such queue still attempts it on its own and keeps the task result.
     */
    pub fn scheduler_tick(
        &self,
        snapshot: Option<SchedulerSnapshot>,
        publish: Option<SessionStatesPublish>,
    ) -> AppResult<()> {
        let mut publish = publish;
        let result = self.run_scheduler_tasks(snapshot, &mut publish);
        if let Some(publish) = publish
            && let Err(error) = self.tmux.publish_session_states(&publish)
        {
            trace_apply(|| {
                format!("event=scheduler-tick action=publish-session-states error={error}")
            });
        }
        result
    }

    fn run_scheduler_tasks(
        &self,
        snapshot: Option<SchedulerSnapshot>,
        publish: &mut Option<SessionStatesPublish>,
    ) -> AppResult<()> {
        let snapshot = match snapshot {
            Some(snapshot) => Some(snapshot),
            None => self.read_scheduler_snapshot()?,
        };
        let Some(snapshot) = snapshot else {
            return Ok(());
        };
        let generation = snapshot.generation;
        let now_seconds = unix_timestamp_seconds();
        let mut failures = Vec::new();

        for task in SchedulerTask::ALL {
            if task == SchedulerTask::Metrics && !METRICS_SUPPORTED {
                continue;
            }
            if let Err(error) = self.run_scheduler_task(
                task,
                generation,
                snapshot.state_for(task),
                now_seconds,
                publish,
            ) {
                trace_apply(|| {
                    format!(
                        "event=scheduler-tick task={} action=error error={error}",
                        task.as_str()
                    )
                });
                failures.push(format!("{}:{error}", task.as_str()));
            }
        }

        if failures.is_empty() {
            return Ok(());
        }
        Err(AppError::Render(format!(
            "scheduler tick failed: {}",
            failures.join("; ")
        )))
    }

    fn read_scheduler_snapshot(&self) -> AppResult<Option<SchedulerSnapshot>> {
        let values = self.tmux.show_options(&[
            (TmuxOptionScope::Server, SCHEDULER_ACTIVE_OPTION),
            (TmuxOptionScope::Server, SCHEDULER_GENERATION_OPTION),
            (
                TmuxOptionScope::Server,
                SchedulerTask::Metrics.state_option(),
            ),
            (
                TmuxOptionScope::Server,
                SchedulerTask::Heartbeat.state_option(),
            ),
        ])?;
        if values.first().map(String::as_str) != Some("1") {
            return Ok(None);
        }
        let generation = values
            .get(1)
            .and_then(|value| value.parse::<u64>().ok())
            .ok_or_else(|| AppError::TmuxParse("invalid scheduler generation".to_string()))?;
        Ok(Some(SchedulerSnapshot::from_observed(
            generation,
            values.get(2).cloned().unwrap_or_default(),
            values.get(3).cloned().unwrap_or_default(),
        )))
    }

    fn run_scheduler_task(
        &self,
        task: SchedulerTask,
        generation: u64,
        observed_state: &str,
        now_seconds: u64,
        publish: &mut Option<SessionStatesPublish>,
    ) -> AppResult<()> {
        let Some(claim) = plan_claim(task, generation, observed_state, now_seconds) else {
            return Ok(());
        };
        match task {
            SchedulerTask::Metrics => self.run_scheduled_metrics(&claim, publish),
            SchedulerTask::Heartbeat => self.run_scheduled_heartbeat(&claim, publish),
        }
    }

    /**
     * Metrics never write a claim. Every tmux option write redraws all attached
     * clients and the driver lock already serializes ticks, so the task reads its
     * inputs, samples, then commits `observed -> completed` in one guarded queue.
     * The exact observed-state guard still rejects a concurrent or stale commit,
     * and a tick that stops before committing leaves the task due for the next one.
     */
    fn run_scheduled_metrics(
        &self,
        claim: &ClaimPlan,
        publish: &mut Option<SessionStatesPublish>,
    ) -> AppResult<()> {
        let deadline = claim.deadline();
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, &claim.observed_state);
        let inputs = match self
            .tmux
            .read_guarded_options(&guards, METRIC_INPUT_OPTIONS)
        {
            Ok(Some(inputs)) => inputs,
            Ok(None) => return Ok(()),
            Err(error) => {
                self.record_scheduler_failure(claim, &claim.observed_state, "read", &error);
                return Err(error);
            }
        };
        let result = self.execute_scheduled_metrics(claim, &inputs, &deadline, publish);
        if let Err(error) = &result {
            self.record_scheduler_failure(claim, &claim.observed_state, "execute", error);
        }
        result
    }

    fn run_scheduled_heartbeat(
        &self,
        claim: &ClaimPlan,
        publish: &mut Option<SessionStatesPublish>,
    ) -> AppResult<()> {
        /*
         * Taken before the queue runs: a skipped, failed, or timed-out queue has
         * still attempted the publication, which is never repeated.
         */
        let publish = publish.take();
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, &claim.observed_state);
        let mutation = SchedulerClaimMutation {
            state_option: claim.task.state_option(),
            claimed_state: &claim.claimed_state,
            last_attempt_option: claim.task.last_attempt_option(),
            now_seconds: claim.started_at_seconds,
        };
        let outcome = match self
            .tmux
            .claim_scheduler_task(&guards, &mutation, publish.as_ref())
        {
            Ok(outcome) => outcome,
            Err(error) => {
                self.record_scheduler_failure(claim, &claim.claimed_state, "claim", &error);
                return Err(error);
            }
        };
        if outcome == GuardedMutationOutcome::Skipped {
            return Ok(());
        }

        let result = self.execute_scheduled_heartbeat(claim);
        if let Err(error) = &result {
            self.record_scheduler_failure(claim, &claim.claimed_state, "execute", error);
        }
        result
    }

    fn execute_scheduled_metrics(
        &self,
        claim: &ClaimPlan,
        values: &[String],
        deadline: &OperationDeadline,
        publish: &mut Option<SessionStatesPublish>,
    ) -> AppResult<()> {
        let [
            cpu_state,
            memory_state,
            network_state,
            network_interface,
            error_count,
        ] = values
        else {
            return Err(AppError::TmuxParse(format!(
                "expected {} metric input options, got {}",
                METRIC_INPUT_OPTIONS.len(),
                values.len()
            )));
        };
        deadline.check("sample-metrics")?;
        let sample = collect_sample(&MetricInputs {
            cpu_state,
            memory_state,
            network_state,
            network_interface,
            error_count,
        });
        deadline.check("publish-metrics")?;
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, &claim.observed_state);
        let completed_at = unix_timestamp_seconds();
        let completion_outcome = claim.outcome(completed_at, "complete", "known", "ok");
        let started_at = claim.started_at_seconds.to_string();
        let mut sets = sample
            .sets
            .iter()
            .map(|(name, value)| (*name, value.as_str()))
            .collect::<Vec<_>>();
        sets.push((claim.task.last_attempt_option(), &started_at));
        sets.push((claim.task.last_outcome_option(), &completion_outcome));
        // The commit is the tick's first mutation queue, so it carries the publication.
        let publish = publish.take();
        let outcome = self.tmux.finish_scheduler_task(
            &guards,
            &sets,
            &scheduler_completion(claim, completed_at),
            publish.as_ref(),
        )?;
        trace_apply(|| {
            format!(
                "event=scheduler-tick task=metrics action={} cpu_published={} memory_published={} network_published={} errors={}",
                if outcome == GuardedMutationOutcome::Applied {
                    "complete"
                } else {
                    "stale"
                },
                sample.summary.cpu_published,
                sample.summary.memory_published,
                sample.summary.network_published,
                sample.summary.errors.join(",")
            )
        });
        Ok(())
    }

    fn execute_scheduled_heartbeat(&self, claim: &ClaimPlan) -> AppResult<()> {
        let deadline = claim.deadline();
        let generation = claim.generation.to_string();
        self.apply_inner(
            RenderEvent::Heartbeat,
            ApplyMode::Scheduler {
                claim,
                generation: &generation,
                deadline: &deadline,
            },
        )?;
        deadline.check("complete-heartbeat")?;
        let guards = scheduler_guards(claim, &generation, &claim.claimed_state);
        let completed_at = unix_timestamp_seconds();
        let completion_outcome = claim.outcome(completed_at, "complete", "known", "ok");
        let outcome = self.tmux.finish_scheduler_task(
            &guards,
            &[(claim.task.last_outcome_option(), &completion_outcome)],
            &scheduler_completion(claim, completed_at),
            None,
        )?;
        trace_apply(|| {
            format!(
                "event=scheduler-tick task=heartbeat action={}",
                if outcome == GuardedMutationOutcome::Applied {
                    "complete"
                } else {
                    "stale"
                }
            )
        });
        Ok(())
    }

    /// Records a failure only while the task still holds `expected_state`.
    fn record_scheduler_failure(
        &self,
        claim: &ClaimPlan,
        expected_state: &str,
        phase: &str,
        error: &AppError,
    ) {
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, expected_state);
        let outcome = claim.outcome(
            unix_timestamp_seconds(),
            phase,
            "unknown",
            &error.to_string(),
        );
        if let Err(record_error) =
            self.tmux
                .record_scheduler_outcome(&guards, claim.task.last_outcome_option(), &outcome)
        {
            trace_apply(|| {
                format!(
                    "event=scheduler-outcome task={} action=record-error error={record_error}",
                    claim.task.as_str()
                )
            });
        }
    }

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        let context = self.live_context()?;
        let rendered = render_status02(&context, METRICS_SUPPORTED);
        println!("status-left={}", rendered.status_left.rich_text);
        println!("status-right={}", rendered.status_right.rich_text);
        println!(
            "status-left-length={}",
            status_left_length(
                &rendered,
                context.snapshot.width,
                context.group.sessions.len()
            )
        );
        println!(
            "status-right-length={}",
            status_right_length(&rendered, context.snapshot.width)
        );
        println!(
            "@GHC_SL_STATUS02_SESSION_FORMAT={}",
            rendered.session_right.rich_text
        );
        println!(
            "@GHC_SL_STATUS02_CURRENT_FORMAT={}",
            rendered.current_format.rich_text
        );
        println!("literal.status-left={}", rendered.status_left.literal_text);
        println!(
            "literal.status-right={}",
            rendered.status_right.literal_text
        );
        println!(
            "width.status-left={}",
            display_width(&rendered.status_left.literal_text)
        );
        println!(
            "width.status-right={}",
            display_width(&rendered.status_right.literal_text)
        );
        Ok(())
    }

    pub fn dump_state(&self) -> AppResult<()> {
        let context = self.live_context()?;
        println!("mode={}", context.snapshot.mode);
        println!("status={}", context.snapshot.status);
        println!("width={}", context.snapshot.width);
        println!("current_session={}", context.snapshot.current_session_name);
        println!("group_count={}", context.group.sessions.len());
        println!("layout={}", context.layout.key);
        println!("rows={}", context.layout.rows);
        println!("target_status={}", context.layout.target_status);
        println!("scheduler:");
        for line in scheduler_state_lines(&context.snapshot) {
            println!("  {line}");
        }
        println!("metric_health:");
        println!("  {}", metric_health_state(&context.snapshot).format_line());
        println!("metric_samples:");
        for state in metric_sample_states(&context.snapshot) {
            println!("  {}", state.format_line());
        }
        println!("sessions:");
        for (index, session) in context.group.sessions.iter().enumerate() {
            println!("  {}. {} {}", index + 1, session.id, session.name);
        }
        Ok(())
    }

    pub fn focus_session(&self, target: FocusTarget) -> AppResult<()> {
        let snapshot = self.tmux.read_session_navigation()?;
        let group = ordered_group(
            &snapshot.current_session_name,
            &snapshot.sessions,
            Some(&snapshot.order_value),
        );
        let Some(target_session) =
            focus_target(&group.sessions, &snapshot.current_session_name, target)
        else {
            return self.tmux.display_message(&focus_missing_message(target));
        };

        if target_session.name == snapshot.current_session_name {
            return Ok(());
        }

        self.tmux.switch_client(&target_session.id)
    }

    pub fn swap_session(&self, direction: MoveDirection) -> AppResult<()> {
        for _ in 0..MAX_SESSION_SWAP_ATTEMPTS {
            let snapshot = self.tmux.read_session_navigation()?;
            let group = ordered_group(
                &snapshot.current_session_name,
                &snapshot.sessions,
                Some(&snapshot.order_value),
            );
            let order_value = Some(snapshot.order_value.as_str());
            match swap_current(
                &snapshot.sessions,
                &group.sessions,
                &snapshot.current_session_name,
                order_value,
                direction,
            ) {
                SwapOutcome::Changed(order) => {
                    let next_revision = next_session_order_revision(&snapshot.order_revision);
                    let operation_token = next_session_order_operation_token();
                    let outcome = self.tmux.compare_and_set_global_option(GlobalOptionCas {
                        option: SESSION_ORDER_OPTION,
                        expected_value: &snapshot.order_value,
                        next_value: &order,
                        revision_option: SESSION_ORDER_REVISION_OPTION,
                        expected_revision: &snapshot.order_revision,
                        next_revision: &next_revision,
                        operation_option: SESSION_ORDER_OPERATION_OPTION,
                        operation_token: &operation_token,
                    })?;
                    match outcome {
                        CompareAndSetOutcome::Skipped => continue,
                        CompareAndSetOutcome::Unknown(error) => {
                            if trace_enabled() {
                                trace_line(
                                    "session",
                                    format!("action=swap-outcome-unknown error={error}"),
                                );
                            }
                            let _ = self.tmux.display_message(
                                "Session swap outcome unknown; inspect session order",
                            );
                            return Ok(());
                        }
                        CompareAndSetOutcome::Applied => {}
                    }

                    if let Err(error) = render_session_order_change() {
                        if trace_enabled() {
                            trace_line(
                                "session",
                                format!("action=swap-render-pending error={error}"),
                            );
                        }
                        let _ = self
                            .tmux
                            .display_message("Session order updated; status refresh pending");
                    }
                    return Ok(());
                }
                SwapOutcome::AlreadyFirst => {
                    return self.tmux.display_message("Already first session");
                }
                SwapOutcome::AlreadyLast => {
                    return self.tmux.display_message("Already last session");
                }
                SwapOutcome::CurrentMissing => {
                    return self.tmux.display_message("Current session is not visible");
                }
            }
        }

        self.tmux
            .display_message("Session order changed concurrently; retry")
    }

    fn commit_plan(
        &self,
        plan: &TmuxCommandPlan,
        render_revision: u64,
        mode: ApplyMode<'_>,
        lifecycle_generation: &str,
    ) -> AppResult<GuardedMutationOutcome> {
        let mut guards = mode.snapshot_guards();
        match mode {
            ApplyMode::Standard => guards.push(TmuxOptionGuard {
                option: SCHEDULER_GENERATION_OPTION,
                expected: lifecycle_generation,
            }),
            ApplyMode::Bootstrap { generation } if generation != lifecycle_generation => {
                return Err(AppError::TmuxParse(format!(
                    "theme bootstrap generation drifted: expected {generation}, got {lifecycle_generation}"
                )));
            }
            ApplyMode::Bootstrap { .. } => {}
            ApplyMode::Scheduler { deadline, .. } => {
                deadline.check("commit-render")?;
                return self
                    .tmux
                    .commit_plan(plan, render_revision, &guards, Some(deadline));
            }
        }
        self.tmux.commit_plan(plan, render_revision, &guards, None)
    }

    fn live_context(&self) -> AppResult<RenderContext> {
        let snapshot = self.tmux.read_snapshot()?;
        current_session_context_from_snapshot(snapshot)
            .ok_or_else(|| AppError::Render("status02 layout is not active".to_string()))
    }
}

fn trace_apply(message: impl FnOnce() -> String) {
    if trace_enabled() {
        trace_line("apply", message());
    }
}

fn lifecycle_generation(snapshot: &TmuxSnapshot) -> AppResult<String> {
    let generation = snapshot
        .options
        .get(SCHEDULER_GENERATION_OPTION)
        .filter(|value| value.parse::<u64>().is_ok())
        .ok_or_else(|| AppError::TmuxParse("invalid scheduler generation".to_string()))?;
    Ok(generation.clone())
}

fn scheduler_guards<'a>(
    claim: &'a ClaimPlan,
    generation: &'a str,
    expected_state: &'a str,
) -> [TmuxOptionGuard<'a>; 3] {
    [
        ACTIVE_LIFECYCLE_GUARD,
        TmuxOptionGuard {
            option: SCHEDULER_GENERATION_OPTION,
            expected: generation,
        },
        TmuxOptionGuard {
            option: claim.task.state_option(),
            expected: expected_state,
        },
    ]
}

fn scheduler_completion(claim: &ClaimPlan, completed_at: u64) -> SchedulerCompletionMutation<'_> {
    SchedulerCompletionMutation {
        state_option: claim.task.state_option(),
        completed_state: &claim.completed_state,
        last_complete_option: claim.task.last_complete_option(),
        now_seconds: completed_at,
    }
}

/**
 * Diagnostic commands describe the invoking session only. Unlike apply's
 * server-wide reconcile context, they must not borrow another attached
 * session's active layout when the current session has `status off`.
 */
fn current_session_context_from_snapshot(snapshot: TmuxSnapshot) -> Option<RenderContext> {
    let LiveContextState::Active(mut context) = context_state_from_snapshot(snapshot) else {
        return None;
    };
    context.layout = resolve_layout(
        &context.snapshot.mode,
        &context.snapshot.status,
        context.snapshot.width,
        context.group.sessions.len(),
        rows_override(&context.snapshot),
    )?;
    Some(context)
}

fn context_state_from_snapshot(snapshot: TmuxSnapshot) -> LiveContextState {
    let snapshot = Rc::new(snapshot);
    let group = ordered_group_from_snapshot(&snapshot);
    let current_layout = resolve_layout(
        &snapshot.mode,
        &snapshot.status,
        snapshot.width,
        group.sessions.len(),
        rows_override(&snapshot),
    );
    let session_layouts = resolve_session_layouts(&snapshot);
    /*
     * `status off` is owned per session. It excludes the invoking session, not
     * the server-wide reconcile: hooks and reloads can legitimately originate
     * from an off popup/agent while other attached sessions still need repair.
     */
    let Some(layout) = current_layout.or_else(|| {
        session_layouts
            .first()
            .map(|session_layout| session_layout.layout.clone())
    }) else {
        return LiveContextState::Inactive(Rc::unwrap_or_clone(snapshot));
    };

    LiveContextState::Active(RenderContext {
        snapshot,
        group,
        layout,
        session_layouts,
    })
}

enum LiveContextState {
    Active(RenderContext),
    Inactive(TmuxSnapshot),
}

static RENDER_REVISION_COUNTER: AtomicU64 = AtomicU64::new(0);

fn next_render_revision() -> u64 {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let time_bits = nanos as u64 ^ ((nanos >> 64) as u64).rotate_left(17);
    let process_bits = u64::from(std::process::id()).rotate_left(32);
    let counter = RENDER_REVISION_COUNTER.fetch_add(1, Ordering::Relaxed);
    time_bits ^ process_bits ^ counter
}

fn next_session_order_revision(current: &str) -> String {
    current
        .parse::<u64>()
        .map(|revision| revision.wrapping_add(1))
        .unwrap_or(1)
        .to_string()
}

fn next_session_order_operation_token() -> String {
    format!("{}:{}", std::process::id(), next_render_revision())
}

fn render_session_order_change() -> AppResult<()> {
    let executable = std::env::current_exe()?;
    let executable = executable.to_str().ok_or_else(|| {
        AppError::Render("current executable path is not valid UTF-8".to_string())
    })?;
    run_bounded_command(
        executable,
        &["apply", "manual-apply"],
        SESSION_SWAP_RENDER_TIMEOUT,
    )
}

fn run_bounded_command(program: &str, args: &[&str], timeout: Duration) -> AppResult<()> {
    let output = output_with_timeout(program, args, timeout)?;
    if output.status.success() {
        return Ok(());
    }
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    Err(AppError::Render(if stderr.is_empty() {
        format!("post-commit render process exited with {}", output.status)
    } else {
        format!("post-commit render process failed: {stderr}")
    }))
}

fn fallback_render_context(context: &RenderContext) -> RenderContext {
    RenderContext {
        snapshot: Rc::clone(&context.snapshot),
        group: SessionGroupView {
            current_session_name: String::new(),
            sessions: Vec::new(),
        },
        layout: context.layout.clone(),
        session_layouts: Vec::new(),
    }
}

fn render_session_statuses(
    context: &RenderContext,
    metrics_supported: bool,
) -> Vec<SessionRenderedStatus> {
    context
        .session_layouts
        .iter()
        .map(|session_layout| {
            let render_context = RenderContext {
                snapshot: Rc::clone(&context.snapshot),
                group: ordered_group_for_session(&context.snapshot, &session_layout.session.name),
                layout: session_layout.layout.clone(),
                session_layouts: Vec::new(),
            };
            let status = render_status02(&render_context, metrics_supported);
            SessionRenderedStatus {
                session_layout: session_layout.clone(),
                session_group_count: render_context.group.sessions.len(),
                render_key: render_cache_key(&status),
                status,
            }
        })
        .collect()
}

fn focus_missing_message(target: FocusTarget) -> String {
    match target {
        FocusTarget::Index(index) => format!("No session at index {index}"),
        FocusTarget::Previous | FocusTarget::Next => "No session to focus".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use std::rc::Rc;
    use std::time::Duration;

    use super::{
        LiveContextState, context_state_from_snapshot, current_session_context_from_snapshot,
        next_render_revision, next_session_order_revision, ordered_group_from_snapshot,
        render_session_statuses, resolve_session_layouts, run_bounded_command,
    };
    use crate::error::AppError;
    use crate::layout::resolve_layout;
    use crate::model::{RenderContext, RowsOverride, SessionInfo, TmuxSnapshot};
    use crate::test_support::{session, snapshot};

    // A popup session is off by policy and shares one 120-column client with `main`.
    fn popup_snapshot() -> TmuxSnapshot {
        TmuxSnapshot {
            status: "off".to_string(),
            width: 120,
            current_session_name: "_popup@x".to_string(),
            sessions: vec![
                SessionInfo {
                    status: "off".to_string(),
                    ..session("$1", "_popup@x")
                },
                session("$2", "main"),
            ],
            client_widths: vec![("$1".to_string(), 120), ("$2".to_string(), 120)],
            ..snapshot()
        }
    }

    #[test]
    fn off_invoking_session_does_not_block_other_session_reconcile() {
        let snapshot = popup_snapshot();

        let LiveContextState::Active(context) = context_state_from_snapshot(snapshot) else {
            panic!("another attached active session must keep the reconcile active");
        };
        assert_eq!(context.session_layouts.len(), 1);
        assert_eq!(context.session_layouts[0].session.id, "$2");
    }

    #[test]
    fn off_invoking_session_is_inactive_for_diagnostic_context() {
        let snapshot = popup_snapshot();

        assert!(current_session_context_from_snapshot(snapshot).is_none());
    }

    #[test]
    fn renders_session_owned_cache_for_each_group() {
        let snapshot = Rc::new(TmuxSnapshot {
            width: 220,
            current_session_name: "main".to_string(),
            sessions: vec![
                session("$1", "main"),
                session("$2", "work"),
                session("$3", "G1-build"),
                session("$4", "G1-test"),
            ],
            client_widths: ["$1", "$2", "$3", "$4"]
                .map(|id| (id.to_string(), 220))
                .to_vec(),
            ..snapshot()
        });
        let session_layouts = resolve_session_layouts(&snapshot);
        let context = RenderContext {
            group: ordered_group_from_snapshot(&snapshot),
            layout: resolve_layout("02", "on", 220, 2, RowsOverride::Auto).unwrap(),
            snapshot,
            session_layouts,
        };

        let rendered = render_session_statuses(&context, false);
        let main = rendered
            .iter()
            .find(|target| target.session_layout.session.id == "$1")
            .unwrap();
        let work = rendered
            .iter()
            .find(|target| target.session_layout.session.id == "$2")
            .unwrap();
        let grouped = rendered
            .iter()
            .find(|target| target.session_layout.session.id == "$3")
            .unwrap();

        assert!(main.status.status_left.rich_text.contains("#{l:main}"));
        assert!(main.status.status_left.rich_text.contains("#{l:work}"));
        assert!(!main.status.status_left.rich_text.contains("G1-build"));
        assert!(
            grouped
                .status
                .status_left
                .rich_text
                .contains("#{l:G1-build}")
        );
        assert!(!grouped.status.status_left.rich_text.contains("#{l:main}"));
        // Session age is drawn by tmux, so same-group right sides no longer differ by age.
        assert!(
            main.status
                .status_right
                .rich_text
                .contains("#{E:@GHC_SESSION_DURATION_FMT}")
        );
        assert_eq!(main.status.status_right, work.status.status_right);
        assert_eq!(main.session_group_count, 2);
        assert_eq!(work.session_group_count, 2);
        assert_eq!(grouped.session_group_count, 2);
        assert_ne!(main.render_key, work.render_key);
    }

    #[test]
    fn render_revisions_are_unique_within_a_process() {
        assert_ne!(next_render_revision(), next_render_revision());
    }

    #[test]
    fn session_order_revision_advances_and_repairs_invalid_values() {
        assert_eq!(next_session_order_revision(""), "1");
        assert_eq!(next_session_order_revision("invalid"), "1");
        assert_eq!(next_session_order_revision("41"), "42");
        assert_eq!(next_session_order_revision(&u64::MAX.to_string()), "0");
    }

    #[cfg(unix)]
    #[test]
    fn post_commit_render_timeout_is_a_recoverable_error() {
        let error = run_bounded_command("/bin/sh", &["-c", "sleep 1"], Duration::from_millis(20))
            .unwrap_err();

        assert!(matches!(error, AppError::CommandTimeout { .. }));
    }
}
