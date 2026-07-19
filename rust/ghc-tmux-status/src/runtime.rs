use std::rc::Rc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Instant;

use crate::commit::{CommitPlanner, TmuxCommandPlan};
use crate::composer::{render_cache_key, render_status02};
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, HEARTBEAT_GENERATION_OPTION,
    HEARTBEAT_INTERVAL_SECONDS, MEMORY_NOW_OPTION, MEMORY_SAMPLE_STATE_OPTION,
    METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    METRIC_RESAMPLE_INTERVAL_SECONDS, METRIC_SAMPLE_GENERATION_OPTION,
    METRIC_SAMPLE_STALE_LIMIT_SECONDS, NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION,
    ROWS_OVERRIDE_OPTION, SCHEDULER_ACTIVE_OPTION, SCHEDULER_GENERATION_OPTION,
};
use crate::error::{AppError, AppResult};
use crate::introspect::{
    CACHED_METRIC_WIDGET_PLACEMENTS, COMPUTED_WIDGET_PLACEMENTS, TEMPLATE_WIDGET_PLACEMENTS,
    cache_bytes, metric_health_state, metric_sample_states, scheduler_state_lines,
};
use crate::layout::LayoutEngine;
use crate::metric::{NET_INTERFACE_OPTION, provider_for_current_platform};
use crate::model::{
    RenderContext, RenderEvent, RenderEventKind, RowsOverride, SessionGroupView, SessionLayout,
    SessionRenderedStatus, TmuxSnapshot,
};
use crate::observability::{duration_ms, trace_enabled, trace_line};
use crate::platform::current_platform;
use crate::process::OperationDeadline;
use crate::scheduler::{ClaimPlan, SchedulerTask, plan_claim};
use crate::session::{
    FocusTarget, MoveDirection, SESSION_ORDER_OPTION, SessionGrouper, SwapOutcome, focus_target,
    ordered_sessions, swap_current,
};
use crate::status_length::{status_left_length, status_right_length};
use crate::tmux::{GuardedMutationOutcome, TmuxAdapter, TmuxOptionGuard, TmuxOptionScope};
use crate::util::format::format_percent_width_2;
use crate::util::time::unix_timestamp_seconds;
use crate::util::width::display_width;
use crate::widget::{
    decode_cpu_snapshot, decode_memory_snapshot, decode_network_snapshot, encode_cpu_snapshot,
    encode_memory_snapshot, encode_network_snapshot, format_memory_now, format_network_now,
};

pub struct StatusRuntime {
    tmux: TmuxAdapter,
}

/// Compatibility path for jobs seeded before the tmux-managed scheduler is
/// activated. New status02 loads only bump these generations to expire the jobs.
struct GuardedSchedule {
    generation_option: &'static str,
    generation: u64,
    delay_seconds: u64,
    command: String,
}

#[derive(Clone, Copy)]
enum ApplyMode<'a> {
    Standard,
    LegacySchedule(&'a GuardedSchedule),
    Scheduler {
        claim: &'a ClaimPlan,
        deadline: &'a OperationDeadline,
    },
}

impl StatusRuntime {
    pub fn live() -> Self {
        Self {
            tmux: TmuxAdapter::new(),
        }
    }

    pub fn apply(&self, event: RenderEvent) -> AppResult<()> {
        self.apply_inner(event, ApplyMode::Standard)
    }

    fn apply_inner(&self, event: RenderEvent, mode: ApplyMode<'_>) -> AppResult<()> {
        check_apply_deadline(mode, "start")?;
        let total_start = Instant::now();
        let context_start = Instant::now();
        let render_revision = next_render_revision();
        let context_state = self.live_context_state(Some(render_revision))?;
        check_apply_deadline(mode, "read-context")?;
        let context_ms = duration_ms(context_start.elapsed());
        let context = match context_state {
            LiveContextState::Active(context) => context,
            LiveContextState::Inactive(snapshot) => {
                let plan_start = Instant::now();
                let plan = CommitPlanner::plan_inactive(&snapshot);
                let plan_commands = plan.commands.len();
                let plan_ms = duration_ms(plan_start.elapsed());
                let commit_start = Instant::now();
                let result = self.commit_plan(&plan, render_revision, mode);
                self.trace_apply(|| {
                    format!(
                        "event={} active=false context_ms={context_ms:.2} plan_ms={plan_ms:.2} commit_ms={:.2} total_ms={:.2} plan_commands={plan_commands}",
                        event.kind.as_str(),
                        duration_ms(commit_start.elapsed()),
                        duration_ms(total_start.elapsed())
                    )
                });
                return result;
            }
        };

        let render_start = Instant::now();
        let metrics_supported = current_platform().supports_metrics();
        let fallback_context = fallback_render_context(&context);
        let fallback_status = render_status02(&fallback_context, metrics_supported)?;
        let session_statuses = render_session_statuses(&context, metrics_supported)?;
        check_apply_deadline(mode, "render")?;
        let render_ms = duration_ms(render_start.elapsed());
        let plan_start = Instant::now();
        let plan = CommitPlanner::plan(&fallback_status, &session_statuses, &context, &event);
        let plan_commands = plan.commands.len();
        let plan_ms = duration_ms(plan_start.elapsed());
        let is_noop = plan.is_empty();
        if is_noop {
            let result = self.commit_plan(&TmuxCommandPlan::default(), render_revision, mode);
            self.trace_apply(|| {
                format!(
                    "event={} active=true noop=true layout={} session_count={} context_ms={context_ms:.2} render_ms={render_ms:.2} total_ms={:.2}",
                    event.kind.as_str(),
                    context.layout.key,
                    context.group.sessions.len(),
                    duration_ms(total_start.elapsed())
                )
            });
            return result;
        }

        let commit_start = Instant::now();
        let result = self.commit_plan(&plan, render_revision, mode);
        self.trace_apply(|| {
            format!(
                "event={} active=true noop=false layout={} session_count={} context_ms={context_ms:.2} render_ms={render_ms:.2} plan_ms={plan_ms:.2} commit_ms={:.2} total_ms={:.2} plan_commands={plan_commands}",
                event.kind.as_str(),
                context.layout.key,
                context.group.sessions.len(),
                duration_ms(commit_start.elapsed()),
                duration_ms(total_start.elapsed())
            )
        });
        result
    }

