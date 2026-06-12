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
        let (cached_key, cached_value) = value.split_once('\t')?;
        if cached_key == key {
            Some(cached_value)
        } else {
            None
        }
    }

    fn set(&mut self, component_id: &str, key: &str, value: String) {
        self.pending.insert(
            component_cache_option_name(component_id),
            format!("{key}\t{value}"),
        );
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
