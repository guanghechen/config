use std::time::Instant;

use crate::commit::CommitPlanner;
use crate::composer::{cache_matches, render_status02};
use crate::config::{
    CPU_NOW_OPTION, CPU_SAMPLE_STATE_OPTION, HEARTBEAT_GENERATION_OPTION,
    HEARTBEAT_INTERVAL_SECONDS, LEGACY_CPU_SAMPLE_GENERATION_OPTION, MEMORY_NOW_OPTION,
    MEMORY_SAMPLE_STATE_OPTION, METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION,
    METRIC_LAST_OK_OPTION, METRIC_RESAMPLE_INTERVAL_SECONDS, METRIC_SAMPLE_GENERATION_OPTION,
    METRIC_SAMPLE_STALE_LIMIT_SECONDS, NETWORK_NOW_OPTION, NETWORK_SAMPLE_STATE_OPTION,
};
use crate::error::{AppError, AppResult};
use crate::introspect::{
    CACHED_METRIC_WIDGET_PLACEMENTS, COMPUTED_WIDGET_PLACEMENTS, TEMPLATE_WIDGET_PLACEMENTS,
    cache_bytes, metric_health_state, metric_sample_states,
};
use crate::layout::LayoutEngine;
use crate::metric::NET_INTERFACE_OPTION;
use crate::model::{RenderContext, RenderEvent, RenderEventKind, SessionGroupView, TmuxSnapshot};
use crate::observability::{duration_ms, trace_enabled, trace_line};
use crate::session::{
    FocusTarget, MoveDirection, SESSION_ORDER_OPTION, SessionGrouper, SwapOutcome, focus_target,
    ordered_sessions, swap_current,
};
use crate::status_length::{status_left_length, status_right_length};
use crate::tmux::TmuxAdapter;
use crate::util::format::format_percent_width_2;
use crate::util::time::unix_timestamp_seconds;
use crate::util::width::display_width;
use crate::widget::{
    decode_cpu_snapshot, decode_memory_snapshot, decode_network_snapshot, encode_cpu_snapshot,
    encode_memory_snapshot, encode_network_snapshot, format_memory_now, format_network_now,
    sample_cpu, sample_memory, sample_network,
};

pub struct StatusRuntime {
    tmux: TmuxAdapter,
}

impl StatusRuntime {
    pub fn live() -> Self {
        Self {
            tmux: TmuxAdapter::new(),
        }
    }