    pub fn heartbeat(&self, expected_generation: u64) -> AppResult<()> {
        let current_generation = match self
            .tmux
            .show_options(&[(TmuxOptionScope::Server, HEARTBEAT_GENERATION_OPTION)])
        {
            Ok(values) => values.into_iter().next().unwrap_or_default(),
            Err(error) => {
                self.trace_apply(|| {
                    format!(
                        "event=heartbeat action=read-error expected={expected_generation} error={error}"
                    )
                });
                return self.schedule_next_heartbeat(expected_generation);
            }
        };
        if !generation_matches(&current_generation, expected_generation) {
            // A newer chain (or a non-02 layout) superseded this one; let it die.
            self.trace_apply(|| {
                format!(
                    "event=heartbeat action=expired expected={expected_generation} current={current_generation}"
                )
            });
            return Ok(());
        }

        let guarded_schedule = GuardedSchedule {
            generation_option: HEARTBEAT_GENERATION_OPTION,
            generation: expected_generation,
            delay_seconds: HEARTBEAT_INTERVAL_SECONDS,
            command: scheduled_command("heartbeat", expected_generation),
        };
        if let Err(error) = self.apply_inner(
            RenderEvent {
                kind: RenderEventKind::Heartbeat,
            },
            ApplyMode::LegacySchedule(&guarded_schedule),
        ) {
            self.trace_apply(|| format!("event=heartbeat action=apply-error error={error}"));
            // Preserve the fallback refresh chain across transient snapshot/render
            // failures, but keep the retry under the same authoritative guard.
            return self.schedule_next_heartbeat(expected_generation);
        }
        Ok(())
    }

    fn schedule_next_heartbeat(&self, generation: u64) -> AppResult<()> {
        let command = scheduled_command("heartbeat", generation);
        self.tmux.schedule_background_guarded(
            HEARTBEAT_GENERATION_OPTION,
            generation,
            HEARTBEAT_INTERVAL_SECONDS,
            &command,
        )
    }

    pub fn metrics_sample(&self, expected_generation: u64) -> AppResult<()> {
        // No metrics provider off macOS: sampling would only error and self-reschedule
        // forever. Let the chain die so we stop polling on unsupported platforms.
        if !current_platform().supports_metrics() {
            return Ok(());
        }
        let total_start = Instant::now();
        let values = match self.tmux.show_options(&[
            (TmuxOptionScope::Server, METRIC_SAMPLE_GENERATION_OPTION),
            (TmuxOptionScope::GlobalSession, CPU_SAMPLE_STATE_OPTION),
            (TmuxOptionScope::GlobalSession, MEMORY_SAMPLE_STATE_OPTION),
            (TmuxOptionScope::GlobalSession, NETWORK_SAMPLE_STATE_OPTION),
            (TmuxOptionScope::GlobalSession, NET_INTERFACE_OPTION),
            (TmuxOptionScope::GlobalSession, METRIC_ERROR_COUNT_OPTION),
        ]) {
            Ok(values) => values,
            Err(error) => {
                self.trace_apply(|| {
                    format!(
                        "event=metrics-sample action=read-error error={error} total_ms={:.2}",
                        duration_ms(total_start.elapsed())
                    )
                });
                return self.schedule_next_metrics_sample(expected_generation);
            }
        };

        let current_generation = values.first().map(String::as_str).unwrap_or_default();
        if !generation_matches(current_generation, expected_generation) {
            // A newer chain (or a non-02 layout) superseded this one; let it die.
            self.trace_apply(|| {
                format!(
                    "event=metrics-sample action=expired expected={expected_generation} current={current_generation}"
                )
            });
            return Ok(());
        }

        let previous_cpu_state = values.get(1).map(String::as_str).unwrap_or_default();
        let previous_memory_state = values.get(2).map(String::as_str).unwrap_or_default();
        let previous_network_state = values.get(3).map(String::as_str).unwrap_or_default();
        let network_interface = normalize_network_interface(values.get(4).map(String::as_str));
        let previous_error_count = parse_metric_error_count(values.get(5).map(String::as_str));

        // The sampler is the single writer for metric baselines, display options, and
        // health state. Render/apply/heartbeat only install templates or repair structure.
        let sample = self.collect_metrics_sample(
            previous_cpu_state,
            previous_memory_state,
            previous_network_state,
            network_interface,
            previous_error_count,
        );
        let sets = sample.set_refs();
        let command = scheduled_command("metrics-sample", expected_generation);
        match self.tmux.apply_sets_and_reschedule_guarded(
            METRIC_SAMPLE_GENERATION_OPTION,
            expected_generation,
            &sets,
            METRIC_RESAMPLE_INTERVAL_SECONDS,
            &command,
        ) {
            Ok(()) => {
                self.trace_apply(|| {
                    format!(
                        "event=metrics-sample action=sample-ok cpu_published={} memory_published={} network_published={} errors={} total_ms={:.2}",
                        sample.summary.cpu_published,
                        sample.summary.memory_published,
                        sample.summary.network_published,
                        sample.summary.errors.join(","),
                        duration_ms(total_start.elapsed())
                    )
                });
                Ok(())
            }
            Err(error) => {
                self.trace_apply(|| {
                    format!(
                        "event=metrics-sample action=sample-error error={error} total_ms={:.2}",
                        duration_ms(total_start.elapsed())
                    )
                });
                self.schedule_next_metrics_sample(expected_generation)
            }
        }
    }

