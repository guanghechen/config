use std::collections::BTreeMap;

pub trait WidgetCache {
    fn get(&self, widget_id: &str) -> Option<&str>;
    fn set(&mut self, widget_id: &str, value: String);
}

#[derive(Default)]
pub struct TmuxWidgetCache {
    stored: BTreeMap<String, String>,
    pending: BTreeMap<String, String>,
}

impl TmuxWidgetCache {
    pub fn from_options(options: &BTreeMap<String, String>) -> Self {
        let stored = options
            .iter()
            .filter(|(name, _)| name.starts_with(WIDGET_CACHE_OPTION_PREFIX))
            .map(|(name, value)| (name.clone(), value.clone()))
            .collect();
        Self {
            stored,
            pending: BTreeMap::new(),
        }
    }

    pub fn pending_options(&self) -> Vec<(String, String)> {
        self.pending
            .iter()
            .map(|(name, value)| (name.clone(), value.clone()))
            .collect()
    }
}

impl WidgetCache for TmuxWidgetCache {
    fn get(&self, widget_id: &str) -> Option<&str> {
        let option_name = widget_cache_option_name(widget_id);
        self.pending
            .get(&option_name)
            .or_else(|| self.stored.get(&option_name))
            .map(String::as_str)
    }

    fn set(&mut self, widget_id: &str, value: String) {
        if self.get(widget_id) == Some(value.as_str()) {
            return;
        }

        self.pending
            .insert(widget_cache_option_name(widget_id), value);
    }
}

// External tmux option names keep COMPONENT for compatibility with existing cached values.
pub const WIDGET_CACHE_OPTION_PREFIX: &str = "@GHC_STATUS_COMPONENT_CACHE_";

fn widget_cache_option_name(widget_id: &str) -> String {
    let suffix = widget_id
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '_'
            }
        })
        .collect::<String>();
    format!("{WIDGET_CACHE_OPTION_PREFIX}{suffix}")
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{TmuxWidgetCache, WidgetCache, widget_cache_option_name};

    #[test]
    fn stores_one_bounded_slot_per_widget() {
        let mut cache = TmuxWidgetCache::default();
        cache.set("demo", "1".to_string());
        cache.set("demo", "2\twith-tab".to_string());

        assert_eq!(cache.get("demo"), Some("2\twith-tab"));
        assert_eq!(cache.pending_options().len(), 1);
    }

    #[test]
    fn reads_existing_single_slot_cache() {
        let mut options = BTreeMap::new();
        options.insert(widget_cache_option_name("demo"), "value".to_string());
        let cache = TmuxWidgetCache::from_options(&options);
        assert_eq!(cache.get("demo"), Some("value"));
    }

    #[test]
    fn unchanged_set_does_not_create_pending_option() {
        let mut options = BTreeMap::new();
        options.insert(widget_cache_option_name("demo"), "same".to_string());
        let mut cache = TmuxWidgetCache::from_options(&options);
        cache.set("demo", "same".to_string());
        assert!(cache.pending_options().is_empty());
    }
}
