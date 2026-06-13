use crate::cache::TmuxComponentCache;
use crate::commit::CommitPlanner;
use crate::component::{
    CpuComponent, DateComponent, DurationComponent, FullscreenComponent, HostComponent,
    MemoryComponent, NetworkComponent, PrefixIndicatorComponent, SessionBellComponent,
    SessionListComponent, TimeComponent, WindowIdComponent,
};
use crate::composer::{cache_matches, format_current_format, render_components};
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::model::{RenderContext, RenderEvent, RenderEventKind, RenderedSegment, RenderedStatus};
use crate::session_group::SessionGrouper;
use crate::status_component::StatusComponent;
use crate::status_length::status_left_length;
use crate::tmux::TmuxAdapter;
use crate::width::display_width;

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
        let Some(context) = self.live_context_if_active()? else {
            return Ok(());
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

    fn live_context(&self) -> AppResult<RenderContext> {
        self.live_context_if_active()?
            .ok_or_else(|| AppError::Render("status02 layout is not active".to_string()))
    }

    fn live_context_if_active(&self) -> AppResult<Option<RenderContext>> {
        let snapshot = self.tmux.read_snapshot()?;
        let group = SessionGrouper::group(&snapshot.current_session_name, &snapshot.sessions);
        let Some(layout) = LayoutEngine::resolve(
            &snapshot.mode,
            &snapshot.status,
            snapshot.width,
            group.sessions.len(),
        ) else {
            return Ok(None);
        };

        Ok(Some(RenderContext {
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
        let mut cache = TmuxComponentCache::from_options(&context.snapshot.options);

        let mut host = HostComponent;
        let mut session_list = SessionListComponent;
        let mut left_components: [&mut dyn StatusComponent; 2] = [&mut host, &mut session_list];
        let status_left = render_components(&mut left_components, context, event, &mut cache)?;

        let mut fullscreen = FullscreenComponent;
        let mut window_id = WindowIdComponent;
        let mut network = NetworkComponent::default();
        let mut prefix = PrefixIndicatorComponent;
        let mut cpu = CpuComponent::default();
        let mut memory = MemoryComponent::default();
        let mut duration = DurationComponent::default();
        let mut date = DateComponent;
        let mut time = TimeComponent;
        let mut right_components: [&mut dyn StatusComponent; 9] = [
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
        let status_right_body =
            render_components(&mut right_components, context, event, &mut cache)?;
        let status_right = RenderedSegment {
            literal_text: format!(" {}", status_right_body.literal_text),
            rich_text: format!("#[default] {}#[default]", status_right_body.rich_text),
        };

        let mut row0_network = NetworkComponent::default();
        let mut row0_right_prefix = PrefixIndicatorComponent;
        let mut row0_bell = SessionBellComponent;
        let mut row0_cpu = CpuComponent::default();
        let mut row0_memory = MemoryComponent::default();
        let mut row0_duration = DurationComponent::default();
        let mut row0_date = DateComponent;
        let mut row0_time = TimeComponent;
        let mut row0_right_components: [&mut dyn StatusComponent; 8] = [
            &mut row0_network,
            &mut row0_right_prefix,
            &mut row0_bell,
            &mut row0_cpu,
            &mut row0_memory,
            &mut row0_duration,
            &mut row0_date,
            &mut row0_time,
        ];
        let row0_right = render_components(&mut row0_right_components, context, event, &mut cache)?;

        let session_format = RenderedSegment {
            literal_text: format!("{}{}", status_left.literal_text, row0_right.literal_text),
            rich_text: format!(
                "#[default]#[align=left]{}#[align=right]{}#[default]",
                status_left.rich_text, row0_right.rich_text
            ),
        };

        let mut row1_fullscreen = FullscreenComponent;
        let mut row1_window_id = WindowIdComponent;
        let mut row1_right_components: [&mut dyn StatusComponent; 2] =
            [&mut row1_fullscreen, &mut row1_window_id];
        let row1_right = render_components(&mut row1_right_components, context, event, &mut cache)?;
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

fn cache_bytes(context: &RenderContext) -> usize {
    context
        .snapshot
        .options
        .iter()
        .filter(|(name, _)| name.starts_with("@GHC_STATUS_COMPONENT_CACHE_"))
        .map(|(_, value)| value.len())
        .sum()
}
