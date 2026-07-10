use crate::config::{
    STATUS_INTERVAL_OPTION, STATUS_JUSTIFY_OPTION, STATUS_JUSTIFY_VALUE, STATUS_LEFT_FORMAT,
    STATUS_LEFT_OPTION, STATUS_POSITION_OPTION, STATUS_REDRAW_INTERVAL_SECONDS_STR,
    STATUS_RIGHT_FORMAT, STATUS_RIGHT_OPTION,
};
use crate::error::AppResult;
use crate::model::{RenderContext, RenderedSegment, RenderedStatus};
use crate::status_widget::{StatusWidget, computed, template};
use crate::util::width::display_width;
use crate::widget::{
    CpuWidget, DateWidget, DurationWidget, FullscreenWidget, HostWidget, MemoryWidget,
    NetworkWidget, PrefixIndicatorWidget, SessionListWidget, TimeWidget, WindowIdWidget,
};

// Responsive metric priority: a higher keep_rank is dropped later. `responsive_metric_segment`
// accumulates thresholds in this rank order, so the on-screen drop order is
// duration → date → memory → cpu → network, with time (the max rank) always kept.
// Display order (network … time, left→right) is independent and fixed by the metric list.
const RANK_DURATION: u8 = 1;
const RANK_DATE: u8 = 2;
const RANK_MEMORY: u8 = 3;
const RANK_CPU: u8 = 4;
const RANK_NETWORK: u8 = 5;
const RANK_TIME: u8 = 6;

/// Purely renders the status02 layout. Dynamic metrics are sampler-owned indirect
/// tmux references, not render-time samples or composer-owned cache writes.
///
/// Each widget type is instantiated exactly once. The single-row and two-row
/// layouts share the rendered sub-segments (prefix / window indicators / metrics):
/// segment concatenation is associative, so composing the shared pieces is
/// byte-identical to rendering each row independently.
pub fn render_status02(
    context: &RenderContext,
    metrics_supported: bool,
) -> AppResult<RenderedStatus> {
    let mut host = computed(HostWidget);
    let mut session_list = computed(SessionListWidget);
    let mut left_widgets: [&mut dyn StatusWidget; 2] = [&mut host, &mut session_list];
    let status_left = render_widgets(&mut left_widgets, context)?;

    let mut prefix = template(PrefixIndicatorWidget);
    let mut prefix_widgets: [&mut dyn StatusWidget; 1] = [&mut prefix];
    let prefix_segment = render_widgets(&mut prefix_widgets, context)?;

    let mut fullscreen = template(FullscreenWidget);
    let mut window_id = template(WindowIdWidget);
    let mut window_indicator_widgets: [&mut dyn StatusWidget; 2] =
        [&mut fullscreen, &mut window_id];
    let window_indicator_segment = render_widgets(&mut window_indicator_widgets, context)?;

    let network = template(NetworkWidget).render(context)?;
    let cpu = template(CpuWidget).render(context)?;
    let memory = template(MemoryWidget).render(context)?;
    let duration = computed(DurationWidget).render(context)?;
    let date = template(DateWidget).render(context)?;
    let time = template(TimeWidget).render(context)?;
    // Display order left→right; keep_rank carries the responsive priority. time has the
    // max rank and stays unconditional, so it is the last metric standing before tmux
    // char-truncation takes over. Platforms without a metrics provider (everything but
    // macOS) never publish CPU/memory/network values, so those pills are omitted entirely
    // here; the width-priority drop then applies to whatever metrics remain.
    let mut metrics: Vec<(RenderedSegment, u8)> = Vec::new();
    if metrics_supported {
        metrics.push((network, RANK_NETWORK));
        metrics.push((cpu, RANK_CPU));
        metrics.push((memory, RANK_MEMORY));
    }
    metrics.push((duration, RANK_DURATION));
    metrics.push((date, RANK_DATE));
    metrics.push((time, RANK_TIME));
    // Base is the width the metric block competes against on the shared narrow row:
    // host + session list (status_left) + prefix reserve. display_width matches tmux's
    // cell accounting (powerline/nerd glyphs are single-width PUA, CJK double), so the
    // narrow thresholds are exact — no slack. The prefix is reserved at its worst case
    // (the same literal shadow status-*-length uses) so an active prefix indicator never
    // overflows a metric. The wide row additionally carries the window indicators and a
    // centered window list that are intentionally not counted — wide clients are roomy,
    // and any residual overflow falls back to tmux truncation.
    let metric_base = display_width(&status_left.literal_text)
        .saturating_add(display_width(&prefix_segment.literal_text));
    let metric_segment = responsive_metric_segment(&metrics, metric_base);

    let status_right_body =
        concat_segments(&[&prefix_segment, &window_indicator_segment, &metric_segment]);
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
        literal_text: window_indicator_segment.literal_text.clone(),
        rich_text: format_current_format(&window_indicator_segment.rich_text),
    };

    Ok(RenderedStatus {
        status_left,
        status_right,
        session_format,
        current_format,
    })
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

