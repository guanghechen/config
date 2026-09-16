use std::collections::BTreeMap;
use std::fmt;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_IDENTITY: AtomicU64 = AtomicU64::new(1);

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct NodeId(pub(crate) u64);

impl NodeId {
    pub fn value(self) -> u64 {
        self.0
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, Ord, PartialEq, PartialOrd)]
pub struct Revision(pub(crate) u64);

impl Revision {
    pub fn value(self) -> u64 {
        self.0
    }

    pub(crate) fn next(self) -> Result<Self> {
        self.0
            .checked_add(1)
            .map(Self)
            .ok_or_else(|| Error::limit("revision exhausted"))
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ErrorCode {
    InvalidUpdate,
    MissingNode,
    Stale,
    Busy,
    Disposed,
    ResourceLimit,
}

impl ErrorCode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::InvalidUpdate => "InvalidUpdate",
            Self::MissingNode => "MissingNode",
            Self::Stale => "Stale",
            Self::Busy => "Busy",
            Self::Disposed => "Disposed",
            Self::ResourceLimit => "ResourceLimit",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Error {
    pub code: ErrorCode,
    pub message: Arc<str>,
    pub node: Option<NodeId>,
}

pub type Result<T> = std::result::Result<T, Error>;

impl Error {
    pub fn new(code: ErrorCode, message: impl Into<Arc<str>>) -> Self {
        Self {
            code,
            message: message.into(),
            node: None,
        }
    }

    pub(crate) fn invalid(message: impl Into<Arc<str>>) -> Self {
        Self::new(ErrorCode::InvalidUpdate, message)
    }

    pub(crate) fn stale(message: impl Into<Arc<str>>) -> Self {
        Self::new(ErrorCode::Stale, message)
    }

    pub(crate) fn limit(message: impl Into<Arc<str>>) -> Self {
        Self::new(ErrorCode::ResourceLimit, message)
    }

    pub(crate) fn missing(node: NodeId) -> Self {
        Self {
            code: ErrorCode::MissingNode,
            message: "node is not alive in this data instance".into(),
            node: Some(node),
        }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.code.as_str(), self.message)
    }
}

impl std::error::Error for Error {}

pub(crate) fn identity() -> Result<u64> {
    NEXT_IDENTITY
        .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |value| {
            value.checked_add(1)
        })
        .map_err(|_| Error::limit("identity space exhausted"))
}

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Null,
    Boolean(bool),
    Integer(i64),
    Number(f64),
    String(Arc<str>),
    Bytes(Arc<[u8]>),
    Array(Arc<[Value]>),
    Object(Arc<BTreeMap<String, Value>>),
}

pub type Fields = Arc<BTreeMap<String, Value>>;

pub(crate) fn empty_fields() -> Fields {
    static EMPTY: std::sync::LazyLock<Fields> =
        std::sync::LazyLock::new(|| Arc::new(BTreeMap::new()));
    EMPTY.clone()
}

#[derive(Clone, Debug, PartialEq)]
pub struct NodeData {
    pub label: Arc<str>,
    pub can_expand: bool,
    pub foldable: bool,
    pub hidden: bool,
    pub score: f64,
    pub icon: Option<Arc<str>>,
    pub highlight: Option<Arc<str>>,
    pub right_text: Option<Arc<str>>,
    pub fields: Fields,
}

impl Default for NodeData {
    fn default() -> Self {
        Self {
            label: "".into(),
            can_expand: false,
            foldable: false,
            hidden: false,
            score: 0.0,
            icon: None,
            highlight: None,
            right_text: None,
            fields: empty_fields(),
        }
    }
}

impl NodeData {
    pub fn leaf(label: impl Into<Arc<str>>) -> Self {
        Self {
            label: label.into(),
            ..Self::default()
        }
    }

    pub fn branch(label: impl Into<Arc<str>>) -> Self {
        Self {
            label: label.into(),
            can_expand: true,
            ..Self::default()
        }
    }

