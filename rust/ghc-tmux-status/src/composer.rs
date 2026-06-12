use crate::cache::ComponentCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment, RenderedStatus};
use crate::status_component::{ComponentInterests, StatusComponent};

pub fn render_components(
    components: &mut [&mut dyn StatusComponent],
    context: &RenderContext,
    event: &RenderEvent,
    cache: &mut dyn ComponentCache,
) -> AppResult<RenderedSegment> {
    let mut literal_text = String::new();
    let mut rich_text = String::new();
    for component in components {
        let interests = component.interests();
        if interests.matches(event) || !matches!(interests, ComponentInterests::Static) {
            component.snapshot(context, event, cache)?;
        }
        let segment = component.render(context)?;
        literal_text.push_str(&segment.literal_text);
        rich_text.push_str(&segment.rich_text);
    }
    Ok(RenderedSegment {
        literal_text,
        rich_text,
    })
}

pub fn format_current_format(row_right: &str) -> String {
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
        && context.snapshot.status == context.layout.target_status
}

fn native_window_list_format() -> &'static str {
    "#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{window-status-separator}}}"
}

#[cfg(test)]
mod tests {
    use super::format_current_format;

    #[test]
    fn current_format_keeps_native_window_list() {
        let formatted = format_current_format("RIGHT");
        assert!(formatted.contains("#{W:"));
        assert!(formatted.contains("RIGHT"));
    }
}
