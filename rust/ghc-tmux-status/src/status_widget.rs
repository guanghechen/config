use crate::cache::WidgetCache;
use crate::error::AppResult;
use crate::model::{RenderContext, RenderEvent, RenderedSegment};
use crate::observability::{trace_enabled, trace_line};
use crate::util::time::unix_timestamp_seconds;

pub trait StatusWidget {
    fn id(&self) -> &'static str;
    fn lifecycle(&self) -> WidgetLifecycle;

    fn refresh(
        &mut self,
        _context: &RenderContext,
        _event: &RenderEvent,
        _cache: &mut dyn WidgetCache,
    ) -> AppResult<()> {
        Ok(())
    }

    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WidgetLifecycle {
    /// Native tmux template. No Rust refresh/cache; safe to render every tick.
    Template,
    /// Cheap process-local computation from context or local time. No external IO/cache.
    Computed,
    /// Expensive sampling controlled by the shared cache TTL adapter.
    CachedMetric { ttl_seconds: u64 },
}

pub trait TemplateWidget {
    fn id(&self) -> &'static str;
    fn render_template(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

pub trait ComputedWidget {
    fn id(&self) -> &'static str;
    fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}

pub trait CachedMetricWidget {
    type Snapshot: Clone;

    fn id(&self) -> &'static str;
    fn ttl_seconds(&self) -> u64;
    fn timestamp_seconds(&self, snapshot: &Self::Snapshot) -> u64;
    fn decode_cache(&self, value: &str) -> Option<Self::Snapshot>;
    fn encode_cache(&self, snapshot: &Self::Snapshot) -> String;
    fn sample(&self, previous: Option<&Self::Snapshot>) -> AppResult<Self::Snapshot>;
    fn render_snapshot(&self, snapshot: &Self::Snapshot) -> RenderedSegment;

    fn should_refresh(&self, _event: &RenderEvent) -> bool {
        // Sampling cadence is governed by the TTL age check, not by event kind.
        // Returning true for every event keeps new hooks/events from silently
        // freezing metrics; the TTL remains the real throttle.
        true
    }
}

pub struct Template<T> {
    widget: T,
}

pub struct Computed<T> {
    widget: T,
}

pub struct CachedMetric<T: CachedMetricWidget> {
    widget: T,
    snapshot: Option<T::Snapshot>,
}

pub fn template<T: TemplateWidget>(widget: T) -> Template<T> {
    Template { widget }
}

pub fn computed<T: ComputedWidget>(widget: T) -> Computed<T> {
    Computed { widget }
}

pub fn cached_metric<T: CachedMetricWidget>(widget: T) -> CachedMetric<T> {
    CachedMetric {
        widget,
        snapshot: None,
    }
}

impl<T: TemplateWidget> StatusWidget for Template<T> {
    fn id(&self) -> &'static str {
        self.widget.id()
    }

    fn lifecycle(&self) -> WidgetLifecycle {
        WidgetLifecycle::Template
    }

    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        self.widget.render_template(context)
    }
}

impl<T: ComputedWidget> StatusWidget for Computed<T> {
    fn id(&self) -> &'static str {
        self.widget.id()
    }

    fn lifecycle(&self) -> WidgetLifecycle {
        WidgetLifecycle::Computed
    }

    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
        self.widget.render_computed(context)
    }
}