/// Wraps each droppable metric in a `#{?#{e|>=:#{client_width},N},…,}` guard so tmux
/// keeps it, per attached client, only when the bar is wide enough. A metric's threshold
/// is `base` plus the pessimistic widths of every metric whose keep_rank is at least as
/// high — so a metric appears only once everything higher-priority already fits, which
/// makes the visible set a clean prefix of the priority order. The single highest rank
/// (time) is emitted unconditionally; when even it overflows, tmux char-truncation is the
/// final fallback.
///
/// `literal_text` stays the full metric block: it is the width shadow for status-*-length,
/// whose worst case is a wide client showing every metric. The numeric `#{e|>=:}` form is
/// required — the lexicographic `#{>=:}` would mis-order widths like 92 vs 120.
fn responsive_metric_segment(metrics: &[(RenderedSegment, u8)], base: usize) -> RenderedSegment {
    let max_rank = metrics.iter().map(|(_, rank)| *rank).max().unwrap_or(0);
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for (segment, rank) in metrics {
        literal_text.push_str(&segment.literal_text);
        if *rank == max_rank {
            rich_text.push_str(&segment.rich_text);
            continue;
        }
        let threshold: usize = base
            + metrics
                .iter()
                .filter(|(_, other_rank)| *other_rank >= *rank)
                .map(|(other, _)| display_width(&other.literal_text))
                .sum::<usize>();
        // Make the rich text safe as a `#{?cond,<branch>,}` argument:
        //  - `escape_conditional_branch` escapes bare literal commas (e.g. DateWidget's
        //    `%a, %d %b`), which would otherwise split the conditional's arguments and
        //    truncate the metric.
        //  - `%%` → `%%%%`: tmux expands a conditional branch twice, so an escaped
        //    percent `%%` collapses to `%` then is eaten as a stray strftime `%` on the
        //    second pass; doubling leaves exactly one `%`. strftime fields (`%a`, `%H`)
        //    are a single `%` that resolves to text on the first pass, so they survive.
        let guarded_rich = escape_conditional_branch(&segment.rich_text).replace("%%", "%%%%");
        rich_text.push_str("#{?#{e|>=:#{client_width},");
        rich_text.push_str(&threshold.to_string());
        rich_text.push_str("},");
        rich_text.push_str(&guarded_rich);
        rich_text.push_str(",}");
    }
    RenderedSegment {
        literal_text,
        rich_text,
    }
}

/// Escapes a metric's rich text so it is safe as a `#{?cond,<branch>,}` argument. Inside a
/// conditional a bare literal `,` is an argument separator, so it must be `#,` — but only
/// when it is real branch text, not part of a `#{...}` replacement (where `,` is operator
/// syntax). Existing `#x` escape pairs (`#,`, `##`, `#{`, `#[`) pass through untouched, and
/// `}` that closes a tracked `#{...}` is left alone; only bare commas at replacement depth 0
/// (e.g. DateWidget's `%a, %d %b`) are escaped.
fn escape_conditional_branch(rich: &str) -> String {
    let mut out = String::with_capacity(rich.len() + 8);
    let mut chars = rich.chars();
    let mut replacement_depth: usize = 0;
    while let Some(ch) = chars.next() {
        match ch {
            '#' => {
                out.push('#');
                if let Some(next) = chars.next() {
                    if next == '{' {
                        replacement_depth += 1;
                    }
                    out.push(next);
                }
            }
            '}' if replacement_depth > 0 => {
                replacement_depth -= 1;
                out.push('}');
            }
            ',' if replacement_depth == 0 => out.push_str("#,"),
            other => out.push(other),
        }
    }
    out
}

