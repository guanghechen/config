use std::time::Instant;

use crate::commit::CommitPlanner;
use crate::composer::{cache_matches, render_status02};
use crate::error::{AppError, AppResult};
use crate::introspect::{
    CACHED_METRIC_WIDGET_PLACEMENTS, COMPUTED_WIDGET_PLACEMENTS, TEMPLATE_WIDGET_PLACEMENTS,
    cache_bytes, metric_cache_states,
};
use crate::layout::LayoutEngine;
use crate::model::{
    RenderContext, RenderEvent, RenderEventKind, SessionGroupView, TmuxSnapshot,
};
use crate::observability::{duration_ms, trace_enabled, trace_line};
use crate::session::{
    FocusTarget, MoveDirection, SESSION_ORDER_OPTION, SessionGrouper, SwapOutcome, focus_target,
    ordered_sessions, swap_current,
};
use crate::status_length::{status_left_length, status_right_length};
use crate::tmux::TmuxAdapter;
use crate::util::width::display_width;

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
        let (rendered, cache_options) = render_status02(&context, &event)?;
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
