use crate::cache::{TmuxWidgetCache, WidgetCache};
use crate::error::AppResult;
use crate::metric::NET_INTERFACE_OPTION;
use crate::model::{RenderContext, RenderEvent, RenderedSegment, RenderedStatus, TmuxSnapshot};
use crate::status_length::{status_left_length, status_right_length};
use crate::status_widget::{
    StatusWidget, WidgetLifecycle, cached_metric, computed, template,
};
use crate::widget::{
    CpuWidget, DateWidget, DurationWidget, FullscreenWidget, HostWidget, MemoryWidget,
    NetworkWidget, PrefixIndicatorWidget, SessionListWidget, TimeWidget, WindowIdWidget,
};

/// Renders the status02 layout once and returns the rendered segments plus any
/// widget-cache option writes accumulated during sampling.
///
/// Each widget type is instantiated exactly once. The single-row and two-row
/// layouts share the rendered sub-segments (prefix / window chrome / metrics):
/// segment concatenation is associative, so composing the shared pieces is
/// byte-identical to rendering each row independently.
pub fn render_status02(
    context: &RenderContext,
    event: &RenderEvent,
) -> AppResult<(RenderedStatus, Vec<(String, String)>)> {
    let mut cache = TmuxWidgetCache::from_options(&context.snapshot.options);
    let net_interface = network_interface_override(&context.snapshot);

    let mut host = computed(HostWidget);
    let mut session_list = computed(SessionListWidget);
    let mut left_widgets: [&mut dyn StatusWidget; 2] = [&mut host, &mut session_list];
    let status_left = render_widgets(&mut left_widgets, context, event, &mut cache)?;

    let mut prefix = template(PrefixIndicatorWidget);
    let mut prefix_widgets: [&mut dyn StatusWidget; 1] = [&mut prefix];
    let prefix_segment = render_widgets(&mut prefix_widgets, context, event, &mut cache)?;

    let mut fullscreen = template(FullscreenWidget);
    let mut window_id = template(WindowIdWidget);
    let mut chrome_widgets: [&mut dyn StatusWidget; 2] = [&mut fullscreen, &mut window_id];
    let chrome_segment = render_widgets(&mut chrome_widgets, context, event, &mut cache)?;

    let mut network = cached_metric(NetworkWidget::for_interface(net_interface));
    let mut cpu = cached_metric(CpuWidget);
    let mut memory = cached_metric(MemoryWidget);
    let mut duration = computed(DurationWidget);
    let mut date = template(DateWidget);
    let mut time = template(TimeWidget);
    let mut metric_widgets: [&mut dyn StatusWidget; 6] = [
        &mut network,
        &mut cpu,
        &mut memory,
        &mut duration,
        &mut date,
        &mut time,
    ];
    let metric_segment = render_widgets(&mut metric_widgets, context, event, &mut cache)?;

    let status_right_body =
        concat_segments(&[&prefix_segment, &chrome_segment, &metric_segment]);
    let status_right = RenderedSegment {
        literal_text: format!(" {}", status_right_body.literal_text),
        rich_text: format!("#[default] {}#[default]", status_right_body.rich_text),
    };

    let row0_right = concat_segments(&[&prefix_segment, &metric_segment]);
    let session_format = RenderedSegment {
        literal_text: format!("{}{}", status_left.literal_text, row0_right.literal_text),
        rich_text: format!(
            "#[default]#[align=left]{}#[align=right]{}#[default]",
            status_left.rich_text, row0_right.rich_text
        ),
    };

    let current_format = RenderedSegment {
        literal_text: chrome_segment.literal_text.clone(),
        rich_text: format_current_format(&chrome_segment.rich_text),
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

fn concat_segments(segments: &[&RenderedSegment]) -> RenderedSegment {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for segment in segments {
        literal_text.push_str(&segment.literal_text);
        rich_text.push_str(&segment.rich_text);
    }
    RenderedSegment {
        literal_text,
        rich_text,
    }
}

fn network_interface_override(snapshot: &TmuxSnapshot) -> Option<String> {
    snapshot
        .options
        .get(NET_INTERFACE_OPTION)
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

fn render_widgets(
    widgets: &mut [&mut dyn StatusWidget],
    context: &RenderContext,
    event: &RenderEvent,
    cache: &mut dyn WidgetCache,
) -> AppResult<RenderedSegment> {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for widget in widgets {
        if matches!(widget.lifecycle(), WidgetLifecycle::CachedMetric { .. }) {
            widget.refresh(context, event, cache)?;
        }
        let segment = widget.render(context)?;
        literal_text.push_str(&segment.literal_text);
        rich_text.push_str(&segment.rich_text);
    }
    Ok(RenderedSegment {
        literal_text,
        rich_text,
    })
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

pub fn cache_matches(context: &RenderContext, rendered: &RenderedStatus) -> bool {
    context
        .snapshot
        .options
        .get("@GHC_SL_STATUS02_LEFT")
        .is_some_and(|value| value == &rendered.status_left.rich_text)
        && context
            .snapshot
            .options
            .get("@GHC_SL_STATUS02_RIGHT")
            .is_some_and(|value| value == &rendered.status_right.rich_text)
        && context
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
            .get("@GHC_SL_LAYOUT")
            .is_some_and(|value| value == &context.layout.key)
        && context
            .snapshot
            .options
            .get("status-left-length")
            .is_some_and(|value| value == &status_left_length(rendered, context))
        && context
            .snapshot
            .options
            .get("status-right-length")
            .is_some_and(|value| value == &status_right_length(rendered, context))
        // Prevent stale 20s redraw from being mistaken for a status02 no-op after cache convergence.
        && context
            .snapshot
            .options
            .get("status-interval")
            .is_some_and(|value| value == "1")
        && context.snapshot.status == context.layout.target_status
}

fn native_window_list_format() -> &'static str {
    "#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}"
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{cache_matches, format_current_format};
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderedSegment, RenderedStatus, SessionGroupView,
        StatusMode, StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn current_format_keeps_native_window_list() {
        let formatted = format_current_format("RIGHT");
        assert!(formatted.contains("#{W:"));
        assert!(formatted.contains("RIGHT"));
    }

    #[test]
    fn cache_matches_requires_dynamic_status_left_length() {
        let status = rendered_status(&"x".repeat(68));
        let context = context_with_options(BTreeMap::from([
            (
                "@GHC_SL_STATUS02_LEFT".to_string(),
                status.status_left.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_RIGHT".to_string(),
                status.status_right.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_SESSION_FORMAT".to_string(),
                status.session_format.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_CURRENT_FORMAT".to_string(),
                status.current_format.rich_text.clone(),
            ),
            ("@GHC_SL_LAYOUT".to_string(), "02:wide".to_string()),
            ("status-left-length".to_string(), "70".to_string()),
            ("status-right-length".to_string(), "84".to_string()),
            ("status-interval".to_string(), "1".to_string()),
        ]));

        assert!(cache_matches(&context, &status));
    }

    #[test]
    fn cache_misses_when_status_left_length_is_stale() {
        let status = rendered_status(&"x".repeat(68));
        let context = context_with_options(BTreeMap::from([
            (
                "@GHC_SL_STATUS02_LEFT".to_string(),
                status.status_left.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_RIGHT".to_string(),
                status.status_right.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_SESSION_FORMAT".to_string(),
                status.session_format.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_CURRENT_FORMAT".to_string(),
                status.current_format.rich_text.clone(),
            ),
            ("@GHC_SL_LAYOUT".to_string(), "02:wide".to_string()),
            ("status-left-length".to_string(), "64".to_string()),
            ("status-right-length".to_string(), "84".to_string()),
            ("status-interval".to_string(), "1".to_string()),
        ]));

        assert!(!cache_matches(&context, &status));
    }

    #[test]
    fn cache_misses_when_status_right_length_is_stale() {
        let status = rendered_status(&"x".repeat(90));
        let context = context_with_options(BTreeMap::from([
            (
                "@GHC_SL_STATUS02_LEFT".to_string(),
                status.status_left.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_RIGHT".to_string(),
                status.status_right.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_SESSION_FORMAT".to_string(),
                status.session_format.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_CURRENT_FORMAT".to_string(),
                status.current_format.rich_text.clone(),
            ),
            ("@GHC_SL_LAYOUT".to_string(), "02:wide".to_string()),
            ("status-left-length".to_string(), "92".to_string()),
            ("status-right-length".to_string(), "84".to_string()),
            ("status-interval".to_string(), "1".to_string()),
        ]));

        assert!(!cache_matches(&context, &status));
    }

    #[test]
    fn cache_misses_when_status_interval_is_stale() {
        let status = rendered_status(&"x".repeat(68));
        let context = context_with_options(BTreeMap::from([
            (
                "@GHC_SL_STATUS02_LEFT".to_string(),
                status.status_left.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_RIGHT".to_string(),
                status.status_right.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_SESSION_FORMAT".to_string(),
                status.session_format.rich_text.clone(),
            ),
            (
                "@GHC_SL_STATUS02_CURRENT_FORMAT".to_string(),
                status.current_format.rich_text.clone(),
            ),
            ("@GHC_SL_LAYOUT".to_string(), "02:wide".to_string()),
            ("status-left-length".to_string(), "70".to_string()),
            ("status-interval".to_string(), "20".to_string()),
        ]));

        assert!(!cache_matches(&context, &status));
    }

    fn rendered_status(value: &str) -> RenderedStatus {
        let segment = RenderedSegment {
            literal_text: value.to_string(),
            rich_text: value.to_string(),
        };
        RenderedStatus {
            status_left: segment.clone(),
            status_right: segment.clone(),
            session_format: segment.clone(),
            current_format: segment,
        }
    }

    fn context_with_options(options: BTreeMap<String, String>) -> RenderContext {
        RenderContext {
            snapshot: TmuxSnapshot {
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
            },
            group: SessionGroupView {
                current_session_name: "s".to_string(),
                sessions: Vec::new(),
            },
            layout: LayoutPlan {
                mode: StatusMode::TopAdaptive,
                position: StatusPosition::Top,
                kind: LayoutKind::Wide,
                rows: 1,
                target_status: "on".to_string(),
                key: "02:wide".to_string(),
            },
        }
    }
}
