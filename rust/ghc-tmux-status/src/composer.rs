use crate::config::STATUS_REDRAW_INTERVAL_SECONDS_STR;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment, RenderedStatus};
use crate::status_length::{status_left_length, status_right_length};
use crate::status_widget::{StatusWidget, computed, template};
use crate::widget::{
    CpuWidget, DateWidget, DurationWidget, FullscreenWidget, HostWidget, MemoryWidget,
    NetworkWidget, PrefixIndicatorWidget, SessionListWidget, TimeWidget, WindowIdWidget,
};

/// Renders the status02 layout once and returns the rendered segments plus any
/// structural option writes. Dynamic metrics are sampler-owned indirect tmux
/// references, not render-time samples.
///
/// Each widget type is instantiated exactly once. The single-row and two-row
/// layouts share the rendered sub-segments (prefix / window chrome / metrics):
/// segment concatenation is associative, so composing the shared pieces is
/// byte-identical to rendering each row independently.
pub fn render_status02(
    context: &RenderContext,
    event: &RenderEvent,
) -> AppResult<(RenderedStatus, Vec<(String, String)>)> {
    let mut host = computed(HostWidget);
    let mut session_list = computed(SessionListWidget);
    let mut left_widgets: [&mut dyn StatusWidget; 2] = [&mut host, &mut session_list];
    let status_left = render_widgets(&mut left_widgets, context, event)?;

    let mut prefix = template(PrefixIndicatorWidget);
    let mut prefix_widgets: [&mut dyn StatusWidget; 1] = [&mut prefix];
    let prefix_segment = render_widgets(&mut prefix_widgets, context, event)?;

    let mut fullscreen = template(FullscreenWidget);
    let mut window_id = template(WindowIdWidget);
    let mut chrome_widgets: [&mut dyn StatusWidget; 2] = [&mut fullscreen, &mut window_id];
    let chrome_segment = render_widgets(&mut chrome_widgets, context, event)?;

    let mut network = template(NetworkWidget);
    let mut cpu = template(CpuWidget);
    let mut memory = template(MemoryWidget);
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
    let metric_segment = render_widgets(&mut metric_widgets, context, event)?;

    let status_right_body = concat_segments(&[&prefix_segment, &chrome_segment, &metric_segment]);
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
        Vec::new(),
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

fn render_widgets(
    widgets: &mut [&mut dyn StatusWidget],
    context: &RenderContext,
    _event: &RenderEvent,
) -> AppResult<RenderedSegment> {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for widget in widgets {
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
            .is_some_and(|value| value == STATUS_REDRAW_INTERVAL_SECONDS_STR)
        && context.snapshot.status == context.layout.target_status
}

fn native_window_list_format() -> &'static str {
    "#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}"
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{cache_matches, format_current_format, render_status02};
    use crate::config::STATUS_REDRAW_INTERVAL_SECONDS_STR;
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderEvent, RenderedSegment, RenderedStatus,
        SessionGroupView, SessionInfo, StatusMode, StatusPosition, TmuxSnapshot,
    };

    #[test]
    fn current_format_keeps_native_window_list() {
        let formatted = format_current_format("RIGHT");
        assert!(formatted.contains("#{W:"));
        assert!(formatted.contains("RIGHT"));
    }

    // The contract tests below lock the structural invariants of render_status02 —
    // row composition, shared sub-segment reuse, chrome routing, wrappers, metric
    // order, and cache-write behavior. They deliberately assert structure (markers,
    // ordering, presence/absence) rather than any color/style value, so intentional
    // theme tweaks do not churn them; only a structural regression breaks them.
    //
    // Stable text markers come from Template widgets (fixed strings): window_id
    // `@00`, fullscreen `00/00`, time `00:00:00`. Dynamic metrics render as
    // indirect tmux options, so these contract tests never sample the host.

    #[test]
    fn render_status02_composes_row0_as_left_then_shared_right() {
        let context = contract_context();
        let (rendered, _) = render_status02(&context, &RenderEvent::manual_apply()).unwrap();

        // session_format is literally status_left ++ row0_right, so status_left is a
        // prefix of it. This locks the line 65-72 composition.
        assert!(
            rendered
                .session_format
                .literal_text
                .starts_with(&rendered.status_left.literal_text)
        );
    }

    #[test]
    fn render_status02_shares_metric_tail_across_both_rows() {
        let context = contract_context();
        let (rendered, _) = render_status02(&context, &RenderEvent::manual_apply()).unwrap();

        // Associativity witness: the metric block is rendered once and is the tail of
        // both the status_right body and the session row0_right, with each appending
        // exactly `#[default]` after it. So the suffix from the first metric marker to
        // end must be byte-identical across the two rows. This is the strong form: a
        // regression that drops network/cpu/memory/duration from the session row (or
        // otherwise desyncs the two metric blocks) breaks the equality, whereas a mere
        // "both rows contain time" check would not. Ordering (asserted on status_right
        // below) therefore transitively holds for the session row too.
        let right_rich = &rendered.status_right.rich_text;
        let session_rich = &rendered.session_format.rich_text;
        let right_tail = &right_rich[right_rich.find("@GHC_SYM_NET").expect("network in right")..];
        let session_tail = &session_rich[session_rich
            .find("@GHC_SYM_NET")
            .expect("network in session")..];
        assert_eq!(right_tail, session_tail);

        let right_literal = &rendered.status_right.literal_text;
        let session_literal = &rendered.session_format.literal_text;
        let right_literal_tail =
            &right_literal[right_literal.find('↓').expect("network in right literal")..];
        let session_literal_tail = &session_literal[session_literal
            .find('↓')
            .expect("network in session literal")..];
        assert_eq!(right_literal_tail, session_literal_tail);
        assert!(right_literal_tail.ends_with(" 00:00:00 "));
    }

    #[test]
    fn render_status02_routes_chrome_into_status_right_only() {
        let context = contract_context();
        let (rendered, _) = render_status02(&context, &RenderEvent::manual_apply()).unwrap();

        // Chrome (fullscreen + window_id) belongs to status_right and the per-session
        // current_format, never to the session row (row0_right = prefix + metric only).
        assert!(rendered.status_right.literal_text.contains("@00"));
        assert!(rendered.status_right.literal_text.contains("00/00"));
        assert!(!rendered.session_format.literal_text.contains("@00"));
        assert!(!rendered.session_format.literal_text.contains("00/00"));
    }

    #[test]
    fn render_status02_wraps_rows_with_default_and_align() {
        let context = contract_context();
        let (rendered, _) = render_status02(&context, &RenderEvent::manual_apply()).unwrap();

        assert!(rendered.status_right.rich_text.starts_with("#[default] "));
        assert!(rendered.status_right.rich_text.ends_with("#[default]"));
        assert!(rendered.session_format.rich_text.contains("#[align=left]"));
        assert!(rendered.session_format.rich_text.contains("#[align=right]"));
        assert!(rendered.current_format.rich_text.contains("#{W:"));
        assert!(rendered.current_format.rich_text.contains("#[list=on"));
    }

    #[test]
    fn render_status02_orders_metrics_left_to_right() {
        let context = contract_context();
        let (rendered, _) = render_status02(&context, &RenderEvent::manual_apply()).unwrap();
        let rich = &rendered.status_right.rich_text;

        // Intended metric order: network, cpu, memory, duration, date, time. Keyed on
        // glyph-identity symbols (which metric), not styles. A deliberate reorder is a
        // semantic change and updates this single assertion.
        let net = rich.find("@GHC_SYM_NET").expect("network symbol");
        let cpu = rich.find("@GHC_SYM_CPU").expect("cpu symbol");
        let memory = rich.find("@GHC_SYM_MEMORY").expect("memory symbol");
        let duration = rich.find("@GHC_SYM_DURATION").expect("duration symbol");
        let date = rich.find("%a, %d %b").expect("date template");
        let time = rich.find("%H:%M:%S").expect("time template");

        assert!(net < cpu);
        assert!(cpu < memory);
        assert!(memory < duration);
        assert!(duration < date);
        assert!(date < time);
    }

    #[test]
    fn render_status02_writes_no_cache_options_for_sampler_metrics() {
        let context = contract_context();
        let (_, cache_options) = render_status02(&context, &RenderEvent::manual_apply()).unwrap();

        // Dynamic metrics are sampler-owned indirect options; render never writes
        // metric cache options. This underpins the noop short-circuit in
        // StatusRuntime::apply (cache_options.is_empty()).
        assert!(cache_options.is_empty());
    }

    fn contract_context() -> RenderContext {
        let options = BTreeMap::new();
        let sessions = vec![SessionInfo {
            id: "$1".to_string(),
            name: "main".to_string(),
            has_bell: false,
        }];

        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                current_layout: "02:wide".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "main".to_string(),
                client_last_session: String::new(),
                host: "h".to_string(),
                // Far-future start ⇒ saturating duration pins to "0m", no wall-clock drift.
                session_created: 9_999_999_999,
                sessions: sessions.clone(),
                options,
            },
            group: SessionGroupView {
                current_session_name: "main".to_string(),
                sessions,
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
            (
                "status-interval".to_string(),
                STATUS_REDRAW_INTERVAL_SECONDS_STR.to_string(),
            ),
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
            (
                "status-interval".to_string(),
                STATUS_REDRAW_INTERVAL_SECONDS_STR.to_string(),
            ),
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
            (
                "status-interval".to_string(),
                STATUS_REDRAW_INTERVAL_SECONDS_STR.to_string(),
            ),
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
