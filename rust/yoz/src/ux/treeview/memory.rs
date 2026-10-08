use super::model::{Error, Fields, NodeData, Result, Value};
use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, Weak};

thread_local! { static CURRENT: RefCell<Option<Arc<Budget>>> = const { RefCell::new(None) }; }

pub(crate) fn check() -> Result<()> {
    CURRENT.with(|current| {
        current
            .borrow()
            .as_ref()
            .map_or(Ok(()), |budget| budget.check())
    })
}

pub(crate) struct Budget {
    used: AtomicUsize,
    limit: usize,
    payloads: Mutex<HashMap<(u8, usize), Weak<Payload>>>,
}

pub(crate) struct Guard(Option<Arc<Budget>>);
impl Drop for Guard {
    fn drop(&mut self) {
        CURRENT.with(|current| *current.borrow_mut() = self.0.take());
    }
}

pub(crate) struct Charge {
    pub budget: Option<Arc<Budget>>,
    bytes: usize,
}

impl Budget {
    pub fn new(limit: usize) -> Arc<Self> {
        Arc::new(Self {
            used: AtomicUsize::new(0),
            limit,
            payloads: Mutex::new(HashMap::new()),
        })
    }
    pub fn enter(self: &Arc<Self>) -> Guard {
        Guard(CURRENT.with(|current| current.borrow_mut().replace(self.clone())))
    }
    pub fn used(&self) -> usize {
        self.used.load(Ordering::Relaxed)
    }
    pub fn check(&self) -> Result<()> {
        if self.used() > self.limit {
            Err(Error::limit(
                "retained Rust treeview memory capacity exceeded",
            ))
        } else {
            Ok(())
        }
    }
    pub fn add(&self, bytes: usize) {
        self.used.fetch_add(bytes, Ordering::Relaxed);
    }
    pub fn remove(&self, bytes: usize) {
        self.used.fetch_sub(bytes, Ordering::Relaxed);
    }
}

impl Charge {
    pub fn new(bytes: usize) -> Self {
        let budget = CURRENT.with(|current| current.borrow().clone());
        if let Some(budget) = &budget {
            budget.add(bytes);
        }
        Self { budget, bytes }
    }
}

impl Drop for Charge {
    fn drop(&mut self) {
        if let Some(budget) = &self.budget {
            budget.remove(self.bytes);
        }
    }
}

enum Owner {
    Text(Arc<str>),
    Bytes(Arc<[u8]>),
    Array(Arc<[Value]>),
    Fields(Fields),
    Data(Arc<NodeData>),
    External(Arc<dyn Send + Sync>, usize),
}

impl Owner {
    fn key(&self) -> (u8, usize) {
        match self {
            Self::Text(value) => (0, Arc::as_ptr(value) as *const () as usize),
            Self::Bytes(value) => (1, Arc::as_ptr(value) as *const () as usize),
            Self::Array(value) => (2, Arc::as_ptr(value) as *const () as usize),
            Self::Fields(value) => (3, Arc::as_ptr(value) as usize),
            Self::Data(value) => (4, Arc::as_ptr(value) as usize),
            Self::External(value, _) => (5, Arc::as_ptr(value) as *const () as usize),
        }
    }
}

/** Keep the allocation alive until its address leaves the ledger; address reuse cannot alias a charge. */
pub(crate) struct Payload {
    charge: Charge,
    owner: Owner,
    _children: Box<[Arc<Payload>]>,
}

impl std::fmt::Debug for Payload {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("Payload")
            .field("bytes", &self.charge.bytes)
            .finish()
    }
}

impl Drop for Payload {
    fn drop(&mut self) {
        if let Some(budget) = &self.charge.budget {
            budget
                .payloads
                .lock()
                .unwrap_or_else(|poison| poison.into_inner())
                .remove(&self.owner.key());
        }
    }
}

