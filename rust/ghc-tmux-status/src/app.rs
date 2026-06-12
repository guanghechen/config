use crate::cache::TmuxComponentCache;
use crate::component::{
    DateComponent, DurationComponent, FullscreenComponent, HostComponent, PrefixIndicatorComponent,
    SessionBellComponent, SessionListComponent, TimeComponent, WindowIdComponent,
};
use crate::composer::render_components;
use crate::error::{AppError, AppResult};
use crate::layout::LayoutEngine;
use crate::model::{LayoutKind, RenderContext, RenderedSegment, RenderedStatus};
use crate::session_group::SessionGrouper;
use crate::status_component::StatusComponent;
use crate::tmux::TmuxAdapter;
use crate::width::display_width;

pub struct StatusApp {
    tmux: TmuxAdapter,
}

impl StatusApp {
    pub fn live() -> Self {
        Self {
            tmux: TmuxAdapter::new(),
        }
    }

    pub fn apply(&self) -> AppResult<()> {
        let Some(context) = self.live_context_if_active()? else {
            return Ok(());
        };
        let (rendered, cache_options) = self.render_status02(&context)?;
        if cache_matches(&context, &rendered) {
            return Ok(());
        }
        self.tmux
            .commit_status02(&rendered, &context, cache_options)
    }

    pub fn render_status02_stdout(&self) -> AppResult<()> {
        let context = self.live_context()?;
        let (rendered, _cache_options) = self.render_status02(&context)?;
        println!("status-left={}", rendered.status_left.rich_text);
        println!("status-right={}", rendered.status_right.rich_text);
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
    ) -> AppResult<(RenderedStatus, Vec<(String, String)>)> {
        let mut cache = TmuxComponentCache::from_options(&context.snapshot.options);

        let mut host = HostComponent;
        let mut session_list = SessionListComponent;
        let mut left_components: [&mut dyn StatusComponent; 2] = [&mut host, &mut session_list];
        let status_left = render_components(&mut left_components, context, &mut cache)?;

        let mut fullscreen = FullscreenComponent;
        let mut window_id = WindowIdComponent;
        let mut prefix = PrefixIndicatorComponent;
        let mut duration = DurationComponent;
        let mut date = DateComponent;
        let mut time = TimeComponent;
        let mut right_components: [&mut dyn StatusComponent; 6] = [
            &mut fullscreen,
            &mut window_id,
            &mut prefix,
            &mut duration,
            &mut date,
            &mut time,
        ];
        let status_right_body = render_components(&mut right_components, context, &mut cache)?;
        let status_right = RenderedSegment {
            literal_text: format!(" {}", status_right_body.literal_text),
            rich_text: format!("#[default] {}#[default]", status_right_body.rich_text),
        };

        let mut row0_right_prefix = PrefixIndicatorComponent;
        let mut row0_bell = SessionBellComponent;
        let mut row0_duration = DurationComponent;
        let mut row0_date = DateComponent;
        let mut row0_time = TimeComponent;
        let mut row0_right_components: [&mut dyn StatusComponent; 5] = [
            &mut row0_right_prefix,
            &mut row0_bell,
            &mut row0_duration,
            &mut row0_date,
            &mut row0_time,
        ];
        let row0_right = render_components(&mut row0_right_components, context, &mut cache)?;

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
        let row1_right = render_components(&mut row1_right_components, context, &mut cache)?;
        let current_format = RenderedSegment {
            literal_text: row1_right.literal_text,
            rich_text: format_current_format(&row1_right.rich_text),
        };

        if context.layout.kind == LayoutKind::Wide {
            return Ok((
                RenderedStatus {
                    status_left,
                    status_right,
                    session_format,
                    current_format,
                },
                cache.pending_options(),
            ));
        }

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

fn cache_matches(context: &RenderContext, rendered: &RenderedStatus) -> bool {
    context
        .snapshot
        .options
        .get("@GHC_SL_STATUS02_SESSION_FORMAT")
        .is_some_and(|value| value == &rendered.session_format.rich_text)
        && context
            .snapshot
            .options
            .get("@GHC_SL_STATUS02_CURRENT_FORMAT")
            .is_some_and(|value| value == &rendered.current_format.rich_text)
        && context
            .snapshot
            .options
            .get("status-left")
            .is_some_and(|value| value == &rendered.status_left.rich_text)
        && context
            .snapshot
            .options
            .get("status-right")
            .is_some_and(|value| value == &rendered.status_right.rich_text)
        && context
            .snapshot
            .options
            .get("@GHC_SL_LAYOUT")
            .is_some_and(|value| value == &context.layout.key)
        && context.snapshot.status == context.layout.target_status
}

fn format_current_format(row_right: &str) -> String {
    format!(
        "#[default]\
#[align=left #{{E:status-left-style}}]\
#{{?client_prefix,#[fg=#{{@GHC_SL_FG_PREFIX}}]#{{@GHC_SYM_PREFIX}} ,}}\
#[norange default]\
#[list=on align=#{{status-justify}}]#[list=left-marker]<#[list=right-marker]>#[list=on]\
{}\
#[nolist default]\
#[align=right]\
{}\
",
        native_window_list_format(),
        row_right,
    )
}

fn native_window_list_format() -> &'static str {
    "#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}"
}