impl<T: CachedMetricWidget> StatusWidget for CachedMetric<T> {
    fn id(&self) -> &'static str {
        self.widget.id()
    }

    fn lifecycle(&self) -> WidgetLifecycle {
        WidgetLifecycle::CachedMetric {
            ttl_seconds: self.widget.ttl_seconds(),
        }
    }

    fn refresh(
        &mut self,
        _context: &RenderContext,
        event: &RenderEvent,
        cache: &mut dyn WidgetCache,
    ) -> AppResult<()> {
        let cached = cache
            .get(self.id())
            .and_then(|value| self.widget.decode_cache(value));
        if let Some(snapshot) = cached.clone() {
            let age_seconds = self.age_seconds(&snapshot);
            if !self.widget.should_refresh(event) {
                self.trace_refresh(|| format!(
                    "id={} action=cache-hit reason=event-skip event={} age_seconds={} ttl_seconds={}",
                    self.id(),
                    event.kind.as_str(),
                    age_seconds,
                    self.widget.ttl_seconds()
                ));
                self.snapshot = Some(snapshot);
                return Ok(());
            }

            if age_seconds < self.widget.ttl_seconds() {
                self.trace_refresh(|| format!(
                    "id={} action=cache-hit reason=fresh event={} age_seconds={} ttl_seconds={}",
                    self.id(),
                    event.kind.as_str(),
                    age_seconds,
                    self.widget.ttl_seconds()
                ));
                self.snapshot = Some(snapshot);
                return Ok(());
            }
        }

        self.snapshot = match self.widget.sample(cached.as_ref()) {
            Ok(snapshot) => {
                self.trace_refresh(|| {
                    format!(
                        "id={} action=sample-ok event={} ttl_seconds={}",
                        self.id(),
                        event.kind.as_str(),
                        self.widget.ttl_seconds()
                    )
                });
                cache.set(self.id(), self.widget.encode_cache(&snapshot));
                Some(snapshot)
            }
            Err(_) => {
                if cached.is_some() {
                    self.trace_refresh(|| {
                        format!(
                            "id={} action=sample-error fallback=cache event={} ttl_seconds={}",
                            self.id(),
                            event.kind.as_str(),
                            self.widget.ttl_seconds()
                        )
                    });
                } else {
                    self.trace_refresh(|| {
                        format!(
                            "id={} action=sample-error fallback=empty event={} ttl_seconds={}",
                            self.id(),
                            event.kind.as_str(),
                            self.widget.ttl_seconds()
                        )
                    });
                }
                cached
            }
        };
        Ok(())
    }

    fn render(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
        Ok(self
            .snapshot
            .as_ref()
            .map(|snapshot| self.widget.render_snapshot(snapshot))
            .unwrap_or_else(RenderedSegment::empty))
    }
}

impl<T: CachedMetricWidget> CachedMetric<T> {
    fn age_seconds(&self, snapshot: &T::Snapshot) -> u64 {
        unix_timestamp_seconds().saturating_sub(self.widget.timestamp_seconds(snapshot))
    }

    fn trace_refresh(&self, message: impl FnOnce() -> String) {
        if !trace_enabled() {
            return;
        }

        trace_line("metric", message());
    }
}

#[cfg(test)]
mod tests {
    use std::cell::Cell;
    use std::collections::BTreeMap;
    use std::rc::Rc;

    use super::{
        CachedMetricWidget, ComputedWidget, StatusWidget, TemplateWidget, WidgetLifecycle,
        cached_metric, computed, template,
    };
    use crate::cache::{TmuxWidgetCache, WidgetCache};
    use crate::error::{AppError, AppResult};
    use crate::model::{
        LayoutKind, LayoutPlan, RenderContext, RenderEvent, RenderEventKind, RenderedSegment,
        SessionGroupView, StatusMode, StatusPosition, TmuxSnapshot,
    };

    struct FakeTemplate;

    impl TemplateWidget for FakeTemplate {
        fn id(&self) -> &'static str {
            "template"
        }

