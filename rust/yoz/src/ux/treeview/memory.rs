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
    pub fn shrink(&mut self, bytes: usize) {
        assert!(
            bytes <= self.bytes,
            "cannot grow a memory reservation by shrinking"
        );
        if let Some(budget) = &self.budget {
            budget.remove(self.bytes - bytes);
        }
        self.bytes = bytes;
    }
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

/** Keep the allocation alive until its address leaves the ledger; address reuse cannot alias a charge. */
pub(crate) struct Payload {
    charge: Charge,
    key: (u8, usize),
    _owner: Owner,
    _children: Vec<Arc<Payload>>,
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
                .remove(&self.key);
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
        let (key, bytes) = match &owner {
            Owner::Text(value) => ((0, Arc::as_ptr(value) as *const () as usize), value.len()),
            Owner::Bytes(value) => ((1, Arc::as_ptr(value) as *const () as usize), value.len()),
            Owner::Array(value) => (
                (2, Arc::as_ptr(value) as *const () as usize),
                value.len() * std::mem::size_of::<Value>(),
            ),
            Owner::Fields(value) => (
                (3, Arc::as_ptr(value) as usize),
                std::mem::size_of_val(&**value)
                    + value.len() * (std::mem::size_of::<Value>() + 64)
                    + value.keys().map(String::len).sum::<usize>(),
            ),
            Owner::Data(value) => (
                (4, Arc::as_ptr(value) as usize),
                std::mem::size_of::<NodeData>(),
            ),
            Owner::External(value, bytes) => {
                ((5, Arc::as_ptr(value) as *const () as usize), *bytes)
            }
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
        let mut children = Vec::new();
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
            }
            Owner::Fields(fields) => values.extend(fields.values()),
            Owner::Array(array) => values.extend(array.iter()),
            _ => {}
        }
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
        let charge = Charge::new(
            bytes
                + 64
                + std::mem::size_of::<Self>()
                + children.capacity() * std::mem::size_of::<Arc<Self>>(),
        );
        let result = Arc::new(Self {
            charge,
            key,
            _owner: owner,
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
