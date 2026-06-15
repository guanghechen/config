use std::time::Instant;

use crate::cache::{TmuxWidgetCache, WIDGET_CACHE_OPTION_PREFIX};
use crate::commit::CommitPlanner;
use crate::composer::{cache_matches, format_current_format, render_widgets};
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::model::{
    RenderContext, RenderEvent, RenderEventKind, RenderedSegment, RenderedStatus, SessionGroupView,
    TmuxSnapshot,
};
use crate::observability::{duration_ms, trace_enabled, trace_line};
use crate::session::{
    FocusTarget, MoveDirection, SESSION_ORDER_OPTION, SessionGrouper, SwapOutcome, focus_target,
    ordered_sessions, swap_current,
};
use crate::status_length::{status_left_length, status_right_length};
use crate::status_widget::{CachedMetricWidget, StatusWidget, cached_metric, computed, template};
use crate::tmux::TmuxAdapter;
use crate::util::width::display_width;
use crate::widget::{
    CpuWidget, DateWidget, DurationWidget, FullscreenWidget, HostWidget, MemoryWidget,
    NetworkWidget, PrefixIndicatorWidget, SessionListWidget, TimeWidget, WindowIdWidget,
};

pub struct StatusRuntime {
    tmux: TmuxAdapter,
}

const HEARTBEAT_GENERATION_OPTION: &str = "@GHC_SL_HEARTBEAT_GEN";
const HEARTBEAT_INTERVAL_SECONDS: u64 = 30;

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
        let (rendered, cache_options) = self.render_status02(&context, &event)?;
        let render_ms = duration_ms(render_start.elapsed());
        let cache_pending_count = cache_options.len();
        let is_noop = event.kind != RenderEventKind::ThemeLoaded
            && cache_matches(&context, &rendered)
            && cache_options.is_empty();
        if is_noop {
            self.trace_apply(|| {
                format!(
                    "event={} active=true noop=true layout={} context_ms={context_ms:.2} render_ms={render_ms:.2} total_ms={:.2} cache_pending=0",
                    event.kind.as_str(),
                    context.layout.key,
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
                "event={} active=true noop=false layout={} context_ms={context_ms:.2} render_ms={render_ms:.2} plan_ms={plan_ms:.2} commit_ms={:.2} total_ms={:.2} cache_pending={cache_pending_count} plan_commands={plan_commands}",
                event.kind.as_str(),
                context.layout.key,
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

        self.apply(RenderEvent { kind: RenderEventKind::Tick })?;
        self.schedule_next_heartbeat(expected_generation)
    }

    fn schedule_next_heartbeat(&self, generation: &str) -> AppResult<()> {
        let command = format!(
            "{} heartbeat {generation}",
            heartbeat_self_command_path()
        );
        self.tmux
            .schedule_background(HEARTBEAT_INTERVAL_SECONDS, &command)
    }

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        let context = self.live_context()?;
        let event = RenderEvent::manual_apply();
        let (rendered, _cache_options) = self.render_status02(&context, &event)?;
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
        println!("cache_bytes={}", cache_bytes(&context));
        println!("widget_lifecycles:");
        println!("  template_placements={}", TEMPLATE_WIDGET_PLACEMENTS);
        println!("  computed_placements={}", COMPUTED_WIDGET_PLACEMENTS);
        println!(
            "  cached_metric_placements={}",
            CACHED_METRIC_WIDGET_PLACEMENTS
        );
        println!("metric_caches:");
        for state in metric_cache_states(&context.snapshot) {
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

    fn render_status02(
        &self,
        context: &RenderContext,
        event: &RenderEvent,
    ) -> AppResult<(RenderedStatus, Vec<(String, String)>)> {
        let mut cache = TmuxWidgetCache::from_options(&context.snapshot.options);

        let mut host = computed(HostWidget);
        let mut session_list = computed(SessionListWidget);
        let mut left_widgets: [&mut dyn StatusWidget; 2] = [&mut host, &mut session_list];
        let status_left = render_widgets(&mut left_widgets, context, event, &mut cache)?;

        let mut fullscreen = template(FullscreenWidget);
        let mut window_id = template(WindowIdWidget);
        let mut network = cached_metric(NetworkWidget);
        let mut prefix = template(PrefixIndicatorWidget);
        let mut cpu = cached_metric(CpuWidget);
        let mut memory = cached_metric(MemoryWidget);
        let mut duration = computed(DurationWidget);
        let mut date = template(DateWidget);
        let mut time = template(TimeWidget);
        let mut right_widgets: [&mut dyn StatusWidget; 9] = [
            &mut prefix,
            &mut fullscreen,
            &mut window_id,
            &mut network,
            &mut cpu,
            &mut memory,
            &mut duration,
            &mut date,
            &mut time,
        ];
        let status_right_body = render_widgets(&mut right_widgets, context, event, &mut cache)?;
        let status_right = RenderedSegment {
            literal_text: format!(" {}", status_right_body.literal_text),
            rich_text: format!("#[default] {}#[default]", status_right_body.rich_text),
        };

        let mut row0_network = cached_metric(NetworkWidget);
        let mut row0_right_prefix = template(PrefixIndicatorWidget);
        let mut row0_cpu = cached_metric(CpuWidget);
        let mut row0_memory = cached_metric(MemoryWidget);
        let mut row0_duration = computed(DurationWidget);
        let mut row0_date = template(DateWidget);
        let mut row0_time = template(TimeWidget);
        let mut row0_right_widgets: [&mut dyn StatusWidget; 7] = [
            &mut row0_right_prefix,
            &mut row0_network,
            &mut row0_cpu,
            &mut row0_memory,
            &mut row0_duration,
            &mut row0_date,
            &mut row0_time,
        ];
        let row0_right = render_widgets(&mut row0_right_widgets, context, event, &mut cache)?;

        let session_format = RenderedSegment {
            literal_text: format!("{}{}", status_left.literal_text, row0_right.literal_text),
            rich_text: format!(
                "#[default]#[align=left]{}#[align=right]{}#[default]",
                status_left.rich_text, row0_right.rich_text
            ),
        };

        let mut row1_fullscreen = template(FullscreenWidget);
        let mut row1_window_id = template(WindowIdWidget);
        let mut row1_right_widgets: [&mut dyn StatusWidget; 2] =
            [&mut row1_fullscreen, &mut row1_window_id];
        let row1_right = render_widgets(&mut row1_right_widgets, context, event, &mut cache)?;
        let current_format = RenderedSegment {
            literal_text: row1_right.literal_text,
            rich_text: format_current_format(&row1_right.rich_text),
        };

        Ok((
            RenderedStatus {
                status_left,
                status_right,
                session_format,
                current_format,
            },
            cache.pending_options(),
        ))
    }
}

enum LiveContextState {
    Active(RenderContext),
    Inactive(TmuxSnapshot),
}

fn ordered_group_from_snapshot(snapshot: &TmuxSnapshot) -> SessionGroupView {
    let mut group = SessionGrouper::group(&snapshot.current_session_name, &snapshot.sessions);
    group.sessions = ordered_sessions(&group.sessions, session_order_value(snapshot));
    group
}

fn heartbeat_self_command_path() -> String {
    let path = std::env::current_exe()
        .ok()
        .and_then(|path| path.into_os_string().into_string().ok())
        .unwrap_or_else(|| {
            std::env::var("HOME")
                .map(|home| {
                    format!("{home}/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status")
                })
                .unwrap_or_else(|_| {
                    "/Users/wanchenfang/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
                        .to_string()
                })
        });
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

const TEMPLATE_WIDGET_PLACEMENTS: usize = 10;
const COMPUTED_WIDGET_PLACEMENTS: usize = 4;
const CACHED_METRIC_WIDGET_PLACEMENTS: usize = 6;

#[derive(Clone, Debug, Eq, PartialEq)]
struct MetricCacheState {
    id: &'static str,
    status: MetricCacheStatus,
}

#[derive(Clone, Debug, Eq, PartialEq)]
enum MetricCacheStatus {
    Missing,
    Invalid {
        bytes: usize,
    },
    Present {
        age_seconds: u64,
        ttl_seconds: u64,
        fresh: bool,
        bytes: usize,
    },
}

impl MetricCacheState {
    fn format_line(&self) -> String {
        match self.status {
            MetricCacheStatus::Missing => format!("{} status=missing", self.id),
            MetricCacheStatus::Invalid { bytes } => {
                format!("{} status=invalid bytes={bytes}", self.id)
            }
            MetricCacheStatus::Present {
                age_seconds,
                ttl_seconds,
                fresh,
                bytes,
            } => format!(
                "{} status=present fresh={} age_seconds={} ttl_seconds={} bytes={}",
                self.id, fresh, age_seconds, ttl_seconds, bytes
            ),
        }
    }
}

fn metric_cache_states(snapshot: &TmuxSnapshot) -> Vec<MetricCacheState> {
    let now = crate::util::time::unix_timestamp_seconds();
    metric_cache_specs()
        .into_iter()
        .map(|spec| metric_cache_state(snapshot, spec, now))
        .collect()
}

#[derive(Clone, Copy)]
struct MetricCacheSpec {
    id: &'static str,
    ttl_seconds: u64,
    timestamp_seconds: fn(&str) -> Option<u64>,
}

fn metric_cache_specs() -> [MetricCacheSpec; 3] {
    [
        MetricCacheSpec {
            id: "cpu",
            ttl_seconds: CpuWidget.ttl_seconds(),
            timestamp_seconds: cpu_cache_timestamp_seconds,
        },
        MetricCacheSpec {
            id: "memory",
            ttl_seconds: MemoryWidget.ttl_seconds(),
            timestamp_seconds: memory_cache_timestamp_seconds,
        },
        MetricCacheSpec {
            id: "network",
            ttl_seconds: NetworkWidget.ttl_seconds(),
            timestamp_seconds: network_cache_timestamp_seconds,
        },
    ]
}

fn cpu_cache_timestamp_seconds(value: &str) -> Option<u64> {
    let widget = CpuWidget;
    widget
        .decode_cache(value)
        .map(|snapshot| widget.timestamp_seconds(&snapshot))
}

fn memory_cache_timestamp_seconds(value: &str) -> Option<u64> {
    let widget = MemoryWidget;
    widget
        .decode_cache(value)
        .map(|snapshot| widget.timestamp_seconds(&snapshot))
}

fn network_cache_timestamp_seconds(value: &str) -> Option<u64> {
    let widget = NetworkWidget;
    widget
        .decode_cache(value)
        .map(|snapshot| widget.timestamp_seconds(&snapshot))
}

fn metric_cache_state(
    snapshot: &TmuxSnapshot,
    spec: MetricCacheSpec,
    now_seconds: u64,
) -> MetricCacheState {
    let option_name = format!("{WIDGET_CACHE_OPTION_PREFIX}{}", spec.id);
    let Some(value) = snapshot.options.get(&option_name) else {
        return MetricCacheState {
            id: spec.id,
            status: MetricCacheStatus::Missing,
        };
    };

    let Some(timestamp_seconds) = (spec.timestamp_seconds)(value) else {
        return MetricCacheState {
            id: spec.id,
            status: MetricCacheStatus::Invalid { bytes: value.len() },
        };
    };

    let age_seconds = now_seconds.saturating_sub(timestamp_seconds);
    MetricCacheState {
        id: spec.id,
        status: MetricCacheStatus::Present {
            age_seconds,
            ttl_seconds: spec.ttl_seconds,
            fresh: age_seconds < spec.ttl_seconds,
            bytes: value.len(),
        },
    }
}

fn cache_bytes(context: &RenderContext) -> usize {
    context
        .snapshot
        .options
        .iter()
        .filter(|(name, _)| name.starts_with(WIDGET_CACHE_OPTION_PREFIX))
        .map(|(_, value)| value.len())
        .sum()
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        MetricCacheSpec, MetricCacheState, MetricCacheStatus, cpu_cache_timestamp_seconds,
        metric_cache_state,
    };
    use crate::model::TmuxSnapshot;

    #[test]
    fn metric_cache_state_reports_missing_cache() {
        let state = metric_cache_state(&snapshot_with_options(BTreeMap::new()), spec(), 100);

        assert_eq!(
            state,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Missing,
            }
        );
    }

    #[test]
    fn metric_cache_state_reports_invalid_cache_timestamp() {
        let state = metric_cache_state(
            &snapshot_with_options(BTreeMap::from([(
                "@GHC_STATUS_COMPONENT_CACHE_cpu".to_string(),
                "invalid\tcache".to_string(),
            )])),
            spec(),
            100,
        );

        assert_eq!(
            state,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Invalid { bytes: 13 },
            }
        );
    }

    #[test]
    fn metric_cache_state_uses_widget_decoder_for_validity() {
        let state = metric_cache_state(
            &snapshot_with_options(BTreeMap::from([(
                "@GHC_STATUS_COMPONENT_CACHE_cpu".to_string(),
                "90\tvalue".to_string(),
            )])),
            spec(),
            100,
        );

        assert_eq!(
            state,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Invalid { bytes: 8 },
            }
        );
    }

    #[test]
    fn metric_cache_state_reports_fresh_and_stale_cache() {
        let cache_value = "90\t12\t1\t2\t3\t4";
        let snapshot = snapshot_with_options(BTreeMap::from([(
            "@GHC_STATUS_COMPONENT_CACHE_cpu".to_string(),
            cache_value.to_string(),
        )]));
        let bytes = cache_value.len();

        let fresh = metric_cache_state(&snapshot, spec(), 100);
        let stale = metric_cache_state(&snapshot, spec(), 111);

        assert_eq!(
            fresh,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Present {
                    age_seconds: 10,
                    ttl_seconds: 20,
                    fresh: true,
                    bytes,
                },
            }
        );
        assert_eq!(
            stale,
            MetricCacheState {
                id: "cpu",
                status: MetricCacheStatus::Present {
                    age_seconds: 21,
                    ttl_seconds: 20,
                    fresh: false,
                    bytes,
                },
            }
        );
    }

    fn spec() -> MetricCacheSpec {
        MetricCacheSpec {
            id: "cpu",
            ttl_seconds: 20,
            timestamp_seconds: cpu_cache_timestamp_seconds,
        }
    }

    fn snapshot_with_options(options: BTreeMap<String, String>) -> TmuxSnapshot {
        TmuxSnapshot {
            mode: "02".to_string(),
            current_layout: "02:wide".to_string(),
            status: "on".to_string(),
            width: 200,
            current_session_name: "s".to_string(),
            client_last_session: String::new(),
            host: "h".to_string(),
            session_created: 1,
            sessions: Vec::new(),
            options,
        }
    }
}
