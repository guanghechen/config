use crate::cache::{TmuxWidgetCache, WIDGET_CACHE_OPTION_PREFIX};
use crate::commit::CommitPlanner;
use crate::composer::{cache_matches, format_current_format, render_widgets};
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::model::{
    RenderContext, RenderEvent, RenderEventKind, RenderedSegment, RenderedStatus, SessionGroupView,
    TmuxSnapshot,
};
use crate::session::{
    FocusTarget, MoveDirection, SESSION_ORDER_OPTION, SessionGrouper, SwapOutcome, focus_target,
    ordered_sessions, swap_current,
};
use crate::status_length::status_left_length;
use crate::status_widget::StatusWidget;
use crate::tmux::TmuxAdapter;
use crate::util::width::display_width;
use crate::widget::{
    CpuWidget, DateWidget, DurationWidget, FullscreenWidget, HostWidget, MemoryWidget,
    NetworkWidget, PrefixIndicatorWidget, SessionBellWidget, SessionListWidget, TimeWidget,
    WindowIdWidget,
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
        let context = match self.live_context_state()? {
            LiveContextState::Active(context) => context,
            LiveContextState::Inactive(snapshot) => {
                let plan = CommitPlanner::plan_inactive(&snapshot);
                return self.tmux.commit_plan(&plan);
            }
        };
        let (rendered, cache_options) = self.render_status02(&context, &event)?;
        if event.kind != RenderEventKind::ThemeLoaded
            && cache_matches(&context, &rendered)
            && cache_options.is_empty()
        {
            return Ok(());
        }

        let plan = CommitPlanner::plan(&rendered, &context, &event, cache_options);
        self.tmux.commit_plan(&plan)
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
        println!("group_count={}", context.group.sessions.len());
        println!("layout={}", context.layout.key);
        println!("rows={}", context.layout.rows);
        println!("target_status={}", context.layout.target_status);
        println!("cache_bytes={}", cache_bytes(&context));
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

        let mut host = HostWidget;
        let mut session_list = SessionListWidget;
        let mut left_widgets: [&mut dyn StatusWidget; 2] = [&mut host, &mut session_list];
        let status_left = render_widgets(&mut left_widgets, context, event, &mut cache)?;

        let mut fullscreen = FullscreenWidget;
        let mut window_id = WindowIdWidget;
        let mut network = NetworkWidget::default();
        let mut prefix = PrefixIndicatorWidget;
        let mut cpu = CpuWidget::default();
        let mut memory = MemoryWidget::default();
        let mut duration = DurationWidget::default();
        let mut date = DateWidget;
        let mut time = TimeWidget;
        let mut right_widgets: [&mut dyn StatusWidget; 9] = [
            &mut fullscreen,
            &mut window_id,
            &mut network,
            &mut prefix,
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

        let mut row0_network = NetworkWidget::default();
        let mut row0_right_prefix = PrefixIndicatorWidget;
        let mut row0_bell = SessionBellWidget;
        let mut row0_cpu = CpuWidget::default();
        let mut row0_memory = MemoryWidget::default();
        let mut row0_duration = DurationWidget::default();
        let mut row0_date = DateWidget;
        let mut row0_time = TimeWidget;
        let mut row0_right_widgets: [&mut dyn StatusWidget; 8] = [
            &mut row0_network,
            &mut row0_right_prefix,
            &mut row0_bell,
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

        let mut row1_fullscreen = FullscreenWidget;
        let mut row1_window_id = WindowIdWidget;
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

fn cache_bytes(context: &RenderContext) -> usize {
    context
        .snapshot
        .options
        .iter()
        .filter(|(name, _)| name.starts_with(WIDGET_CACHE_OPTION_PREFIX))
        .map(|(_, value)| value.len())
        .sum()
}
