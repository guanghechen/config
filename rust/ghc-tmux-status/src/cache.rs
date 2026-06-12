use std::collections::BTreeMap;

pub trait ComponentCache {
    fn get(&self, component_id: &str) -> Option<&str>;
    fn set(&mut self, component_id: &str, value: String);
}

#[derive(Default)]
pub struct TmuxComponentCache {
    stored: BTreeMap<String, String>,
    pending: BTreeMap<String, String>,
}

impl TmuxComponentCache {
    pub fn from_options(options: &BTreeMap<String, String>) -> Self {
        let stored = options
            .iter()
            .filter(|(name, _)| name.starts_with(COMPONENT_CACHE_PREFIX))
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

impl ComponentCache for TmuxComponentCache {
    fn get(&self, component_id: &str) -> Option<&str> {
        let option_name = component_cache_option_name(component_id);
        self.pending
            .get(&option_name)
            .or_else(|| self.stored.get(&option_name))
            .map(String::as_str)
    }

    fn set(&mut self, component_id: &str, value: String) {
        if self.get(component_id) == Some(value.as_str()) {
            return;
        }

        self.pending
            .insert(component_cache_option_name(component_id), value);
    }
}

const COMPONENT_CACHE_PREFIX: &str = "@GHC_STATUS_COMPONENT_CACHE_";

fn component_cache_option_name(component_id: &str) -> String {
    let suffix = component_id
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '_'
            }
        })
        .collect::<String>();
    format!("{COMPONENT_CACHE_PREFIX}{suffix}")
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{ComponentCache, TmuxComponentCache, component_cache_option_name};

    #[test]
    fn stores_one_bounded_slot_per_component() {
        let mut cache = TmuxComponentCache::default();
        cache.set("demo", "1".to_string());
        cache.set("demo", "2\twith-tab".to_string());

        assert_eq!(cache.get("demo"), Some("2\twith-tab"));
        assert_eq!(cache.pending_options().len(), 1);
    }

    #[test]
    fn reads_existing_single_slot_cache() {
        let mut options = BTreeMap::new();
        options.insert(component_cache_option_name("demo"), "value".to_string());
        let cache = TmuxComponentCache::from_options(&options);
        assert_eq!(cache.get("demo"), Some("value"));
    }

    #[test]
    fn unchanged_set_does_not_create_pending_option() {
        let mut options = BTreeMap::new();
        options.insert(component_cache_option_name("demo"), "same".to_string());
        let mut cache = TmuxComponentCache::from_options(&options);
        cache.set("demo", "same".to_string());
        assert!(cache.pending_options().is_empty());
    }
}