    pub(crate) fn validate(&self) -> Result<usize> {
        let mut bytes = 0usize;
        for text in [
            Some(&self.label),
            self.icon.as_ref(),
            self.highlight.as_ref(),
            self.right_text.as_ref(),
        ]
        .into_iter()
        .flatten()
        {
            if text.bytes().any(|byte| matches!(byte, b'\n' | b'\r' | 0)) {
                return Err(Error::invalid("display text must contain one line"));
            }
            bytes = bytes
                .checked_add(text.len())
                .ok_or_else(|| Error::limit("payload size overflow"))?;
        }
        if !self.score.is_finite() {
            return Err(Error::invalid("sort score must be finite"));
        }
        let mut pending: Vec<_> = self.fields.values().map(|value| (value, 0usize)).collect();
        bytes = bytes
            .checked_add(self.fields.keys().map(String::len).sum::<usize>())
            .ok_or_else(|| Error::limit("payload size overflow"))?;
        while let Some((value, depth)) = pending.pop() {
            if depth > 32 {
                return Err(Error::limit("payload nesting exceeds 32"));
            }
            let size = match value {
                Value::String(text) => text.len(),
                Value::Bytes(data) => data.len(),
                Value::Array(values) => {
                    pending.extend(values.iter().map(|value| (value, depth + 1)));
                    values.len() * std::mem::size_of::<Value>()
                }
                Value::Object(values) => {
                    pending.extend(values.values().map(|value| (value, depth + 1)));
                    values.keys().map(String::len).sum()
                }
                Value::Number(value) if !value.is_finite() => {
                    return Err(Error::invalid("payload numbers must be finite"));
                }
                _ => std::mem::size_of::<Value>(),
            };
            bytes = bytes
                .checked_add(size)
                .ok_or_else(|| Error::limit("payload size overflow"))?;
        }
        Ok(bytes)
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum Completeness {
    #[default]
    Unknown,
    Partial,
    Complete,
}

impl Completeness {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Unknown => "unknown",
            Self::Partial => "partial",
            Self::Complete => "complete",
        }
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum LoadState {
    #[default]
    Idle,
    Loading,
    Error,
}

impl LoadState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Loading => "loading",
            Self::Error => "error",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Scope {
    SelfOnly,
    Subtree,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Root {
    ChildrenOf(NodeId),
    Forest(Arc<[NodeId]>),
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum Mode {
    #[default]
    Tree,
    List,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum Sort {
    #[default]
    Source,
    Name,
    Score,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DisplayOptions {
    pub mode: Mode,
    pub pattern: Arc<str>,
    pub case_sensitive: bool,
    pub show_hidden: bool,
    pub selected_only: bool,
    pub compress: bool,
    pub sort: Sort,
    pub branches_first: bool,
}

impl Default for DisplayOptions {
    fn default() -> Self {
        Self {
            mode: Mode::Tree,
            pattern: "".into(),
            case_sensitive: false,
            show_hidden: true,
            selected_only: false,
            compress: false,
            sort: Sort::Source,
            branches_first: false,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Limits {
    pub memory_bytes: usize,
    pub nodes: usize,
    pub payload_bytes: usize,
    pub states: usize,
    pub views: usize,
    pub queued_actions: usize,
    pub concurrent_reads: usize,
    pub queued_reads: usize,
    pub batch_nodes: usize,
    pub batch_bytes: usize,
}

impl Default for Limits {
    fn default() -> Self {
        Self {
            memory_bytes: 512 * 1024 * 1024,
            nodes: 1_000_000,
            payload_bytes: 256 * 1024 * 1024,
            states: 16,
            views: 64,
            queued_actions: 256,
            concurrent_reads: 8,
            queued_reads: 128,
            batch_nodes: 200_000,
            batch_bytes: 64 * 1024 * 1024,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_revision_overflow_is_a_structured_error() {
        assert_eq!(
            Revision(u64::MAX).next().unwrap_err().code,
            ErrorCode::ResourceLimit
        );
    }

    #[test]
    fn t_invalid_display_input_is_rejected_before_storage() {
        for label in ["a\nb", "a\rb", "a\0b"] {
            assert_eq!(
                NodeData::leaf(label).validate().unwrap_err().code,
                ErrorCode::InvalidUpdate
            );
        }
        let mut node = NodeData::leaf("中文.lua");
        assert_eq!(node.validate().unwrap(), "中文.lua".len());
        node.score = f64::NAN;
        assert!(node.validate().is_err());
    }
}