        fn render_template(&self, _context: &RenderContext) -> AppResult<RenderedSegment> {
            Ok(RenderedSegment {
                literal_text: "template".to_string(),
                rich_text: "template".to_string(),
            })
        }
    }

    struct FakeComputed;

    impl ComputedWidget for FakeComputed {
        fn id(&self) -> &'static str {
            "computed"
        }

        fn render_computed(&self, context: &RenderContext) -> AppResult<RenderedSegment> {
            Ok(RenderedSegment {
                literal_text: context.snapshot.host.clone(),
                rich_text: context.snapshot.host.clone(),
            })
        }
    }

    #[derive(Clone, Debug, Eq, PartialEq)]
    struct FakeSnapshot {
        timestamp_seconds: u64,
        value: u64,
    }

    struct FakeMetric {
        calls: Rc<Cell<usize>>,
        now: u64,
        fails: bool,
    }

    impl CachedMetricWidget for FakeMetric {
        type Snapshot = FakeSnapshot;

        fn id(&self) -> &'static str {
            "fake"
        }

        fn ttl_seconds(&self) -> u64 {
            20
        }

        fn timestamp_seconds(&self, snapshot: &Self::Snapshot) -> u64 {
            snapshot.timestamp_seconds
        }

        fn decode_cache(&self, value: &str) -> Option<Self::Snapshot> {
            let (timestamp_seconds, value) = value.split_once(':')?;
            Some(FakeSnapshot {
                timestamp_seconds: timestamp_seconds.parse().ok()?,
                value: value.parse().ok()?,
            })
        }

        fn encode_cache(&self, snapshot: &Self::Snapshot) -> String {
            format!("{}:{}", snapshot.timestamp_seconds, snapshot.value)
        }

        fn sample(&self, _previous: Option<&Self::Snapshot>) -> AppResult<Self::Snapshot> {
            self.calls.set(self.calls.get() + 1);
            if self.fails {
                return Err(AppError::Render("fake metric sample failed".to_string()));
            }

            Ok(FakeSnapshot {
                timestamp_seconds: self.now,
                value: 42,
            })
        }

        fn render_snapshot(&self, snapshot: &Self::Snapshot) -> RenderedSegment {
            RenderedSegment {
                literal_text: snapshot.value.to_string(),
                rich_text: snapshot.value.to_string(),
            }
        }
    }

    #[test]
    fn template_adapter_renders_without_cache_refresh() {
        let mut widget = template(FakeTemplate);
        let mut cache = TmuxWidgetCache::default();

        widget.refresh(&context(), &tick(), &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(widget.lifecycle(), WidgetLifecycle::Template);
        assert_eq!(segment.literal_text, "template");
        assert!(cache.pending_options().is_empty());
    }

    #[test]
    fn computed_adapter_renders_from_context_without_cache_refresh() {
        let mut widget = computed(FakeComputed);
        let mut cache = TmuxWidgetCache::default();

        widget.refresh(&context(), &tick(), &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(widget.lifecycle(), WidgetLifecycle::Computed);
        assert_eq!(segment.literal_text, "h");
        assert!(cache.pending_options().is_empty());
    }

    #[test]
    fn cached_metric_uses_fresh_cache_without_sampling() {
        let calls = Rc::new(Cell::new(0));
        let mut widget = cached_metric(FakeMetric {
            calls: Rc::clone(&calls),
            now: 100,
            fails: false,
        });
        let mut cache = cache_with_value("9999999999:7");

        widget.refresh(&context(), &tick(), &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(
            widget.lifecycle(),
            WidgetLifecycle::CachedMetric { ttl_seconds: 20 }
        );
        assert_eq!(calls.get(), 0);
        assert_eq!(segment.literal_text, "7");
        assert!(cache.pending_options().is_empty());
    }

    #[test]
    fn cached_metric_samples_and_updates_stale_cache() {
        let calls = Rc::new(Cell::new(0));
        let mut widget = cached_metric(FakeMetric {
            calls: Rc::clone(&calls),
            now: 100,
            fails: false,
        });
        let mut cache = cache_with_value("1:7");

        widget.refresh(&context(), &tick(), &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(calls.get(), 1);
        assert_eq!(segment.literal_text, "42");
        assert_eq!(cache.get("fake"), Some("100:42"));
    }

    #[test]
    fn cached_metric_samples_on_event_hook() {
        let calls = Rc::new(Cell::new(0));
        let mut widget = cached_metric(FakeMetric {
            calls: Rc::clone(&calls),
            now: 100,
            fails: false,
        });
        let mut cache = cache_with_value("1:7");
        let event = RenderEvent {
            kind: RenderEventKind::WindowChanged,
        };

        widget.refresh(&context(), &event, &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(calls.get(), 1);
        assert_eq!(segment.literal_text, "42");
        assert_eq!(cache.get("fake"), Some("100:42"));
    }

    #[test]
    fn cached_metric_sample_failure_falls_back_to_cached_snapshot() {
        let calls = Rc::new(Cell::new(0));
        let mut widget = cached_metric(FakeMetric {
            calls: Rc::clone(&calls),
            now: 100,
            fails: true,
        });
        let mut cache = cache_with_value("1:7");

        widget.refresh(&context(), &tick(), &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(calls.get(), 1);
        assert_eq!(segment.literal_text, "7");
        assert_eq!(cache.get("fake"), Some("1:7"));
        assert!(cache.pending_options().is_empty());
    }

    #[test]
    fn cached_metric_sample_failure_without_cache_renders_empty() {
        let calls = Rc::new(Cell::new(0));
        let mut widget = cached_metric(FakeMetric {
            calls: Rc::clone(&calls),
            now: 100,
            fails: true,
        });
        let mut cache = TmuxWidgetCache::default();

        widget.refresh(&context(), &tick(), &mut cache).unwrap();
        let segment = widget.render(&context()).unwrap();

        assert_eq!(calls.get(), 1);
        assert_eq!(segment, RenderedSegment::empty());
        assert!(cache.pending_options().is_empty());
    }

    fn cache_with_value(value: &str) -> TmuxWidgetCache {
        let mut options = BTreeMap::new();
        options.insert(
            "@GHC_STATUS_COMPONENT_CACHE_fake".to_string(),
            value.to_string(),
        );
        TmuxWidgetCache::from_options(&options)
    }

    fn tick() -> RenderEvent {
        RenderEvent {
            kind: RenderEventKind::Tick,
        }
    }

    fn context() -> RenderContext {
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
                options: BTreeMap::new(),
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