fn render_widgets(
    widgets: &mut [&mut dyn StatusWidget],
    context: &RenderContext,
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

/// Full global STYLE witness: rendered templates, their `status-left` / `status-right`
/// bindings, position, justification, and redraw interval. Per-session LAYOUT values
/// (rows, lengths, `@GHC_SL_LAYOUT`) are checked by [`session_layouts_settled`].
pub fn cache_matches(context: &RenderContext, rendered: &RenderedStatus) -> bool {
    let options = &context.snapshot.options;
    option_matches(
        options,
        "@GHC_SL_STATUS02_LEFT",
        &rendered.status_left.rich_text,
    ) && option_matches(
        options,
        "@GHC_SL_STATUS02_RIGHT",
        &rendered.status_right.rich_text,
    ) && option_matches(
        options,
        "@GHC_SL_STATUS02_SESSION_FORMAT",
        &rendered.session_format.rich_text,
    ) && option_matches(
        options,
        "@GHC_SL_STATUS02_CURRENT_FORMAT",
        &rendered.current_format.rich_text,
    ) && option_matches(options, STATUS_LEFT_OPTION, STATUS_LEFT_FORMAT)
        && option_matches(options, STATUS_RIGHT_OPTION, STATUS_RIGHT_FORMAT)
        && option_matches(
            options,
            STATUS_POSITION_OPTION,
            context.layout.position.as_str(),
        )
        && option_matches(options, STATUS_JUSTIFY_OPTION, STATUS_JUSTIFY_VALUE)
        // Prevent stale 20s redraw from being mistaken for a status02 no-op after cache convergence.
        && option_matches(
            options,
            STATUS_INTERVAL_OPTION,
            STATUS_REDRAW_INTERVAL_SECONDS_STR,
        )
}

fn option_matches(
    options: &std::collections::BTreeMap<String, String>,
    name: &str,
    expected: &str,
) -> bool {
    options.get(name).is_some_and(|value| value == expected)
}

fn native_window_list_format() -> &'static str {
    "#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}"
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        RANK_CPU, RANK_DATE, RANK_DURATION, RANK_MEMORY, RANK_NETWORK, RANK_TIME, cache_matches,
        escape_conditional_branch, format_current_format, render_status02,
        responsive_metric_segment,
    };
    use crate::config::{
        STATUS_INTERVAL_OPTION, STATUS_JUSTIFY_OPTION, STATUS_JUSTIFY_VALUE, STATUS_LEFT_FORMAT,
        STATUS_LEFT_OPTION, STATUS_POSITION_OPTION, STATUS_REDRAW_INTERVAL_SECONDS_STR,
        STATUS_RIGHT_FORMAT, STATUS_RIGHT_OPTION,
    };
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderedSegment, RenderedStatus, SessionGroupView,
        SessionInfo, StatusMode, StatusPosition, TmuxSnapshot,
    };

    fn metric_seg(tag: &str) -> RenderedSegment {
        // ASCII tags keep display_width == byte length, so thresholds are hand-checkable.
        RenderedSegment {
            literal_text: tag.to_string(),
            rich_text: tag.to_string(),
        }
    }

    // network … time, mirroring render_status02's display order; widths NET/CPU/MEM/DUR=3,
    // DATE/TIME=4.
    fn priority_metrics() -> [(RenderedSegment, u8); 6] {
        [
            (metric_seg("NET"), RANK_NETWORK),
            (metric_seg("CPU"), RANK_CPU),
            (metric_seg("MEM"), RANK_MEMORY),
            (metric_seg("DUR"), RANK_DURATION),
            (metric_seg("DATE"), RANK_DATE),
            (metric_seg("TIME"), RANK_TIME),
        ]
    }

    #[test]
    fn responsive_metric_literal_keeps_full_block_as_width_shadow() {
        let segment = responsive_metric_segment(&priority_metrics(), 10);
        assert_eq!(segment.literal_text, "NETCPUMEMDURDATETIME");
    }

    #[test]
    fn responsive_metric_guards_every_droppable_and_frees_time() {
        let segment = responsive_metric_segment(&priority_metrics(), 10);
        // Five droppable metrics get a client_width guard; time (max rank) does not.
        assert_eq!(
            segment
                .rich_text
                .matches("#{?#{e|>=:#{client_width},")
                .count(),
            5
        );
        assert!(!segment.rich_text.contains(",TIME,}"));
        assert!(segment.rich_text.ends_with("TIME"));
    }

    #[test]
    fn responsive_metric_threshold_grows_as_priority_drops() {
        // threshold(metric) = base + Σ widths of metrics with keep_rank >= its rank.
        // base 10, widths NET3 CPU3 MEM3 DUR3 DATE4 TIME4:
        //   network(5): 10 + NET+TIME            = 17
        //   cpu(4):     10 + CPU+NET+TIME         = 20
        //   memory(3):  10 + MEM+CPU+NET+TIME     = 23
        //   date(2):    10 + DATE+MEM+CPU+NET+TIME= 27
        //   duration(1):10 + all six             = 30
        let segment = responsive_metric_segment(&priority_metrics(), 10);
        assert!(segment.rich_text.contains("#{client_width},17},NET,}"));
        assert!(segment.rich_text.contains("#{client_width},20},CPU,}"));
        assert!(segment.rich_text.contains("#{client_width},23},MEM,}"));
        assert!(segment.rich_text.contains("#{client_width},27},DATE,}"));
        assert!(segment.rich_text.contains("#{client_width},30},DUR,}"));
    }

    #[test]
    fn escape_conditional_branch_escapes_only_bare_commas() {
        // Bare literal comma (DateWidget's `%a, %d %b`) must be escaped so it does not
        // split the conditional arguments and truncate the metric to the weekday.
        assert_eq!(escape_conditional_branch("%a, %d %b"), "%a#, %d %b");
        // Already-escaped style commas pass through unchanged (no double escaping).
        assert_eq!(
            escape_conditional_branch("#[fg=x#,bg=y]A"),
            "#[fg=x#,bg=y]A"
        );
        // A comma that is operator syntax inside a `#{...}` replacement is left alone.
        assert_eq!(escape_conditional_branch("#{s:a,b:c}"), "#{s:a,b:c}");
        // A bare comma after a closed replacement is still escaped.
        assert_eq!(escape_conditional_branch("#{@X}, y"), "#{@X}#, y");
    }

    #[test]
    fn responsive_metric_guards_escape_branch_commas() {
        // A guarded metric whose rich carries a bare comma must emit it escaped, so the
        // true branch survives whole; the unconditional max-rank metric is emitted raw.
        let metrics = [
            (metric_seg("%a, %d %b"), RANK_DATE),
            (metric_seg("T, Z"), RANK_TIME),
        ];
        let rendered = responsive_metric_segment(&metrics, 10);
        assert!(rendered.rich_text.contains("%a#, %d %b,}"));
        assert!(rendered.rich_text.ends_with("T, Z"));
    }

    #[test]
    fn responsive_metric_doubles_literal_percent_only_when_guarded() {
        // cpu/memory emit an escaped literal percent `%%`; inside a guard it must become
        // `%%%%` to survive tmux's double branch expansion. The unconditional max-rank
        // metric keeps the single `%%`.
        let metrics = [
            (metric_seg("#{@CPU}%% "), RANK_CPU),
            (metric_seg("TIME%% "), RANK_TIME),
        ];
        let rendered = responsive_metric_segment(&metrics, 10);
        assert!(rendered.rich_text.contains("#{@CPU}%%%% ,}"));
        assert!(rendered.rich_text.ends_with("TIME%% "));
        assert!(!rendered.rich_text.contains("TIME%%%%"));
    }

    #[test]
    fn responsive_metric_base_lifts_every_threshold() {
        // A wider base (more sessions on the shared row) pushes every guard up by the
        // same delta, so metrics drop earlier as the left side grows.
        let lo = responsive_metric_segment(&priority_metrics(), 10);
        let hi = responsive_metric_segment(&priority_metrics(), 20);
        assert!(lo.rich_text.contains("#{client_width},17},NET,}"));
        assert!(hi.rich_text.contains("#{client_width},27},NET,}"));
    }

    #[test]
    fn current_format_keeps_native_window_list() {
        let formatted = format_current_format("RIGHT");
        assert!(formatted.contains("#{W:"));
        assert!(formatted.contains("RIGHT"));
    }

    // The contract tests below lock the structural invariants of render_status02 —
    // row composition, shared sub-segment reuse, window-indicator routing, wrappers, metric
    // order, and provider-dependent visibility. They deliberately assert structure
    // (markers, ordering, presence/absence) rather than any color/style value, so
    // intentional theme tweaks do not churn them; only a structural regression breaks them.
    //
    // Stable text markers come from Template widgets (fixed strings): window_id
    // `@00`, fullscreen `00/00`, time `00:00:00`. Dynamic metrics render as
    // indirect tmux options, so these contract tests never sample the host.

    #[test]
    fn render_status02_composes_row0_as_left_then_shared_right() {
        let context = contract_context();
        let rendered = render_status02(&context, true).unwrap();

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
        let rendered = render_status02(&context, true).unwrap();

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
    fn render_status02_routes_window_indicators_into_status_right_only() {
        let context = contract_context();
        let rendered = render_status02(&context, true).unwrap();

        // The window indicators (fullscreen + window_id) belong to status_right and the
        // per-session current_format, never to the session row (row0_right = prefix +
        // metric only).
        assert!(rendered.status_right.literal_text.contains("@00"));
        assert!(rendered.status_right.literal_text.contains("00/00"));
        assert!(!rendered.session_format.literal_text.contains("@00"));
        assert!(!rendered.session_format.literal_text.contains("00/00"));
    }

    #[test]
    fn render_status02_wraps_rows_with_default_and_align() {
        let context = contract_context();
        let rendered = render_status02(&context, true).unwrap();

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
        let rendered = render_status02(&context, true).unwrap();
        let rich = &rendered.status_right.rich_text;

        // Intended metric order: network, cpu, memory, duration, date, time. Keyed on
        // glyph-identity symbols (which metric), not styles. A deliberate reorder is a
        // semantic change and updates this single assertion.
        let net = rich.find("@GHC_SYM_NET").expect("network symbol");
        let cpu = rich.find("@GHC_SYM_CPU").expect("cpu symbol");
        let memory = rich.find("@GHC_SYM_MEMORY").expect("memory symbol");
        let duration = rich.find("@GHC_SYM_DURATION").expect("duration symbol");
        // Date's literal comma is escaped to `#,` when wrapped as a conditional branch.
        let date = rich.find("%a#, %d %b").expect("date template");
        let time = rich.find("%H:%M:%S").expect("time template");

        assert!(net < cpu);
        assert!(cpu < memory);
        assert!(memory < duration);
        assert!(duration < date);
        assert!(date < time);
    }

    #[test]
    fn render_status02_omits_metric_pills_without_provider() {
        let context = contract_context();
        let rendered = render_status02(&context, false).unwrap();
        let rich = &rendered.status_right.rich_text;

        // No metrics provider ⇒ network/cpu/memory pills are dropped, but the
        // always-on duration/date/time tail still renders.
        assert!(!rich.contains("@GHC_SYM_NET"));
        assert!(!rich.contains("@GHC_SYM_CPU"));
        assert!(!rich.contains("@GHC_SYM_MEMORY"));
        assert!(rich.contains("@GHC_SYM_DURATION"));
        assert!(rich.contains("%H:%M:%S"));
    }

    fn contract_context() -> RenderContext {
        let options = BTreeMap::new();
        let sessions = vec![SessionInfo {
            id: "$1".to_string(),
            name: "main".to_string(),
            has_bell: false,
            status: "on".to_string(),
            layout_key: "02:wide".to_string(),
            left_length: "64".to_string(),
            right_length: "84".to_string(),
        }];

        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "main".to_string(),
                client_last_session: String::new(),
                host: "h".to_string(),
                // Far-future start ⇒ saturating duration pins to "0m", no wall-clock drift.
                session_created: 9_999_999_999,
                sessions: sessions.clone(),
                client_widths: Vec::new(),
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
            session_layouts: Vec::new(),
        }
    }

    #[test]
    fn cache_matches_on_global_style_and_interval() {
        let status = rendered_status(&"x".repeat(68));
        let context = context_with_options(settled_global_options(&status));

        assert!(cache_matches(&context, &status));
    }

    #[test]
    fn cache_misses_when_status_interval_is_stale() {
        let status = rendered_status(&"x".repeat(68));
        let mut options = settled_global_options(&status);
        options.insert(STATUS_INTERVAL_OPTION.to_string(), "20".to_string());
        let context = context_with_options(options);

        assert!(!cache_matches(&context, &status));
    }

    #[test]
    fn cache_misses_when_owned_global_style_drifted() {
        let status = rendered_status(&"x".repeat(68));
        let mut options = settled_global_options(&status);
        options.insert(STATUS_LEFT_OPTION.to_string(), "drifted".to_string());
        let context = context_with_options(options);

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

    fn settled_global_options(status: &RenderedStatus) -> BTreeMap<String, String> {
        BTreeMap::from([
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
            (
                STATUS_LEFT_OPTION.to_string(),
                STATUS_LEFT_FORMAT.to_string(),
            ),
            (
                STATUS_RIGHT_OPTION.to_string(),
                STATUS_RIGHT_FORMAT.to_string(),
            ),
            (STATUS_POSITION_OPTION.to_string(), "top".to_string()),
            (
                STATUS_JUSTIFY_OPTION.to_string(),
                STATUS_JUSTIFY_VALUE.to_string(),
            ),
            (
                STATUS_INTERVAL_OPTION.to_string(),
                STATUS_REDRAW_INTERVAL_SECONDS_STR.to_string(),
            ),
        ])
    }

    fn context_with_options(options: BTreeMap<String, String>) -> RenderContext {
        RenderContext {
            snapshot: TmuxSnapshot {
                mode: "02".to_string(),
                status: "on".to_string(),
                width: 200,
                current_session_name: "s".to_string(),
                client_last_session: String::new(),
                host: "h".to_string(),
                session_created: 1,
                sessions: Vec::new(),
                client_widths: Vec::new(),
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
            session_layouts: Vec::new(),
        }
    }
}