    pub fn cpu_sample(&self, expected_generation: u64) -> AppResult<()> {
        // Legacy CPU-only samplers must terminate after one invocation. They are
        // intentionally not rescheduled, so no tmux read is needed here.
        self.trace_apply(|| {
            format!("event=cpu-sample action=legacy-expired expected={expected_generation}")
        });
        Ok(())
    }

    fn collect_metrics_sample(
        &self,
        previous_cpu_state: &str,
        previous_memory_state: &str,
        previous_network_state: &str,
        network_interface: Option<&str>,
        previous_error_count: u64,
    ) -> CollectedMetricSample {
        let previous_cpu = decode_cpu_snapshot(previous_cpu_state);
        let previous_memory = decode_memory_snapshot(previous_memory_state);
        let previous_network = decode_network_snapshot(previous_network_state);
        let provider = provider_for_current_platform(network_interface);
        let mut summary = MetricPublishSummary::default();
        let mut set_values: Vec<(&'static str, String)> = Vec::new();

        match provider.sample_cpu(previous_cpu.as_ref().map(|snapshot| &snapshot.sample)) {
            Ok(snapshot) => {
                set_values.push((CPU_SAMPLE_STATE_OPTION, encode_cpu_snapshot(&snapshot)));
                if is_recent_sample(
                    previous_cpu
                        .as_ref()
                        .map(|snapshot| snapshot.timestamp_seconds),
                    snapshot.timestamp_seconds,
                ) {
                    set_values.push((CPU_NOW_OPTION, format_percent_width_2(snapshot.percent)));
                    summary.cpu_published = true;
                }
            }
            Err(error) => summary.errors.push(format!("cpu:{error}")),
        }

        match provider.sample_memory() {
            Ok(snapshot) => {
                set_values.push((
                    MEMORY_SAMPLE_STATE_OPTION,
                    encode_memory_snapshot(&snapshot),
                ));
                set_values.push((MEMORY_NOW_OPTION, format_memory_now(&snapshot)));
                summary.memory_published = true;
            }
            Err(error) => {
                if previous_memory.is_none() {
                    summary.errors.push(format!("memory:{error}"));
                } else {
                    summary.errors.push(format!("memory:{error}:kept-last"));
                }
            }
        }

        match provider.sample_network(previous_network.as_ref().map(|snapshot| &snapshot.sample)) {
            Ok(snapshot) => {
                set_values.push((
                    NETWORK_SAMPLE_STATE_OPTION,
                    encode_network_snapshot(&snapshot),
                ));
                if is_recent_sample(
                    previous_network
                        .as_ref()
                        .map(|snapshot| snapshot.sample.timestamp_seconds),
                    snapshot.sample.timestamp_seconds,
                ) {
                    set_values.push((NETWORK_NOW_OPTION, format_network_now(&snapshot)));
                    summary.network_published = true;
                }
            }
            Err(error) => summary.errors.push(format!("network:{error}")),
        }

        set_values.extend(metric_health_sets(
            &summary,
            previous_error_count,
            unix_timestamp_seconds(),
        ));
        CollectedMetricSample {
            summary,
            set_values,
        }
    }

    fn schedule_next_metrics_sample(&self, generation: u64) -> AppResult<()> {
        let command = scheduled_command("metrics-sample", generation);
        self.tmux.schedule_background_guarded(
            METRIC_SAMPLE_GENERATION_OPTION,
            generation,
            METRIC_RESAMPLE_INTERVAL_SECONDS,
            &command,
        )
    }

    pub fn scheduler_tick(&self) -> AppResult<()> {
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
            return Ok(());
        }
        let generation = values
            .get(1)
            .and_then(|value| value.parse::<u64>().ok())
            .ok_or_else(|| AppError::TmuxParse("invalid scheduler generation".to_string()))?;
        let now_seconds = unix_timestamp_seconds();
        let mut failures = Vec::new();

        if current_platform().supports_metrics()
            && let Err(error) = self.run_scheduler_task(
                SchedulerTask::Metrics,
                generation,
                values.get(2).map(String::as_str).unwrap_or_default(),
                now_seconds,
            )
        {
            self.trace_apply(|| {
                format!("event=scheduler-tick task=metrics action=error error={error}")
            });
            failures.push(format!("metrics:{error}"));
        }
        if let Err(error) = self.run_scheduler_task(
            SchedulerTask::Heartbeat,
            generation,
            values.get(3).map(String::as_str).unwrap_or_default(),
            now_seconds,
        ) {
            self.trace_apply(|| {
                format!("event=scheduler-tick task=heartbeat action=error error={error}")
            });
            failures.push(format!("heartbeat:{error}"));
        }

        if failures.is_empty() {
            return Ok(());
        }
        Err(AppError::Render(format!(
            "scheduler tick failed: {}",
            failures.join("; ")
        )))
    }