    pub fn apply(&self, event: RenderEvent) -> AppResult<()> {
        let total_start = Instant::now();
        let context_start = Instant::now();
        let context_state = self.live_context_state()?;
        let context_ms = duration_ms(context_start.elapsed());
        let context = match context_state {
            LiveContextState::Active(context) => context,
            LiveContextState::Inactive(snapshot) => {
                let plan_start = Instant::now();
                let plan = CommitPlanner::plan_inactive(&snapshot);
                let plan_commands = plan.commands.len();
                let plan_ms = duration_ms(plan_start.elapsed());
                let commit_start = Instant::now();
                let result = self.tmux.commit_plan(&plan);
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
        let (rendered, cache_options) = render_status02(&context, &event)?;
        let render_ms = duration_ms(render_start.elapsed());
        let cache_pending_count = cache_options.len();
        let is_noop = event.kind != RenderEventKind::ThemeLoaded
            && cache_matches(&context, &rendered)
            && cache_options.is_empty();
        if is_noop {
            self.trace_apply(|| {
                format!(
                    "event={} active=true noop=true layout={} session_count={} context_ms={context_ms:.2} render_ms={render_ms:.2} total_ms={:.2} cache_pending=0",
                    event.kind.as_str(),
                    context.layout.key,
                    context.group.sessions.len(),
                    duration_ms(total_start.elapsed())
                )
            });
            return Ok(());
        }

        let plan_start = Instant::now();
        let plan = CommitPlanner::plan(&rendered, &context, &event, cache_options);
        let plan_commands = plan.commands.len();
        let plan_ms = duration_ms(plan_start.elapsed());
        let commit_start = Instant::now();
        let result = self.tmux.commit_plan(&plan);
        self.trace_apply(|| {
            format!(
                "event={} active=true noop=false layout={} session_count={} context_ms={context_ms:.2} render_ms={render_ms:.2} plan_ms={plan_ms:.2} commit_ms={:.2} total_ms={:.2} cache_pending={cache_pending_count} plan_commands={plan_commands}",
                event.kind.as_str(),
                context.layout.key,
                context.group.sessions.len(),
                duration_ms(commit_start.elapsed()),
                duration_ms(total_start.elapsed())
            )
        });
        result
    }

    pub fn heartbeat(&self, expected_generation: &str) -> AppResult<()> {
        let current_generation = self
            .tmux
            .show_global_option(HEARTBEAT_GENERATION_OPTION)
            .unwrap_or_default();
        if current_generation != expected_generation {
            // A newer chain (or a non-02 layout) superseded this one; let it die.
            self.trace_apply(|| {
                format!(
                    "event=heartbeat action=expired expected={expected_generation} current={current_generation}"
                )
            });
            return Ok(());
        }

        // Always reschedule, even if this beat's apply fails: a transient tmux
        // error must not permanently kill the no-event fallback refresh source.
        if let Err(error) = self.apply(RenderEvent {
            kind: RenderEventKind::Heartbeat,
        }) {
            self.trace_apply(|| format!("event=heartbeat action=apply-error error={error}"));
        }
        self.schedule_next_heartbeat(expected_generation)
    }

    fn schedule_next_heartbeat(&self, generation: &str) -> AppResult<()> {
        let command = format!("{} heartbeat {generation}", heartbeat_self_command_path());
        self.tmux
            .schedule_background(HEARTBEAT_INTERVAL_SECONDS, &command)
    }

    pub fn metrics_sample(&self, expected_generation: &str) -> AppResult<()> {
        let total_start = Instant::now();
        let values = match self.tmux.show_global_options(&[
            METRIC_SAMPLE_GENERATION_OPTION,
            CPU_SAMPLE_STATE_OPTION,
            MEMORY_SAMPLE_STATE_OPTION,
            NETWORK_SAMPLE_STATE_OPTION,
            NET_INTERFACE_OPTION,
            METRIC_ERROR_COUNT_OPTION,
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
        if current_generation != expected_generation {
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
        match self.tick_metrics_sample(
            previous_cpu_state,
            previous_memory_state,
            previous_network_state,
            network_interface,
            previous_error_count,
            expected_generation,
        ) {
            Ok(summary) => {
                self.trace_apply(|| {
                    format!(
                        "event=metrics-sample action=sample-ok cpu_published={} memory_published={} network_published={} errors={} total_ms={:.2}",
                        summary.cpu_published,
                        summary.memory_published,
                        summary.network_published,
                        summary.errors.join(","),
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

    pub fn cpu_sample(&self, expected_generation: &str) -> AppResult<()> {
        let current_generation = self
            .tmux
            .show_global_option(LEGACY_CPU_SAMPLE_GENERATION_OPTION)
            .unwrap_or_default();
        self.trace_apply(|| {
            format!(
                "event=cpu-sample action=legacy-expired expected={expected_generation} current={current_generation}"
            )
        });
        Ok(())
    }

    fn tick_metrics_sample(
        &self,
        previous_cpu_state: &str,
        previous_memory_state: &str,
        previous_network_state: &str,
        network_interface: Option<&str>,
        previous_error_count: u64,
        generation: &str,
    ) -> AppResult<MetricPublishSummary> {
        let previous_cpu = decode_cpu_snapshot(previous_cpu_state);
        let previous_memory = decode_memory_snapshot(previous_memory_state);
        let previous_network = decode_network_snapshot(previous_network_state);
        let mut summary = MetricPublishSummary::default();
        let mut set_values: Vec<(&'static str, String)> = Vec::new();

        match sample_cpu(previous_cpu.as_ref()) {
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

        match sample_memory() {
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

        match sample_network(network_interface, previous_network.as_ref()) {
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
        let sets = set_values
            .iter()
            .map(|(name, value)| (*name, value.as_str()))
            .collect::<Vec<_>>();
        let command = format!(
            "{} metrics-sample {generation}",
            heartbeat_self_command_path()
        );
        self.tmux
            .apply_sets_and_reschedule(&sets, METRIC_RESAMPLE_INTERVAL_SECONDS, &command)?;
        Ok(summary)
    }

    fn schedule_next_metrics_sample(&self, generation: &str) -> AppResult<()> {
        let command = format!(
            "{} metrics-sample {generation}",
            heartbeat_self_command_path()
        );
        self.tmux
            .schedule_background(METRIC_RESAMPLE_INTERVAL_SECONDS, &command)
    }

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        let context = self.live_context()?;
        let event = RenderEvent::manual_apply();
        let (rendered, _cache_options) = render_status02(&context, &event)?;
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
            rendered.session_format.rich_text
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
        let snapshot = self.tmux.read_snapshot()?;
        let group = ordered_group_from_snapshot(&snapshot);
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
        let snapshot = self.tmux.read_snapshot()?;
        let group = ordered_group_from_snapshot(&snapshot);
        let order_value = session_order_value(&snapshot);
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

    fn trace_apply(&self, message: impl FnOnce() -> String) {
        if !trace_enabled() {
            return;
        }

        trace_line("apply", message());
    }

    fn live_context(&self) -> AppResult<RenderContext> {
        match self.live_context_state()? {
            LiveContextState::Active(context) => Ok(context),
            LiveContextState::Inactive(_) => Err(AppError::Render(
                "status02 layout is not active".to_string(),
            )),
        }
    }

    fn live_context_state(&self) -> AppResult<LiveContextState> {
        let snapshot = self.tmux.read_snapshot()?;
        let group = ordered_group_from_snapshot(&snapshot);
        let Some(layout) = LayoutEngine::resolve(
            &snapshot.mode,
            &snapshot.status,
            snapshot.width,
            group.sessions.len(),
        ) else {
            return Ok(LiveContextState::Inactive(snapshot));
        };

        Ok(LiveContextState::Active(RenderContext {
            snapshot,
            group,
            layout,
        }))
    }
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

#[cfg(test)]
mod tests {
    use super::{
        MetricPublishSummary, metric_health_sets, normalize_network_interface,
        parse_metric_error_count, sanitize_metric_error,
    };
    use crate::config::{
        METRIC_ERROR_COUNT_OPTION, METRIC_LAST_ERROR_OPTION, METRIC_LAST_OK_OPTION,
    };

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
}

fn ordered_group_from_snapshot(snapshot: &TmuxSnapshot) -> SessionGroupView {
    let mut group = SessionGrouper::group(&snapshot.current_session_name, &snapshot.sessions);
    group.sessions = ordered_sessions(&group.sessions, session_order_value(snapshot));
    group
}

const RELEASE_BINARY_RELATIVE_PATH: &str =
    ".config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status";

fn heartbeat_self_command_path() -> String {
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
