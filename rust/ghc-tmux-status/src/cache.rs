use std::collections::BTreeMap;

pub trait ComponentCache {
    fn get(&self, component_id: &str, key: &str) -> Option<&str>;
    fn set(&mut self, component_id: &str, key: &str, value: String);
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
    fn get(&self, component_id: &str, key: &str) -> Option<&str> {
        let option_name = component_cache_option_name(component_id);
        let value = self
            .pending
            .get(&option_name)
            .or_else(|| self.stored.get(&option_name))?;
        get_record(value, key)
    }

    fn set(&mut self, component_id: &str, key: &str, value: String) {
        if self.get(component_id, key) == Some(value.as_str()) {
            return;
        }

        let option_name = component_cache_option_name(component_id);
        let mut records = self
            .pending
            .get(&option_name)
            .or_else(|| self.stored.get(&option_name))
            .map(|value| parse_records(value))
            .unwrap_or_default();
        records.insert(key.to_string(), value);
        self.pending
            .insert(option_name, serialize_records(&records));
    }
}

const COMPONENT_CACHE_PREFIX: &str = "@GHC_STATUS_COMPONENT_CACHE_";
const RECORD_SEP: char = '\u{1e}';

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

fn get_record<'a>(value: &'a str, key: &str) -> Option<&'a str> {
    value.split(RECORD_SEP).find_map(|record| {
        let (record_key, record_value) = record.split_once('\t')?;
        if record_key == key {
            Some(record_value)
        } else {
            None
        }
    })
}

fn parse_records(value: &str) -> BTreeMap<String, String> {
    value
        .split(RECORD_SEP)
        .filter_map(|record| {
            let (key, value) = record.split_once('\t')?;
            Some((key.to_string(), value.to_string()))
        })
        .collect()
}

fn serialize_records(records: &BTreeMap<String, String>) -> String {
    records
        .iter()
        .map(|(key, value)| format!("{key}\t{value}"))
        .collect::<Vec<_>>()
        .join(&RECORD_SEP.to_string())
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{ComponentCache, TmuxComponentCache, component_cache_option_name};

    #[test]
    fn supports_multiple_records_per_component() {
        let mut cache = TmuxComponentCache::default();
        cache.set("demo", "a", "1".to_string());
        cache.set("demo", "b", "2\twith-tab".to_string());

        assert_eq!(cache.get("demo", "a"), Some("1"));
        assert_eq!(cache.get("demo", "b"), Some("2\twith-tab"));
        assert_eq!(cache.pending_options().len(), 1);
    }

    #[test]
    fn reads_legacy_single_record_cache() {
        let mut options = BTreeMap::new();
        options.insert(
            component_cache_option_name("demo"),
            "old\tvalue".to_string(),
        );
        let cache = TmuxComponentCache::from_options(&options);
        assert_eq!(cache.get("demo", "old"), Some("value"));
    }

    #[test]
    fn unchanged_set_does_not_create_pending_option() {
        let mut options = BTreeMap::new();
        options.insert(
            component_cache_option_name("demo"),
            "same\tvalue".to_string(),
        );
        let mut cache = TmuxComponentCache::from_options(&options);
        cache.set("demo", "same", "value".to_string());
        assert!(cache.pending_options().is_empty());
    }
}