    fn run_scheduler_task(
        &self,
        task: SchedulerTask,
        generation: u64,
        observed_state: &str,
        now_seconds: u64,
    ) -> AppResult<()> {
        let Some(claim) = plan_claim(task, generation, observed_state, now_seconds) else {
            return Ok(());
        };
        let generation_text = generation.to_string();
        let guards = scheduler_guards(&claim, &generation_text, &claim.observed_state);
        let outcome = match self.tmux.claim_scheduler_task(
            &guards,
            task.state_option(),
            &claim.claimed_state,
            task.last_attempt_option(),
            claim.started_at_seconds,
        ) {
            Ok(outcome) => outcome,
            Err(error) => {
                self.record_scheduler_failure(&claim, "claim", &error);
                return Err(error);
            }
        };
        if outcome == GuardedMutationOutcome::Skipped {
            return Ok(());
        }

        let result = match task {
            SchedulerTask::Metrics => self.execute_scheduled_metrics(&claim),
            SchedulerTask::Heartbeat => self.execute_scheduled_heartbeat(&claim),
        };
        if let Err(error) = &result {
            self.record_scheduler_failure(&claim, "execute", error);
        }
        result
    }

    fn execute_scheduled_metrics(&self, claim: &ClaimPlan) -> AppResult<()> {
        let deadline = claim.deadline();
        deadline.check("read-metric-state")?;
        let values = self.tmux.show_options(&[
            (TmuxOptionScope::GlobalSession, CPU_SAMPLE_STATE_OPTION),
            (TmuxOptionScope::GlobalSession, MEMORY_SAMPLE_STATE_OPTION),
            (TmuxOptionScope::GlobalSession, NETWORK_SAMPLE_STATE_OPTION),
            (TmuxOptionScope::GlobalSession, NET_INTERFACE_OPTION),
            (TmuxOptionScope::GlobalSession, METRIC_ERROR_COUNT_OPTION),
        ])?;
        deadline.check("sample-metrics")?;
        let sample = self.collect_metrics_sample(
            values.first().map(String::as_str).unwrap_or_default(),
            values.get(1).map(String::as_str).unwrap_or_default(),
            values.get(2).map(String::as_str).unwrap_or_default(),
            normalize_network_interface(values.get(3).map(String::as_str)),
            parse_metric_error_count(values.get(4).map(String::as_str)),
        );
        deadline.check("publish-metrics")?;
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, &claim.claimed_state);
        let completed_at = unix_timestamp_seconds();
        let completion_outcome = scheduler_outcome_value(
            completed_at,
            claim.generation,
            claim.sequence,
            "complete",
            "known",
            "ok",
        );
        let mut sets = sample.set_refs();
        sets.push((claim.task.last_outcome_option(), &completion_outcome));
        let outcome = self.tmux.finish_scheduler_task(
            &guards,
            &sets,
            claim.task.state_option(),
            &claim.completed_state,
            claim.task.last_complete_option(),
            completed_at,
        )?;
        self.trace_apply(|| {
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
        self.apply_inner(
            RenderEvent {
                kind: RenderEventKind::Heartbeat,
            },
            ApplyMode::Scheduler {
                claim,
                deadline: &deadline,
            },
        )?;
        deadline.check("complete-heartbeat")?;
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, &claim.claimed_state);
        let completed_at = unix_timestamp_seconds();
        let completion_outcome = scheduler_outcome_value(
            completed_at,
            claim.generation,
            claim.sequence,
            "complete",
            "known",
            "ok",
        );
        let outcome = self.tmux.finish_scheduler_task(
            &guards,
            &[(claim.task.last_outcome_option(), &completion_outcome)],
            claim.task.state_option(),
            &claim.completed_state,
            claim.task.last_complete_option(),
            completed_at,
        )?;
        self.trace_apply(|| {
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

    fn record_scheduler_failure(&self, claim: &ClaimPlan, phase: &str, error: &AppError) {
        let generation = claim.generation.to_string();
        let guards = scheduler_guards(claim, &generation, &claim.claimed_state);
        let outcome = scheduler_outcome_value(
            unix_timestamp_seconds(),
            claim.generation,
            claim.sequence,
            phase,
            "unknown",
            &error.to_string(),
        );
        if let Err(record_error) =
            self.tmux
                .record_scheduler_outcome(&guards, claim.task.last_outcome_option(), &outcome)
        {
            self.trace_apply(|| {
                format!(
                    "event=scheduler-outcome task={} action=record-error error={record_error}",
                    claim.task.as_str()
                )
            });
        }
    }

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        let context = self.live_context()?;
        let rendered = render_status02(&context, current_platform().supports_metrics())?;
        println!("status-left={}", rendered.status_left.rich_text);
        println!("status-right={}", rendered.status_right.rich_text);
        println!(
            "status-left-length={}",
            status_left_length(&rendered, &context)
        );
        println!(
            "status-right-length={}",
            status_right_length(&rendered, &context)
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
        println!(
            "client_last_session={}",
            context.snapshot.client_last_session
        );
        println!("group_count={}", context.group.sessions.len());
        println!("layout={}", context.layout.key);
        println!("rows={}", context.layout.rows);
        println!("target_status={}", context.layout.target_status);
        println!("cache_bytes={}", cache_bytes(&context.snapshot));
        println!("scheduler:");
        for line in scheduler_state_lines(&context.snapshot) {
            println!("  {line}");
        }
        println!("widget_lifecycles:");
        println!("  template_placements={}", TEMPLATE_WIDGET_PLACEMENTS);
        println!("  computed_placements={}", COMPUTED_WIDGET_PLACEMENTS);
        println!(
            "  cached_metric_placements={}",
            CACHED_METRIC_WIDGET_PLACEMENTS
        );
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
                self.tmux.set_global_option(SESSION_ORDER_OPTION, &order)?;
                self.apply(RenderEvent::manual_apply())
            }
            SwapOutcome::AlreadyFirst => self.tmux.display_message("Already first session"),
            SwapOutcome::AlreadyLast => self.tmux.display_message("Already last session"),
            SwapOutcome::CurrentMissing => {
                self.tmux.display_message("Current session is not visible")
            }
        }
    }

    fn commit_plan(
        &self,
        plan: &TmuxCommandPlan,
        render_revision: u64,
        mode: ApplyMode<'_>,
    ) -> AppResult<()> {
        match mode {
            ApplyMode::Standard => self.tmux.commit_plan_guarded(plan, render_revision),
            ApplyMode::LegacySchedule(schedule) => self.tmux.commit_plan_guarded_and_reschedule(
                plan,
                schedule.generation_option,
                schedule.generation,
                render_revision,
                schedule.delay_seconds,
                &schedule.command,
            ),
            ApplyMode::Scheduler { claim, deadline } => {
                deadline.check("commit-render")?;
                let generation = claim.generation.to_string();
                let guards = scheduler_guards(claim, &generation, &claim.claimed_state);
                self.tmux
                    .commit_plan_scheduler_guarded(plan, render_revision, &guards, deadline)
            }
        }
    }

    fn trace_apply(&self, message: impl FnOnce() -> String) {
        if !trace_enabled() {
            return;
        }

        trace_line("apply", message());
    }

    fn live_context(&self) -> AppResult<RenderContext> {
        let snapshot = self.tmux.read_snapshot()?;
        current_session_context_from_snapshot(snapshot)
            .ok_or_else(|| AppError::Render("status02 layout is not active".to_string()))
    }

    fn live_context_state(&self, render_revision: Option<u64>) -> AppResult<LiveContextState> {
        let snapshot = match render_revision {
            Some(revision) => self.tmux.read_snapshot_for_render(revision)?,
            None => self.tmux.read_snapshot()?,
        };
        Ok(context_state_from_snapshot(snapshot))
    }
}

fn check_apply_deadline(mode: ApplyMode<'_>, phase: &str) -> AppResult<()> {
    match mode {
        ApplyMode::Scheduler { deadline, .. } => deadline.check(phase),
        ApplyMode::Standard | ApplyMode::LegacySchedule(_) => Ok(()),
    }
}

fn scheduler_guards<'a>(
    claim: &'a ClaimPlan,
    generation: &'a str,
    expected_state: &'a str,
) -> [TmuxOptionGuard<'a>; 3] {
    [
        TmuxOptionGuard {
            option: SCHEDULER_ACTIVE_OPTION,
            expected: "1",
        },
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

fn scheduler_outcome_value(
    timestamp_seconds: u64,
    generation: u64,
    sequence: u64,
    phase: &str,
    certainty: &str,
    message: &str,
) -> String {
    format!(
        "{timestamp_seconds}\t{generation}\t{sequence}\t{phase}\t{certainty}\t{}",
        sanitize_metric_error(message)
    )
}

/// Diagnostic commands describe the invoking session only. Unlike apply's
/// server-wide reconcile context, they must not borrow another attached
/// session's active layout when the current session has `status off`.
fn current_session_context_from_snapshot(snapshot: TmuxSnapshot) -> Option<RenderContext> {
    let LiveContextState::Active(mut context) = context_state_from_snapshot(snapshot) else {
        return None;
    };
    context.layout = LayoutEngine::resolve(
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
    let render_session_created = snapshot.session_created;
    let group = ordered_group_from_snapshot(&snapshot);
    let current_layout = LayoutEngine::resolve(
        &snapshot.mode,
        &snapshot.status,
        snapshot.width,
        group.sessions.len(),
        rows_override(&snapshot),
    );
    let session_layouts = resolve_session_layouts(&snapshot);
    // `status off` is owned per session. It excludes the invoking session, not
    // the server-wide reconcile: hooks and reloads can legitimately originate
    // from an off popup/agent while other attached sessions still need repair.
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
        render_session_created,
        session_layouts,
    })
}

/// The manual rows override (`@GHC_SL_ROWS`) for this snapshot, defaulting to
/// `Auto` when the option is unset. Shared by the global and per-session resolves
/// so both agree on the pinned row count.
fn rows_override(snapshot: &TmuxSnapshot) -> RowsOverride {
    RowsOverride::parse(
        snapshot
            .options
            .get(ROWS_OVERRIDE_OPTION)
            .map(String::as_str)
            .unwrap_or_default(),
    )
}

/// Reconciles a per-session target layout for every ON (not currently `off`),
/// attached session. A session whose effective `status` is `off` (popup/agent,
/// owned by hook/session-created.sh) is skipped — the renderer respects the
/// current status and has no knowledge of the naming convention. Detached
/// sessions (no client width) are skipped until a client attaches and an event
/// re-reconciles them.
fn resolve_session_layouts(snapshot: &TmuxSnapshot) -> Vec<SessionLayout> {
    let min_widths = min_client_widths(&snapshot.client_widths);
    let group_counts = SessionGrouper::counts(&snapshot.sessions);
    let rows = rows_override(snapshot);
    let mut session_layouts = Vec::new();
    for session in &snapshot.sessions {
        if session.status == "off" {
            continue;
        }
        let Some(&width) = min_widths.get(session.id.as_str()) else {
            continue;
        };
        let count = group_counts
            .get(&SessionGrouper::key(&session.name))
            .copied()
            .unwrap_or_default();
        let Some(layout) = LayoutEngine::resolve(&snapshot.mode, "on", width, count, rows) else {
            continue;
        };
        session_layouts.push(SessionLayout {
            session_id: session.id.clone(),
            session_name: session.name.clone(),
            current_status: session.status.clone(),
            current_layout_key: session.layout_key.clone(),
            current_left_length: session.left_length.clone(),
            current_right_length: session.right_length.clone(),
            current_format_0: session.format_0.clone(),
            current_format_1: session.format_1.clone(),
            current_render_key: session.render_key.clone(),
            current_cache_witnesses: session.cache_witnesses.clone(),
            session_created: session.created,
            layout,
            width,
        });
    }
    session_layouts
}

/// Minimum attached-client width per session id. A session shared by several
/// clients sizes to its narrowest client, matching tmux `window-size smallest`.
fn min_client_widths(client_widths: &[(String, usize)]) -> std::collections::BTreeMap<&str, usize> {
    let mut min_widths: std::collections::BTreeMap<&str, usize> = std::collections::BTreeMap::new();
    for (session_id, width) in client_widths {
        min_widths
            .entry(session_id.as_str())
            .and_modify(|current| *current = (*current).min(*width))
            .or_insert(*width);
    }
    min_widths
}

enum LiveContextState {
    Active(RenderContext),
    Inactive(TmuxSnapshot),
}

#[derive(Default)]
struct MetricPublishSummary {
    cpu_published: bool,
    memory_published: bool,
    network_published: bool,
    errors: Vec<String>,
}

struct CollectedMetricSample {
    summary: MetricPublishSummary,
    set_values: Vec<(&'static str, String)>,
}

impl CollectedMetricSample {
    fn set_refs(&self) -> Vec<(&str, &str)> {
        self.set_values
            .iter()
            .map(|(name, value)| (*name, value.as_str()))
            .collect()
    }
}

fn is_recent_sample(
    previous_timestamp_seconds: Option<u64>,
    current_timestamp_seconds: u64,
) -> bool {
    previous_timestamp_seconds.is_some_and(|previous_timestamp_seconds| {
        current_timestamp_seconds.saturating_sub(previous_timestamp_seconds)
            <= METRIC_SAMPLE_STALE_LIMIT_SECONDS
    })
}

fn normalize_network_interface(value: Option<&str>) -> Option<&str> {
    value.map(str::trim).filter(|value| !value.is_empty())
}

fn parse_metric_error_count(value: Option<&str>) -> u64 {
    value
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or_default()
}

fn metric_health_sets(
    summary: &MetricPublishSummary,
    previous_error_count: u64,
    now_seconds: u64,
) -> Vec<(&'static str, String)> {
    if summary.errors.is_empty() {
        return vec![
            (METRIC_LAST_OK_OPTION, now_seconds.to_string()),
            (METRIC_ERROR_COUNT_OPTION, "0".to_string()),
        ];
    }

    vec![
        (
            METRIC_LAST_ERROR_OPTION,
            format!(
                "{}\t{}",
                now_seconds,
                sanitize_metric_error(&summary.errors.join("; "))
            ),
        ),
        (
            METRIC_ERROR_COUNT_OPTION,
            previous_error_count.saturating_add(1).to_string(),
        ),
    ]
}

fn sanitize_metric_error(value: &str) -> String {
    const MAX_ERROR_LEN: usize = 240;
    let sanitized = value
        .chars()
        .map(|character| match character {
            '\t' | '\n' | '\r' => ' ',
            _ => character,
        })
        .collect::<String>();
    sanitized.chars().take(MAX_ERROR_LEN).collect()
}

fn generation_matches(current: &str, expected: u64) -> bool {
    current.parse::<u64>() == Ok(expected)
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

fn ordered_group_from_snapshot(snapshot: &TmuxSnapshot) -> SessionGroupView {
    ordered_group_for_session(snapshot, &snapshot.current_session_name)
}

fn ordered_group_for_session(snapshot: &TmuxSnapshot, session_name: &str) -> SessionGroupView {
    ordered_group(
        session_name,
        &snapshot.sessions,
        session_order_value(snapshot),
    )
}

fn ordered_group(
    session_name: &str,
    sessions: &[crate::model::SessionInfo],
    order_value: Option<&str>,
) -> SessionGroupView {
    let mut group = SessionGrouper::group(session_name, sessions);
    group.sessions = ordered_sessions(&group.sessions, order_value);
    group
}

fn fallback_render_context(context: &RenderContext) -> RenderContext {
    RenderContext {
        snapshot: Rc::clone(&context.snapshot),
        group: SessionGroupView {
            current_session_name: String::new(),
            sessions: Vec::new(),
        },
        layout: context.layout.clone(),
        // A future creation timestamp deterministically renders the neutral "0m"
        // fallback until an attached session receives its local cache.
        render_session_created: i64::MAX,
        session_layouts: Vec::new(),
    }
}

fn render_session_statuses(
    context: &RenderContext,
    metrics_supported: bool,
) -> AppResult<Vec<SessionRenderedStatus>> {
    context
        .session_layouts
        .iter()
        .map(|session_layout| {
            let render_context = RenderContext {
                snapshot: Rc::clone(&context.snapshot),
                group: ordered_group_for_session(&context.snapshot, &session_layout.session_name),
                layout: session_layout.layout.clone(),
                render_session_created: session_layout.session_created,
                session_layouts: Vec::new(),
            };
            let status = render_status02(&render_context, metrics_supported)?;
            Ok(SessionRenderedStatus {
                session_layout: session_layout.clone(),
                render_key: render_cache_key(&status),
                status,
            })
        })
        .collect()
}

const RELEASE_BINARY_RELATIVE_PATH: &str =
    ".config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status";

fn scheduled_command(command: &str, generation: u64) -> String {
    format!("{} {command} {generation}", executable_command_path())
}

fn executable_command_path() -> String {
    let path = std::env::current_exe()
        .ok()
        .and_then(|path| path.into_os_string().into_string().ok())
        .or_else(|| {
            std::env::var("HOME")
                .ok()
                .map(|home| format!("{home}/{RELEASE_BINARY_RELATIVE_PATH}"))
        })
        .unwrap_or_else(|| "ghc-tmux-status".to_string());
    format!("'{}'", path.replace('\'', "'\\''"))
}

fn session_order_value(snapshot: &TmuxSnapshot) -> Option<&str> {
    snapshot
        .options
        .get(SESSION_ORDER_OPTION)
        .map(String::as_str)
}

fn focus_missing_message(target: FocusTarget) -> String {
    match target {
        FocusTarget::Index(index) => format!("No session at index {index}"),
        FocusTarget::Previous | FocusTarget::Next => "No session to focus".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;
    use std::rc::Rc;

    use super::{
        LiveContextState, MetricPublishSummary, context_state_from_snapshot,
        current_session_context_from_snapshot, generation_matches, metric_health_sets,
        next_render_revision, normalize_network_interface, ordered_group_from_snapshot,
        parse_metric_error_count, render_session_statuses, resolve_session_layouts,
        sanitize_metric_error, scheduler_outcome_value,
    };
    use crate::config::{
        METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    };
    use crate::layout::LayoutEngine;
    use crate::model::{RenderContext, RowsOverride, SessionInfo, TmuxSnapshot};

    fn session(id: &str, name: &str, status: &str) -> SessionInfo {
        SessionInfo {
            id: id.to_string(),
            name: name.to_string(),
            has_bell: false,
            status: status.to_string(),
            layout_key: String::new(),
            left_length: String::new(),
            right_length: String::new(),
            format_0: String::new(),
            format_1: String::new(),
            render_key: String::new(),
            cache_witnesses: std::array::from_fn(|_| String::new()),
            created: 0,
        }
    }

    #[test]
    fn resolve_session_layouts_skips_off_status_and_detached_sessions() {
        // on + attached -> reconciled; off + attached (popup/agent) -> skipped by
        // status, not by name; on + detached (no client width) -> skipped.
        let snapshot = TmuxSnapshot {
            mode: "02".to_string(),
            status: "on".to_string(),
            width: 200,
            current_session_name: "main".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: vec![
                session("$1", "main", "on"),
                session("$2", "_popup@x", "off"),
                session("$3", "detached", "on"),
            ],
            client_widths: vec![("$1".to_string(), 200), ("$2".to_string(), 200)],
            options: BTreeMap::new(),
        };

        let layouts = resolve_session_layouts(&snapshot);
        assert_eq!(layouts.len(), 1);
        assert_eq!(layouts[0].session_id, "$1");
    }

    #[test]
    fn off_invoking_session_does_not_block_other_session_reconcile() {
        let snapshot = TmuxSnapshot {
            mode: "02".to_string(),
            status: "off".to_string(),
            width: 120,
            current_session_name: "_popup@x".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: vec![
                session("$1", "_popup@x", "off"),
                session("$2", "main", "on"),
            ],
            client_widths: vec![("$1".to_string(), 120), ("$2".to_string(), 120)],
            options: BTreeMap::new(),
        };

        let LiveContextState::Active(context) = context_state_from_snapshot(snapshot) else {
            panic!("another attached active session must keep the reconcile active");
        };
        assert_eq!(context.session_layouts.len(), 1);
        assert_eq!(context.session_layouts[0].session_id, "$2");
    }

    #[test]
    fn off_invoking_session_is_inactive_for_diagnostic_context() {
        let snapshot = TmuxSnapshot {
            mode: "02".to_string(),
            status: "off".to_string(),
            width: 120,
            current_session_name: "_popup@x".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: vec![
                session("$1", "_popup@x", "off"),
                session("$2", "main", "on"),
            ],
            client_widths: vec![("$1".to_string(), 120), ("$2".to_string(), 120)],
            options: BTreeMap::new(),
        };

        assert!(current_session_context_from_snapshot(snapshot).is_none());
    }

    #[test]
    fn renders_session_owned_cache_for_each_group_and_duration() {
        let now = crate::util::time::unix_timestamp_seconds() as i64;
        let mut sessions = vec![
            session("$1", "main", "on"),
            session("$2", "work", "on"),
            session("$3", "G1-build", "on"),
            session("$4", "G1-test", "on"),
        ];
        sessions[0].created = now;
        sessions[1].created = now.saturating_sub(3_600);
        sessions[2].created = now;
        sessions[3].created = now;
        let snapshot = Rc::new(TmuxSnapshot {
            mode: "02".to_string(),
            status: "on".to_string(),
            width: 220,
            current_session_name: "main".to_string(),
            client_last_session: String::new(),
            host: "host".to_string(),
            session_created: now,
            sessions,
            client_widths: ["$1", "$2", "$3", "$4"]
                .map(|id| (id.to_string(), 220))
                .to_vec(),
            options: BTreeMap::new(),
        });
        let session_layouts = resolve_session_layouts(&snapshot);
        let context = RenderContext {
            group: ordered_group_from_snapshot(&snapshot),
            layout: LayoutEngine::resolve("02", "on", 220, 2, RowsOverride::Auto).unwrap(),
            render_session_created: now,
            snapshot,
            session_layouts,
        };

        let rendered = render_session_statuses(&context, false).unwrap();
        let main = rendered
            .iter()
            .find(|target| target.session_layout.session_id == "$1")
            .unwrap();
        let work = rendered
            .iter()
            .find(|target| target.session_layout.session_id == "$2")
            .unwrap();
        let grouped = rendered
            .iter()
            .find(|target| target.session_layout.session_id == "$3")
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
        assert!(main.status.status_right.rich_text.contains(" 0m "));
        assert!(work.status.status_right.rich_text.contains(" 1h 00m "));
        assert_ne!(main.render_key, work.render_key);
    }

    #[test]
    fn render_revisions_are_unique_within_a_process() {
        assert_ne!(next_render_revision(), next_render_revision());
    }

    #[test]
    fn normalize_network_interface_trims_and_filters_empty_values() {
        assert_eq!(normalize_network_interface(Some(" en0 ")), Some("en0"));
        assert_eq!(
            normalize_network_interface(Some("\tutun4\n")),
            Some("utun4")
        );
        assert_eq!(normalize_network_interface(Some("   ")), None);
        assert_eq!(normalize_network_interface(None), None);
    }

    #[test]
    fn parse_metric_error_count_uses_zero_for_missing_or_invalid_values() {
        assert_eq!(parse_metric_error_count(Some("7")), 7);
        assert_eq!(parse_metric_error_count(Some("bad")), 0);
        assert_eq!(parse_metric_error_count(None), 0);
    }

    #[test]
    fn generation_match_requires_an_unsigned_integer() {
        assert!(generation_matches("42", 42));
        assert!(generation_matches("0042", 42));
        assert!(!generation_matches("42; command", 42));
        assert!(!generation_matches("", 0));
    }

    #[test]
    fn metric_health_sets_reset_error_count_on_clean_sample() {
        let summary = MetricPublishSummary::default();
        assert_eq!(
            metric_health_sets(&summary, 3, 100),
            vec![
                (METRIC_LAST_OK_OPTION, "100".to_string()),
                (METRIC_ERROR_COUNT_OPTION, "0".to_string()),
            ]
        );
    }

    #[test]
    fn metric_health_sets_increment_error_count_and_records_last_error() {
        let summary = MetricPublishSummary {
            errors: vec!["network:failed\tbadly".to_string()],
            ..MetricPublishSummary::default()
        };
        assert_eq!(
            metric_health_sets(&summary, 3, 100),
            vec![
                (
                    METRIC_LAST_ERROR_OPTION,
                    "100\tnetwork:failed badly".to_string()
                ),
                (METRIC_ERROR_COUNT_OPTION, "4".to_string()),
            ]
        );
    }

    #[test]
    fn sanitize_metric_error_replaces_separators_and_bounds_length() {
        assert_eq!(sanitize_metric_error("a\tb\nc\rd"), "a b c d");
        assert_eq!(sanitize_metric_error(&"x".repeat(300)).len(), 240);
    }

    #[test]
    fn scheduler_outcome_records_phase_certainty_and_sanitized_error() {
        assert_eq!(
            scheduler_outcome_value(100, 7, 3, "claim", "unknown", "bad\tstate\nnow"),
            "100\t7\t3\tclaim\tunknown\tbad state now"
        );
    }
}