impl Payload {
    pub fn external<T: Send + Sync + 'static>(value: Arc<T>, bytes: usize) -> Arc<Self> {
        Self::capture(Owner::External(value, bytes))
    }

    pub fn text(value: Arc<str>) -> Arc<Self> {
        Self::capture(Owner::Text(value))
    }

    pub fn input(pattern: Arc<str>, fields: Fields) -> Arc<[Arc<Self>]> {
        vec![
            Self::capture(Owner::Text(pattern)),
            Self::capture(Owner::Fields(fields)),
        ]
        .into()
    }
    pub fn node(key: Arc<str>, data: Arc<NodeData>) -> Arc<[Arc<Self>]> {
        vec![
            Self::capture(Owner::Text(key)),
            Self::capture(Owner::Data(data)),
        ]
        .into()
    }

    fn capture(owner: Owner) -> Arc<Self> {
        let key = owner.key();
        let bytes = match &owner {
            Owner::Text(value) => value.len(),
            Owner::Bytes(value) => value.len(),
            Owner::Array(value) => value.len() * std::mem::size_of::<Value>(),
            Owner::Fields(value) => {
                std::mem::size_of_val(&**value)
                    + value.len() * (std::mem::size_of::<Value>() + 64)
                    + value.keys().map(String::len).sum::<usize>()
            }
            Owner::Data(_) => std::mem::size_of::<NodeData>(),
            Owner::External(_, bytes) => *bytes,
        };
        let budget = CURRENT.with(|current| current.borrow().clone());
        if let Some(budget) = &budget
            && let Some(existing) = budget
                .payloads
                .lock()
                .unwrap_or_else(|poison| poison.into_inner())
                .get(&key)
                .and_then(Weak::upgrade)
        {
            return existing;
        }
        let mut children = Vec::with_capacity(match &owner {
            Owner::Data(data) => {
                2 + usize::from(data.payload.is_some())
                    + usize::from(data.icon.is_some())
                    + usize::from(data.highlight.is_some())
                    + usize::from(data.right_text.is_some())
            }
            _ => 0,
        });
        let mut values = Vec::new();
        match &owner {
            Owner::Data(data) => {
                for text in [
                    Some(&data.label),
                    data.icon.as_ref(),
                    data.highlight.as_ref(),
                    data.right_text.as_ref(),
                ]
                .into_iter()
                .flatten()
                {
                    children.push(Self::capture(Owner::Text(text.clone())));
                }
                children.push(Self::capture(Owner::Fields(data.fields.clone())));
                if let Some(payload) = &data.payload {
                    children.push(Self::capture(Owner::Bytes(payload.clone())));
                }
            }
            Owner::Fields(fields) => values.extend(fields.values()),
            Owner::Array(array) => values.extend(array.iter()),
            _ => {}
        }
        children.reserve_exact(
            values
                .iter()
                .filter(|value| {
                    matches!(
                        value,
                        Value::String(_) | Value::Bytes(_) | Value::Array(_) | Value::Object(_)
                    )
                })
                .count(),
        );
        for value in values {
            let child = match value {
                Value::String(value) => Some(Owner::Text(value.clone())),
                Value::Bytes(value) => Some(Owner::Bytes(value.clone())),
                Value::Array(value) => Some(Owner::Array(value.clone())),
                Value::Object(value) => Some(Owner::Fields(value.clone())),
                _ => None,
            };
            if let Some(child) = child {
                children.push(Self::capture(child));
            }
        }
        /* Children never grow after capture; snapshots share this exact allocation. */
        let children = children.into_boxed_slice();
        let charge = Charge::new(
            bytes
                + 64
                + std::mem::size_of::<Self>()
                + children.len() * std::mem::size_of::<Arc<Self>>(),
        );
        let result = Arc::new(Self {
            charge,
            owner,
            _children: children,
        });
        if let Some(budget) = budget {
            budget
                .payloads
                .lock()
                .unwrap_or_else(|poison| poison.into_inner())
                .insert(key, Arc::downgrade(&result));
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    #[test]
    fn t_shared_nested_payloads_stay_charged_until_the_last_capture() {
        let budget = Budget::new(1024 * 1024);
        let _guard = budget.enter();
        let text: Arc<str> = "shared text".into();
        let bytes: Arc<[u8]> = vec![7; 1024].into();
        let nested: Fields = Arc::new(BTreeMap::from([
            ("bytes".into(), Value::Bytes(bytes.clone())),
            ("flag".into(), Value::Boolean(true)),
        ]));
        let data = Arc::new(NodeData {
            label: text.clone(),
            icon: Some(text.clone()),
            fields: Arc::new(BTreeMap::from([
                ("number".into(), Value::Integer(1)),
                ("text".into(), Value::String(text)),
                ("object".into(), Value::Object(nested.clone())),
                (
                    "array".into(),
                    Value::Array(
                        vec![Value::Null, Value::Bytes(bytes), Value::Object(nested)].into(),
                    ),
                ),
            ])),
            ..NodeData::default()
        });
        let key: Arc<str> = "node".into();
        let first = Payload::node(key.clone(), data.clone());
        let used = budget.used();
        assert!(used > 1024);
        let second = Payload::node(key, data);
        assert_eq!(budget.used(), used);
        drop(first);
        assert_eq!(budget.used(), used);
        assert!(!budget.payloads.lock().unwrap().is_empty());
        drop(second);
        assert_eq!(budget.used(), 0);
        assert!(budget.payloads.lock().unwrap().is_empty());
    }

    #[test]
    fn t_external_payload_owns_its_allocation_until_ledger_release() {
        let budget = Budget::new(1024 * 1024);
        let _guard = budget.enter();
        let value = Arc::new(vec![3_u8; 1024]);
        let weak = Arc::downgrade(&value);
        let first = Payload::external(value.clone(), 1024);
        let used = budget.used();
        let second = Payload::external(value.clone(), 1024);
        assert_eq!(budget.used(), used);
        drop(value);
        drop(first);
        assert!(weak.upgrade().is_some());
        assert_eq!(budget.used(), used);
        drop(second);
        assert!(weak.upgrade().is_none());
        assert_eq!(budget.used(), 0);
        assert!(budget.payloads.lock().unwrap().is_empty());
    }

    #[test]
    fn t_native_payload_alone_is_charged_and_released() {
        let budget = Budget::new(4096);
        let _guard = budget.enter();
        let bytes: Arc<[u8]> = vec![5; 8192].into();
        let weak = Arc::downgrade(&bytes);
        let retained = Payload::node(
            "native".into(),
            Arc::new(NodeData {
                payload: Some(bytes),
                ..NodeData::leaf("item")
            }),
        );
        assert_eq!(
            budget.check().unwrap_err().code,
            super::super::model::ErrorCode::ResourceLimit
        );
        drop(retained);
        assert!(weak.upgrade().is_none());
        assert_eq!(budget.used(), 0);
    }

    #[test]
    fn t_native_payload_shares_accounting_with_fields_and_retains_its_owner() {
        let budget = Budget::new(1024 * 1024);
        let _guard = budget.enter();
        let bytes: Arc<[u8]> = vec![5; 4096].into();
        let weak = Arc::downgrade(&bytes);
        let fields = Arc::new(BTreeMap::from([(
            "shared".into(),
            Value::Bytes(bytes.clone()),
        )]));
        let data = Arc::new(NodeData {
            fields,
            payload: Some(bytes.clone()),
            ..NodeData::leaf("item")
        });
        let key: Arc<str> = "item".into();
        let first = Payload::node(key.clone(), data.clone());
        let used = budget.used();
        assert!(used >= bytes.len() && used < bytes.len() * 2);
        let second = Payload::node(key, data.clone());
        assert_eq!(budget.used(), used);
        drop(bytes);
        drop(data);
        drop(first);
        assert!(weak.upgrade().is_some());
        assert_eq!(budget.used(), used);
        drop(second);
        assert!(weak.upgrade().is_none());
        assert_eq!(budget.used(), 0);
        assert!(budget.payloads.lock().unwrap().is_empty());
    }
}
